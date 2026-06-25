# BI Cost Flink 作业运维说明

**目标**

整理 `bi-cost/flink` 目录下的 Flink SQL 作业类型、运行参数、ODS/DIM 变更同步规则，方便后续运维、调度和交接。

**适用范围**

本文只描述 `bi-cost/flink` 下的可运行 SQL 作业，不包含 `table-scripts/*.sql` 这类纯 DDL/视图脚本的业务逻辑。

---

## 1. 作业分类

### 1.1 流处理 CDC

这类作业直接监听原始 PostgreSQL 业务表变更，源库表一旦发生 `INSERT / UPDATE / DELETE`，ODS 或 DIM 会跟着更新。

当前典型作业：

- `ods/sp_sync_qbit_card_settlement_ods.sql`
- `ods/sp_sync_qbit_card_settlement_sl_ods.sql`
- `ods/sp_init_qbit_physical_card_ods.sql`
- `ods/sp_init_global_sub_account_ods.sql`
- `ods/sp_init_crypto_assets_addresses_ods.sql`
- `ods/sp_init_crypto_assets_transactions_ods.sql`
- `ods/sp_init_idv_channel_request_record_ods.sql`
- `ods/sp_init_payment_transaction_record_ods.sql`
- `account_relation/sp_sync_dim_sale_account_relation_incremental.sql`
- `quantum/bb/sp_sync_bb_card_incremental.sql`
- `quantum/qi/sp_sync_qi_card_incremental.sql`

### 1.2 批处理

这类作业按调度窗口或月度参数重跑，不依赖常驻 CDC 监听。它们通常消费已经落好的 ODS/DIM，或直接消费业务查询结果、账单表、月度配置表。

当前典型作业：

- `quantum/sl/sp_init_sl_card_dwm_by_fast.sql`
- `quantum/sl/sp_init_sl_card_dwm_by_fast_v2.sql`
- `quantum/sl/sp_init_sl_card_dws_by_fast.sql`
- `quantum/sl/sp_sync_sl_card_incremental.sql`
- `quantum/bb/sp_init_bb_card_dwm_by_fast.sql`
- `quantum/bb/sp_init_bb_card_dws_by_fast.sql`
- `profit/sp_init_gross_profit_daily_by_fast.sql`
- `dwm_online_api_client_bill-batch-sql.sql`
- `total_cost/sp_init_finance_channel_cost_by_fast.sql`
- `total_cost/sp_init_finance_channel_cost_by_fast_v2.sql`
- `total_cost/sp_init_total_channel_cost_by_fast.sql`
- `total_cost/finance/*.sql`

### 1.3 例外脚本

`ods/sp_init_crypto_blockchain_transfers_ods.sql` 是派生视图同步脚本，源不是普通业务表 CDC，而是 `view_crypto_assets_blockchain_transfers`。

这类脚本的规则是：

- 先保证上游 ODS / MV 刷新完成
- 再调度本脚本重跑
- 不按标准 `postgres-cdc` 常驻源表处理

### 1.4 纯 DDL / 视图脚本

这类文件只负责建表、建索引、建视图，不作为 Flink 作业部署：

- `*/table-scripts/*.sql`
- `profit/vw_gross_profit_daily.sql`

---

## 2. ODS 与 DIM 的变更规则

### 2.1 ODS

ODS 原始层的目标是“源库变，ODS 也变”。

因此，凡是从 PostgreSQL 原始业务表同步到 ODS 的作业，应该使用 `postgres-cdc`。

这意味着：

- ODS 作业要能常驻运行
- 源库的新增、修改、删除都要持续写入 ODS
- 下游 DWM / DWS 只消费最新 ODS 数据，不直接连原始库

### 2.2 DIM

DIM 层里真正需要随源库变化同步的表，也应该有自己的 CDC 增量作业。

当前最关键的是销售关系维表：

