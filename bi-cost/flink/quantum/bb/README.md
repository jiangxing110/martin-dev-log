# Quantum BB Flink SQL

链路:

- `qbit_card_transaction` + `qbitCardSettlement` -> `dwm_bb_card_transaction_detail_p`
- `dwm_bb_card_transaction_detail_p` -> `dws_bb_card_finance_daily_p`

文件:

- `sp_sync_bb_card_incremental.sql`: CDC 增量同步，ODS 到 DWM
- `sp_init_bb_card_dwm_by_fast.sql`: Batch 初始化/回刷 DWM
- `sp_init_bb_card_dws_by_fast.sql`: Batch 初始化/回刷 DWS
- `table-scripts/dwm_bb_card_transaction_detail_p.sql`: DWM 建表和 2026 月分区
- `table-scripts/dws_bb_card_finance_daily_p.sql`: DWS 建表和 2026 年分区

口径:

- DWM 交易归属按 `transaction_time`
- DWM 通过 `transaction_time` 匹配 `dim_sale_account_relation_p` 获取 `sale_id`、`am_id`
- 销售关系先按交易 `account_id` 直接匹配，direct 没命中时再用 `api_account_relation.root_id` 兜底
- DWS 粒度是 `account_id + report_date + sale_id + am_id`
- `cost_fixed_fee` 只在 DWS，占位为 0，后续通过 `bi_month_tag` 单独更新
