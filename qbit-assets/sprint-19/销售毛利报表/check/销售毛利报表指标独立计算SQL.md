# 销售毛利报表指标独立计算 SQL

## 说明

- 以下 SQL 从 `dws.dws_sales_gross_profit_snapshot_detail_p` 按销售维度汇总，适用于核对接口/看板使用的快照结果。
- 示例时间范围为 2026-09。`report_date >= 起始日 AND report_date < 结束日次日`，结束日包含在查询范围内；需要其他区间时替换日期。
- 每条 SQL 都可单独执行，并取每个 `settlement_month` 最新的 `snapshot_date`，适用于跨月时间范围。
- 过滤 `sale_id IS NOT NULL`，不统计无销售归属的数据。需要核对某一位销售时，可在 `WHERE` 追加 `AND src.sale_id = '销售ID'`。
- `saleName` 不在 SQL 中关联查询；按约定由接口根据 `sale_id` 查询用户信息后填充。
- 金额保留原始正负值，不归零、不截断。

## 指标口径

| 指标 | 计算口径 |
|---|---|
| Revenue / Pref_Rev | `SUM(pref_rev)` |
| Client Rebate | `SUM(client_rebate)` |
| Collection Rebate | `SUM(client_collection_rebate)` |
| Gross Profit Rebate | `SUM(gross_profit_rebate)`；当前兼容字段，已并入返现合计，视图目前为 0 |
| Rebate | `SUM(rebate)`；等于客户返现 + 代收返现 + 毛利返现 |
| Effective Revenue / Pref_Rev_effective | `SUM(pref_rev_effective)`；公式为 `pref_rev - rebate` |
| Cost | `SUM(cost)` |
| Gross Profit / Pref_GP | `SUM(pref_gp)`；估算视图公式为 `pref_rev - cost + physical_card_gp` |
| Cash Flow Revenue / Cashflow_Rev_sale | `SUM(cashflow_rev_sale)` |
| Cash Flow Effective Revenue | `SUM(cashflow_rev_sale_effective)`；公式为 `cashflow_rev_sale - rebate` |
| Cash Flow Gross Profit | `SUM(cashflow_gp_sale)`；估算视图公式为 `cashflow_rev_sale - cost + physical_card_gp` |

快照表没有单独存储 `physical_card_gp`，所以毛利指标必须汇总快照中已算好的 `pref_gp` / `cashflow_gp_sale`，不能仅用收入减成本重算。当前接口实现的是销售维度的 `Cashflow_Rev_sale` 系列；通用 `Cashflow_Rev` 系列和“毛利-实收”暂未作为独立指标实现。

## 1. Revenue / Pref_Rev

```sql
SELECT src.sale_id, SUM(src.pref_rev) AS pref_rev
FROM dws.dws_sales_gross_profit_snapshot_detail_p src
WHERE src.delete_time IS NULL
  AND src.report_date >= DATE '2026-09-01'
  AND src.report_date <  DATE '2026-10-01'
  AND src.sale_id IS NOT NULL
  AND src.snapshot_date = (
      SELECT MAX(s.snapshot_date)
      FROM dws.dws_sales_gross_profit_snapshot_detail_p s
      WHERE s.delete_time IS NULL
        AND s.settlement_month = src.settlement_month
  )
GROUP BY src.sale_id;
```

## 2. Client Rebate

```sql
SELECT src.sale_id, SUM(src.client_rebate) AS client_rebate
FROM dws.dws_sales_gross_profit_snapshot_detail_p src
WHERE src.delete_time IS NULL
  AND src.report_date >= DATE '2026-09-01'
  AND src.report_date <  DATE '2026-10-01'
  AND src.sale_id IS NOT NULL
  AND src.snapshot_date = (
      SELECT MAX(s.snapshot_date)
      FROM dws.dws_sales_gross_profit_snapshot_detail_p s
      WHERE s.delete_time IS NULL
        AND s.settlement_month = src.settlement_month
  )
GROUP BY src.sale_id;
```

## 3. Collection Rebate

```sql
SELECT src.sale_id, SUM(src.client_collection_rebate) AS client_collection_rebate
FROM dws.dws_sales_gross_profit_snapshot_detail_p src
WHERE src.delete_time IS NULL
  AND src.report_date >= DATE '2026-09-01'
  AND src.report_date <  DATE '2026-10-01'
  AND src.sale_id IS NOT NULL
  AND src.snapshot_date = (
      SELECT MAX(s.snapshot_date)
      FROM dws.dws_sales_gross_profit_snapshot_detail_p s
      WHERE s.delete_time IS NULL
        AND s.settlement_month = src.settlement_month
  )
GROUP BY src.sale_id;
```

## 4. Gross Profit Rebate

```sql
SELECT src.sale_id, SUM(src.gross_profit_rebate) AS gross_profit_rebate
FROM dws.dws_sales_gross_profit_snapshot_detail_p src
WHERE src.delete_time IS NULL
  AND src.report_date >= DATE '2026-09-01'
  AND src.report_date <  DATE '2026-10-01'
  AND src.sale_id IS NOT NULL
  AND src.snapshot_date = (
      SELECT MAX(s.snapshot_date)
      FROM dws.dws_sales_gross_profit_snapshot_detail_p s
      WHERE s.delete_time IS NULL
        AND s.settlement_month = src.settlement_month
  )
GROUP BY src.sale_id;
```

## 5. Rebate

直接汇总快照已计算字段：

