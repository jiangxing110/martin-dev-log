--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-29
-- Description:    销售佣金8号前预估物化视图
-- Notes:
--   1. 本物化视图承载8号前页面查询和半天刷新结果。
--   2. 每次刷新保留近三个月 settlement_month 数据。
--   3. 每月8号快照任务从本物化视图读取目标 settlement_month 并固化到快照表。
--   4. 成本接入点为 v_cost_by_account_product；当前已接入加密承兑特殊成本，其他成本继续补齐。
--********************************************************************--

DROP MATERIALIZED VIEW IF EXISTS "dws"."mv_sales_commission_recent_estimate";

CREATE MATERIALIZED VIEW "dws"."mv_sales_commission_recent_estimate" AS
WITH revenue_base AS (
  SELECT
    CURRENT_DATE AS report_date,
    settlement_month,
    root_account_id,
    product,
    provider,
    CASE
      WHEN product = 'open_api' AND metric_code IN ('api_one_time_fee', 'api_monthly_fee') THEN metric_code
      ELSE NULL
    END AS item,
    CASE
      WHEN product = 'open_api' AND metric_code = 'api_monthly_fee' THEN 'api_monthly_billing'
      WHEN metric_code = 'past_due_invoice' THEN 'past_due_invoice'
      WHEN metric_code = 'billing_decline_fee' THEN 'billing_decline_fee'
      ELSE 'real_time_processing_fee'
    END AS source_type,
    CASE
      WHEN product = 'open_api' AND metric_code = 'api_monthly_fee' THEN 'future_payout'
      ELSE 'current_payout'
    END AS commission_stage,
    sale_id,
    sale_department AS department_id,
    operation_manager_id,
    am_id,
    settlement_month AS activity_month,
    settlement_month AS collection_month,
    CASE
      WHEN product = 'open_api' AND metric_code = 'api_monthly_fee'
        THEN date_trunc('month', settlement_month + interval '1 month')::date
      ELSE settlement_month
    END AS payable_settlement_month,
    SUM(COALESCE(real_income_value, income_value, 0))::numeric(20,4) AS effective_revenue
  FROM "dws"."dws_sales_revenue_monthly"
  WHERE delete_time IS NULL
    AND settlement_month >= date_trunc('month', CURRENT_DATE - interval '3 months')::date
    AND metric_code NOT IN ('assets_acceptance_fee_gt_zero', 'assets_acceptance_fee_eq_zero')
  GROUP BY
    settlement_month, root_account_id, product, provider, metric_code, sale_id,
    sale_department, operation_manager_id, am_id
),
crypto_acceptance_cost AS (
  SELECT
    settlement_month,
    root_account_id,
    product,
    provider,
    SUM(
      CASE
        WHEN sale_department = '1851130772357509121'
         AND metric_code IN ('assets_acceptance_fee_gt_zero', 'assets_acceptance_fee_eq_zero')
          THEN COALESCE(real_income_value, income_value, 0) * 0.0009
        WHEN sale_department <> '1851130772357509121'
         AND metric_code = 'assets_acceptance_fee_gt_zero'
          THEN COALESCE(real_income_value, income_value, 0) * 0.0009
        ELSE 0
      END
    )::numeric(20,4) AS cogs
  FROM "dws"."dws_sales_revenue_monthly"
  WHERE delete_time IS NULL
    AND settlement_month >= date_trunc('month', CURRENT_DATE - interval '3 months')::date
    AND product = 'crypto'
    AND metric_code IN ('assets_acceptance_fee_gt_zero', 'assets_acceptance_fee_eq_zero')
  GROUP BY settlement_month, root_account_id, product, provider
),
v_cost_by_account_product AS (
  SELECT
    settlement_month,
    root_account_id,
    product,
    provider,
    SUM(cogs)::numeric(20,4) AS cogs
  FROM (
    SELECT
      settlement_month,
      root_account_id,
      product,
      provider,
      0::numeric(20,4) AS cogs
    FROM revenue_base
    GROUP BY settlement_month, root_account_id, product, provider
    UNION ALL
    SELECT
      settlement_month,
      root_account_id,
      product,
      provider,
      cogs
    FROM crypto_acceptance_cost
  ) cost_union
  GROUP BY settlement_month, root_account_id, product, provider
),
estimate_base AS (
  SELECT
    b.*,
    COALESCE(c.cogs, 0)::numeric(20,4) AS cogs,
    (b.effective_revenue - COALESCE(c.cogs, 0))::numeric(20,4) AS gp,
    CASE
      WHEN b.product = 'qbit_card' AND a.card_active_time IS NOT NULL THEN (b.settlement_month - a.card_active_time::date)
      WHEN b.product = 'group_account' AND a.global_active_time IS NOT NULL THEN (b.settlement_month - a.global_active_time::date)
      WHEN b.product = 'crypto' AND a.crypto_active_time IS NOT NULL THEN (b.settlement_month - a.crypto_active_time::date)
      WHEN b.product = 'open_api' AND a.api_active_time IS NOT NULL THEN (b.settlement_month - a.api_active_time::date)
      WHEN b.product = 'treasury' AND a.treasury_active_time IS NOT NULL THEN (b.settlement_month - a.treasury_active_time::date)
      ELSE NULL
    END AS active_days,
    CASE
      WHEN a.referral_user_id IS NOT NULL AND a.referral_user_id = b.sale_id THEN 'direct'
      ELSE 'non_direct'
    END AS invite_type
  FROM revenue_base b
  LEFT JOIN v_cost_by_account_product c
    ON c.settlement_month = b.settlement_month
   AND c.root_account_id = b.root_account_id
   AND c.product = b.product
   AND COALESCE(c.provider, '') = COALESCE(b.provider, '')
  LEFT JOIN "dim"."dim_account_analysis" a
    ON a.account_id = b.root_account_id
   AND a.delete_time IS NULL
),
rule_candidates AS (
  SELECT
    b.*,
    r.rule_code,
    r.commission_base_type,
    r.commission_rate,
    ROW_NUMBER() OVER (
      PARTITION BY b.settlement_month, b.root_account_id, b.product, COALESCE(b.provider, ''), COALESCE(b.item, ''), COALESCE(b.sale_id, ''), b.source_type, b.commission_stage
      ORDER BY r.priority ASC, r.id ASC
    ) AS rn
  FROM estimate_base b
  JOIN "dim"."dim_sales_commission_rule" r
    ON r.department_id = b.department_id
   AND (r.product IS NULL OR r.product = b.product)
   AND (r.provider IS NULL OR r.provider = b.provider)
   AND (r.item IS NULL OR r.item = b.item)
   AND (r.invite_type = 'all' OR r.invite_type = b.invite_type)
   AND (r.active_days_min IS NULL OR b.active_days >= r.active_days_min)
   AND (r.active_days_max IS NULL OR b.active_days <= r.active_days_max)
   AND b.settlement_month::timestamp >= r.start_time
   AND b.settlement_month::timestamp < r.end_time
   AND r.enabled = true
   AND r.delete_time IS NULL
)
SELECT
  abs(hashtext(concat_ws(':',
    to_char(report_date, 'YYYYMMDD'),
    to_char(settlement_month, 'YYYYMM'),
    root_account_id,
    product,
    COALESCE(provider, ''),
    COALESCE(item, ''),
    COALESCE(sale_id, ''),
    source_type,
    commission_stage
  )))::bigint AS id,
  report_date,
  settlement_month,
  root_account_id,
  product,
  provider,
  item,
  source_type,
  commission_stage,
  sale_id,
  operation_manager_id,
  am_id,
  department_id,
  invite_type,
  activity_month,
  collection_month,
  payable_settlement_month,
  effective_revenue,
  cogs,
  gp,
  (CASE WHEN commission_base_type = 'actual_fee' THEN effective_revenue ELSE gp END)::numeric(20,4) AS commission_base,
  commission_rate,
  ((CASE WHEN commission_base_type = 'actual_fee' THEN effective_revenue ELSE gp END) * commission_rate)::numeric(20,4) AS estimated_commission,
  active_days,
  rule_code,
  now() AS refreshed_at
FROM rule_candidates
WHERE rn = 1
WITH DATA;

ALTER MATERIALIZED VIEW "dws"."mv_sales_commission_recent_estimate"
  OWNER TO "flink_cdc_user";

COMMENT ON MATERIALIZED VIEW "dws"."mv_sales_commission_recent_estimate" IS '销售佣金8号前预估物化视图，半天刷新近三个月数据';

CREATE INDEX "idx_mv_sales_commission_recent_estimate_query" ON "dws"."mv_sales_commission_recent_estimate" (
  "settlement_month",
  "sale_id",
  "am_id",
  "commission_stage"
);
