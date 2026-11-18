--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-18
-- Description:    销售绩效实际收入近6个月物化视图
-- Notes:
--   1. 只计算 realTimeProcessing / Total Generated Performance 使用的实际收入。
--   2. 所有收入来源直接保留来源记录中的 sale_id、am_id，不关联当前销售关系。
--   3. OpenAPI 使用 state_date 归属实收月份，账单月份单独保留为 bill_month。
--   4. BB/QI 渠道返现按收入项目单独计入；客户返现、成本和佣金不在本视图内。
--   5. 金额保留原始正负值，不使用 ABS/GREATEST 做符号修正或归零。
--   6. 普通物化视图由销售佣金/绩效收入/合伙人利润 Flink JDBC 刷新链路更新，不使用 pg_cron。
--********************************************************************--

CREATE MATERIALIZED VIEW "dws"."mv_sales_commission_performance_income_recent" AS
WITH params AS (
  SELECT
    date_trunc('month', CURRENT_DATE - interval '5 months')::date AS start_date,
    (CURRENT_DATE + 1)::date AS end_date_exclusive
),
account_root_relation AS (
  SELECT DISTINCT
    account_id::varchar AS account_id,
    root_id::varchar AS root_id
  FROM public.api_account_relation
  WHERE delete_time IS NULL
),
global_account_income_rows AS (
  SELECT
    date_trunc('month', d.create_date::timestamp)::date AS activity_month,
    NULL::date AS bill_month,
    d.root_account_id::varchar AS root_account_id,
    'group_account'::varchar AS product,
    NULLIF(TRIM(d.provider_st), '')::varchar AS provider,
    'global_account_income'::varchar AS income_type,
    NULLIF(TRIM(d.sale_id), '')::varchar AS sale_id,
    NULLIF(TRIM(d.am_id), '')::varchar AS am_id,
    SUM(COALESCE(d.income_value, 0))::numeric(20, 4) AS income_amount
  FROM dwm.dwm_global_account_sales_revenue_daily d
  CROSS JOIN params p
  WHERE d.create_date >= p.start_date
    AND d.create_date < p.end_date_exclusive
    AND d.metric_code IN ('deposit_fee', 'payment_fee', 'fx_income')
    AND NULLIF(TRIM(d.root_account_id), '') IS NOT NULL
  GROUP BY 1, 3, 5, 7, 8
),
qbit_main_fee_rows AS (
  SELECT
    date_trunc('month', d.create_date::timestamp)::date,
    NULL::date,
    d.root_account_id::varchar,
    'qbit_card'::varchar,
    NULLIF(TRIM(d.provider_st), '')::varchar,
    'main_fee'::varchar,
    NULLIF(TRIM(d.sale_id), '')::varchar,
    NULLIF(TRIM(d.am_id), '')::varchar,
    SUM(COALESCE(d.income_value, 0))::numeric(20, 4)
  FROM dwm.dwm_qbit_card_main_fee_sales_detail d
  CROSS JOIN params p
  WHERE d.create_date >= p.start_date
    AND d.create_date < p.end_date_exclusive
    AND NULLIF(TRIM(d.root_account_id), '') IS NOT NULL
  GROUP BY 1, 3, 5, 7, 8
),
qbit_virtual_card_fee_rows AS (
  SELECT
    date_trunc('month', d.create_date::timestamp)::date,
    NULL::date,
    d.root_account_id::varchar,
    'qbit_card'::varchar,
    NULLIF(TRIM(d.provider_st), '')::varchar,
    'virtual_card_create_fee'::varchar,
    NULLIF(TRIM(d.sale_id), '')::varchar,
    NULLIF(TRIM(d.am_id), '')::varchar,
    SUM(COALESCE(d.income_value, 0))::numeric(20, 4)
  FROM dwm.dwm_qbit_virtual_card_create_fee_sales_detail d
  CROSS JOIN params p
  WHERE d.create_date >= p.start_date
    AND d.create_date < p.end_date_exclusive
    AND NULLIF(TRIM(d.root_account_id), '') IS NOT NULL
  GROUP BY 1, 3, 5, 7, 8
),
qbit_recharge_fee_rows AS (
  SELECT
    date_trunc('month', d.create_month::timestamp)::date,
    NULL::date,
    d.root_account_id::varchar,
    'qbit_card'::varchar,
    NULLIF(TRIM(d.provider_st), '')::varchar,
    'recharge_fee'::varchar,
    NULLIF(TRIM(d.sale_id), '')::varchar,
    NULLIF(TRIM(d.am_id), '')::varchar,
    SUM(COALESCE(d.income_value, 0))::numeric(20, 4)
  FROM dwm.dwm_qbit_card_recharge_fee_channel_monthly_share d
  CROSS JOIN params p
  WHERE d.create_month >= p.start_date
    AND d.create_month < p.end_date_exclusive
    AND NULLIF(TRIM(d.root_account_id), '') IS NOT NULL
  GROUP BY 1, 3, 5, 7, 8
),
qbit_pc_channel_rebate_rows AS (
  SELECT
    date_trunc('month', d.create_date::timestamp)::date,
    NULL::date,
    d.root_account_id::varchar,
    'qbit_card'::varchar,
    NULLIF(TRIM(d.provider_st), '')::varchar,
    'pc_channel_rebate'::varchar,
    NULLIF(TRIM(d.sale_id), '')::varchar,
    NULLIF(TRIM(d.am_id), '')::varchar,
    SUM(COALESCE(d.income_value, 0))::numeric(20, 4)
  FROM dwm.dwm_qbit_card_cash_back_file_up_sales_detail d
  CROSS JOIN params p
  WHERE d.create_date >= p.start_date
    AND d.create_date < p.end_date_exclusive
    AND d.product = 'qbit_card'
    AND d.metric_code = 'qbit_card_cash_back_file_up_amount'
    AND NULLIF(TRIM(d.root_account_id), '') IS NOT NULL
  GROUP BY 1, 3, 5, 7, 8
),
crypto_income_rows AS (
  SELECT
    date_trunc('month', d.create_date::timestamp)::date,
    NULL::date,
    d.root_account_id::varchar,
    'crypto'::varchar,
    NULL::varchar,
    'crypto_connect_income'::varchar,
    NULLIF(TRIM(d.sale_id), '')::varchar,
    NULLIF(TRIM(d.am_id), '')::varchar,
    SUM(COALESCE(d.income_value, 0))::numeric(20, 4)
  FROM dwm.dwm_crypto_connect_sales_revenue_daily d
  CROSS JOIN params p
  WHERE d.create_date >= p.start_date
    AND d.create_date < p.end_date_exclusive
    AND d.metric_code = 'assets_acceptance_fee'
    AND NULLIF(TRIM(d.root_account_id), '') IS NOT NULL
  GROUP BY 1, 3, 7, 8
),
offline_income_rows AS (
  SELECT
    date_trunc('month', d.settlement_month::timestamp)::date,
    NULL::date,
    d.root_account_id::varchar,
    'bi_month_tag'::varchar,
    NULLIF(TRIM(d.provider), '')::varchar,
    'offline_income'::varchar,
    NULLIF(TRIM(d.sale_id), '')::varchar,
    NULLIF(TRIM(d.am_id), '')::varchar,
    SUM(COALESCE(d.metric_value, 0))::numeric(20, 4)
  FROM dwm.dwm_bi_month_tag_sales_attribution_detail d
  CROSS JOIN params p
  WHERE d.settlement_month >= p.start_date
    AND d.settlement_month < p.end_date_exclusive
    AND d.product = 'bi_month_tag'
    AND d.metric_code = 'offline_api_income_amount'
    AND NULLIF(TRIM(d.root_account_id), '') IS NOT NULL
  GROUP BY 1, 3, 5, 7, 8
),
card_creation_fee_rows AS (
  SELECT
    date_trunc('month', d.create_date::timestamp)::date,
    NULL::date,
    d.root_account_id::varchar,
    'qbit_card'::varchar,
    NULLIF(TRIM(d.provider_st), '')::varchar,
    'card_creation_fee'::varchar,
    NULLIF(TRIM(d.sale_id), '')::varchar,
    NULLIF(TRIM(d.am_id), '')::varchar,
    SUM(COALESCE(d.income_value, 0))::numeric(20, 4)
  FROM dwm.dwm_qbit_card_wallet_fee_sales_detail d
  CROSS JOIN params p
  WHERE d.create_date >= p.start_date
    AND d.create_date < p.end_date_exclusive
    AND d.product = 'qbit_card'
    AND d.metric_code = 'card_creation_fee_amount'
    AND NULLIF(TRIM(d.root_account_id), '') IS NOT NULL
  GROUP BY 1, 3, 5, 7, 8
),
api_allocation_codes(metric_code, include_in_revenue) AS (
  VALUES
    ('api_client_bill_monthly_fee_received_amount', TRUE),
    ('api_client_bill_monthly_fx_fee_received_amount', TRUE),
    ('api_client_bill_monthly_crypto_fee_received_amount', TRUE),
    ('api_client_bill_one_time_api_fee_received_amount', TRUE),
    ('api_client_bill_monthly_api_fee_received_amount', TRUE),
    ('api_client_bill_revenue_adjustment_received_amount', TRUE),
    ('api_client_bill_uncategorized_fee_received_amount', TRUE),
    ('api_client_bill_monthly_kyc_fee_received_amount', FALSE),
    ('api_client_bill_minimum_commitment_received_amount', FALSE),
    ('api_client_bill_physical_card_fee_received_amount', FALSE)
),
api_revenue_detail AS (
  SELECT
    d.state_date AS report_date,
    d.root_account_id::varchar AS root_account_id,
    NULLIF(TRIM(d.provider), '')::varchar AS provider,
    NULLIF(TRIM(d.sale_id), '')::varchar AS sale_id,
    NULLIF(TRIM(d.am_id), '')::varchar AS am_id,
    d.metric_code,
    d.income_value,
    CASE
      WHEN d.source_detail_id ~ '^DEBIT_RECORD:[0-9]+:'
        THEN split_part(d.source_detail_id, ':', 2)::bigint
      WHEN d.metric_source_id ~ '^RECEIVED:[0-9]+:'
        THEN split_part(d.metric_source_id, ':', 2)::bigint
    END AS debit_event_id
  FROM dwm.dwm_open_api_monthly_revenue_attribution_detail d
  CROSS JOIN params p
  WHERE d.product = 'open_api'
    AND d.state_date >= p.start_date
    AND d.state_date < p.end_date_exclusive
    AND NULLIF(TRIM(d.root_account_id), '') IS NOT NULL
),
api_bill_month_by_debit AS (
  SELECT
    ids.debit_event_id,
    CASE
      WHEN LEFT(TRIM(b.bill_month), 7) ~ '^[1-9][0-9]{3}-(0[1-9]|1[0-2])$'
        THEN (LEFT(TRIM(b.bill_month), 7) || '-01')::date
    END AS bill_month
  FROM (SELECT DISTINCT debit_event_id FROM api_revenue_detail) ids
  LEFT JOIN public.api_client_debit_record debit
    ON debit.id = ids.debit_event_id
  LEFT JOIN public.api_client_bill b
    ON b.id = debit.bill_id
),
api_allocated_by_debit AS (
  SELECT
    d.debit_event_id,
    SUM(d.income_value)::numeric(38, 6) AS allocated_amount
  FROM api_revenue_detail d
  JOIN api_allocation_codes c
    ON c.metric_code = d.metric_code
  GROUP BY d.debit_event_id
),
api_revenue_contributions AS (
  SELECT
    d.report_date,
    b.bill_month,
    d.root_account_id,
    d.provider,
    d.sale_id,
    d.am_id,
    d.income_value AS included_fee_amount,
    0::numeric(38, 6) AS residual_amount
  FROM api_revenue_detail d
  JOIN api_allocation_codes c
    ON c.metric_code = d.metric_code
  LEFT JOIN api_bill_month_by_debit b
    ON b.debit_event_id = d.debit_event_id
  WHERE c.include_in_revenue

  UNION ALL

  SELECT
    d.report_date,
    b.bill_month,
    d.root_account_id,
    NULL::varchar AS provider,
    d.sale_id,
    d.am_id,
    0::numeric(38, 6),
    (d.income_value - COALESCE(a.allocated_amount, 0))::numeric(38, 6)
  FROM api_revenue_detail d
  LEFT JOIN api_bill_month_by_debit b
    ON b.debit_event_id = d.debit_event_id
  LEFT JOIN api_allocated_by_debit a
    ON a.debit_event_id = d.debit_event_id
  WHERE d.metric_code = 'api_client_bill_actual_received_amount'
),
open_api_income_rows AS (
  SELECT
    date_trunc('month', c.report_date::timestamp)::date AS activity_month,
    c.bill_month,
    c.root_account_id,
    'open_api'::varchar AS product,
    c.provider,
    'month_revenue'::varchar AS income_type,
    c.sale_id,
    c.am_id,
    SUM(c.included_fee_amount + c.residual_amount)::numeric(20, 4) AS income_amount
  FROM api_revenue_contributions c
  GROUP BY 1, 2, 3, 5, 7, 8
),
bb_channel_cashback_rows AS (
  SELECT
    date_trunc('month', b.report_date::timestamp)::date,
    NULL::date,
    COALESCE(aar.root_id, b.account_id::varchar)::varchar,
    'qbit_card'::varchar,
    'BB'::varchar,
    'bb_channel_cashback'::varchar,
    NULLIF(TRIM(b.sale_id), '')::varchar,
    NULLIF(TRIM(b.am_id), '')::varchar,
    SUM(COALESCE(b.cashback_income, 0))::numeric(20, 4)
  FROM dws.dws_bb_card_finance_daily_v2_p b
  LEFT JOIN account_root_relation aar
    ON aar.account_id = b.account_id::varchar
  CROSS JOIN params p
  WHERE b.delete_time IS NULL
    AND b.report_date >= p.start_date
    AND b.report_date < p.end_date_exclusive
    AND b.account_id IS NOT NULL
  GROUP BY 1, 3, 7, 8
),
qi_channel_cashback_rows AS (
  SELECT
    date_trunc('month', qi.report_date::timestamp)::date,
    NULL::date,
    COALESCE(aar.root_id, qi.account_id::varchar)::varchar,
    'qbit_card'::varchar,
    'IQ'::varchar,
    'qi_channel_cashback'::varchar,
    NULLIF(TRIM(qi.sale_id), '')::varchar,
    NULLIF(TRIM(qi.am_id), '')::varchar,
    COALESCE(SUM(
      COALESCE(qi.rebate_interchange_base_amt, 0)
        * COALESCE(qi.rebate_interchange_rate, 1)
      + COALESCE(qi.rebate_incentive_base_amt, 0)
        * COALESCE(qi.rebate_incentive_rate, 1)
    ) FILTER (WHERE qi.special_fee_type IS NULL), 0)::numeric(20, 4)
  FROM dws.dws_qi_card_finance_daily_v2_p qi
  LEFT JOIN account_root_relation aar
    ON aar.account_id = qi.account_id::varchar
  CROSS JOIN params p
  WHERE qi.delete_time IS NULL
    AND qi.report_date >= p.start_date
    AND qi.report_date < p.end_date_exclusive
    AND qi.account_id IS NOT NULL
  GROUP BY 1, 3, 7, 8
),
all_income_rows AS (
  SELECT * FROM global_account_income_rows
  UNION ALL SELECT * FROM qbit_main_fee_rows
  UNION ALL SELECT * FROM qbit_virtual_card_fee_rows
  UNION ALL SELECT * FROM qbit_recharge_fee_rows
  UNION ALL SELECT * FROM qbit_pc_channel_rebate_rows
  UNION ALL SELECT * FROM crypto_income_rows
  UNION ALL SELECT * FROM offline_income_rows
  UNION ALL SELECT * FROM card_creation_fee_rows
  UNION ALL SELECT * FROM open_api_income_rows
  UNION ALL SELECT * FROM bb_channel_cashback_rows
  UNION ALL SELECT * FROM qi_channel_cashback_rows
),
monthly_income AS (
  SELECT
    activity_month,
    bill_month,
    root_account_id,
    product,
    provider,
    income_type,
    sale_id,
    am_id,
    SUM(income_amount)::numeric(20, 4) AS income_amount
  FROM all_income_rows
  GROUP BY
    activity_month, bill_month, root_account_id, product,
    provider, income_type, sale_id, am_id
)
SELECT
  ABS(hashtext(concat_ws(':',
    to_char(activity_month, 'YYYYMM'),
    COALESCE(to_char(bill_month, 'YYYYMM'), '<NULL>'),
    root_account_id,
    product,
    COALESCE(provider, '<NULL>'),
    income_type,
    COALESCE(sale_id, '<NULL>'),
    COALESCE(am_id, '<NULL>')
  )))::bigint AS id,
  activity_month,
  bill_month,
  root_account_id,
  product,
  provider,
  income_type,
  sale_id,
  am_id,
  income_amount,
  now() AS refreshed_at
FROM monthly_income
WITH DATA
DISTRIBUTED BY (id);

ALTER MATERIALIZED VIEW "dws"."mv_sales_commission_performance_income_recent"
  OWNER TO "flink_cdc_user";
COMMENT ON MATERIALIZED VIEW "dws"."mv_sales_commission_performance_income_recent"
  IS '销售绩效实际收入近6个月明细估算视图；包含BB/QI渠道返现，不含客户返现扣减、成本和佣金';

CREATE INDEX IF NOT EXISTS "idx_sales_commission_performance_income_month_sale"
  ON "dws"."mv_sales_commission_performance_income_recent"
  ("activity_month", "sale_id", "am_id");
CREATE INDEX IF NOT EXISTS "idx_sales_commission_performance_income_account"
  ON "dws"."mv_sales_commission_performance_income_recent"
  ("activity_month", "root_account_id", "product", "provider");
