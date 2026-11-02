--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-02
-- Description:    销售毛利近6个月估算物化视图
-- Notes:
--   1. 结构/刷新方式参考 sale-repoet/sales-commission/table-scripts/mv_sales_commission_recent_estimate_v3.sql。
--   2. 收入及客户返现输入改为 dws.dws_sales_metric_daily（日粒度，按report_date归月）。
--   3. 当前月API账单应收读取 dws.dws_metrics_sales_revenue_monthly.month_receivable；月度行按 settlement_month 归属。
--   4. 成本沿用销售佣金预估视图的 cogs 分配结果；不读取佣金 gp/commission 字段。
--   5. QI/BZ RS毛利返现从 public.cash_back_bonuses 项目记录读取。
--   6. 不使用 GREATEST/ABS 限制金额；收入、返现、成本、毛利均保留负数。
--********************************************************************--

DROP MATERIALIZED VIEW IF EXISTS "dws"."mv_sales_gross_profit_recent_estimate";

CREATE MATERIALIZED VIEW "dws"."mv_sales_gross_profit_recent_estimate" AS
WITH account_root_relation AS (
  SELECT
    account_id::varchar AS account_id,
    root_id::varchar AS root_id
  FROM public.api_account_relation
  WHERE delete_time IS NULL
),
recent_sales_metric AS (
  SELECT
    date_trunc('month', m.report_date)::date AS settlement_month,
    date_trunc('month', m.report_date)::date AS report_month,
    m.root_account_id,
    CASE
      WHEN m.product = 'crypto_connect' THEN 'crypto'
      WHEN m.product = 'global_account' THEN 'group_account'
      ELSE m.product
    END AS product,
    NULLIF(TRIM(m.provider), '') AS provider,
    m.sale_id,
    SUM(CASE WHEN m.metric_code = 'main' AND m.metric_type = 'income'
             THEN m.metric_value ELSE 0 END)::numeric(20,4) AS main_revenue,
    SUM(CASE WHEN m.metric_code = 'client_rebate'
             THEN m.metric_value ELSE 0 END)::numeric(20,4) AS client_rebate,
    SUM(CASE WHEN m.metric_code = 'client_collection_rebate'
             THEN m.metric_value ELSE 0 END)::numeric(20,4) AS client_collection_rebate
  FROM "dws"."dws_sales_metric_daily" m
  WHERE m.delete_time IS NULL
    AND m.report_date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
    AND m.sale_id IS NOT NULL
  GROUP BY
    date_trunc('month', m.report_date)::date,
    m.root_account_id,
    CASE
      WHEN m.product = 'crypto_connect' THEN 'crypto'
      WHEN m.product = 'global_account' THEN 'group_account'
      ELSE m.product
    END,
    NULLIF(TRIM(m.provider), ''),
    m.sale_id
),
api_month_receivable AS (
  SELECT
    r.settlement_month,
    date_trunc('month', r.report_date)::date AS report_month,
    r.root_account_id,
    'open_api'::varchar AS product,
    NULLIF(TRIM(r.provider), '') AS provider,
    r.sale_id,
    SUM(COALESCE(r.income_value, 0))::numeric(20,4) AS pref_rev
  FROM "dws"."dws_metrics_sales_revenue_monthly" r
  WHERE r.delete_time IS NULL
    AND r.product = 'open_api'
    AND r.metric_code = 'month_receivable'
    AND r.settlement_month >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY r.settlement_month, date_trunc('month', r.report_date)::date,
           r.root_account_id, NULLIF(TRIM(r.provider), ''), r.sale_id
),
cost_by_sale_dimension AS (
  SELECT
    c.settlement_month,
    c.root_account_id,
    CASE
      WHEN c.product = 'crypto_connect' THEN 'crypto'
      WHEN c.product = 'global_account' THEN 'group_account'
      ELSE c.product
    END AS product,
    NULLIF(TRIM(c.provider), '') AS provider,
    c.sale_id,
    SUM(COALESCE(c.cogs, 0))::numeric(20,4) AS source_cost
  FROM "dws"."mv_sales_commission_recent_estimate" c
  WHERE c.settlement_month >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
    AND c.sale_id IS NOT NULL
  GROUP BY c.settlement_month, c.root_account_id,
           CASE
             WHEN c.product = 'crypto_connect' THEN 'crypto'
             WHEN c.product = 'global_account' THEN 'group_account'
             ELSE c.product
           END,
           NULLIF(TRIM(c.provider), ''), c.sale_id
),
sales_month_root AS (
  SELECT DISTINCT settlement_month, root_account_id, sale_id
  FROM recent_sales_metric
),
gross_profit_rebate_by_sale AS (
  SELECT
    to_date(b.month || '-01', 'YYYY-MM-DD') AS settlement_month,
    sm.root_account_id,
    sm.sale_id,
    SUM(COALESCE(b.cash_back_amount, 0))::numeric(20,4) AS gross_profit_rebate
  FROM public.cash_back_bonuses b
  LEFT JOIN account_root_relation ar
    ON ar.account_id = b.account_id::varchar
  JOIN sales_month_root sm
    ON sm.root_account_id = COALESCE(ar.root_id, b.account_id::varchar)
   AND sm.settlement_month = to_date(b.month || '-01', 'YYYY-MM-DD')
  WHERE b.status <> 'Cancelled'
    AND b.delete_time IS NULL
    AND b.project IN ('QuantumCardQIRSProfitCashBack', 'QuantumCardBZRSProfitCashBack')
    AND to_date(b.month || '-01', 'YYYY-MM-DD') >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY to_date(b.month || '-01', 'YYYY-MM-DD'), sm.root_account_id, sm.sale_id
),sales_rows AS (
  SELECT
    m.report_month,
    m.settlement_month,
    m.root_account_id,
    m.product,
    m.provider,
    m.sale_id,
    'main'::varchar AS metric_code,
    'sales_metric_daily'::varchar AS source_type,
    m.main_revenue AS pref_rev,
    m.client_rebate,
    m.client_collection_rebate,
    0::numeric(20,4) AS gross_profit_rebate,
    COALESCE(c.source_cost, 0)::numeric(20,4)
      + m.client_rebate + m.client_collection_rebate AS cost,
    m.main_revenue AS cashflow_rev_sale
  FROM recent_sales_metric m
  LEFT JOIN cost_by_sale_dimension c
    ON c.settlement_month = m.settlement_month
   AND c.root_account_id = m.root_account_id
   AND c.product = m.product
   AND c.provider IS NOT DISTINCT FROM m.provider
   AND c.sale_id = m.sale_id
),api_receivable_rows AS (
  SELECT
    a.report_month,
    a.settlement_month,
    a.root_account_id,
    a.product,
    a.provider,
    a.sale_id,
    'month_receivable'::varchar AS metric_code,
    'api_month_receivable'::varchar AS source_type,
    a.pref_rev,
    0::numeric(20,4) AS client_rebate,
    0::numeric(20,4) AS client_collection_rebate,
    0::numeric(20,4) AS gross_profit_rebate,
    0::numeric(20,4) AS cost,
    0::numeric(20,4) AS cashflow_rev_sale
  FROM api_month_receivable a
),gross_profit_rebate_rows AS (
  SELECT
    g.settlement_month AS report_month,
    g.settlement_month,
    g.root_account_id,
    'gross_profit_rebate'::varchar AS product,
    NULL::varchar AS provider,
    g.sale_id,
    'gross_profit_rebate'::varchar AS metric_code,
    'gross_profit_rebate'::varchar AS source_type,
    0::numeric(20,4) AS pref_rev,
    0::numeric(20,4) AS client_rebate,
    0::numeric(20,4) AS client_collection_rebate,
    g.gross_profit_rebate,
    g.gross_profit_rebate AS cost,
    0::numeric(20,4) AS cashflow_rev_sale
  FROM gross_profit_rebate_by_sale g
),cost_only_rows AS (
  SELECT
    c.settlement_month AS report_month,
    c.settlement_month,
    c.root_account_id,
    c.product,
    c.provider,
    c.sale_id,
    'sales_cost'::varchar AS metric_code,
    'sales_cost'::varchar AS source_type,
    0::numeric(20,4) AS pref_rev,
    0::numeric(20,4) AS client_rebate,
    0::numeric(20,4) AS client_collection_rebate,
    0::numeric(20,4) AS gross_profit_rebate,
    c.source_cost AS cost,
    0::numeric(20,4) AS cashflow_rev_sale
  FROM cost_by_sale_dimension c
  WHERE NOT EXISTS (
    SELECT 1
    FROM recent_sales_metric m
    WHERE m.settlement_month = c.settlement_month
      AND m.root_account_id = c.root_account_id
      AND m.product = c.product
      AND m.provider IS NOT DISTINCT FROM c.provider
      AND m.sale_id = c.sale_id
  )
),all_rows AS (
  SELECT * FROM sales_rows
  UNION ALL SELECT * FROM api_receivable_rows
  UNION ALL SELECT * FROM gross_profit_rebate_rows
  UNION ALL SELECT * FROM cost_only_rows
),calculated AS (
  SELECT
    report_month,
    settlement_month,
    root_account_id,
    product,
    provider,
    sale_id,
    metric_code,
    source_type,
    pref_rev::numeric(20,4) AS pref_rev,
    client_rebate::numeric(20,4) AS client_rebate,
    client_collection_rebate::numeric(20,4) AS client_collection_rebate,
    gross_profit_rebate::numeric(20,4) AS gross_profit_rebate,
    (client_rebate + client_collection_rebate + gross_profit_rebate)::numeric(20,4) AS rebate,
    (pref_rev - client_rebate - client_collection_rebate - gross_profit_rebate)::numeric(20,4) AS pref_rev_effective,
    cost::numeric(20,4) AS cost,
    (pref_rev - cost)::numeric(20,4) AS pref_gp,
    cashflow_rev_sale::numeric(20,4) AS cashflow_rev_sale,
    (cashflow_rev_sale - client_rebate - client_collection_rebate - gross_profit_rebate)::numeric(20,4) AS cashflow_rev_sale_effective,
    (cashflow_rev_sale - cost)::numeric(20,4) AS cashflow_gp_sale
  FROM all_rows
)
SELECT
  abs(hashtext(concat_ws(':',
    to_char(report_month, 'YYYYMM'), to_char(settlement_month, 'YYYYMM'),
    root_account_id, product, COALESCE(provider, '<NULL>'),
    COALESCE(sale_id, '<NULL>'), metric_code, source_type
  )))::bigint AS id,
  report_month,
  settlement_month,
  root_account_id,
  product,
  provider,
  sale_id,
  metric_code,
  source_type,
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
  cashflow_gp_sale,
  now() AS refreshed_at
FROM calculated
WITH DATA
DISTRIBUTED BY (id);

ALTER MATERIALIZED VIEW "dws"."mv_sales_gross_profit_recent_estimate" OWNER TO "flink_cdc_user";
COMMENT ON MATERIALIZED VIEW "dws"."mv_sales_gross_profit_recent_estimate" IS '销售毛利近6个月估算视图；收入/返现按销售日指标表归月，负数原样保留';
CREATE INDEX IF NOT EXISTS "idx_mv_sales_gross_profit_recent_estimate_query"
  ON "dws"."mv_sales_gross_profit_recent_estimate" ("settlement_month", "sale_id", "root_account_id");
CREATE INDEX IF NOT EXISTS "idx_mv_sales_gross_profit_recent_estimate_detail"
  ON "dws"."mv_sales_gross_profit_recent_estimate" ("root_account_id", "settlement_month", "product", "provider");