```sql
SELECT src.sale_id, SUM(src.rebate) AS rebate
FROM dws.dws_sales_gross_profit_snapshot_detail_p src
WHERE src.delete_time IS NULL
  AND src.report_date >= DATE '2026-09-01'
  AND src.report_date <  DATE '2026-10-01'
  AND src.sale_id IS NOT NULL
  AND src.snapshot_date = (
      SELECT MAX(s.snapshot_date)
      FROM dws.dws_sales_gross_profit_snapshot_detail_p s
      WHERE s.delete_time IS NULL
        AND s.settlement_month = src.settlement_month
  )
GROUP BY src.sale_id;
```

校验组成项之和：

```sql
SELECT
    src.sale_id,
    SUM(src.client_rebate + src.client_collection_rebate + src.gross_profit_rebate) AS rebate_from_components
FROM dws.dws_sales_gross_profit_snapshot_detail_p src
WHERE src.delete_time IS NULL
  AND src.report_date >= DATE '2026-09-01'
  AND src.report_date <  DATE '2026-10-01'
  AND src.sale_id IS NOT NULL
  AND src.snapshot_date = (
      SELECT MAX(s.snapshot_date)
      FROM dws.dws_sales_gross_profit_snapshot_detail_p s
      WHERE s.delete_time IS NULL
        AND s.settlement_month = src.settlement_month
  )
GROUP BY src.sale_id;
```

## 6. Effective Revenue / Pref_Rev_effective

直接汇总快照字段：

```sql
SELECT src.sale_id, SUM(src.pref_rev_effective) AS pref_rev_effective
FROM dws.dws_sales_gross_profit_snapshot_detail_p src
WHERE src.delete_time IS NULL
  AND src.report_date >= DATE '2026-09-01'
  AND src.report_date <  DATE '2026-10-01'
  AND src.sale_id IS NOT NULL
  AND src.snapshot_date = (
      SELECT MAX(s.snapshot_date)
      FROM dws.dws_sales_gross_profit_snapshot_detail_p s
      WHERE s.delete_time IS NULL
        AND s.settlement_month = src.settlement_month
  )
GROUP BY src.sale_id;
```

## 7. Cost

```sql
SELECT src.sale_id, SUM(src.cost) AS cost
FROM dws.dws_sales_gross_profit_snapshot_detail_p src
WHERE src.delete_time IS NULL
  AND src.report_date >= DATE '2026-09-01'
  AND src.report_date <  DATE '2026-10-01'
  AND src.sale_id IS NOT NULL
  AND src.snapshot_date = (
      SELECT MAX(s.snapshot_date)
      FROM dws.dws_sales_gross_profit_snapshot_detail_p s
      WHERE s.delete_time IS NULL
        AND s.settlement_month = src.settlement_month
  )
GROUP BY src.sale_id;
```

## 8. Gross Profit / Pref_GP

快照已按 `pref_rev - cost + physical_card_gp` 计算并保存毛利；直接汇总该字段：

```sql
SELECT src.sale_id, SUM(src.pref_gp) AS pref_gp
FROM dws.dws_sales_gross_profit_snapshot_detail_p src
WHERE src.delete_time IS NULL
  AND src.report_date >= DATE '2026-09-01'
  AND src.report_date <  DATE '2026-10-01'
  AND src.sale_id IS NOT NULL
  AND src.snapshot_date = (
      SELECT MAX(s.snapshot_date)
      FROM dws.dws_sales_gross_profit_snapshot_detail_p s
      WHERE s.delete_time IS NULL
        AND s.settlement_month = src.settlement_month
  )
GROUP BY src.sale_id;
```

## 9. Cash Flow Revenue / Cashflow_Rev_sale

```sql
SELECT src.sale_id, SUM(src.cashflow_rev_sale) AS cashflow_rev_sale
FROM dws.dws_sales_gross_profit_snapshot_detail_p src
WHERE src.delete_time IS NULL
  AND src.report_date >= DATE '2026-09-01'
  AND src.report_date <  DATE '2026-10-01'
  AND src.sale_id IS NOT NULL
  AND src.snapshot_date = (
      SELECT MAX(s.snapshot_date)
      FROM dws.dws_sales_gross_profit_snapshot_detail_p s
      WHERE s.delete_time IS NULL
        AND s.settlement_month = src.settlement_month
  )
GROUP BY src.sale_id;
```

## 10. Cash Flow Effective Revenue / Cashflow_Rev_sale_effective

```sql
SELECT src.sale_id, SUM(src.cashflow_rev_sale_effective) AS cashflow_rev_sale_effective
FROM dws.dws_sales_gross_profit_snapshot_detail_p src
WHERE src.delete_time IS NULL
  AND src.report_date >= DATE '2026-09-01'
  AND src.report_date <  DATE '2026-10-01'
  AND src.sale_id IS NOT NULL
  AND src.snapshot_date = (
      SELECT MAX(s.snapshot_date)
      FROM dws.dws_sales_gross_profit_snapshot_detail_p s
      WHERE s.delete_time IS NULL
        AND s.settlement_month = src.settlement_month
  )
GROUP BY src.sale_id;
```

## 11. Cash Flow Gross Profit / Cashflow_GP_sale

快照已按 `cashflow_rev_sale - cost + physical_card_gp` 计算并保存毛利；直接汇总该字段：

```sql
SELECT src.sale_id, SUM(src.cashflow_gp_sale) AS cashflow_gp_sale
FROM dws.dws_sales_gross_profit_snapshot_detail_p src
WHERE src.delete_time IS NULL
  AND src.report_date >= DATE '2026-09-01'
  AND src.report_date <  DATE '2026-10-01'
  AND src.sale_id IS NOT NULL
  AND src.snapshot_date = (
      SELECT MAX(s.snapshot_date)
      FROM dws.dws_sales_gross_profit_snapshot_detail_p s
      WHERE s.delete_time IS NULL
        AND s.settlement_month = src.settlement_month
  )
GROUP BY src.sale_id;
```
