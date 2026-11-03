--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-02
-- Updated Time:   2026-11-03 11:48:51
-- Description:    销售毛利估算视图与日汇总快照区间对账
-- 参数：替换 :start_date (yyyy-MM-dd) 和 :end_date (yyyy-MM-dd，含当天)。
--********************************************************************--

-- 1. 按日期区间和销售比较估算视图与快照，所有金额列均应一致。
WITH estimate AS (
  SELECT
    report_date,
    settlement_month,
    sale_id,
    SUM(pref_rev) AS pref_rev,
    SUM(client_rebate) AS client_rebate,
    SUM(client_collection_rebate) AS client_collection_rebate,
    SUM(gross_profit_rebate) AS gross_profit_rebate,
    SUM(rebate) AS rebate,
    SUM(pref_rev_effective) AS pref_rev_effective,
    SUM(cost) AS cost,
    SUM(pref_gp) AS pref_gp,
    SUM(cashflow_rev_sale) AS cashflow_rev_sale,
    SUM(cashflow_rev_sale_effective) AS cashflow_rev_sale_effective,
    SUM(cashflow_gp_sale) AS cashflow_gp_sale
  FROM dws.mv_sales_gross_profit_recent_estimate
  WHERE report_date >= CAST(:start_date AS date)
    AND report_date <= CAST(:end_date AS date)
  GROUP BY report_date, settlement_month, sale_id
), snapshot AS (
  SELECT
    report_date,
    settlement_month,
    sale_id,
    pref_rev,
    client_rebate,
    client_collection_rebate,
    gross_profit_rebate,
    rebate,
    pref_rev_effective,
    cost,
    pref_gp,
    cashflow_rev_sale,
    cashflow_rev_sale_effective,
    cashflow_gp_sale
  FROM dws.dws_sales_gross_profit_snapshot_p s
  WHERE s.report_date >= CAST(:start_date AS date)
    AND s.report_date <= CAST(:end_date AS date)
    AND s.snapshot_date = (
      SELECT MAX(s2.snapshot_date)
      FROM dws.dws_sales_gross_profit_snapshot_p s2
      WHERE s2.settlement_month = s.settlement_month
        AND s2.delete_time IS NULL
    )
    AND s.delete_time IS NULL
)
SELECT
  COALESCE(e.report_date, s.report_date) AS report_date,
  COALESCE(e.settlement_month, s.settlement_month) AS settlement_month,
  COALESCE(e.sale_id, s.sale_id) AS sale_id,
  e.pref_rev AS estimate_pref_rev, s.pref_rev AS snapshot_pref_rev,
  e.rebate AS estimate_rebate, s.rebate AS snapshot_rebate,
  e.cost AS estimate_cost, s.cost AS snapshot_cost,
  e.pref_gp AS estimate_pref_gp, s.pref_gp AS snapshot_pref_gp,
  e.cashflow_rev_sale AS estimate_cashflow_rev_sale, s.cashflow_rev_sale AS snapshot_cashflow_rev_sale,
  CASE
    WHEN e.report_date IS NULL THEN 'SNAPSHOT_ONLY'
    WHEN s.report_date IS NULL THEN 'ESTIMATE_ONLY'
    WHEN e.pref_rev IS DISTINCT FROM s.pref_rev
      OR e.client_rebate IS DISTINCT FROM s.client_rebate
      OR e.client_collection_rebate IS DISTINCT FROM s.client_collection_rebate
      OR e.gross_profit_rebate IS DISTINCT FROM s.gross_profit_rebate
      OR e.rebate IS DISTINCT FROM s.rebate
      OR e.pref_rev_effective IS DISTINCT FROM s.pref_rev_effective
      OR e.cost IS DISTINCT FROM s.cost
      OR e.pref_gp IS DISTINCT FROM s.pref_gp
      OR e.cashflow_rev_sale IS DISTINCT FROM s.cashflow_rev_sale
      OR e.cashflow_rev_sale_effective IS DISTINCT FROM s.cashflow_rev_sale_effective
      OR e.cashflow_gp_sale IS DISTINCT FROM s.cashflow_gp_sale
      THEN 'DIFF'
    ELSE 'MATCH'
  END AS reconcile_status
FROM estimate e
FULL OUTER JOIN snapshot s
  ON s.settlement_month = e.settlement_month
 AND s.report_date = e.report_date
 AND s.sale_id IS NOT DISTINCT FROM e.sale_id
ORDER BY report_date, sale_id;

-- 2. 确认视图和快照均保留负数，结果应返回实际存在的负值记录。
SELECT 'estimate' AS source, report_date, sale_id, settlement_month, pref_rev, rebate, cost, pref_gp
FROM dws.mv_sales_gross_profit_recent_estimate
WHERE report_date >= CAST(:start_date AS date)
  AND report_date <= CAST(:end_date AS date)
  AND (pref_rev < 0 OR rebate < 0 OR cost < 0 OR pref_gp < 0)
UNION ALL
SELECT 'snapshot' AS source, s.report_date, s.sale_id, s.settlement_month, s.pref_rev, s.rebate, s.cost, s.pref_gp
FROM dws.dws_sales_gross_profit_snapshot_p s
WHERE s.report_date >= CAST(:start_date AS date)
  AND s.report_date <= CAST(:end_date AS date)
  AND s.snapshot_date = (
    SELECT MAX(s2.snapshot_date)
    FROM dws.dws_sales_gross_profit_snapshot_p s2
    WHERE s2.settlement_month = s.settlement_month
      AND s2.delete_time IS NULL
  )
  AND s.delete_time IS NULL
  AND (s.pref_rev < 0 OR s.rebate < 0 OR s.cost < 0 OR s.pref_gp < 0);
