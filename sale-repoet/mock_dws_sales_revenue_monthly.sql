-- Mock dws.dws_sales_revenue_monthly data from existing account-sale relation data.
-- Source accounts:
--   root_account_id = COALESCE(api_account_relation.root_id, dws_total_channel_cost_daily_v2_p.account_id)
--   remarks records whether root_id exists in api_account_relation.

WITH account_base AS (
  SELECT
    COALESCE(aar.root_id::text, qi.account_id::text) AS root_account_id,
    MIN(qi.account_id::text) AS source_account_id,
    MAX(aar.root_id::text) AS relation_root_id,
    MAX(NULLIF(qi.sale_id::text, '')) AS sale_id,
    MAX(NULLIF(qi.am_id::text, '')) AS am_id,
    MAX(ae."systemType") AS system_type,
    MAX(acc."type") AS account_type,
    MAX(CASE WHEN aar.root_id IS NOT NULL THEN 1 ELSE 0 END) AS has_root_relation
  FROM dws_total_channel_cost_daily_v2_p AS qi
  LEFT JOIN api_account_relation AS aar
    ON aar.account_id::varchar = qi.account_id
  LEFT JOIN "public"."accountExtend" AS ae
    ON ae."accountId"::text = COALESCE(aar.root_id::text, qi.account_id::text)
   AND ae."deleteTime" IS NULL
  LEFT JOIN "public"."account" AS acc
    ON acc."id"::text = COALESCE(aar.root_id::text, qi.account_id::text)
   AND acc."deleteTime" IS NULL
  GROUP BY
    COALESCE(aar.root_id::text, qi.account_id::text)
),
report_dates AS (
  SELECT DISTINCT report_date::date
  FROM (
    VALUES
      ('2026-05-02'),
      ('2026-05-08'),
      ('2026-05-25'),
      ('2026-05-30'),
      ('2026-06-02'),
      ('2026-06-08'),
      ('2026-06-25'),
      ('2026-05-30')
  ) AS v(report_date)
),
metric_map AS (
  SELECT *
  FROM (
    VALUES
      ('crypto',        '',           'main',                          30.000::numeric,     500.000::numeric),
      ('crypto',        '',           'assets_acceptance_fee_gt_zero', 100000.000::numeric, 2000000.000::numeric),
      ('crypto',        '',           'assets_acceptance_fee_eq_zero', 100000.000::numeric, 2000000.000::numeric),
      ('treasury',      '',           'main',                          30.000::numeric,     500.000::numeric),
      ('qbit_card',     'BB',         'main',                          30.000::numeric,     500.000::numeric),
      ('qbit_card',     'QI',         'main',                          30.000::numeric,     500.000::numeric),
      ('qbit_card',     'PC',         'main',                          30.000::numeric,     500.000::numeric),
      ('qbit_card',     'SL',         'main',                          30.000::numeric,     500.000::numeric),
      ('qbit_card',     'BZ',         'main',                          30.000::numeric,     500.000::numeric),
      ('qbit_card',     'BB',         'physical_card_cost',            30.000::numeric,     500.000::numeric),
      ('qbit_card',     'QI',         'physical_card_cost',            30.000::numeric,     500.000::numeric),
      ('qbit_card',     'PC',         'physical_card_cost',            30.000::numeric,     500.000::numeric),
      ('qbit_card',     'SL',         'physical_card_cost',            30.000::numeric,     500.000::numeric),
      ('qbit_card',     'BZ',         'physical_card_cost',            30.000::numeric,     500.000::numeric),
      ('group_account', 'BZ',         'main',                          30.000::numeric,     500.000::numeric),
      ('group_account', 'CL',         'main',                          30.000::numeric,     500.000::numeric),
      ('open_api',      '',           'main',                          30.000::numeric,     500.000::numeric),
      ('open_api',      '',           'month_receivable',              1000.000::numeric,   3000.000::numeric),
      ('open_api',      '',           'month_revenue',                 1000.000::numeric,   3000.000::numeric)
  ) AS m(product, provider, metric_code, min_income_value, max_income_value)
),
mock_row_candidates AS (
  SELECT
    a.root_account_id,
    CASE
      WHEN m.product = 'open_api' AND m.metric_code IN ('month_receivable', 'month_revenue')
        THEN DATE_TRUNC('month', d.report_date)::date
      ELSE d.report_date
    END AS report_date,
    DATE_TRUNC('month', d.report_date)::date AS settlement_month,
    m.product,
    m.metric_code,
    m.provider,
    a.sale_id AS sale_id,
    NULL::varchar(100) AS sale_department,
    NULL::varchar(64) AS operation_manager_id,
    NULLIF(a.am_id, '') AS am_id,
    ROUND((
      m.min_income_value
      + (
        ABS(HASHTEXT(
          CONCAT_WS(
            '|',
            a.root_account_id,
            CASE
              WHEN m.product = 'open_api' AND m.metric_code IN ('month_receivable', 'month_revenue')
                THEN DATE_TRUNC('month', d.report_date)::date::text
              ELSE d.report_date::text
            END,
            m.product,
            m.provider,
            m.metric_code,
            COALESCE(a.sale_id, ''),
            COALESCE(a.am_id, '')
          )
        )) % 1000000
      )::numeric / 1000000.000
      * (m.max_income_value - m.min_income_value)
    ), 2)::numeric(20,2) AS mock_income_value,
    CASE
      WHEN a.has_root_relation = 1 THEN LEFT(CONCAT('mock: root_id exists in api_account_relation, source_account_id=', a.source_account_id, ', root_id=', a.relation_root_id), 2000)
      ELSE LEFT(CONCAT('mock: root_id not found, use source account_id=', a.source_account_id), 2000)
    END AS remarks
  FROM account_base AS a
  CROSS JOIN report_dates AS d
  CROSS JOIN metric_map AS m
  WHERE (m.product <> 'crypto' OR a.system_type = 'QbitInternational')
    AND (m.product <> 'open_api' OR a.account_type = 'ApiClient')
),
mock_rows AS (
  SELECT
    root_account_id,
    report_date,
    settlement_month,
    product,
    metric_code,
    provider,
    MAX(sale_id) AS sale_id,
    NULL::varchar(100) AS sale_department,
    NULL::varchar(64) AS operation_manager_id,
    MAX(am_id) AS am_id,
    MAX(mock_income_value)::numeric(20,2) AS mock_income_value,
    MAX(remarks) AS remarks
  FROM mock_row_candidates
  GROUP BY
    root_account_id,
    report_date,
    settlement_month,
    product,
    metric_code,
    provider
)
INSERT INTO "dws"."dws_sales_revenue_monthly" (
  "root_account_id",
  "report_date",
  "settlement_month",
  "product",
  "metric_code",
  "provider",
  "sale_id",
  "sale_department",
  "operation_manager_id",
  "am_id",
  "income_value",
  "real_income_value",
  "loaded_at",
  "version",
  "remarks",
  "create_time",
  "update_time",
  "delete_time"
)
SELECT
  root_account_id,
  report_date,
  settlement_month,
  product,
  metric_code,
  provider,
  sale_id,
  sale_department,
  operation_manager_id,
  am_id,
  mock_income_value AS income_value,
  mock_income_value AS real_income_value,
  CURRENT_TIMESTAMP AS loaded_at,
  1 AS version,
  remarks,
  CURRENT_TIMESTAMP AS create_time,
  CURRENT_TIMESTAMP AS update_time,
  NULL::timestamp(6) AS delete_time
FROM mock_rows
ON CONFLICT ON CONSTRAINT "dws_sales_revenue_monthly_pkey"
DO UPDATE SET
  "income_value" = EXCLUDED."income_value",
  "real_income_value" = EXCLUDED."real_income_value",
  "loaded_at" = EXCLUDED."loaded_at",
  "version" = "dws_sales_revenue_monthly"."version" + 1,
  "remarks" = EXCLUDED."remarks",
  "update_time" = CURRENT_TIMESTAMP,
  "delete_time" = NULL;
