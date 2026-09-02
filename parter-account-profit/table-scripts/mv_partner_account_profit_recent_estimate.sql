--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-09-02
-- Description:    合伙人客户毛利近6个月估算物化视图
-- Notes:
--   1. 复用销售返佣物化视图已经完成的收入/成本归集结果。
--   2. 不引入销售佣金规则和费率计算。
--   3. open_api 与 qbit_card 统一输出为 qbit_card，source_product 保留原始产品。
--   4. 负毛利原样保留，gp = effective_revenue - cogs。
--   5. month_revenue 为 API 实收，本期排除。
--********************************************************************--

DROP MATERIALIZED VIEW IF EXISTS "dws"."mv_partner_account_profit_recent_estimate";

CREATE MATERIALIZED VIEW "dws"."mv_partner_account_profit_recent_estimate" AS
WITH normalized AS (
  SELECT
    m.report_date,
    m.settlement_month,
    m.root_account_id,
    a.referral_user_id AS root_account_referral_id,
    CASE WHEN m.product IN ('open_api', 'qbit_card') THEN 'qbit_card' ELSE m.product END AS product,
    m.product AS source_product,
    m.provider,
    m.item,
    m.source_type,
    COALESCE(m.effective_revenue, 0)::numeric(20,4) AS effective_revenue,
    COALESCE(m.cogs, 0)::numeric(20,4) AS cogs
  FROM "dws"."mv_sales_commission_recent_estimate" m
  LEFT JOIN "dim"."dim_account_analysis" a
    ON a.account_id = m.root_account_id
   AND a.delete_time IS NULL
  WHERE m.settlement_month >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
    AND COALESCE(m.item, '') <> 'month_revenue'
), aggregated AS (
  SELECT
    report_date,
    settlement_month,
    root_account_id,
    root_account_referral_id,
    product,
    source_product,
    provider,
    item,
    source_type,
    SUM(effective_revenue)::numeric(20,4) AS effective_revenue,
    SUM(cogs)::numeric(20,4) AS cogs
  FROM normalized
  GROUP BY report_date, settlement_month, root_account_id, root_account_referral_id,
           product, source_product, provider, item, source_type
)
SELECT
  abs(hashtext(concat_ws(':',
    to_char(report_date, 'YYYYMMDD'),
    to_char(settlement_month, 'YYYYMM'),
    root_account_id,
    COALESCE(root_account_referral_id, ''),
    product,
    source_product,
    COALESCE(provider, ''),
    COALESCE(item, ''),
    source_type
  )))::bigint AS id,
  report_date,
  settlement_month,
  root_account_id,
  root_account_referral_id,
  product,
  source_product,
  provider,
  item,
  source_type,
  effective_revenue,
  cogs,
  (effective_revenue - cogs)::numeric(20,4) AS gp,
  now() AS refreshed_at
FROM aggregated
WITH DATA
DISTRIBUTED BY (id);

ALTER MATERIALIZED VIEW "dws"."mv_partner_account_profit_recent_estimate"
  OWNER TO "flink_cdc_user";

COMMENT ON MATERIALIZED VIEW "dws"."mv_partner_account_profit_recent_estimate" IS
  '合伙人客户毛利近6个月估算物化视图，不含API month_revenue实收和任何佣金计算';

CREATE INDEX IF NOT EXISTS "idx_mv_partner_account_profit_query"
  ON "dws"."mv_partner_account_profit_recent_estimate" (settlement_month, root_account_referral_id, root_account_id, product);

CREATE INDEX IF NOT EXISTS "idx_mv_partner_account_profit_detail"
  ON "dws"."mv_partner_account_profit_recent_estimate" (root_account_id, settlement_month, provider, item);
