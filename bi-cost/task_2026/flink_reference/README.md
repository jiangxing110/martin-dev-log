# qbit-card-cost-cleaning —— Flink v2 参考实现（分表版 / v1，全量）

> 把原 `insert_task_job.sql` 里的交易与销售统计目标表统一改造为幂等的 Flink v2 作业。
> 目录结构对齐 `bi-cost/online`（`table/` `cdc/` `batch/`），范式借鉴 `bi-cost/flink/quantum-v2/sl`。

## 核心改造（对应你提出的“按唯一 key 删/写”）

原 PG 任务用 `generate_snowflake_id()` + `ON CONFLICT(id) DO NOTHING`，**主键随机、非幂等**，
pending 长期挂起 → 反复重写 → 消费行被叠加放大（你贴的数据里消费 2.27×、退款冲正基本不变，正是此特征）。

v2 改为：

1. **确定性主键** `id = ABS(HASH_CODE(CONCAT(业务键)))` —— 同一业务键永远算出同一个 id。
2. **按唯一业务键精准删**：删除函数 `fn_delete_<base>_cdc` 用
   `WHERE (业务键列) IN (SELECT DISTINCT 业务键 FROM 源 WHERE 变更窗口)`，**只清受影响的那几个聚合行**，
   不再“按整天删”（修复你指出的空洞/放大问题）。
3. **upsert 写回**：SINK `writeMode='upsert'`，主键命中即覆盖、新 key 才新增 → 任意重跑/补跑只留一份。
4. **不重建表**：复用现有 `dws_*` / `ods_*` 分表，DDL 用 `IF NOT EXISTS` 仅作结构参考。
5. **跨年（分表 _YYYY）**：删除函数按源行 `createTime` 的**年份**动态路由分表；v2 会改成按年分区单表（见末）。

## sale 维度表：基于 `dim_sale_account_relation_p` 的作用域重算

11 张 sale 维度表（`dws_sale_*` 9 张 + `ods_sale_fund_profits` + `ods_sale_qbit_card`）直接通过 `dim.dim_sale_account_relation_p` 获取销售/AM 关系。`sale_id` 与 `am_id` 不同则输出两条，相同则只输出一条。

- **删除按作用域(scope)而非唯一键**：删除函数 `fn_delete_<base>_cdc` 用
  `WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT 作用域日期, account_id FROM 源 WHERE 变更窗口) scope WHERE DATE(目标.日期列)=scope.日期 AND 目标.account_id=scope.account_id)`，
  **整段清空该 (日期,账户) 的聚合行后重算**，而非只删当前业务键行。这彻底解决“pending 状态长期挂起后翻转→旧状态行残留/重复”的问题（也对应你“不应该按唯一 key 删”的要求）。
- **三通道变更窗口**：窗口条件为
  `createTime OR updateTime OR deleteTime` 任一个落在昨天。原 INSERT 块从不引用 `updateTime`，但 qbit 系源表实际有该列——若不纳入，status 翻转等长尾更新仍会被漏掉、陈旧行清不掉。**`updateTime`/`update_time` 按源表名硬编码强制纳入**（见 `gen_all_jobs.py` 的 `SALE_TIMECOLS`）。
- **关系匹配**：按交易发生时间匹配关系有效期，账户直接关系优先，root account 关系兜底；销售关系变化需要触发对应日期和账户重算。
- 其余 11 张非 sale 表**维持唯一键精准删**不变。
- 生成器通过 `SALE_SET` 分支实现，改原 `insert_task_job.sql` 后重跑 `python3 gen_all_jobs.py` 即同步。

## 目录结构（22 个目标表；删除函数统一合并为 1 个 SQL）

```
flink_reference/
├── gen_all_jobs.py                      # 代码生成器（解析原 insert_task_job.sql → 产出下方全部脚本）
├── README.md / DEPLOY.md                # 本文件 / 运行部署指南
├── table/                               # 22 个 DDL + 1 个删除函数汇总文件
 │   ├── <base>_ddl.sql                    # 分表结构参考（IF NOT EXISTS，不重建）
 │   └── register_all_delete_functions_v2.sql  # 一次注册全部 22 个删除函数
├── cdc/                                 # 22 × 每日增量作业（BATCH 模式 + 每日定时）
│   └── <base>_v2-cdc-sql.sql
└── batch/                               # 22 × 一次性修复/补数作业
    └── <base>_v2-batch-sql.sql
```

## 22 张目标表与业务键（即删除/upsert 的唯一 key）

