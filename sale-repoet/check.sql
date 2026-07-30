-- 销售佣金 effective_revenue 排查脚本
-- 执行方式：一段一段执行，不要整文件一次性全跑。
--
-- 固定排查条件：
--   settlement_month = 2026-05-01
--   sale_id = edfc4d0a-2131-440f-87a3-f3781767fa7f


-- =========================
-- 第 1 段：源收入 vs 当前物化视图结果
-- =========================
-- 用途：
--   对比 dws_sales_revenue_monthly 分摊前源收入和 mv_sales_commission_recent_estimate 当前结果。
WITH params AS (
  SELECT
    DATE '2026-05-01' AS settlement_month_filter,
    'edfc4d0a-2131-440f-87a3-f3781767fa7f'::varchar AS sale_id_filter
),
source_rows AS (
  SELECT
    r.settlement_month,
    r.sale_id,
    r.operation_manager_id,
    r.am_id,
    CASE
      WHEN r.product = 'open_api' AND r.metric_code = 'api_monthly_fee' THEN 'api_monthly_billing'
      WHEN r.product = 'open_api' AND r.metric_code = 'month_receivable' THEN 'billing_decline_fee'
      WHEN r.product = 'open_api' AND r.metric_code = 'month_revenue' THEN 'past_due_invoice'
      WHEN r.metric_code = 'past_due_invoice' THEN 'past_due_invoice'
      WHEN r.metric_code = 'billing_decline_fee' THEN 'billing_decline_fee'
      ELSE 'real_time_processing_fee'
    END AS source_type,
    COALESCE(r.real_income_value, r.income_value, 0) AS effective_revenue
  FROM dws.dws_sales_revenue_monthly r
  CROSS JOIN params p
  WHERE r.delete_time IS NULL
    AND r.settlement_month = p.settlement_month_filter
    AND r.sale_id = p.sale_id_filter
    AND r.metric_code NOT IN (
      'assets_acceptance_fee_gt_zero',
      'assets_acceptance_fee_eq_zero',
      'physical_card_cost'
    )
),
source_summary AS (
  SELECT
    settlement_month,
    sale_id,
    operation_manager_id,
    am_id,
    source_type,
    SUM(effective_revenue)::numeric(20,4) AS source_effective_revenue
  FROM source_rows
  GROUP BY settlement_month, sale_id, operation_manager_id, am_id, source_type
),
mv_summary AS (
  SELECT
    m.settlement_month,
    m.sale_id,
    m.operation_manager_id,
    m.am_id,
    m.source_type,
    SUM(m.effective_revenue)::numeric(20,4) AS mv_effective_revenue,
    SUM(m.cogs)::numeric(20,4) AS mv_cogs,
    SUM(m.gp)::numeric(20,4) AS mv_gp,
    SUM(m.estimated_commission)::numeric(20,4) AS mv_commission
  FROM dws.mv_sales_commission_recent_estimate m
  CROSS JOIN params p
  WHERE m.settlement_month = p.settlement_month_filter
    AND m.sale_id = p.sale_id_filter
  GROUP BY m.settlement_month, m.sale_id, m.operation_manager_id, m.am_id, m.source_type
)
SELECT
  'source_vs_mv_summary' AS check_step,
  COALESCE(s.settlement_month, m.settlement_month) AS settlement_month,
  COALESCE(s.sale_id, m.sale_id) AS sale_id,
  COALESCE(s.operation_manager_id, m.operation_manager_id) AS operation_manager_id,
  COALESCE(s.am_id, m.am_id) AS am_id,
  COALESCE(s.source_type, m.source_type) AS source_type,
  COALESCE(s.source_effective_revenue, 0)::numeric(20,4) AS source_effective_revenue,
  COALESCE(m.mv_effective_revenue, 0)::numeric(20,4) AS mv_effective_revenue,
  (COALESCE(m.mv_effective_revenue, 0) - COALESCE(s.source_effective_revenue, 0))::numeric(20,4) AS effective_revenue_diff,
  COALESCE(m.mv_cogs, 0)::numeric(20,4) AS mv_cogs,
  COALESCE(m.mv_gp, 0)::numeric(20,4) AS mv_gp,
  COALESCE(m.mv_commission, 0)::numeric(20,4) AS mv_commission