- 源表：`public.salesAccountRelation`
- 目标表：`dim.dim_sale_account_relation_p`
- 增量作业：`account_relation/sp_sync_dim_sale_account_relation_incremental.sql`

这张 DIM 的作用是：

- 保存销售关系时间线
- 供 DWM 按 `account_id + 交易时间` 匹配 `sale_id / am_id`
- 源关系变更后，维表也跟着变

`account_relation/sp_init_dim_sale_account_relation_by_fast.sql` 只负责初始化和回刷，不承担持续同步。

---

## 3. 运行参数

### 3.1 需要显式传参的批处理

这些作业在运维时需要传入时间窗口或月份参数：

- `dwm_online_api_client_bill-batch-sql.sql`
  - `start_date`
  - `end_date`

- `profit/sp_init_gross_profit_daily_by_fast.sql`
  - `start_date`
  - `end_date`

- `quantum/sl/sp_init_sl_card_dwm_by_fast.sql`
  - `start_time`
  - `end_time`

- `quantum/sl/sp_init_sl_card_dwm_by_fast_v2.sql`
  - `start_time`
  - `end_time`

- `total_cost/sp_init_finance_channel_cost_by_fast.sql`
  - `source_month`
  - `next_month`
  - `product_line`
  - `provider`
  - `source_tag`
  - `cost_type`

- `total_cost/sp_init_finance_channel_cost_by_fast_v2.sql`
  - `source_month`
  - `next_month`

- `total_cost/finance/*.sql`
  - 通常使用 `source_month`
  - `next_month`

### 3.2 无业务参数脚本

以下脚本通常只依赖环境密钥 `secret_values`，不需要额外的业务运行参数：

- `ods/*.sql`
- `account_relation/*.sql`
- `quantum/bb/*.sql`
- `quantum/qi/*.sql`
- `quantum/sl/sp_init_sl_card_dws_by_fast.sql`
- `quantum/sl/sp_sync_sl_card_incremental.sql`
- `total_cost/sp_init_total_channel_cost_by_fast.sql`

---

## 4. 调度建议

### 4.1 常驻作业

以下作业建议作为常驻任务运行：

- ODS CDC 作业
- DIM 销售关系 CDC 作业

它们负责把源库变化持续同步到 ODS / DIM。

### 4.2 批量作业

以下作业建议按天、按月或按窗口调度执行：

- DWM / DWS 作业
- profit 作业
- total_cost 作业

这类作业不直接监听原始库，而是依赖最新的 ODS / DIM。

### 4.3 金融成本作业

金融成本类脚本建议按月执行：

- `source_month` 固定为当月第一天
- `next_month` 固定为下月第一天
- 月度账单、配置表、分摊基数都按同一月份口径处理

---

## 5. 运维口径

### 5.1 看到脚本名时怎么判断

- `sp_sync_*` 且 source 是 `postgres-cdc`，一般是流处理 CDC
- `sp_init_*_by_fast.sql` 一般是批处理初始化或回刷
- `sp_sync_sl_card_incremental.sql` 虽然带 `sync`，但当前是日增量批处理，不是常驻 CDC
- `table-scripts/*.sql` 是建表/建视图，不是作业

### 5.2 ODS / DIM 变更传播链路

推荐理解成这条链路：

`原始库 -> ODS CDC -> DIM CDC -> DWM/DWS 批处理 -> total_cost / profit`

这样能保证：

- 源库一变，ODS 跟着变
- 销售关系维表跟着变
- 下游 DWM / DWS / 毛利 / 总成本只做重算，不直连源库

### 5.3 例外处理

如果上游是视图或物化视图，不是普通业务表，则不能强行套 CDC。  
这种情况必须先刷新上游，再重跑下游脚本。

---

## 6. 交接建议

后续交接时，建议按下面的顺序说明：

1. 先讲 ODS / DIM 是否常驻 CDC
2. 再讲 DWM / DWS 的批量回刷窗口
3. 再讲 total_cost / profit 的月度参数
4. 最后讲例外脚本和派生视图脚本

