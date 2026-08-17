# qbit-card-cost-cleaning —— Flink v2 参考实现（分表版 / v1，全量）

> 把原 `insert_task_job.sql` 里 **全部 23 个 insert 目标表** 统一改造为幂等的 Flink v2 作业。
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

## 目录结构（共 92 个文件 = 23 表 × 4 件套）

```
flink_reference/
├── gen_all_jobs.py                      # 代码生成器（解析原 insert_task_job.sql → 产出下方全部脚本）
├── README.md / DEPLOY.md                # 本文件 / 运行部署指南
├── table/                               # 23 × (DDL + 删除函数)
│   ├── <base>_ddl.sql                    # 分表结构参考（IF NOT EXISTS，不重建）
│   └── register_fn_<base>_cdc_delete_v2.sql  # 按 key 精准删的删除函数
├── cdc/                                 # 23 × 每日增量作业（BATCH 模式 + 每日定时）
│   └── <base>-cdc-v2-sql.sql
└── batch/                               # 23 × 一次性修复/补数作业
    └── batch-<base>-v2-sql.sql
```

## 23 张目标表与业务键（即删除/upsert 的唯一 key）

| # | 目标表 base | 业务键（唯一 key） |
|---|---|---|
| 01 | ods_sale_am_transaction | transaction_id |
| 02 | dws_qbit_card_wallet_transaction | account_id, business_type, create_date, status |
| 03 | dws_qbit_card_transaction | account_id, provider, bin, business_type, create_date, status |
| 04 | dws_qbit_card_transaction_extend | account_id, provider, bin, business_type, status, transaction_currency, country, create_date |
| 05 | dws_qbit_card_group_transaction | account_id, business_type, create_date, status |
| 06 | dws_transfer | account_id, business_type_detail, business_type_code, settlement_currency, create_date, status, currency |
| 07 | dws_transfer_extend | account_id, create_date, status |
| 08 | dws_crypto_assets_transfers | account_id, status, sender_type, recipient_type, hidden, create_date, currency, action |
| 09 | ods_fund_profits | fund_id |
| 10 | ods_qbit_card | card_id |
| 11 | dws_open_card | status, account_id, provider, bin, create_date |
| 12 | dws_physical_card | account_id, provider, bin, status, create_date |
| 13 | dws_sale_card_wallet_transaction | account_id, business_type, status, create_date, sale_or_am_id |
| 14 | dws_sale_card_transaction | account_id, sale_or_am_id, business_type, status, provider, bin, create_date |
| 15 | dws_sale_card_transaction_extend | account_id, provider, bin, business_type, status, transaction_currency, country, create_date, sale_or_am_id |
| 16 | dws_sale_card_group_transaction | account_id, business_type, status, create_date, sale_or_am_id |
| 17 | dws_sale_transfer | account_id, business_type_detail, business_type_code, settlement_currency, status, currency, create_date, sale_or_am_id |
| 18 | dws_sale_transfer_extend | account_id, create_date, status, sale_or_am_id |
| 19 | dws_sale_crypto_assets_transfers | account_id, status, sender_type, recipient_type, hidden, create_date, currency, action, sale_or_am_id |
| 20 | ods_sale_fund_profits | fund_id |
| 21 | ods_sale_qbit_card | card_id |
| 22 | dws_sale_open_card | status, account_id, provider, bin, sale_or_am_id, create_date |
| 23 | dws_sale_physical_card | account_id, sale_or_am_id, provider, bin, status, create_date |

> DWS 聚合表：业务键 = 原 `GROUP BY` 列。ODS 原始表：业务键 = 源表自然主键（`transaction_id` / `card_id` / `fund_id`）。

## 生成器用法（改了原 SQL 后重跑即可）

```bash
cd flink_reference
python3 gen_all_jobs.py     # 解析 ../old/insert_task_job.sql，覆盖生成 92 个文件
```
- 聚合逻辑**留在 PostgreSQL**（JDBC source 直接跑原版聚合子查询，Flink 只算 id + upsert），类型转换最少、原 SQL 复用度最高。
- 新增一张目标表：只需在原 `insert_task_job.sql` 里加一段 `INSERT INTO ... SELECT ... GROUP BY ...`，重跑生成器即出 4 件套。
- 新增 2027 分表：脚本已为每个 `_YYYY` 留了 2024~2027 的 SINK 与年份路由，扩到 2028 只需在 `YEARS` 列表加一年。

## ⚠️ 上线前必读（参考脚手架性质）

1. **列类型需对照 Flink catalog 校准**：生成器按命名启发式推断 Flink 类型（`amount→DECIMAL(20,4)`、`count→BIGINT`、`id→BIGINT` 等）。UUID / JSON / boolean 等真实类型请按线上 catalog 修正。
2. **嵌套子查询表已打 `[TODO]`**：`ods_sale_fund_profits`、`ods_sale_qbit_card`（其 FROM 含 `UNION ALL` 子查询）等 8 个文件的删除函数“变更窗口引用源别名”可能需人工校准，上线前务必核对 affected-key 子查询是否能正确解析。
3. **先 dry-run**：每个删除函数 `SELECT fn_delete_<base>_cdc(true);` 核对影响行数后再转正。
4. **v1 不改表结构、不删表**，回滚只需停 cdc 作业、重启旧 PG 三步任务。

## 路线图：v2（按年分区单表）

v1 用 `_YYYY` 分表是为兼容现有数据。v2 改为**单表按 `create_date` 分区**（`PARTITION BY RANGE(create_date)`）：
- 删除函数简化为单表区间删除，不再动态拼分表名；
- Flink 只剩一个 SINK，新增年份零改脚本；
- 跨年天然无感（数据落在哪个分区由 `create_date` 决定）。
等历史数据迁移到分区表后切换。