FROM source_summary s
FULL JOIN mv_summary m
  ON m.settlement_month = s.settlement_month
 AND m.sale_id = s.sale_id
 AND COALESCE(m.operation_manager_id, '') = COALESCE(s.operation_manager_id, '')
 AND COALESCE(m.am_id, '') = COALESCE(s.am_id, '')
 AND m.source_type = s.source_type
ORDER BY am_id, source_type;


-- =========================
-- 第 2 段：physical_card_cost 加法/减法口径汇总
-- =========================
-- 用途：
--   验证如果把 dws_sales_revenue_monthly.physical_card_cost 当分摊项时，
--   “加法口径”和“减法口径”的结果差异。
WITH params AS (
  SELECT
    DATE '2026-05-01' AS settlement_month_filter,
    'edfc4d0a-2131-440f-87a3-f3781767fa7f'::varchar AS sale_id_filter
),
revenue_base AS (
  SELECT
    r.settlement_month,
    r.root_account_id,
    r.product,
    r.provider,
    CASE
      WHEN r.product = 'open_api' AND r.metric_code = 'api_monthly_fee' THEN 'api_monthly_billing'
      WHEN r.product = 'open_api' AND r.metric_code = 'month_receivable' THEN 'billing_decline_fee'
      WHEN r.product = 'open_api' AND r.metric_code = 'month_revenue' THEN 'past_due_invoice'
      WHEN r.metric_code = 'past_due_invoice' THEN 'past_due_invoice'
      WHEN r.metric_code = 'billing_decline_fee' THEN 'billing_decline_fee'
      ELSE 'real_time_processing_fee'
    END AS source_type,
    r.sale_id,
    r.operation_manager_id,
    r.am_id,
    SUM(COALESCE(r.real_income_value, r.income_value, 0))::numeric(20,4) AS effective_revenue
  FROM dws.dws_sales_revenue_monthly r
  CROSS JOIN params p
  WHERE r.delete_time IS NULL
    AND r.settlement_month = p.settlement_month_filter
    AND r.sale_id = p.sale_id_filter
    AND r.metric_code NOT IN (
      'assets_acceptance_fee_gt_zero',
      'assets_acceptance_fee_eq_zero',
      'physical_card_cost'
    )
  GROUP BY
    r.settlement_month, r.root_account_id, r.product, r.provider,
    r.metric_code, r.sale_id, r.operation_manager_id, r.am_id
),
physical_card_cost AS (
  SELECT
    r.settlement_month,
    r.root_account_id,
    r.product,
    r.provider,
    SUM(COALESCE(r.real_income_value, r.income_value, 0))::numeric(20,4) AS physical_card_cost
  FROM dws.dws_sales_revenue_monthly r
  CROSS JOIN params p
  WHERE r.delete_time IS NULL
    AND r.settlement_month = p.settlement_month_filter
    AND r.sale_id = p.sale_id_filter
    AND r.metric_code = 'physical_card_cost'
  GROUP BY r.settlement_month, r.root_account_id, r.product, r.provider
),
allocated AS (
  SELECT
    b.*,
    COALESCE(c.physical_card_cost, 0)::numeric(20,4) AS allocated_source_amount,
    SUM(b.effective_revenue) OVER (
      PARTITION BY b.settlement_month, b.root_account_id, b.product, COALESCE(b.provider, '')
    )::numeric(20,4) AS product_effective_revenue
  FROM revenue_base b
  LEFT JOIN physical_card_cost c
    ON c.settlement_month = b.settlement_month
   AND c.root_account_id = b.root_account_id
   AND c.product = b.product
   AND COALESCE(c.provider, '') = COALESCE(b.provider, '')
),
calculated AS (
  SELECT
    settlement_month,
    sale_id,
    operation_manager_id,
    am_id,
    source_type,
    effective_revenue,
    CASE
      WHEN product_effective_revenue <> 0 THEN allocated_source_amount * effective_revenue / product_effective_revenue
      ELSE 0
    END AS allocated_amount,
    GREATEST((
      effective_revenue
      + CASE
          WHEN product_effective_revenue <> 0 THEN allocated_source_amount * effective_revenue / product_effective_revenue
          ELSE 0
        END
    ), 0)::numeric(20,4) AS effective_revenue_add,
    GREATEST((
      effective_revenue
      - CASE
          WHEN product_effective_revenue <> 0 THEN allocated_source_amount * effective_revenue / product_effective_revenue
          ELSE 0
        END
    ), 0)::numeric(20,4) AS effective_revenue_subtract
  FROM allocated
)
SELECT
  'physical_card_cost_add_vs_subtract_summary' AS check_step,
  settlement_month,
  sale_id,
  operation_manager_id,
  am_id,
  source_type,
  COUNT(*) AS row_count,
  SUM(effective_revenue)::numeric(20,4) AS source_effective_revenue,
  SUM(allocated_amount)::numeric(20,4) AS allocated_physical_card_cost,
  SUM(effective_revenue_add)::numeric(20,4) AS effective_revenue_add,
  SUM(effective_revenue_subtract)::numeric(20,4) AS effective_revenue_subtract
