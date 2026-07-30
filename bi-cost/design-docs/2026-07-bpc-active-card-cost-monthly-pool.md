# BPC QI 活跃卡成本月度客户池修正方案

## 摘要

BPC 的 `ACTIVE_CARD_COST` 是 QI 活跃卡客户均摊成本，客户池必须按费用月份独立计算。拆分作业当前没有把 `source_month` 从活跃客户池一路带到分摊明细，多个费用月份同时回刷时会把客户池混在一起，导致不同月份使用同一个均摊分母。

本次修正只调整 `flink/total_cost/finance/quantum_card/dwm_online_quantum_card_bpc_cost-batch-sql.sql` 的 BPC 拆分作业，使其与合并作业 `online/batch/total_cost/finance/dwm_online_quantum_card_cost-batch-sql.sql` 的月度口径一致。

## 业务口径

BPC 来源为每月明细数据，统计时间记为当月第一天。假设统计 2026-04：

```sql
SELECT "accountId"
FROM "qbitCard"
WHERE provider LIKE '%Qbit%'
  AND ("deleteCardTime" > '2026-04-01 00:00:00' OR "deleteCardTime" IS NULL)
GROUP BY "accountId";
```

月度 BPC 金额按当月符合条件的 `account_id` 均摊，再按当月自然日展开到每日成本。每个客户在同一个月份的日成本一致，但不同月份的客户池和分母可以不同，所以不同月份的成本不应被混成同一批客户均摊。

## 根因

拆分作业中：

1. `v_bpc_accounts` 只输出 `account_id`，丢失 `source_month`。
2. `v_bpc_basis` 使用 `CROSS JOIN v_month_days`，把所有入参月份的日期都套到同一客户池上。
3. `v_cost_basis_month_total` 未按 `source_month` 聚合，月分母会跨月累计。
4. `v_allocated_cost_base` 与 `v_bi_month_tag_cost` 未按 `source_month` 关联，可能让费用月份与分摊基数错配。

因此当 `start_time/end_time` 命中多个费用月份时，BPC 客户池、分母和金额关联都会跨月。

## 修正方案

1. `v_month_days` 保留 `source_month`。
2. `v_bpc_accounts` 输出并按 `source_month, account_id` 聚合。
3. `v_bpc_basis` 通过 `source_month` 关联当月日期，不再跨月展开。
4. `v_cost_basis_month_total` 按 `source_month, product_line, provider, cost_type` 聚合。
5. `v_cost_basis` 和 `v_allocated_cost_base` 按 `source_month` 关联月度分母和月度金额。

## 验收口径

回刷多个月份时，每个月的 BPC 结果应满足：

- `month_basis_count` 等于当月 QI 活跃卡客户数。
- 同一个 `source_month` 内，单客户每日 `allocation_rate = 1 / month_basis_count / month_day_count`。
- 不同 `source_month` 的 `month_basis_count` 可以不同。
- `source_month = 2026-04-01` 的客户池只使用 `delete_card_time > 2026-04-01 00:00:00 OR delete_card_time IS NULL` 判断，不被其他月份客户池影响。
