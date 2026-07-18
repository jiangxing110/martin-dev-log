# Quantum SL Flink 版

本目录收纳 SL 渠道在阿里云实时计算 Flink 版下的完整落地材料：

- `sp_sync_sl_card_incremental.sql`：CDC 增量同步，`qbitCardSettlement` 直入 DWM
- `sp_init_sl_card_dwm_by_fast.sql`：Batch 初始化/回刷 DWM
- `sp_init_sl_card_dws_by_fast.sql`：Batch 初始化/回刷 DWS

## 口径

- `DWM` 直接消费 `qbitCardSettlement`，不再单独落 ODS / DWD
- `DWM.id` 沿用 `qbitCardSettlement.id`
- `DWM` 按 `settlement_date` 月分区，主键为 `id + settlement_date`
- `DWM` 通过 `qbitCardSettlement.qbitCardTransactionId` 关联 `qbit_card_transaction`
- `DWM` 里的销售归属按 `qbit_card_transaction.transactionTime` 匹配 `dim_sale_account_relation_p`
- 销售关系先按交易 `account_id` 直接匹配，direct 没命中时再用 `api_account_relation.root_id` 兜底
- `DWS.rebate_base` 来源于 DWM 的 `billing_amount`
- `DWS.rebate_amt` 按 DWM 的 `country` 计算：美国 2%，非美国 0.5%
- `DWS.cost_fixed_fee` 当前先写 0，后续通过 `bi_month_tag` 单独更新
- `DWS` 同一天允许同一客户出现多条记录，只要销售或 AM 归属不同
- 当前目录只保留 DWM / DWS 两层

## 执行顺序

历史初始化：

1. 先跑 `sp_init_sl_card_dwm_by_fast.sql`
2. 再跑 `sp_init_sl_card_dws_by_fast.sql`

日常增量：

1. 跑 `sp_sync_sl_card_incremental.sql`
2. 再按需跑 `sp_init_sl_card_dws_by_fast.sql` 回刷受影响日期