FROM calculated
GROUP BY settlement_month, sale_id, operation_manager_id, am_id, source_type
ORDER BY am_id, source_type;


-- =========================
-- 第 3 段：按 MV 真实 channel_rebate 来源复算
-- =========================
-- 用途：
--   mv_sales_commission_recent_estimate 真实 channel_rebate 来源不是 physical_card_cost，
--   而是 BB/QI 日表的渠道返现字段。本段按真实来源复算。
WITH params AS (
  SELECT
    DATE '2026-05-01' AS settlement_month_filter,
    'edfc4d0a-2131-440f-87a3-f3781767fa7f'::varchar AS sale_id_filter
),
account_root_relation AS (
  SELECT
    aar.root_id::text AS root_id,
    aar.account_id::text AS account_id
  FROM public.api_account_relation aar
  WHERE aar.root_id IS NOT NULL
    AND aar.account_id IS NOT NULL
),
revenue_base AS (
  SELECT
    r.settlement_month,
    r.root_account_id,
    r.product,
    r.provider,
    CASE
      WHEN r.product = 'open_api' AND r.metric_code = 'api_monthly_fee' THEN 'api_monthly_billing'
      WHEN r.product = 'open_api' AND r.metric_code = 'month_receivable' THEN 'billing_decline_fee'
      WHEN r.product = 'open_api' AND r.metric_code = 'month_revenue' THEN 'past_due_invoice'
      WHEN r.metric_code = 'past_due_invoice' THEN 'past_due_invoice'
      WHEN r.metric_code = 'billing_decline_fee' THEN 'billing_decline_fee'
      ELSE 'real_time_processing_fee'
    END AS source_type,
    r.sale_id,
    r.operation_manager_id,
    r.am_id,
    SUM(COALESCE(r.real_income_value, r.income_value, 0))::numeric(20,4) AS effective_revenue
  FROM dws.dws_sales_revenue_monthly r
  CROSS JOIN params p
  WHERE r.delete_time IS NULL
    AND r.settlement_month = p.settlement_month_filter
    AND r.sale_id = p.sale_id_filter
    AND r.metric_code NOT IN (
      'assets_acceptance_fee_gt_zero',
      'assets_acceptance_fee_eq_zero',
      'physical_card_cost'
    )
  GROUP BY
    r.settlement_month, r.root_account_id, r.product, r.provider,
    r.metric_code, r.sale_id, r.operation_manager_id, r.am_id
),
qbit_card_channel_rebate AS (
  SELECT
    settlement_month,
    root_account_id,
    product,
    provider,
    SUM(channel_rebate)::numeric(20,4) AS channel_rebate
  FROM (
    SELECT
      date_trunc('month', b.report_date)::date AS settlement_month,
      COALESCE(aar.root_id, b.account_id) AS root_account_id,
      'qbit_card' AS product,
      'BB' AS provider,
      ABS(SUM(COALESCE(b.bb_channel_cashback_comm, 0)))::numeric(20,4) AS channel_rebate
    FROM dws.dws_bb_card_finance_daily_p b
    LEFT JOIN account_root_relation aar
      ON aar.account_id = b.account_id::text
    CROSS JOIN params p
    WHERE b.delete_time IS NULL
      AND date_trunc('month', b.report_date)::date = p.settlement_month_filter
    GROUP BY date_trunc('month', b.report_date)::date, COALESCE(aar.root_id, b.account_id)
    UNION ALL
    SELECT
      date_trunc('month', q.report_date)::date AS settlement_month,
      COALESCE(aar.root_id, q.account_id) AS root_account_id,
      'qbit_card' AS product,
      'QI' AS provider,
      ABS(SUM(
          COALESCE(q.rebate_interchange_base_amt, 0) * COALESCE(q.rebate_interchange_rate, 0)
        + COALESCE(q.rebate_incentive_base_amt, 0) * COALESCE(q.rebate_incentive_rate, 0)
      ))::numeric(20,4) AS channel_rebate
    FROM dws.dws_qi_card_finance_daily_v2_p q
    LEFT JOIN account_root_relation aar
      ON aar.account_id = q.account_id::text
    CROSS JOIN params p
    WHERE q.delete_time IS NULL
      AND date_trunc('month', q.report_date)::date = p.settlement_month_filter
    GROUP BY date_trunc('month', q.report_date)::date, COALESCE(aar.root_id, q.account_id)
  ) rebate_union
  GROUP BY settlement_month, root_account_id, product, provider
),
allocated AS (
  SELECT
    b.*,
    COALESCE(r.channel_rebate, 0)::numeric(20,4) AS channel_rebate,
    SUM(b.effective_revenue) OVER (
      PARTITION BY b.settlement_month, b.root_account_id, b.product, COALESCE(b.provider, '')
    )::numeric(20,4) AS product_effective_revenue
  FROM revenue_base b
  LEFT JOIN qbit_card_channel_rebate r
    ON r.settlement_month = b.settlement_month
   AND r.root_account_id = b.root_account_id
   AND r.product = b.product
   AND COALESCE(r.provider, '') = COALESCE(b.provider, '')
),
calculated AS (
  SELECT
    settlement_month,
    sale_id,
    operation_manager_id,
    am_id,
    source_type,
    effective_revenue,
    channel_rebate,
    CASE
      WHEN product_effective_revenue <> 0 THEN channel_rebate * effective_revenue / product_effective_revenue
      ELSE 0
    END AS allocated_channel_rebate,
    GREATEST((
      effective_revenue
      + CASE
          WHEN product_effective_revenue <> 0 THEN channel_rebate * effective_revenue / product_effective_revenue
          ELSE 0
        END
    ), 0)::numeric(20,4) AS effective_revenue_add,
    GREATEST((
      effective_revenue
      - CASE
          WHEN product_effective_revenue <> 0 THEN channel_rebate * effective_revenue / product_effective_revenue
          ELSE 0
        END
    ), 0)::numeric(20,4) AS effective_revenue_subtract
  FROM allocated
)
SELECT
  'mv_real_rebate_add_vs_subtract_summary' AS check_step,
  settlement_month,
  sale_id,
  operation_manager_id,
  am_id,
  source_type,
  COUNT(*) AS row_count,
  SUM(effective_revenue)::numeric(20,4) AS source_effective_revenue,
  SUM(channel_rebate)::numeric(20,4) AS joined_channel_rebate,
  SUM(allocated_channel_rebate)::numeric(20,4) AS allocated_channel_rebate,
  SUM(effective_revenue_add)::numeric(20,4) AS effective_revenue_add,
  SUM(effective_revenue_subtract)::numeric(20,4) AS effective_revenue_subtract
