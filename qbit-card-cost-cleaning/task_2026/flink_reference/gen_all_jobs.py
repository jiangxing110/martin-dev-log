#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_all_jobs.py
================
从 old/insert_task_job.sql 解析出每张 insert 目标表，按 quantum-v2 范式
（确定性哈希主键 + 按唯一业务键精准删 + upsert）生成 4 件套：

  flink_reference/
    table/<base>_ddl.sql                        # IF NOT EXISTS，不重建现有表
    table/register_fn_<base>_cdc_delete_v2.sql # 删除函数（真·按 key 删）
    cdc/<base>-cdc-v2-sql.sql                  # 每日增量（BATCH 定时）
    batch/<base>-batch-sql.sql                 # 一次性修复/补数

设计要点：
  * 聚合逻辑留在 PostgreSQL（JDBC source 子查询直接跑原版聚合），Flink 只算 id + upsert，
    类型转换最少、原 SQL 复用度最高。
  * 删除函数用 `(业务键) IN (SELECT DISTINCT 业务键 FROM 源 WHERE 变更窗口)` 精准删受影响 key，
    不再按“整天”删（修复用户指出的一致性问题）。
  * 删除函数按 create_date 年份动态路由分表（跨年安全，v1 要求）。
  * 不重建表：DDL 用 IF NOT EXISTS，仅作结构参考。