| # | 目标表 base | 业务键（唯一 key） |
|---|---|---|
| 01 | dws_qbit_card_wallet_transaction | account_id, business_type, create_date, status |
| 02 | dws_qbit_card_transaction | account_id, provider, bin, business_type, create_date, status |
| 03 | dws_qbit_card_transaction_extend | account_id, provider, bin, business_type, status, transaction_currency, country, create_date |
| 04 | dws_qbit_card_group_transaction | account_id, business_type, create_date, status |
| 05 | dws_transfer | account_id, business_type_detail, business_type_code, settlement_currency, create_date, status, currency |
| 06 | dws_transfer_extend | account_id, create_date, status |
| 07 | dws_crypto_assets_transfers | account_id, status, sender_type, recipient_type, hidden, create_date, currency, action |
| 08 | ods_fund_profits | fund_id |
| 09 | ods_qbit_card | card_id |
| 10 | dws_open_card | status, account_id, provider, bin, create_date |
| 11 | dws_physical_card | account_id, provider, bin, status, create_date |
| 12 | dws_sale_card_wallet_transaction | account_id, business_type, status, create_date, sale_or_am_id |
| 13 | dws_sale_card_transaction | account_id, sale_or_am_id, business_type, status, provider, bin, create_date |
| 14 | dws_sale_card_transaction_extend | account_id, provider, bin, business_type, status, transaction_currency, country, create_date, sale_or_am_id |
| 15 | dws_sale_card_group_transaction | account_id, business_type, status, create_date, sale_or_am_id |
| 16 | dws_sale_transfer | account_id, business_type_detail, business_type_code, settlement_currency, status, currency, create_date, sale_or_am_id |
| 17 | dws_sale_transfer_extend | account_id, create_date, status, sale_or_am_id |
| 18 | dws_sale_crypto_assets_transfers | account_id, status, sender_type, recipient_type, hidden, create_date, currency, action, sale_or_am_id |
| 19 | ods_sale_fund_profits | fund_id |
| 20 | ods_sale_qbit_card | card_id |
| 21 | dws_sale_open_card | status, account_id, provider, bin, sale_or_am_id, create_date |
| 22 | dws_sale_physical_card | account_id, sale_or_am_id, provider, bin, status, create_date |

> DWS 聚合表：业务键 = 原 `GROUP BY` 列。ODS 原始表：业务键 = 源表自然主键（`transaction_id` / `card_id` / `fund_id`）。

## 生成器用法（改了原 SQL 后重跑即可）

```bash
cd flink_reference
python3 gen_all_jobs.py     # 解析 ../insert_task_job.sql，生成 67 个文件（cdc/batch 各 22 + table DDL 22 + 删除函数汇总 1）
```
- 聚合逻辑**留在 PostgreSQL**（JDBC source 直接跑原版聚合子查询，Flink 只算 id + upsert），类型转换最少、原 SQL 复用度最高。
- 新增一张目标表：只需在原 `insert_task_job.sql` 里加一段 `INSERT INTO ... SELECT ... GROUP BY ...`，重跑生成器即出 4 件套。
- 年份分表范围：**`YEARS = [2024, 2025, 2026]`（不含 2027）**。2027 表尚未生成，且 2.0 可能改分区表，故脚本不产出 2027 的 SINK / DDL / 年份路由。需要 2027 时，在 `gen_all_jobs.py` 的 `YEARS` 列表补回 `2027` 并重跑生成器即可（路由边界自动延展）。

## ⚠️ 上线前必读（参考脚手架性质）

1. **列类型需对照 Flink catalog 校准**：生成器按命名启发式推断 Flink 类型（`amount→DECIMAL(20,4)`、`count→BIGINT`、`id→BIGINT` 等）。UUID / JSON / boolean 等真实类型请按线上 catalog 修正。
2. **销售统计关系需人工核对**：`dim_sale_account_relation_p` 的关系有效期、直接账户与 root account 的优先级，以及关系变化触发的重算范围必须与线上口径一致。
3. **引号转义已处理**：删除函数用 `format($fmt$...$fmt$)` 美元引号包住含 `INTERVAL '1 day'` 的 SQL；Flink `table-name` 属性值内单引号已转义为 `''`（如 `INTERVAL ''1 day''`、`''0000...UUID''`）。**重改生成器后重跑前请勿手动去掉转义**。
4. **先 dry-run**：每个删除函数 `SELECT fn_delete_<base>_cdc(true);` 核对影响行数后再转正。
5. **v1 不改表结构、不删表**，回滚只需停 cdc 作业、重启旧 PG 三步任务。

## 路线图：v2（按年分区单表）

v1 用 `_YYYY` 分表是为兼容现有数据。v2 改为**单表按 `create_date` 分区**（`PARTITION BY RANGE(create_date)`）：
- 删除函数简化为单表区间删除，不再动态拼分表名；
- Flink 只剩一个 SINK，新增年份零改脚本；
- 跨年天然无感（数据落在哪个分区由 `create_date` 决定）。
等历史数据迁移到分区表后切换。
