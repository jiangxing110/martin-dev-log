# dws_qbit_card_transaction —— Flink v2 参考实现（分表版 / v1）

> 基于 `bi-cost/online` 的目录结构（`table/`、`cdc/`、`batch/`），并借鉴 `bi-cost/flink/quantum-v2/sl` 的成熟范式。
> 本目录实现 **v1：按年分表 `_YYYY`、不重建表、跨年安全**。v2（按年分区单表）见文末路线图。

## 目录结构

```
flink_reference/
├── README.md
├── table/                                                   # 结构参考 + 删除函数（每个 insert 表一套）
│   ├── dws_qbit_card_transaction_ddl.sql                    # transaction 分表结构参考（IF NOT EXISTS，不重建）
│   ├── dws_qbit_card_transaction_extend_ddl.sql             # extend 分表结构参考
│   └── register_fn_dws_qbit_card_transaction_cdc_delete_v2.sql  # 删除函数（动态年份路由，跨年核心）
├── cdc/                                                     # 流作业：每个 insert 表一个脚本
│   ├── dws_qbit_card_transaction-cdc-v2-sql.sql
│   └── dws_qbit_card_transaction_extend-cdc-v2-sql.sql
└── batch/                                                   # 批作业（补数/修复）：每个 insert 表一个脚本
    ├── dws_qbit_card_transaction-batch-sql.sql
    └── dws_qbit_card_transaction_extend-batch-sql.sql
```

> 旧的 `dws_qbit_card_group_transaction_2026` / `dws_transfer_2026` 走的是同一套“先删后插 + 确定性主键”模式，
> 只是业务键不同（group 无 bin、transfer 无 provider/bin），可按上面模板直接补出。

## 为什么这样改（对应你的 4 点）

### 0. pending 长期挂起 = 重复根因
`status=pending` 的交易 `createTime` 与 `updateTime` 不同日。旧任务的三步法
（INSERT → DELETE create≠update → UPDATE 重插）配合 `generate_snowflake_id()` 随机主键 +
`ON CONFLICT(id) DO NOTHING`：**主键永远不冲突 → 去重永不触发**。pending 每次被重写，就在目标表多叠一份，
消费金额被 `SUM` 放大（你的数据里消费 2.27×、退款/冲正基本不变，正是这个特征）。

### 3. 不重建表、不改结构（in-place）
- 复用现有 `dws_qbit_card_transaction_YYYY`（含线上数据）。
- `table/*.sql` 全部用 `CREATE TABLE IF NOT EXISTS`，只做结构补齐，**绝不 DROP / TRUNCATE**。
- 删除函数只 `DELETE`，不碰 DDL。
- 新写入复用现有 `id bigint` 列，只是把“随机雪花 id”换成“确定性哈希 id”，**列类型不变、无需改表**。

### 4. 分表 + 跨年（v1 重点）
- 目标按 `create_date` 年份分表：`_2024/_2025/_2026/_2027…`（源表 `qbit_card_transaction` 本身是单表）。
- **跨年核心在删除函数**：它按“每条变更源行的 `createTime` 年份”动态拼出 `dws_qbit_card_transaction_<year>` 再删除。
  因此「2025-12-31 创建、2026-01-05 才更新」的 pending 行，会正确地清掉 **2025 分表**那一行，
  并由重算写回 **2025 分表**（聚合键永远是 create_date 年份），不会误写进 2026 分表。
- Flink 端每个 `_YYYY` 一个 SINK + 一个按年过滤的 `INSERT` 块。`_2027` 上线时，只需在各脚本
  【分表 SINK + INSERT】段追加一对（复制 2026 块改后缀即可）。

## 幂等机制（按唯一 key 删 + 确定性主键 upsert）

```
删除函数(昨天变更 → 定位受影响唯一业务键 → 对应分表按 key 精准 DELETE)
        ↓
Flink 重算：id = ABS(HASH_CODE(CONCAT(create_date, 业务键)))   ← 确定性主键
        ↓
UPSERT writeMode='upsert' 到对应分表（同 key 覆盖 / 新 key 新增）
```
- **唯一 key = `(create_date, account_id, provider, bin, business_type, status)`**，即其哈希 `id`。
- 删除函数按业务键列精准删（PG 内用 `IS NOT DISTINCT FROM` 直接匹配，无需复现 HASH_CODE），写放大与失败空窗面从“整天”降到“单 key”。
- 确定性 `id` 让重跑产生**同一个主键**；SINK `writeMode='upsert'` 命中即覆盖 → 任意重跑/重试/补跑都只留一份，彻底消除重复。
- 与 quantum-v2 完全一致的思路（`ABS(HASH_CODE(CONCAT(...)))` 而非雪花 id），并进一步把删除粒度从“整天”收紧到“受影响业务键”。

## 运行步骤（先 dry-run，再上线）

```sql
-- 1) 在目标库注册删除函数（一次性）
\i table/register_fn_dws_qbit_card_transaction_cdc_delete_v2.sql

-- 2) 先核对影响行数（不应误删历史），把 cdc 脚本里删除函数调用 false 改 true，或直连执行：
SELECT public.fn_delete_qbit_card_transaction_cdc(true);
SELECT public.fn_delete_qbit_card_transaction_extend_cdc(true);

-- 3) 修复现有脏数据：提交 batch 脚本（默认区间 2026-01-01 ~ 2026-08-17，按需改区间）
--    batch 会先整段删除再确定性重算，把重复/膨胀的消费行一次性校正。

-- 4) 灰度切换：停旧 PG 三步任务，部署 cdc 流作业（每天调度）。
```

## 注意事项 / 已知坑

- **extend 的 `settle_fee` 列**：旧 INSERT 引用了该列，但复制出的 DDL 副本未列出。以线上真实表结构为准；
  若线上确无此列，执行前请删掉 extend 脚本里的 `settle_fee` 写入（或先 `ALTER TABLE ... ADD COLUMN`）。
- **CDC 源全表扫描**：当前源用 JDBC 全量扫描 `qbit_card_transaction`（与 quantum-v2 扫描 DWM 同思路）。
  若源表非常大，建议：(a) 给 `updateTime`/`deleteTime` 加索引并在源子查询加 `scan.query` 收窄；或
  (b) 把源换成 Postgres CDC（Debezium）做真正的流式变更捕获。删除函数本身已按年份路由，切换源不影响跨年逻辑。
- **删除函数调用次数**：每个分表 INSERT 都 `CROSS JOIN` 删除结果，故删除函数会执行多次（幂等，仅多删几次无影响）。
  若想严格只删一次，可把删除函数调用改为 Flink 作业外的独立调度步骤（先删，再跑纯 INSERT 作业）。

## v2 路线图：按年分区单表（你提到的第二版）

v1 的分表靠“删除函数动态拼表名 + Flink 多 SINK”实现跨年，新增年份要改脚本。
**v2 改为按年分区单表**，彻底去掉分表：

```sql
CREATE TABLE dws_qbit_card_transaction (
  ... ,
  create_date DATE NOT NULL,
  PRIMARY KEY (id, create_date)
) PARTITION BY RANGE (create_date);   -- 每年一个分区，如 dws_qbit_card_transaction_2026
```
- 删除函数简化为**单表按 create_date 区间删除**（不再 `EXECUTE format` 拼表名）。
- Flink 端**只需一个 SINK、一个 INSERT**，数据库自动落对应分区；新增 2027 仅 `CREATE PARTITION`，脚本零改动。
- 业务键 / 确定性主键 / 先删后插 完全复用 v1，迁移成本低。
