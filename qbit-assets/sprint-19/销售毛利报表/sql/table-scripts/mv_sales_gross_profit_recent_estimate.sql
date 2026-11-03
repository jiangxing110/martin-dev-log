--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-02
-- Updated Time:   2026-11-03 14:12:53
-- Description:    销售毛利近6个月日粒度估算物化视图
-- Notes:
--   1. 结构/刷新方式参考 sale-repoet/sales-commission/table-scripts/mv_sales_commission_recent_estimate_v3.sql。
--   2. 收入及客户返现保留 dws.dws_sales_metric_daily.report_date，不在视图中先归月；来源窗口与销售返佣视图一致，取近6个月。
--   3. 实时收入/实收、月账单应收、Crypto成本、实体卡毛利及返现统一从 dws.dws_sales_metric_daily 读取。
--   4. 实体卡毛利从日指标读取并单独加到毛利；不计入 Cost，实体卡真实成本仍按 BB/QI/SL/BZ 成本源公式计算。
--   5. Cost 仍汇总 DWM 成本、卡成本、Crypto 日成本、支付手续费及月度调账；不读取佣金视图 cogs/gp/commission，也不按收入权重二次分摊。
--   6. QI/BZ RS毛利返现已并入 dws_sales_metric_daily.client_rebate；Pref_GP = Pref_Rev - Cost + physical_card_gp。
--   7. 不使用 GREATEST/ABS 限制金额；收入、返现、成本、毛利均保留负数。
--********************************************************************--

DROP MATERIALIZED VIEW IF EXISTS "dws"."mv_sales_gross_profit_recent_estimate";