FROM calculated
GROUP BY settlement_month, sale_id, operation_manager_id, am_id, source_type
ORDER BY am_id, source_type;


-- =========================
-- 第 4 段：定位真实 channel_rebate 负数来自哪张表/哪个账户
-- =========================
-- 用途：
--   第 3 段已经确认负数来自 MV 真实 channel_rebate。
--   本段拆开 BB/QI 两部分，定位负数来自：
--     1. dws_bb_card_finance_daily_p.bb_channel_cashback_comm
--     2. dws_qi_card_finance_daily_v2_p.rebate_interchange_base_amt * rebate_interchange_rate
--     3. dws_qi_card_finance_daily_v2_p.rebate_incentive_base_amt * rebate_incentive_rate
WITH params AS (
  SELECT
    DATE '2026-05-01' AS settlement_month_filter,
    'edfc4d0a-2131-440f-87a3-f3781767fa7f'::varchar AS sale_id_filter
),
account_root_relation AS (
  SELECT
    aar.root_id::text AS root_id,
    aar.account_id::text AS account_id
  FROM public.api_account_relation aar
  WHERE aar.root_id IS NOT NULL
    AND aar.account_id IS NOT NULL
),
sale_revenue_account AS (
  SELECT DISTINCT
    r.settlement_month,
    r.root_account_id,
    r.product,
    r.provider
  FROM dws.dws_sales_revenue_monthly r
  CROSS JOIN params p
  WHERE r.delete_time IS NULL
    AND r.settlement_month = p.settlement_month_filter
    AND r.sale_id = p.sale_id_filter
    AND r.metric_code NOT IN (
      'assets_acceptance_fee_gt_zero',
      'assets_acceptance_fee_eq_zero',
      'physical_card_cost'
    )
),
rebate_detail AS (
  SELECT
    date_trunc('month', b.report_date)::date AS settlement_month,
    COALESCE(aar.root_id, b.account_id) AS root_account_id,
    b.account_id,
    'qbit_card' AS product,
    'BB' AS provider,
    'bb_channel_cashback_comm' AS rebate_part,
    SUM(COALESCE(b.bb_channel_cashback_comm, 0))::numeric(20,4) AS rebate_amount
  FROM dws.dws_bb_card_finance_daily_p b
  LEFT JOIN account_root_relation aar
    ON aar.account_id = b.account_id::text
  CROSS JOIN params p
  WHERE b.delete_time IS NULL
    AND date_trunc('month', b.report_date)::date = p.settlement_month_filter
  GROUP BY date_trunc('month', b.report_date)::date, COALESCE(aar.root_id, b.account_id), b.account_id
  UNION ALL
  SELECT
    date_trunc('month', q.report_date)::date AS settlement_month,
    COALESCE(aar.root_id, q.account_id) AS root_account_id,
    q.account_id,
    'qbit_card' AS product,
    'QI' AS provider,
    'qi_rebate_interchange' AS rebate_part,
    SUM(COALESCE(q.rebate_interchange_base_amt, 0) * COALESCE(q.rebate_interchange_rate, 0))::numeric(20,4) AS rebate_amount
  FROM dws.dws_qi_card_finance_daily_v2_p q
  LEFT JOIN account_root_relation aar
    ON aar.account_id = q.account_id::text
  CROSS JOIN params p
  WHERE q.delete_time IS NULL
    AND date_trunc('month', q.report_date)::date = p.settlement_month_filter
  GROUP BY date_trunc('month', q.report_date)::date, COALESCE(aar.root_id, q.account_id), q.account_id
  UNION ALL
  SELECT
    date_trunc('month', q.report_date)::date AS settlement_month,
    COALESCE(aar.root_id, q.account_id) AS root_account_id,
    q.account_id,
    'qbit_card' AS product,
    'QI' AS provider,
    'qi_rebate_incentive' AS rebate_part,
    SUM(COALESCE(q.rebate_incentive_base_amt, 0) * COALESCE(q.rebate_incentive_rate, 0))::numeric(20,4) AS rebate_amount
  FROM dws.dws_qi_card_finance_daily_v2_p q
  LEFT JOIN account_root_relation aar
    ON aar.account_id = q.account_id::text
  CROSS JOIN params p
  WHERE q.delete_time IS NULL
    AND date_trunc('month', q.report_date)::date = p.settlement_month_filter
  GROUP BY date_trunc('month', q.report_date)::date, COALESCE(aar.root_id, q.account_id), q.account_id
)
SELECT
  'negative_rebate_source_detail' AS check_step,
  d.settlement_month,
  d.root_account_id,
  d.account_id,
  d.product,
  d.provider,
  d.rebate_part,
  d.rebate_amount
