# Flink 脚本运行参数与同步说明

> 说明：本文只列业务运行参数，不列 `${secret_values.*}` 这类环境密钥。

## 1. 需要传入或替换业务参数的脚本

| 脚本 | 作业类型 | 运行参数 | 说明 |
| --- | --- | --- | --- |
| `dwm_online_api_client_bill-batch-sql.sql` | 批处理 | `start_date`, `end_date` | 按账单月份范围回刷 API 客户账单指标。 |
| `profit/sp_init_gross_profit_daily_by_fast.sql` | 批处理 | `start_date`, `end_date` | 按日期范围生成毛利 DWS。 |
| `quantum/sl/sp_init_sl_card_dwm_by_fast.sql` | 批处理 | `start_time`, `end_time` | 按 SL settlement 创建时间窗口回刷 DWM。 |
| `quantum/sl/sp_init_sl_card_dwm_by_fast_v2.sql` | 批处理 | `start_time`, `end_time` | V2 批量回刷版本，按时间窗口读取分区数据。 |
| `total_cost/sp_init_finance_channel_cost_by_fast.sql` | 批处理 | `source_month`, `next_month`, `product_line`, `provider`, `source_tag`, `cost_type` | V1 金融渠道成本脚本，一次处理一个产品线/渠道/指标。 |
| `total_cost/sp_init_finance_channel_cost_by_fast_v2.sql` | 批处理 | `source_month`, `next_month` | V2 金融渠道成本脚本，一次处理当月全部 bi_month_tag 成本数据。 |
| `total_cost/finance/sp_init_acquiring_cost.sql` | 批处理 | `start_time`, `end_time` | 收单金融渠道成本，按 `ods_bi_month_tag.update_time` 窗口回刷，默认昨天。 |
| `total_cost/finance/sp_init_crypto_asset_cost.sql` | 批处理 | `start_time`, `end_time` | 加密资产金融渠道成本汇总脚本，按 `ods_bi_month_tag.update_time` 窗口回刷，默认昨天。 |
| `total_cost/finance/sp_init_global_account_cost.sql` | 批处理 | `start_time`, `end_time` | 全球账户金融渠道成本汇总脚本，按 `ods_bi_month_tag.update_time` 窗口回刷，默认昨天。 |
| `total_cost/finance/sp_init_quantum_card_cost.sql` | 批处理 | `start_time`, `end_time` | 量子卡金融渠道成本汇总脚本，按 `ods_bi_month_tag.update_time` 窗口回刷，默认昨天。 |
| `total_cost/finance/crypto_assets/sp_init_crypto_asset_bitstamp_cost.sql` | 批处理 | `start_time`, `end_time` | Bitstamp 成本，按 `ods_bi_month_tag.update_time` 窗口回刷，默认昨天。 |
| `total_cost/finance/crypto_assets/sp_init_crypto_asset_cregis_cost.sql` | 批处理 | `start_time`, `end_time` | Cregis 成本，按 `ods_bi_month_tag.update_time` 窗口回刷，默认昨天。 |
| `total_cost/finance/crypto_assets/sp_init_crypto_asset_safeheron_cost.sql` | 批处理 | `start_time`, `end_time` | Safeheron 成本，按 `ods_bi_month_tag.update_time` 窗口回刷，默认昨天。 |
| `total_cost/finance/crypto_assets/sp_init_crypto_asset_th_cost.sql` | 批处理 | `start_time`, `end_time` | Thunes 成本，按 `ods_bi_month_tag.update_time` 窗口回刷，默认昨天。 |
| `total_cost/finance/crypto_assets/sp_init_crypto_asset_tz_cost.sql` | 批处理 | `start_time`, `end_time` | TZ 成本，按 `ods_bi_month_tag.update_time` 窗口回刷，默认昨天。 |
| `total_cost/finance/global_account/sp_init_global_account_bz_cost.sql` | 批处理 | `start_time`, `end_time` | BZ 成本，按 `ods_bi_month_tag.update_time` 窗口回刷，默认昨天。 |
| `total_cost/finance/global_account/sp_init_global_account_cl_cost.sql` | 批处理 | `start_time`, `end_time` | CL 成本，按 `ods_bi_month_tag.update_time` 窗口回刷，默认昨天。 |
| `total_cost/finance/quantum_card/sp_init_quantum_card_bpc_cost.sql` | 批处理 | `start_time`, `end_time` | BPC 成本，按 `ods_bi_month_tag.update_time` 窗口回刷，默认昨天。 |
| `total_cost/finance/quantum_card/sp_init_quantum_card_hz_bank_cost.sql` | 批处理 | `start_time`, `end_time` | HZ 银行手续费，按 `ods_bi_month_tag.update_time` 窗口回刷，默认昨天。 |
| `total_cost/finance/quantum_card/sp_init_quantum_card_idemia_cost.sql` | 批处理 | `start_time`, `end_time` | IDEMIA 制卡成本，按 `ods_bi_month_tag.update_time` 窗口回刷，默认昨天。 |
| `total_cost/finance/quantum_card/sp_init_quantum_card_sumsub_cost.sql` | 批处理 | `start_time`, `end_time` | Sumsub KYC 成本，按 `ods_bi_month_tag.update_time` 窗口回刷，默认昨天。 |