CREATE MATERIALIZED VIEW "dws"."mv_sales_gross_profit_recent_estimate" AS
WITH account_root_relation AS (
  SELECT
    account_id::varchar AS account_id,
    root_id::varchar AS root_id
  FROM public.api_account_relation
  WHERE delete_time IS NULL
),recent_sales_metric AS (
  SELECT
    m.report_date::date AS report_date,
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
    SUM(CASE WHEN m.metric_code = 'month_receivable' AND m.metric_type = 'income'
             THEN m.metric_value ELSE 0 END)::numeric(20,4) AS month_receivable,
    SUM(CASE WHEN m.metric_code = 'physical_card_gp'
                  AND m.product = 'qbit_card'
                  AND NULLIF(TRIM(m.provider), '') = 'IQ'
             THEN m.metric_value ELSE 0 END)::numeric(20,4) AS physical_card_gp,
    SUM(CASE WHEN m.metric_code IN ('assets_acceptance_fee_gt_zero', 'assets_acceptance_fee_eq_zero')
                  AND m.metric_type = 'cost'
             THEN m.metric_value ELSE 0 END)::numeric(20,4) AS crypto_acceptance_cost,
    SUM(CASE WHEN m.metric_code = 'client_rebate' AND m.metric_type = 'cost'
             THEN m.metric_value ELSE 0 END)::numeric(20,4) AS client_rebate,
    SUM(CASE WHEN m.metric_code = 'client_collection_rebate' AND m.metric_type = 'cost'
             THEN m.metric_value ELSE 0 END)::numeric(20,4) AS client_collection_rebate,
    0::numeric(20,4) AS gross_profit_rebate
  FROM "dws"."dws_sales_metric_daily" m
  WHERE m.delete_time IS NULL
    AND m.report_date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
    AND m.metric_code IN (
      'main',
      'month_receivable',
      'physical_card_gp',
      'assets_acceptance_fee_gt_zero',
      'assets_acceptance_fee_eq_zero',
      'client_rebate',
      'client_collection_rebate'
    )
  GROUP BY
    m.report_date::date,
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
bb_month_net_amount AS (
  SELECT
    date_trunc('month', report_date)::date AS report_month,
    SUM(COALESCE(total_net_amount, 0))::numeric(20,4) AS month_total_net_amount
  FROM "dws"."dws_bb_card_finance_daily_v2_p"
  WHERE delete_time IS NULL
    AND report_date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY date_trunc('month', report_date)::date
),raw_cost_rows AS (
  -- DWM 已经按客户和日期分摊，直接读取 cost_amount，并沿用源表 sale_id。
  SELECT
    c.report_date::date AS report_date,
    COALESCE(aar.root_id, c.account_id)::varchar AS root_account_id,
    CASE c.product_line
      WHEN 'GLOBAL_ACCOUNT' THEN 'group_account'
      WHEN 'QUANTUM_CARD' THEN 'qbit_card'
    END::varchar AS product,
    CASE
      WHEN c.product_line = 'GLOBAL_ACCOUNT' AND c.cost_type = 'SETTLEMENT_COST' THEN NULL::varchar
      WHEN c.product_line = 'QUANTUM_CARD' AND c.provider = 'BPC' THEN 'IQ'::varchar
      ELSE NULLIF(TRIM(c.provider), '')::varchar
    END AS provider,
    c.sale_id::varchar AS sale_id,
    SUM(COALESCE(c.cost_amount, 0))::numeric(20,4) AS source_cost
  FROM "dwm"."dwm_finance_channel_cost_p" c
  LEFT JOIN account_root_relation aar
    ON aar.account_id = c.account_id::varchar
  WHERE c.delete_time IS NULL
    AND c.report_date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
    AND (
      (c.product_line = 'GLOBAL_ACCOUNT'
       AND (c.provider IN ('BZ', 'CL') OR c.cost_type = 'SETTLEMENT_COST'))
      OR (c.product_line = 'QUANTUM_CARD' AND c.provider = 'BPC')
    )
  GROUP BY c.report_date::date, COALESCE(aar.root_id, c.account_id),
           c.product_line,
           CASE
             WHEN c.product_line = 'GLOBAL_ACCOUNT' AND c.cost_type = 'SETTLEMENT_COST' THEN NULL::varchar
             WHEN c.product_line = 'QUANTUM_CARD' AND c.provider = 'BPC' THEN 'IQ'::varchar
             ELSE NULLIF(TRIM(c.provider), '')::varchar
           END,
           c.sale_id

  UNION ALL

  -- BB 按来源日计算；月累计净额只用于应用当月阶梯费率，不再分摊佣金视图的 cogs。
  SELECT
    b.report_date::date,
    COALESCE(aar.root_id, b.account_id)::varchar,
    'qbit_card'::varchar,
    'BB'::varchar,
    b.sale_id::varchar,
    SUM(
        COALESCE(b.m_dom_auth_count, 0) * 0.1090
      + COALESCE(b.m_int_auth_count, 0) * 0.4845
      + COALESCE(b.v_dom_auth_count, 0) * 0.0725
      + COALESCE(b.v_int_auth_count, 0) * 0.4770
      + COALESCE(b.av_m_dom_count, 0) * 0.1090
      + COALESCE(b.av_m_int_count, 0) * 0.4845
      + COALESCE(b.av_v_dom_count, 0) * 0.0725
      + COALESCE(b.av_v_int_count, 0) * 0.4770
      + COALESCE(b.m_dom_clearing_vol, 0) * 0.0021
      + COALESCE(b.m_int_clearing_vol, 0) * 0.0111
      + COALESCE(b.v_dom_clearing_vol, 0) * 0.0016
      + COALESCE(b.v_int_clearing_vol, 0) * 0.0116
      + COALESCE(b.m_int_reversal_count, 0) * 0.7190
      + COALESCE(b.v_int_reversal_count, 0) * 0.7140
      + COALESCE(b.dom_reversal_count, 0) * 0.1780
      + COALESCE(b.m_int_refund_count, 0) * 0.4845
      + COALESCE(b.v_int_refund_count, 0) * 0.4770
      + COALESCE(b.dom_refund_count, 0) * 0.1090
      + COALESCE(b.m_int_decline_count, 0) * 0.3595
      + COALESCE(b.v_int_decline_count, 0) * 0.3570
      + COALESCE(b.dom_decline_count, 0) * 0.0890
      + COALESCE(b.ac_m_int_decline_count, 0) * 0.3595
      + COALESCE(b.ac_v_int_decline_count, 0) * 0.3570
      + COALESCE(b.ac_dom_decline_count, 0) * 0.0890
      + COALESCE(b.active_card_count, 0) * 0.1000
      + CASE
          WHEN COALESCE(mn.month_total_net_amount, 0) = 0 THEN 0
          WHEN mn.month_total_net_amount <= 5000000
            THEN COALESCE(b.total_net_amount, 0) * 0.0055
          WHEN mn.month_total_net_amount <= 10000000
            THEN COALESCE(b.total_net_amount, 0) / mn.month_total_net_amount
               * (5000000 * 0.0055 + (mn.month_total_net_amount - 5000000) * 0.0045)
          ELSE COALESCE(b.total_net_amount, 0) / mn.month_total_net_amount
               * (5000000 * 0.0055 + 5000000 * 0.0045 + (mn.month_total_net_amount - 10000000) * 0.0040)
        END
      + COALESCE(b.cost_fixed_fee, 0)
    )::numeric(20,4)
  FROM "dws"."dws_bb_card_finance_daily_v2_p" b
  LEFT JOIN account_root_relation aar ON aar.account_id = b.account_id::varchar
  LEFT JOIN bb_month_net_amount mn
    ON mn.report_month = date_trunc('month', b.report_date)::date
  WHERE b.delete_time IS NULL
    AND b.report_date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY b.report_date::date, COALESCE(aar.root_id, b.account_id), b.sale_id

  UNION ALL

  SELECT
    q.report_date::date,
    COALESCE(aar.root_id::varchar, q.account_id::varchar),
    'qbit_card'::varchar,
    'IQ'::varchar,
    q.sale_id::varchar,
    SUM(
        COALESCE(q.cost_reimbursement_base_amt, 0) * COALESCE(q.cost_reimbursement_rate, 1)
      + COALESCE(q.cost_service_base_amt, 0) * COALESCE(q.cost_service_rate, 1)
      + COALESCE(q.cost_acs_regular_base_amt, 0) * COALESCE(q.cost_acs_regular_rate, 1)
      + COALESCE(q.cost_acs_vip_base_amt, 0) * COALESCE(q.cost_acs_vip_rate, 1)
      + COALESCE(q.cost_vrm_base_amt, 0) * COALESCE(q.cost_vrm_rate, 1)
      + COALESCE(q.cost_hk_regular_base_amt, 0) * COALESCE(q.cost_hk_regular_rate, 1)
      + COALESCE(q.cost_hk_vip_base_amt, 0) * COALESCE(q.cost_hk_vip_rate, 1)
      + COALESCE(q.cost_dcsf_base_amt, 0) * COALESCE(q.cost_dcsf_rate, 1)
      + COALESCE(q.cost_fixed_fee, 0)
    )::numeric(20,4)
  FROM "dws"."dws_qi_card_finance_daily_v2_p" q
  LEFT JOIN account_root_relation aar ON aar.account_id = q.account_id::varchar
  WHERE q.delete_time IS NULL
    AND q.report_date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY q.report_date::date, COALESCE(aar.root_id::varchar, q.account_id::varchar), q.sale_id

  UNION ALL

  SELECT
    s.report_date::date,
    COALESCE(aar.root_id, s.account_id)::varchar,
    'qbit_card'::varchar,
    'SL'::varchar,
    s.sale_id::varchar,
    SUM(COALESCE(s.cost_fixed_fee, 0))::numeric(20,4)
  -- SL v2 CDC/Batch 链路写入该表名，保留源 sale_id 与 report_date。
  FROM "dws"."dws_sl_card_finance_daily_p" s
  LEFT JOIN account_root_relation aar ON aar.account_id = s.account_id::varchar
  WHERE s.delete_time IS NULL
    AND s.report_date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY s.report_date::date, COALESCE(aar.root_id, s.account_id), s.sale_id

  UNION ALL

  SELECT
    z.report_date::date,
    COALESCE(aar.root_id, z.account_id)::varchar,
    'qbit_card'::varchar,
    'BZ'::varchar,
    z.sale_id::varchar,
    SUM(
        COALESCE(z.refund_base_amt, 0) * COALESCE(z.reimbursement_rate, 0)
      + COALESCE(z.visa_charges_base_amt, 0) * COALESCE(z.visa_charges_rate, 0)
      + COALESCE(z.card_create_count, 0) * COALESCE(z.card_setup_rate, 0)
      + COALESCE(z.card_create_count, 0) * COALESCE(z.account_activation_rate, 0)
      + COALESCE(z.card_active_count, 0) * COALESCE(z.account_on_file_rate, 0)
      + COALESCE(z.settlement_volume, 0) * COALESCE(z.service_fee_rate, 0)
      + COALESCE(z.verify_count, 0) * COALESCE(z.verify_fee_rate, 0)
      + COALESCE(z.auth_count, 0) * COALESCE(z.auth_fee_rate, 0)
      + COALESCE(z.clearing_count, 0) * COALESCE(z.clearing_fee_rate, 0)
      + COALESCE(z.refund_count, 0) * COALESCE(z.refund_fee_rate, 0)
      + COALESCE(z.reversal_count, 0) * COALESCE(z.reversal_fee_rate, 0)
      + COALESCE(z.cost_fixed_fee, 0)
    )::numeric(20,4)
  FROM "dws"."dws_bz_card_finance_daily_v2_p" z
  LEFT JOIN account_root_relation aar ON aar.account_id = z.account_id::varchar
  WHERE z.delete_time IS NULL
    AND z.report_date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY z.report_date::date, COALESCE(aar.root_id, z.account_id), z.sale_id

  UNION ALL

  SELECT
    ptr.submit_time::date,
    COALESCE(aar.root_id, ptr.account_id)::varchar,
    'group_account'::varchar,
    NULL::varchar,
    NULL::varchar,
    SUM(COALESCE(NULLIF((regexp_match(ptr.extra,
      '"fee_cost"[[:space:]]*:[[:space:]]*"?([-+]?[0-9]+([.][0-9]+)?)"?'))[1], '')::numeric, 0))::numeric(20,4)
  FROM ods.ods_payment_transaction_record ptr
  LEFT JOIN account_root_relation aar ON aar.account_id = ptr.account_id::varchar
  WHERE ptr.delete_time IS NULL
    AND ptr.dt >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
    AND ptr.status = 'Closed'
    AND ptr.submit_time >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY ptr.submit_time::date, COALESCE(aar.root_id, ptr.account_id)

  UNION ALL

  -- bi_month_tag 调账按所属月份1号归属，避免使用录入/更新时间制造日分摊。
  SELECT
    date_trunc('month', t.statistics_time AT TIME ZONE 'Asia/Shanghai')::date,
    COALESCE(aar.root_id, t.account_id)::varchar,
    CASE t.product_line
      WHEN 'GLOBAL_ACCOUNT' THEN 'group_account'
      WHEN 'QUANTUM_CARD' THEN 'qbit_card'
      WHEN 'CRYPTO_ASSET' THEN 'crypto'
    END::varchar,
    CASE WHEN t.product_line = 'GLOBAL_ACCOUNT' THEN NULL::varchar ELSE 'OFFLINE_REFUND'::varchar END,
    NULL::varchar,
    SUM(COALESCE(t.amount, 0))::numeric(20,4)
  FROM ods.ods_bi_month_tag t
  LEFT JOIN account_root_relation aar ON aar.account_id = t.account_id::varchar
  WHERE t.delete_time IS NULL
    AND t.account_id IS NOT NULL
    AND t.tag = 'OFFLINE_REFUND'
    AND date_trunc('month', t.statistics_time AT TIME ZONE 'Asia/Shanghai')::date
        >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY date_trunc('month', t.statistics_time AT TIME ZONE 'Asia/Shanghai')::date,
           COALESCE(aar.root_id, t.account_id), t.product_line

  UNION ALL

  -- Crypto acceptance fee 已清洗到日指标，按日指标有符号金额直接计入成本。
  SELECT
    m.report_date,
    m.root_account_id::varchar,
    m.product::varchar,
    m.provider::varchar,
    m.sale_id::varchar,
    m.crypto_acceptance_cost::numeric(20,4) AS source_cost
  FROM recent_sales_metric m
  WHERE m.crypto_acceptance_cost <> 0
),cost_account_dates AS (
  -- 多个成本来源会落在同一账户和业务日；销售归属只需按账户/日期查一次。
  SELECT DISTINCT report_date, root_account_id
  FROM raw_cost_rows
  WHERE sale_id IS NULL
),cost_owner_by_date AS (
  SELECT
    d.report_date,
    d.root_account_id,
    owner.sale_id::varchar AS sale_id
  FROM cost_account_dates d
  LEFT JOIN LATERAL (
    SELECT sr_inner.sale_id
    FROM "dim"."dim_sale_account_relation_p" sr_inner
    WHERE sr_inner.relation_account_id = d.root_account_id
      AND sr_inner.delete_time IS NULL
      AND sr_inner.relation_start_time <= d.report_date
    ORDER BY
      CASE WHEN sr_inner.relation_end_time IS NULL OR d.report_date < sr_inner.relation_end_time THEN 0 ELSE 1 END,
      sr_inner.relation_start_time DESC,
      sr_inner.id DESC
    LIMIT 1
  ) owner ON true
),mapped_cost_rows AS (
  SELECT
    c.report_date,
    c.root_account_id,
    c.product,
    c.provider,
    COALESCE(c.sale_id, owner.sale_id)::varchar AS sale_id,
    c.source_cost
  FROM raw_cost_rows c
  LEFT JOIN cost_owner_by_date owner
    ON c.sale_id IS NULL
   AND owner.report_date = c.report_date
   AND owner.root_account_id = c.root_account_id
),cost_by_sale_dimension AS (
  SELECT
    report_date,
    date_trunc('month', report_date)::date AS settlement_month,
    root_account_id,
    product,
    provider,
    sale_id,
    SUM(COALESCE(source_cost, 0))::numeric(20,4) AS source_cost
  FROM mapped_cost_rows
  GROUP BY report_date, date_trunc('month', report_date)::date,
           root_account_id, product, provider, sale_id
),
sales_rows AS (
  SELECT
    m.report_date,
    m.report_month,
    m.settlement_month,
    m.root_account_id,
    m.product,
    m.provider,
    m.sale_id,
    'main'::varchar AS metric_code,
    'sales_metric_daily'::varchar AS source_type,
    m.main_revenue::numeric(20,4) AS pref_rev,
    m.client_rebate,
    m.client_collection_rebate,
    0::numeric(20,4) AS gross_profit_rebate,
    CASE WHEN m.product = 'qbit_card' AND m.provider = 'IQ' THEN m.physical_card_gp ELSE 0 END::numeric(20,4) AS physical_card_gp,
    -- Cost 只包含真实成本来源；实体卡毛利单独参与 GP，不进入 Cost 或 Rebate。
    COALESCE(c.source_cost, 0)::numeric(20,4) AS cost,
    m.main_revenue::numeric(20,4) AS cashflow_rev_sale
  FROM recent_sales_metric m
  LEFT JOIN cost_by_sale_dimension c
    ON c.report_date = m.report_date
   AND c.root_account_id = m.root_account_id
   AND c.product = m.product
   AND c.provider IS NOT DISTINCT FROM m.provider
   AND c.sale_id = m.sale_id
),month_receivable_rows AS (
  -- 本月月账单应收与实时收入分行保留，便于按原 metric_code 追溯。
  SELECT
    m.report_date,
    m.report_month,
    m.settlement_month,
    m.root_account_id,
    m.product,
    m.provider,
    m.sale_id,
    'month_receivable'::varchar AS metric_code,
    'sales_metric_daily'::varchar AS source_type,
    m.month_receivable::numeric(20,4) AS pref_rev,
    0::numeric(20,4) AS client_rebate,
    0::numeric(20,4) AS client_collection_rebate,
    0::numeric(20,4) AS gross_profit_rebate,
    0::numeric(20,4) AS physical_card_gp,
    0::numeric(20,4) AS cost,
    0::numeric(20,4) AS cashflow_rev_sale
  FROM recent_sales_metric m
  WHERE m.month_receivable <> 0
),cost_only_rows AS (
  SELECT
    c.report_date,
    date_trunc('month', c.report_date)::date AS report_month,
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
    0::numeric(20,4) AS physical_card_gp,
    c.source_cost AS cost,
    0::numeric(20,4) AS cashflow_rev_sale
  FROM cost_by_sale_dimension c
  WHERE NOT EXISTS (
    SELECT 1
    FROM recent_sales_metric m
    WHERE m.report_date = c.report_date
      AND m.root_account_id = c.root_account_id
      AND m.product = c.product
      AND m.provider IS NOT DISTINCT FROM c.provider
      AND m.sale_id = c.sale_id
  )
),all_rows AS (
  SELECT * FROM sales_rows
  UNION ALL SELECT * FROM month_receivable_rows
  UNION ALL SELECT * FROM cost_only_rows
),calculated AS (
  SELECT
    report_date,
    report_month,
    report_month AS settlement_month,
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
    physical_card_gp::numeric(20,4) AS physical_card_gp,
    (client_rebate + client_collection_rebate + gross_profit_rebate)::numeric(20,4) AS rebate,
    (pref_rev - client_rebate - client_collection_rebate - gross_profit_rebate)::numeric(20,4) AS pref_rev_effective,
    cost::numeric(20,4) AS cost,
    (pref_rev - cost + physical_card_gp)::numeric(20,4) AS pref_gp,
    cashflow_rev_sale::numeric(20,4) AS cashflow_rev_sale,
    (cashflow_rev_sale - client_rebate - client_collection_rebate - gross_profit_rebate)::numeric(20,4) AS cashflow_rev_sale_effective,
    (cashflow_rev_sale - cost + physical_card_gp)::numeric(20,4) AS cashflow_gp_sale
  FROM all_rows
)
SELECT
  abs(hashtext(concat_ws(':',
    to_char(report_date, 'YYYYMMDD'), to_char(settlement_month, 'YYYYMM'),
    root_account_id, product, COALESCE(provider, '<NULL>'),
    COALESCE(sale_id, '<NULL>'), metric_code, source_type
  )))::bigint AS id,
  report_date,
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
COMMENT ON MATERIALIZED VIEW "dws"."mv_sales_gross_profit_recent_estimate" IS '销售毛利近6个月日粒度估算视图；report_date 保留业务日期，负数原样保留';
CREATE INDEX IF NOT EXISTS "idx_mv_sales_gross_profit_recent_estimate_query"
  ON "dws"."mv_sales_gross_profit_recent_estimate" ("report_date", "sale_id", "root_account_id");
CREATE INDEX IF NOT EXISTS "idx_mv_sales_gross_profit_recent_estimate_detail"
  ON "dws"."mv_sales_gross_profit_recent_estimate" ("root_account_id", "report_date", "product", "provider");
