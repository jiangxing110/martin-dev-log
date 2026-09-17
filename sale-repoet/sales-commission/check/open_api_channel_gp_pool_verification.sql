--********************************************************************--
-- Description: 验证有渠道 OpenAPI 月结手续费与 real_time 的共享毛利池。
-- Usage: 先重建规则、刷新 mv_sales_commission_recent_estimate，再修改 params 执行。
-- Note: month_receivable 为应收（future_payout），不进入本期实收毛利池。
--********************************************************************--

WITH params AS (
  SELECT
    DATE '2026-08-01' AS settlement_month,
    '2cef54b6-51c9-47c8-a56a-66934cbfd619'::varchar AS root_account_id,
    'IQ'::varchar AS provider
),
pool AS (
  SELECT
    m.settlement_month,
    m.root_account_id,
    m.provider,
    SUM(CASE
      WHEN m.source_type = 'real_time_processing_fee'
       AND m.product <> 'open_api'
        THEN m.effective_revenue
      ELSE 0
    END) AS real_time_effective_revenue,
    SUM(CASE
      WHEN m.product = 'open_api'
       AND m.item = 'api_monthly_settlement_fee'
        THEN m.effective_revenue
      ELSE 0
    END) AS api_monthly_settlement_effective_revenue,
    SUM(CASE
      WHEN (m.source_type = 'real_time_processing_fee' AND m.product <> 'open_api')
        OR (m.product = 'open_api' AND m.item = 'api_monthly_settlement_fee')
        THEN m.effective_revenue
      ELSE 0
    END) AS pool_effective_revenue,
    SUM(CASE
      WHEN (m.source_type = 'real_time_processing_fee' AND m.product <> 'open_api')
        OR (m.product = 'open_api' AND m.item = 'api_monthly_settlement_fee')
        THEN m.cogs
      ELSE 0
    END) AS pool_cogs,
    SUM(CASE
      WHEN m.source_type = 'real_time_processing_fee'
       AND m.product <> 'open_api'
        THEN m.gp
      ELSE 0
    END) AS actual_real_time_gp,
    SUM(CASE
      WHEN m.product = 'open_api'
       AND m.item = 'api_monthly_settlement_fee'
        THEN m.gp
      ELSE 0
    END) AS actual_api_monthly_settlement_gp
  FROM dws.mv_sales_commission_recent_estimate m
  CROSS JOIN params p
  WHERE m.settlement_month = p.settlement_month
    AND m.root_account_id = p.root_account_id
    AND m.provider = p.provider
    AND m.commission_stage = 'current_payout'
  GROUP BY m.settlement_month, m.root_account_id, m.provider
)
SELECT
  settlement_month,
  root_account_id,
  provider,
  real_time_effective_revenue,
  api_monthly_settlement_effective_revenue,
  pool_cogs,
  GREATEST(pool_effective_revenue - pool_cogs, 0)::numeric(20, 4) AS expected_pool_gp,
  CASE
    WHEN real_time_effective_revenue > 0
     AND api_monthly_settlement_effective_revenue > 0
      THEN (
        GREATEST(pool_effective_revenue - pool_cogs, 0)
        * api_monthly_settlement_effective_revenue
        / (real_time_effective_revenue + api_monthly_settlement_effective_revenue)
      )::numeric(20, 4)
    ELSE NULL
  END AS expected_real_time_gp,
  actual_real_time_gp,
  CASE
    WHEN real_time_effective_revenue > 0
     AND api_monthly_settlement_effective_revenue > 0
      THEN (
        GREATEST(pool_effective_revenue - pool_cogs, 0)
        * real_time_effective_revenue
        / (real_time_effective_revenue + api_monthly_settlement_effective_revenue)
      )::numeric(20, 4)
    ELSE NULL
  END AS expected_api_monthly_settlement_gp,
  actual_api_monthly_settlement_gp
FROM pool;