## 2. 无业务运行参数的脚本

以下脚本只依赖 `${secret_values.*}` 环境密钥，部署时不需要额外传业务参数：

- `account_relation/sp_init_dim_sale_account_relation_by_fast.sql`
- `account_relation/sp_sync_dim_sale_account_relation_incremental.sql`
- `ods/sp_init_crypto_assets_addresses_ods.sql`
- `ods/sp_init_crypto_assets_transactions_ods.sql`
- `ods/sp_init_crypto_blockchain_transfers_ods.sql`
- `ods/sp_init_global_sub_account_ods.sql`
- `ods/sp_init_idv_channel_request_record_ods.sql`
- `ods/sp_init_payment_transaction_record_ods.sql`
- `ods/sp_init_qbit_physical_card_ods.sql`
- `ods/sp_sync_qbit_card_settlement_ods.sql`
- `ods/sp_sync_qbit_card_settlement_sl_ods.sql`
- `quantum/bb/sp_init_bb_card_dwm_by_fast.sql`
- `quantum/bb/sp_init_bb_card_dws_by_fast.sql`
- `quantum/bb/sp_sync_bb_card_incremental.sql`
- `quantum/qi/sp_init_qi_card_dwm_by_fast.sql`
- `quantum/qi/sp_init_qi_card_dws_by_fast.sql`
- `quantum/qi/sp_sync_qi_card_incremental.sql`
- `quantum/sl/sp_init_sl_card_dws_by_fast.sql`
- `quantum/sl/sp_sync_sl_card_incremental.sql`
- `total_cost/sp_init_total_channel_cost_by_fast.sql`

## 3. ODS/DIM 源库变更同步说明

### ODS

ODS 原始层需要做到“源库表变更，ODS 跟着变”。当前以下脚本使用 `postgres-cdc`，可以监听源库 INSERT/UPDATE/DELETE 并写入对应 ODS 表：

| 脚本 | 原始库表 | ODS 表 |
| --- | --- | --- |
| `ods/sp_sync_qbit_card_settlement_ods.sql` | `public.qbitCardSettlement` | `ods.ods_qbit_card_settlement` |
| `ods/sp_sync_qbit_card_settlement_sl_ods.sql` | `public.qbitCardSettlement` | `ods.ods_qbit_card_settlement_sl` |
| `ods/sp_init_qbit_physical_card_ods.sql` | `public.qbitPhysicalCard` | `ods.ods_qbit_physical_card` |
| `ods/sp_init_global_sub_account_ods.sql` | `public.globalSubAccount` | `ods.ods_global_sub_account` |
| `ods/sp_init_crypto_assets_transactions_ods.sql` | `public.crypto_assets_transactions` | `ods.ods_crypto_assets_transactions` |
| `ods/sp_init_crypto_assets_addresses_ods.sql` | `public.crypto_assets_addresses` | `ods.ods_crypto_assets_addresses` |
| `ods/sp_init_idv_channel_request_record_ods.sql` | `public.idv_channel_request_record` | `ods.ods_idv_channel_request_record` |
| `ods/sp_init_payment_transaction_record_ods.sql` | `public.payment_transaction_record` | `ods.ods_payment_transaction_record` |

例外：`ods/sp_init_crypto_blockchain_transfers_ods.sql` 的源是 `view_crypto_assets_blockchain_transfers`，不是普通业务表 CDC 源。它需要依赖上游 ODS/MV 刷新后批量重跑。

### DIM

销售关系 DIM 的持续同步由以下脚本承担：

| 脚本 | 原始库表 | DIM 表 | 说明 |
| --- | --- | --- | --- |
| `account_relation/sp_sync_dim_sale_account_relation_incremental.sql` | `public.salesAccountRelation` | `dim.dim_sale_account_relation_p` | CDC 增量同步，源表变更后 DIM 跟着变。 |
| `account_relation/sp_init_dim_sale_account_relation_by_fast.sql` | `public.salesAccountRelation` | `dim.dim_sale_account_relation_p` | 批处理初始化/回刷，不承担持续同步。 |

## 4. 部署建议

1. ODS/DIM CDC 作业常驻运行，用来保证源库表变更能进 ODS/DIM。
2. DWM/DWS/total_cost/profit 类脚本按批处理调度，依赖 ODS/DIM 已经同步到最新。
3. 金融渠道成本类脚本建议按月执行，`source_month` 固定为当月第一天，`next_month` 固定为下月第一天。
4. `sp_init_finance_channel_cost_by_fast_v2.sql` 适合一次处理当月全部 `bi_month_tag` 成本；V1 适合单指标补跑。