FROM rebate_detail d
JOIN sale_revenue_account a
  ON a.settlement_month = d.settlement_month
 AND a.root_account_id = d.root_account_id
 AND a.product = d.product
 AND COALESCE(a.provider, '') = COALESCE(d.provider, '')
WHERE d.rebate_amount < 0
ORDER BY d.rebate_amount ASC, d.root_account_id, d.account_id, d.rebate_part;


-- 第 4.1 段：负数来源汇总版
-- 用途：
--   如果第 4 段明细太多，先跑这个汇总版。
WITH params AS (
  SELECT
    DATE '2026-05-01' AS settlement_month_filter,
    'edfc4d0a-2131-440f-87a3-f3781767fa7f'::varchar AS sale_id_filter
),
account_root_relation AS (
  SELECT
    aar.root_id::text AS root_id,
    aar.account_id::text AS account_id
  FROM public.api_account_relation aar
  WHERE aar.root_id IS NOT NULL
    AND aar.account_id IS NOT NULL
),
sale_revenue_account AS (
  SELECT DISTINCT
    r.settlement_month,
    r.root_account_id,
    r.product,
    r.provider
  FROM dws.dws_sales_revenue_monthly r
  CROSS JOIN params p
  WHERE r.delete_time IS NULL
    AND r.settlement_month = p.settlement_month_filter
    AND r.sale_id = p.sale_id_filter
    AND r.metric_code NOT IN (
      'assets_acceptance_fee_gt_zero',
      'assets_acceptance_fee_eq_zero',
      'physical_card_cost'
    )
),
rebate_detail AS (
  SELECT
    date_trunc('month', b.report_date)::date AS settlement_month,
    COALESCE(aar.root_id, b.account_id) AS root_account_id,
    b.account_id,
    'qbit_card' AS product,
    'BB' AS provider,
    'bb_channel_cashback_comm' AS rebate_part,
    SUM(COALESCE(b.bb_channel_cashback_comm, 0))::numeric(20,4) AS rebate_amount
  FROM dws.dws_bb_card_finance_daily_p b
  LEFT JOIN account_root_relation aar
    ON aar.account_id = b.account_id::text
  CROSS JOIN params p
  WHERE b.delete_time IS NULL
    AND date_trunc('month', b.report_date)::date = p.settlement_month_filter
  GROUP BY date_trunc('month', b.report_date)::date, COALESCE(aar.root_id, b.account_id), b.account_id
  UNION ALL
  SELECT
    date_trunc('month', q.report_date)::date AS settlement_month,
    COALESCE(aar.root_id, q.account_id) AS root_account_id,
    q.account_id,
    'qbit_card' AS product,
    'QI' AS provider,
    'qi_rebate_interchange' AS rebate_part,
    SUM(COALESCE(q.rebate_interchange_base_amt, 0) * COALESCE(q.rebate_interchange_rate, 0))::numeric(20,4) AS rebate_amount
  FROM dws.dws_qi_card_finance_daily_v2_p q
  LEFT JOIN account_root_relation aar
    ON aar.account_id = q.account_id::text
  CROSS JOIN params p
  WHERE q.delete_time IS NULL
    AND date_trunc('month', q.report_date)::date = p.settlement_month_filter
  GROUP BY date_trunc('month', q.report_date)::date, COALESCE(aar.root_id, q.account_id), q.account_id
  UNION ALL
  SELECT
    date_trunc('month', q.report_date)::date AS settlement_month,
    COALESCE(aar.root_id, q.account_id) AS root_account_id,
    q.account_id,
    'qbit_card' AS product,
    'QI' AS provider,
    'qi_rebate_incentive' AS rebate_part,
    SUM(COALESCE(q.rebate_incentive_base_amt, 0) * COALESCE(q.rebate_incentive_rate, 0))::numeric(20,4) AS rebate_amount
  FROM dws.dws_qi_card_finance_daily_v2_p q
  LEFT JOIN account_root_relation aar
    ON aar.account_id = q.account_id::text
  CROSS JOIN params p
  WHERE q.delete_time IS NULL
    AND date_trunc('month', q.report_date)::date = p.settlement_month_filter
  GROUP BY date_trunc('month', q.report_date)::date, COALESCE(aar.root_id, q.account_id), q.account_id
)
SELECT
  'negative_rebate_source_summary' AS check_step,
  d.settlement_month,
  d.product,
  d.provider,
  d.rebate_part,
  COUNT(*) AS account_row_count,
  COUNT(DISTINCT d.root_account_id) AS root_account_count,
  SUM(d.rebate_amount)::numeric(20,4) AS rebate_amount
FROM rebate_detail d
JOIN sale_revenue_account a
  ON a.settlement_month = d.settlement_month
 AND a.root_account_id = d.root_account_id
 AND a.product = d.product
 AND COALESCE(a.provider, '') = COALESCE(d.provider, '')
WHERE d.rebate_amount < 0
GROUP BY d.settlement_month, d.product, d.provider, d.rebate_part
ORDER BY rebate_amount ASC;
