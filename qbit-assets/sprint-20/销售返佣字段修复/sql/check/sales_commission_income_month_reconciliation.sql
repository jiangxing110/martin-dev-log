--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-18
-- Description:    销售绩效实际收入物化视图与8号收入快照对账
-- 参数：
--   :activity_month - 活动月份月初日期，例如 2026-10-01
--   :snapshot_date  - 8号快照日期，例如 2026-11-08
-- Notes:
--   1. 快照生成时，estimate 与 snapshot 的相同维度金额应一致。
--   2. 后续源数据刷新后，estimate 可能变化；历史快照仍保留8号固化值。
--********************************************************************--

WITH params AS (
  SELECT
    CAST(:activity_month AS date) AS activity_month,
    CAST(:snapshot_date AS date) AS snapshot_date
),
estimate AS (
  SELECT
    v.activity_month,
    v.bill_month,
    v.root_account_id,
    v.product,
    v.provider,
    v.income_type,
    v.sale_id,
    v.am_id,
    SUM(v.income_amount)::numeric(20, 4) AS income_amount
  FROM "dws"."mv_sales_commission_performance_income_recent" v
  CROSS JOIN params p
  WHERE v.activity_month = p.activity_month
  GROUP BY
    v.activity_month, v.bill_month, v.root_account_id, v.product,
    v.provider, v.income_type, v.sale_id, v.am_id
),
snapshot AS (
  SELECT
    s.activity_month,
    s.bill_month,
    s.root_account_id,
    s.product,
    s.provider,
    s.income_type,
    s.sale_id,
    s.am_id,
    SUM(s.income_amount)::numeric(20, 4) AS income_amount
  FROM "dws"."dws_sales_commission_income_snapshot_detail_p" s
  CROSS JOIN params p
  WHERE s.activity_month = p.activity_month
    AND s.snapshot_date = p.snapshot_date
    AND s.delete_time IS NULL
  GROUP BY
    s.activity_month, s.bill_month, s.root_account_id, s.product,
    s.provider, s.income_type, s.sale_id, s.am_id
)
SELECT
  COALESCE(e.activity_month, s.activity_month) AS activity_month,
  COALESCE(e.bill_month, s.bill_month) AS bill_month,
  COALESCE(e.root_account_id, s.root_account_id) AS root_account_id,
  COALESCE(e.product, s.product) AS product,
  COALESCE(e.provider, s.provider) AS provider,
  COALESCE(e.income_type, s.income_type) AS income_type,
  COALESCE(e.sale_id, s.sale_id) AS sale_id,
  COALESCE(e.am_id, s.am_id) AS am_id,
  e.income_amount AS estimate_income_amount,
  s.income_amount AS snapshot_income_amount,
  COALESCE(s.income_amount, 0) - COALESCE(e.income_amount, 0) AS diff_amount,
  CASE
    WHEN e.activity_month IS NULL THEN 'SNAPSHOT_ONLY'
    WHEN s.activity_month IS NULL THEN 'ESTIMATE_ONLY'
    WHEN e.income_amount IS DISTINCT FROM s.income_amount THEN 'DIFF'
    ELSE 'MATCH'
  END AS reconcile_status
FROM estimate e
FULL OUTER JOIN snapshot s
  ON s.activity_month = e.activity_month
 AND s.bill_month IS NOT DISTINCT FROM e.bill_month
 AND s.root_account_id = e.root_account_id
 AND s.product = e.product
 AND s.provider IS NOT DISTINCT FROM e.provider
 AND s.income_type = e.income_type
 AND s.sale_id IS NOT DISTINCT FROM e.sale_id
 AND s.am_id IS NOT DISTINCT FROM e.am_id
ORDER BY activity_month, sale_id, am_id, root_account_id, income_type;

-- 绩效卡片应读取 realTimeProcessing = 所有收入项目金额合计。
SELECT
  'estimate' AS data_source,
  activity_month,
  sale_id,
  am_id,
  SUM(income_amount)::numeric(20, 4) AS real_time_processing
FROM "dws"."mv_sales_commission_performance_income_recent"
WHERE activity_month = CAST(:activity_month AS date)
GROUP BY activity_month, sale_id, am_id
UNION ALL
SELECT
  'snapshot' AS data_source,
  activity_month,
  sale_id,
  am_id,
  SUM(income_amount)::numeric(20, 4) AS real_time_processing
FROM "dws"."dws_sales_commission_income_snapshot_detail_p"
WHERE activity_month = CAST(:activity_month AS date)
  AND snapshot_date = CAST(:snapshot_date AS date)
  AND delete_time IS NULL
GROUP BY activity_month, sale_id, am_id
ORDER BY data_source, sale_id, am_id;