注意：生成结果是“参考脚手架”，上线前需对照线上 Flink catalog 校准列类型
（尤其 UUID / JSON / boolean 等），以及对少数复杂聚合（如 sale_transfer_extend 嵌套子查询）做复核。
"""
import re, os, sys

SRC = os.path.join(os.path.dirname(__file__), "..", "old", "insert_task_job.sql")
OUT = os.path.dirname(__file__)
YEARS = [2024, 2025, 2026, 2027]

# ODS 原始表（无 GROUP BY）的业务键（源表自然主键），用 override 指定
ODS_KEYS = {
    "ods_sale_am_transaction": ["transaction_id"],
    "ods_qbit_card": ["card_id"],
    "ods_sale_qbit_card": ["card_id"],
    "ods_fund_profits": ["fund_id"],
    "ods_fund_profits_2026": ["fund_id"],
    "ods_sale_fund_profits": ["fund_id"],
    "ods_sale_fund_profits_2026": ["fund_id"],
}

# ---------------------------------------------------------------------------
# 解析工具
# ---------------------------------------------------------------------------
def split_args(s):
    """括号感知地按逗号切分（CASE/SUM 内的逗号不切）。"""
    parts, depth, cur = [], 0, ""
    for ch in s:
        if ch == ",":
            if depth == 0:
                parts.append(cur); cur = ""
            else:
                cur += ch
        elif ch in "([":
            depth += 1; cur += ch
        elif ch in ")]":
            depth -= 1; cur += ch
        else:
            cur += ch
    if cur.strip():
        parts.append(cur)
    return [p.strip() for p in parts]

def split_blocks(raw):
    """按 INSERT INTO 切分，返回 [(section, target_raw, block)]。"""
    blocks = re.split(r'(?m)(?=^\s*INSERT INTO)', raw)
    out = []
    for b in blocks:
        if not b.strip():
            continue
        target = None
        m1 = re.search(r'INSERT INTO\s+("?)public\1\.("?)([\w]+)\2', b)
        if m1:
            target = m1.group(3)
        else:
            m2 = re.search(r'INSERT INTO\s+("?)([\w]+)\1\s*\(', b)
            if m2:
                target = m2.group(2)
        if not target:
            continue
        sm = re.search(r'--\s*(\d+)\.\s*INSERT', b)
        section = sm.group(1) if sm else "??"
        out.append((section, target, b))
    return out

def parse_block(block):
    """解析单块：列、SELECT 体、GROUP BY、FROM..JOIN、WHERE。"""
    sel_idx = block.index("SELECT")
    head = block[:sel_idx]
    op = head.index("(")
    cp = head.rindex(")")
    cols = [c.strip().strip('"') for c in split_args(head[op+1:cp])]
    # SELECT 体（到 ON CONFLICT 之前）
    after = block[sel_idx:]
    sel_body = after.split("ON CONFLICT")[0].strip()
    # FROM..JOIN（关键字大小写敏感，避免误匹配标识符中的 FROM/WHERE 等）
    from_m = re.search(r'\bFROM\b\s+(.*?)(?:\bWHERE\b|\bGROUP BY\b|$)', sel_body, re.DOTALL)
    from_join = from_m.group(1).strip() if from_m else ""
    # WHERE
    where_m = re.search(r'\bWHERE\b\s+(.*?)(?:\bGROUP BY\b|$)', sel_body, re.DOTALL)
    where = where_m.group(1).strip() if where_m else ""
    # GROUP BY
    gb_m = re.search(r'\bGROUP BY\b\s+(.*?)(?:\bON CONFLICT\b|;|$)', sel_body, re.DOTALL)
    group_by = gb_m.group(1).strip() if gb_m else None
    # SELECT 列表（FROM 之前）；sel_body 保持原大小写，FROM 关键字全大写
    sel_list = sel_body[len("SELECT"):sel_body.index("FROM")].strip()
    exprs = split_args(sel_list)
    return {
        "cols": cols,
        "exprs": exprs,            # 与 cols 对齐；exprs[0] 通常是 generate_snowflake_id()
        "from_join": from_join,
        "where": where,
        "group_by": group_by,
    }

# ---------------------------------------------------------------------------
# 业务键推导
# ---------------------------------------------------------------------------
def _norm(s):
    """归一化：去引号、去多余空格、小写，便于 GROUP BY 列引用与 SELECT 表达式对齐。"""
    return s.replace('"', '').replace("'", "").strip().lower()

def _strip_alias(e):
    """去掉 SELECT 表达式尾部 AS 别名（兼容带引号：AS "bin" / AS bin）。"""
    return re.sub(r'\s+AS\s+"?[\w]+"?\s*$', '', e, flags=re.IGNORECASE).strip()

def derive_business_keys(p):
    cols, exprs, group_by = p["cols"], p["exprs"], p["group_by"]
    if group_by is None:
        return None  # ODS
    group_by = group_by.rstrip(";").strip()
    gb_tokens = [t.strip().rstrip(";") for t in split_args(group_by)]
    keys = []
    for tok in gb_tokens:
        ntok = _norm(tok)
        if ntok in [_norm(c) for c in cols]:
            c = cols[[_norm(c) for c in cols].index(ntok)]
            if c not in keys:
                keys.append(c)
            continue
        # 匹配 SELECT 表达式（去掉尾部 AS 别名）
        matched = False
        for i, e in enumerate(exprs):
            e0 = _norm(_strip_alias(e))
            if e0 == ntok or ntok in e0:
                c = cols[i]
                if c not in keys:
                    keys.append(c)
                matched = True
                break
        if not matched:
            # 兜底：当作列名（已是 DWS 列名则直接用，否则保留 token 去掉引号）
            fb = tok.replace('"', '').strip()
            if fb not in keys:
                keys.append(fb)
    return keys

# ---------------------------------------------------------------------------
# PG 表达式构造
# ---------------------------------------------------------------------------
def find_time_cols(from_join):
    """检测源表里出现的时间列，返回 dict: create/update/delete -> 列引用(含别名)。"""
    res = {"create": None, "update": None, "delete": None}
    for kind, pat in [("create", r'(\w+\."(?:createTime|create_time)")'),
                      ("update", r'(\w+\."(?:updateTime|update_time)")'),
                      ("delete", r'(\w+\."(?:deleteTime|delete_time)")')]:
        m = re.search(pat, from_join)
        if m:
            res[kind] = m.group(1)
    return res

def change_window(time_cols):
    """变更窗口：create/update/delete 任一在昨天。"""
    conds = []
    for kind in ("create", "update", "delete"):
        c = time_cols.get(kind)
        if c:
            conds.append(f'({c} >= CURRENT_DATE - INTERVAL \'1 day\' AND {c} < CURRENT_DATE)')
    if not conds:
        return 'FALSE'
    return " OR ".join(conds)

def remove_create_window(where):
    """去掉原 WHERE 里的 createTime 昨天窗口条件。"""
    if not where:
        return ""
    pat = r'\s*AND\s*\w+\."(?:createTime|create_time)"\s*>=\s*CURRENT_DATE\s*-\s*INTERVAL\s*\'1 day\'\s*AND\s*\w+\."(?:createTime|create_time)"\s*<\s*CURRENT_DATE'
    w = re.sub(pat, '', where, flags=re.IGNORECASE)
    w = re.sub(r'^\s*AND\s+', '', w, flags=re.IGNORECASE)
    w = re.sub(r'\s+AND\s*$', '', w, flags=re.IGNORECASE)
    return w.strip()

def create_date_expr(time_cols):
    c = time_cols.get("create")
    return f'DATE({c})' if c else 'CURRENT_DATE'

def dws_key_exprs(base, keys, p, time_cols):
    """返回 (dws_key_cols_csv, pg_key_exprs_csv)
    pg_key_exprs 用于删除函数的 IN 子查询，类型需与 DWS 列一致。"""
    cols, exprs = p["cols"], p["exprs"]
    expr_by_col = {}
    for i, c in enumerate(cols):
        expr_by_col[c] = _strip_alias(exprs[i])
    pg_exprs = []
    for k in keys:
        if k == "create_date":
            pg_exprs.append(create_date_expr(time_cols))
        else:
            pg_exprs.append(expr_by_col.get(k, k))
    return ", ".join(keys), ", ".join(pg_exprs)

# ---------------------------------------------------------------------------
# Flink 类型映射（DWS 列 -> Flink 类型）
# ---------------------------------------------------------------------------
def flink_type(col):
    c = col.lower()
    if c in ("create_date", "date"):
        return "DATE"
    if c in ("create_time", "update_time", "delete_time"):
        return "TIMESTAMP(6)"
    if c in ("transaction_count", "count", "version"):
        return "BIGINT"
    if c in ("hidden",):
        return "BOOLEAN"
    if any(t in c for t in ("amount", "fee", "profit", "share", "net_value", "apr",
                            "usd_amount", "origin_amount", "settle_amount", "fx_fee",
                            "atm_fee", "apple_pay_fee", "settle_fee", "cross_chain_fee",
                            "physical_card_fee", "conversion_fx_amount", "conversion_fx_fee",
                            "inbound_profit", "conversion_fx_profit", "exchange_profit",
                            "withdraw_fee_diff", "dbs_receive", "cl_receive", "ep_receive",
                            "rd_receive", "settle_fx_fee", "service_fee", "fee2",
                            "rate_diff_income", "from_amount")):
        return "DECIMAL(20,4)"
    if c == "id":
        return "BIGINT"
    return "STRING"

# ---------------------------------------------------------------------------
# 文件内容生成
# ---------------------------------------------------------------------------
SET_BLOCK = """SET 'parallelism.default' = '1';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'sink.parallelism' = '1';
SET 'table.dml-sync' = 'true';
SET 'execution.checkpointing.interval' = '5min';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'execution.checkpointing.timeout' = '30min';
SET 'table.optimizer.reuse-source-enabled' = 'true';
SET 'table.optimizer.reuse-sub-plan-enabled' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';
"""

def src_cols_decl(cols):
    """JDBC source 输出列声明（聚合结果列，不含 id）。"""
    return ",\n    ".join(f"{c} {flink_type(c)}" for c in cols[1:])

def jdbc_src_block(base, cols, pg_subquery):
    return f"""CREATE TEMPORARY TABLE source_{base} (
    {src_cols_decl(cols)}
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${{secret_values.ADB_PG_VPC_HOSTNAME}}:${{secret_values.ADB_PG_VPC_PORT}}/${{secret_values.ADB_PG_DATABASE}}?stringtype=unspecified',
    'table-name' = '({pg_subquery}) AS src',
    'username' = '${{secret_values.ADB_PG_USERNAME}}',
    'password' = '${{secret_values.ADB_PG_PASSWORD}}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);"""

def delete_fn_block(base, keys, pg_key_exprs, from_join, change_win, create_expr):
    keycols = keys
    n = len(keycols)
    # IN 子查询：左侧 DWS 列，右侧源表达式，顺序一致
    left = ", ".join(keycols)
    # 删除函数体
    body = f"""CREATE OR REPLACE FUNCTION public.fn_delete_{base}_cdc(
    p_dry_run BOOLEAN DEFAULT false,
    p_start   DATE DEFAULT NULL,
    p_end     DATE DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $function$
DECLARE
    affected BIGINT := 0;
    v_year   INT;
    v_n      BIGINT;
BEGIN
    IF p_start IS NULL THEN
        -- ===== CDC 模式：按唯一业务键精准删（受影响 key 集合，不再按整天删）=====
        FOR v_year IN
            SELECT DISTINCT EXTRACT(YEAR FROM {create_expr})::INT
            FROM {from_join}
            WHERE {change_win}
        LOOP
            IF p_dry_run THEN
                EXECUTE format('SELECT COUNT(*) FROM public.{base}_%s WHERE ({left}) IN (SELECT DISTINCT {pg_key_exprs} FROM {from_join} WHERE {change_win})', v_year) INTO v_n;
            ELSE
                EXECUTE format('DELETE FROM public.{base}_%s WHERE ({left}) IN (SELECT DISTINCT {pg_key_exprs} FROM {from_join} WHERE {change_win})', v_year);
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    ELSE
        -- ===== 补数/修复模式：按 create_date 区间跨分表清理 =====
        FOR v_year IN
            SELECT DISTINCT gs.y
            FROM generate_series(EXTRACT(YEAR FROM p_start)::INT, EXTRACT(YEAR FROM p_end)::INT) gs(y)
        LOOP
            IF p_dry_run THEN
                EXECUTE format('SELECT COUNT(*) FROM public.{base}_%s WHERE create_date >= $1 AND create_date <= $2', v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format('DELETE FROM public.{base}_%s WHERE create_date >= $1 AND create_date <= $2', v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_{base}_cdc(true);
"""
    return body

def cdc_block(base, cols, keys, pg_subquery):
    # Flink key exprs（基于 source 输出列名）
    flink_keys = []
    for k in keys:
        if k == "create_date":
            flink_keys.append(f"DATE_FORMAT(create_date, 'yyyy-MM-dd')")
        else:
            flink_keys.append(f"COALESCE({k}, '')")
    id_expr = "CAST(ABS(HASH_CODE(CONCAT(" + ", ': ', ".join(flink_keys) + "))) AS BIGINT)"
    out_cols = ["id"] + cols[1:]
    sink_cols = ", ".join(out_cols)
    # sinks
    sinks = []
    inserts = []
    for y in YEARS:
        ycols = ", ".join(f"{c} {flink_type(c)}" for c in out_cols)
        sinks.append(f"""CREATE TEMPORARY TABLE sink_{base}_{y} (
    {ycols},
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${{secret_values.ADB_PG_VPC_HOSTNAME}}:${{secret_values.ADB_PG_VPC_PORT}}/${{secret_values.ADB_PG_DATABASE}}','tableName'='public.{base}_{y}','userName'='${{secret_values.ADB_PG_USERNAME}}','password'='${{secret_values.ADB_PG_PASSWORD}}','writeMode'='upsert','batchSize'='2000');""")
        y_start = f"{y}-01-01"; y_end = f"{y+1}-01-01"
        inserts.append(f"""INSERT INTO sink_{base}_{y}
SELECT {sink_cols}
FROM v_{base}_base
CROSS JOIN source_delete_{base}_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '{y_start}' AND create_date < DATE '{y_end}';""")
    return f"""{SET_BLOCK}
-- ==============================================
-- 0. 先调用删除函数：按唯一业务键精准清空受影响分表行（先清后写，保证幂等）
-- ==============================================
CREATE TEMPORARY TABLE source_delete_{base}_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${{secret_values.ADB_PG_VPC_HOSTNAME}}:${{secret_values.ADB_PG_VPC_PORT}}/${{secret_values.ADB_PG_DATABASE}}',
    'table-name' = '(SELECT public.fn_delete_{base}_cdc(false) AS affected_rows) AS delete_result',
    'username' = '${{secret_values.ADB_PG_USERNAME}}',
    'password' = '${{secret_values.ADB_PG_PASSWORD}}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

-- ==============================================
-- 1. 源聚合（留在 PostgreSQL 内执行，复用原版聚合逻辑；只回传受影响 key 的聚合结果）
-- ==============================================
CREATE TEMPORARY TABLE source_{base} (
    {src_cols_decl(cols)}
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${{secret_values.ADB_PG_VPC_HOSTNAME}}:${{secret_values.ADB_PG_VPC_PORT}}/${{secret_values.ADB_PG_DATABASE}}?stringtype=unspecified',
    'table-name' = '({pg_subquery}) AS src',
    'username' = '${{secret_values.ADB_PG_USERNAME}}',
    'password' = '${{secret_values.ADB_PG_PASSWORD}}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

-- ==============================================
-- 2. 聚合结果视图：计算确定性主键 id = HASH(业务键)
--    （source_{base} 已输出聚合列，此处只补 id；列名与 DWS 表一致）
-- ==============================================
CREATE TEMPORARY VIEW v_{base}_base AS
SELECT
    {id_expr} AS id,
    *
FROM source_{base};

-- ==============================================
-- 3. 分表 SINK（每个 _YYYY 一个，upsert 按 key 幂等）
-- ==============================================
{chr(10).join(sinks)}

-- ==============================================
-- 4. 写入（CROSS JOIN 确保删除函数先执行；upsert 覆盖同 key / 新增异 key）
-- ==============================================
{chr(10).join(inserts)}
"""

def batch_block(base, cols, keys, from_join, where_no_window, pg_key_exprs, create_expr, pg_subquery):
    out_cols = ["id"] + cols[1:]
    sink_cols = ", ".join(out_cols)
    flink_keys = []
    for k in keys:
        if k == "create_date":
            flink_keys.append("DATE_FORMAT(create_date, 'yyyy-MM-dd')")
        else:
            flink_keys.append(f"COALESCE({k}, '')")
    id_expr = "CAST(ABS(HASH_CODE(CONCAT(" + ", ': ', ".join(flink_keys) + "))) AS BIGINT)"
    sinks = []
    inserts = []
    for y in YEARS:
        ycols = ", ".join(f"{c} {flink_type(c)}" for c in out_cols)
        sinks.append(f"""CREATE TEMPORARY TABLE sink_{base}_{y} (
    {ycols},
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${{secret_values.ADB_PG_VPC_HOSTNAME}}:${{secret_values.ADB_PG_VPC_PORT}}/${{secret_values.ADB_PG_DATABASE}}','tableName'='public.{base}_{y}','userName'='${{secret_values.ADB_PG_USERNAME}}','password'='${{secret_values.ADB_PG_PASSWORD}}','writeMode'='upsert','batchSize'='2000');""")
        y_start = f"{y}-01-01"; y_end = f"{y+1}-01-01"
        inserts.append(f"""INSERT INTO sink_{base}_{y}
SELECT {sink_cols}
FROM v_{base}_base
CROSS JOIN source_delete_{base}_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '{y_start}' AND create_date < DATE '{y_end}';""")
    # batch 用日期区间清理（修复模式），默认 2026 全量；可改
    return f"""{SET_BLOCK}
-- 说明：batch 用于一次性修复/补数。删除函数走“修复模式”(传入 p_start/p_end)，按 create_date
--       区间整段清理后由下方重算 upsert 覆盖（幂等）。默认区间 2026-01-01~2026-08-17，按需调整。

CREATE TEMPORARY TABLE source_delete_{base}_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${{secret_values.ADB_PG_VPC_HOSTNAME}}:${{secret_values.ADB_PG_VPC_PORT}}/${{secret_values.ADB_PG_DATABASE}}',
    'table-name' = '(SELECT public.fn_delete_{base}_cdc(false, DATE ''2026-01-01'', DATE ''2026-08-17'') AS affected_rows) AS delete_result',
    'username' = '${{secret_values.ADB_PG_USERNAME}}',
    'password' = '${{secret_values.ADB_PG_PASSWORD}}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

CREATE TEMPORARY TABLE source_{base} (
    {src_cols_decl(cols)}
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${{secret_values.ADB_PG_VPC_HOSTNAME}}:${{secret_values.ADB_PG_VPC_PORT}}/${{secret_values.ADB_PG_DATABASE}}?stringtype=unspecified',
    'table-name' = '({pg_subquery}) AS src',
    'username' = '${{secret_values.ADB_PG_USERNAME}}',
    'password' = '${{secret_values.ADB_PG_PASSWORD}}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

CREATE TEMPORARY VIEW v_{base}_base AS
SELECT
    {id_expr} AS id,
    *
FROM source_{base};

{chr(10).join(sinks)}

{chr(10).join(inserts)}
"""

def ddl_block(base, cols):
    col_defs = []
    for c in cols:
        col_defs.append(f'    "{c}" {flink_type(c)},')
    body = ",\n".join(col_defs).rstrip(",")
    # 对每个分表生成 IF NOT EXISTS（不重建现有表）
    creates = []
    for y in YEARS:
        creates.append(f"""CREATE TABLE IF NOT EXISTS public.{base}_{y} (
{body}
);""")
    return "\n\n".join(creates) + "\n"

# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
def main():
    raw = open(SRC, encoding="utf-8").read()
    blocks = split_blocks(raw)
    for section, target, block in blocks:
        base = re.sub(r'_\d{4}$', '', target)  # 去掉 _2026 等
        p = parse_block(block)
        is_ods = (p["group_by"] is None)
        if is_ods:
            keys = ODS_KEYS.get(base)
            if not keys:
                # 默认用首列（通常是源 id 映射列）作为键
                keys = [p["cols"][1]] if len(p["cols"]) > 1 else ["id"]
                print(f"[WARN] {base}: ODS 未配置业务键，使用 {keys}", file=sys.stderr)
        else:
            keys = derive_business_keys(p)
            if not keys:
                print(f"[WARN] {base}: 未推导到业务键，跳过", file=sys.stderr)
                continue
        time_cols = find_time_cols(block)
        change_win = change_window(time_cols)
        where_no_window = remove_create_window(p["where"])
        create_expr = create_date_expr(time_cols)
        dws_keys, pg_key_exprs = dws_key_exprs(base, keys, p, time_cols)

        # 聚合 SELECT（去掉 id 列）
        agg_select = ", ".join(p["exprs"][1:])
        # PG 重算子查询：CTE 找受影响 key，再聚合这些 key 的当前有效源行
        key_exprs_aliased = ", ".join(f"{e} AS k{i}" for i, e in enumerate(pg_key_exprs.split(", ")))
        if is_ods:
            # ODS 原始表：直接取受影响 key 的源行（无聚合）
            pg_subquery = f"""WITH affected AS (
        SELECT DISTINCT {key_exprs_aliased}
        FROM {p['from_join']}
        WHERE {change_win}
    )
    SELECT {agg_select}
    FROM {p['from_join']}
    JOIN affected a ON {" AND ".join(f"({pg_key_exprs.split(', ')[i]}) IS NOT DISTINCT FROM a.k{i}" for i in range(len(keys)))}
    WHERE {'TRUE' if not where_no_window else where_no_window}"""
        else:
            key_eq = " AND ".join(f"({pg_key_exprs.split(', ')[i]}) IS NOT DISTINCT FROM a.k{i}" for i in range(len(keys)))
            pg_subquery = f"""WITH affected AS (
        SELECT DISTINCT {key_exprs_aliased}
        FROM {p['from_join']}
        WHERE {change_win}
    )
    SELECT {agg_select}
    FROM {p['from_join']}
    JOIN affected a ON {key_eq}
    WHERE {'TRUE' if not where_no_window else where_no_window}
    GROUP BY {p['group_by']}"""

        # 嵌套子查询 / 非标准 FROM 的表：原 SELECT 的 FROM 含子查询，
        # 通用解析对“变更窗口引用源别名”可能失效，打上 TODO 标记由人工复核。
        fj_up = p["from_join"].upper()
        nested = fj_up.strip().startswith("(") or fj_up.count(" FROM ") > 1 or " FROM (" in fj_up
        todo = (f"-- [TODO] {base} 检测到嵌套/非标准 FROM（{p['from_join'].strip()[:40]}...），\n"
                f"--        删除函数的变更窗口与聚合子查询的源别名引用可能需要人工校准，上线前务必核对。\n"
                if nested else "")

        # 写文件
        tdir = os.path.join(OUT, "table"); cdir = os.path.join(OUT, "cdc"); bdir = os.path.join(OUT, "batch")
        for d in (tdir, cdir, bdir):
            os.makedirs(d, exist_ok=True)
        with open(os.path.join(tdir, f"{base}_ddl.sql"), "w", encoding="utf-8") as f:
            f.write(todo + f"-- {base} DDL（IF NOT EXISTS，不重建现有表）\n" + ddl_block(base, p["cols"]))
        with open(os.path.join(tdir, f"register_fn_{base}_cdc_delete_v2.sql"), "w", encoding="utf-8") as f:
            f.write(todo + delete_fn_block(base, keys, pg_key_exprs, p["from_join"], change_win, create_expr))
        with open(os.path.join(cdir, f"{base}-cdc-v2-sql.sql"), "w", encoding="utf-8") as f:
            f.write(todo + cdc_block(base, p["cols"], keys, pg_subquery))
        with open(os.path.join(bdir, f"batch-{base}-v2-sql.sql"), "w", encoding="utf-8") as f:
            f.write(todo + batch_block(base, p["cols"], keys, p["from_join"], where_no_window, pg_key_exprs, create_expr, pg_subquery))
        print(f"[OK] {section:>2} {base:<45} keys={dws_keys}")

if __name__ == "__main__":
    main()
