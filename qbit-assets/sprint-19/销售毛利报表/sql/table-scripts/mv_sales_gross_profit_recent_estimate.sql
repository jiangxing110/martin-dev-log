--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-02
-- Updated Time:   2026-11-26 12:03:58
-- Description:    销售毛利近3个自然月日粒度估算物化视图
-- Notes:
--   1. 结构/刷新方式参考 sale-repoet/sales-commission/table-scripts/mv_sales_commission_recent_estimate_v3.sql。
--   2. 收入及客户返现保留 dws.dws_sales_metric_daily.report_date，不在视图中先归月；窗口为当前月及前两个月，采用月初左闭、下月月初右开。
--   3. 实时收入、Open API实收及返现等日指标从 dws.dws_sales_metric_daily 读取；Open API月账单应收和BI离线API收入从月度汇总表读取。
--   4. 三类 GP 均按对应收入减真实成本后，加实体卡毛利 physical_card_gp。
--   5. Cost 仍汇总 DWM 成本、卡成本、Crypto 日成本、支付手续费及月度调账；不读取佣金视图 cogs/gp/commission，也不按收入权重二次分摊。
--   6. QI/BZ RS毛利返现已并入 dws_sales_metric_daily.client_rebate。
--   7. 不使用 GREATEST/ABS 限制金额；收入、返现、成本、毛利均保留负数。
--   8. 补入 Open API offline_api_income_amount、量子卡渠道返现及 BI 月度收入/返现调账来源。
--   9. BI月度收入及 ods_bi_month_tag 调账按业务月份首日记录；日指标应收/实收及返现保留来源日和 sale_id。
--  10. BB、QI、BZ 日财务各扫描一次，同时汇总成本和渠道返现；API 子户沿用根账户销售，其他行仅在 sale_id、am_id 均为空时回查。
--  11. BB volume_fee_cost 已在上游按日分摊，视图直接读取该字段，不重复计算月度阶梯费。
--  12. BB、QI、BZ 仍按销售维度汇总；am_id 为根账户归属核对字段，不参与金额分组。
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
    SUM(CASE WHEN m.metric_code = 'api_client_bill_actual_received_amount' AND m.metric_type = 'income'
             THEN m.metric_value ELSE 0 END)::numeric(20,4) AS api_actual_received_amount,
    SUM(CASE
      WHEN m.metric_type = 'income'
       AND m.metric_code = 'api_client_bill_actual_received_amount'
        THEN m.metric_value
      WHEN m.metric_type = 'income'
       AND m.metric_code IN (
         'api_client_bill_monthly_kyc_fee_received_amount',
         'api_client_bill_physical_card_fee_received_amount',
         'api_client_bill_minimum_commitment_received_amount'
       )
        THEN -m.metric_value
      ELSE 0
    END)::numeric(20,4) AS api_actual_received_sale_amount,
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
    AND m.report_date >= date_trunc('month', CURRENT_DATE - interval '2 months')::date
    AND m.report_date < date_trunc('month', CURRENT_DATE + interval '1 month')::date
    AND m.metric_code IN (
      'main',
      'api_client_bill_actual_received_amount',
      'api_client_bill_monthly_kyc_fee_received_amount',
      'api_client_bill_physical_card_fee_received_amount',
      'api_client_bill_minimum_commitment_received_amount',
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
card_channel_finance_raw AS (
  -- BB 按来源日计算；volume_fee_cost 已由上游按日分摊，直接计入成本，不重复套用月度阶梯费。
  SELECT
    b.report_date AS report_date,
    CASE WHEN aar.account_id IS NOT NULL THEN aar.root_id ELSE b.account_id::varchar END AS root_account_id,
    'BB'::varchar AS provider,
    (aar.account_id IS NOT NULL OR (
      NULLIF(BTRIM(b.sale_id::varchar), '') IS NULL
      AND NULLIF(BTRIM(b.am_id::varchar), '') IS NULL
    )) AS needs_owner_lookup,
    CASE WHEN aar.account_id IS NULL THEN NULLIF(BTRIM(b.sale_id::varchar), '') END AS source_sale_id,
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
      + COALESCE(b.volume_fee_cost, 0)
      + COALESCE(b.cost_fixed_fee, 0)
    ) AS source_cost,
    SUM(COALESCE(b.cashback_income, 0)) AS channel_rebate,
    SUM(COALESCE(b.cashback_income, 0)) AS channel_rebate_sale
  FROM "dws"."dws_bb_card_finance_daily_v2_p" b
  LEFT JOIN (
    SELECT
      account_id::varchar AS account_id,
      CASE WHEN COUNT(DISTINCT root_id::varchar) = 1 THEN MIN(root_id::varchar) END AS root_id
    FROM public.api_account_relation
    WHERE delete_time IS NULL
      AND NULLIF(BTRIM(root_id::varchar), '') IS NOT NULL
      AND root_id::varchar <> account_id::varchar
    GROUP BY account_id::varchar
  ) aar ON aar.account_id = b.account_id::varchar
  WHERE b.delete_time IS NULL
    AND b.report_date >= date_trunc('month', CURRENT_DATE - interval '2 months')::date
    AND b.report_date < date_trunc('month', CURRENT_DATE + interval '1 month')::date
  GROUP BY b.report_date,
           CASE WHEN aar.account_id IS NOT NULL THEN aar.root_id ELSE b.account_id::varchar END,
           (aar.account_id IS NOT NULL OR (
             NULLIF(BTRIM(b.sale_id::varchar), '') IS NULL
             AND NULLIF(BTRIM(b.am_id::varchar), '') IS NULL
           )),
           CASE WHEN aar.account_id IS NULL THEN NULLIF(BTRIM(b.sale_id::varchar), '') END

  UNION ALL

  SELECT
    q.report_date AS report_date,
    CASE WHEN aar.account_id IS NOT NULL THEN aar.root_id ELSE q.account_id::varchar END AS root_account_id,
    'IQ'::varchar AS provider,
    (aar.account_id IS NOT NULL OR (
      NULLIF(BTRIM(q.sale_id::varchar), '') IS NULL
      AND NULLIF(BTRIM(q.am_id::varchar), '') IS NULL
    )) AS needs_owner_lookup,
    CASE WHEN aar.account_id IS NULL THEN NULLIF(BTRIM(q.sale_id::varchar), '') END AS source_sale_id,
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
    ) AS source_cost,
    SUM(
        COALESCE(q.rebate_interchange_base_amt, 0) * COALESCE(q.rebate_interchange_rate, 1)
      + COALESCE(q.rebate_incentive_base_amt, 0) * COALESCE(q.rebate_incentive_rate, 1)
    ) AS channel_rebate,
    SUM(
        COALESCE(q.rebate_interchange_base_amt, 0)
      + COALESCE(q.rebate_incentive_base_amt, 0) * COALESCE(q.rebate_incentive_rate, 1)
    ) AS channel_rebate_sale
  FROM "dws"."dws_qi_card_finance_daily_v2_p" q
  LEFT JOIN (
    SELECT
      account_id::varchar AS account_id,
      CASE WHEN COUNT(DISTINCT root_id::varchar) = 1 THEN MIN(root_id::varchar) END AS root_id
    FROM public.api_account_relation
    WHERE delete_time IS NULL
      AND NULLIF(BTRIM(root_id::varchar), '') IS NOT NULL
      AND root_id::varchar <> account_id::varchar
    GROUP BY account_id::varchar
  ) aar ON aar.account_id = q.account_id::varchar
  WHERE q.delete_time IS NULL
    AND q.report_date >= date_trunc('month', CURRENT_DATE - interval '2 months')::date
    AND q.report_date < date_trunc('month', CURRENT_DATE + interval '1 month')::date
  GROUP BY q.report_date,
           CASE WHEN aar.account_id IS NOT NULL THEN aar.root_id ELSE q.account_id::varchar END,
           (aar.account_id IS NOT NULL OR (
             NULLIF(BTRIM(q.sale_id::varchar), '') IS NULL
             AND NULLIF(BTRIM(q.am_id::varchar), '') IS NULL
           )),
           CASE WHEN aar.account_id IS NULL THEN NULLIF(BTRIM(q.sale_id::varchar), '') END

  UNION ALL

  -- BZ 与 BB/QI 一样按根账户归属销售；成本和返现同次扫描计算。
  SELECT
    z.report_date AS report_date,
    CASE WHEN aar.account_id IS NOT NULL THEN aar.root_id ELSE z.account_id::varchar END AS root_account_id,
    'BZ'::varchar AS provider,
    (aar.account_id IS NOT NULL OR (
      NULLIF(BTRIM(z.sale_id::varchar), '') IS NULL
      AND NULLIF(BTRIM(z.am_id::varchar), '') IS NULL
    )) AS needs_owner_lookup,
    CASE WHEN aar.account_id IS NULL THEN NULLIF(BTRIM(z.sale_id::varchar), '') END AS source_sale_id,
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
    ) AS source_cost,
    SUM(COALESCE(z.clearing_base_amt, 0) * COALESCE(z.reimbursement_rate, 0)) AS channel_rebate,
    SUM(COALESCE(z.clearing_base_amt, 0) * COALESCE(z.reimbursement_rate, 0)) AS channel_rebate_sale
  FROM "dws"."dws_bz_card_finance_daily_v2_p" z
  LEFT JOIN (
    SELECT
      account_id::varchar AS account_id,
      CASE WHEN COUNT(DISTINCT root_id::varchar) = 1 THEN MIN(root_id::varchar) END AS root_id
    FROM public.api_account_relation
    WHERE delete_time IS NULL
      AND NULLIF(BTRIM(root_id::varchar), '') IS NOT NULL
      AND root_id::varchar <> account_id::varchar
    GROUP BY account_id::varchar
  ) aar ON aar.account_id = z.account_id::varchar
  WHERE z.delete_time IS NULL
    AND z.report_date >= date_trunc('month', CURRENT_DATE - interval '2 months')::date
    AND z.report_date < date_trunc('month', CURRENT_DATE + interval '1 month')::date
  GROUP BY z.report_date,
           CASE WHEN aar.account_id IS NOT NULL THEN aar.root_id ELSE z.account_id::varchar END,
           (aar.account_id IS NOT NULL OR (
             NULLIF(BTRIM(z.sale_id::varchar), '') IS NULL
             AND NULLIF(BTRIM(z.am_id::varchar), '') IS NULL
           )),
           CASE WHEN aar.account_id IS NULL THEN NULLIF(BTRIM(z.sale_id::varchar), '') END
),
card_channel_owner_keys AS (
  -- API 子户仍按根账户回查；非 API 行仅在 sale_id、am_id 都为空时，先按账号找根账户再按日回查。
  SELECT DISTINCT report_date, root_account_id
  FROM card_channel_finance_raw
  WHERE needs_owner_lookup
),card_channel_owner_candidates AS (
  -- 集合 JOIN 替代逐行 LATERAL；保持原视图口径，取业务日前最近开始的销售关系。
  SELECT
    k.report_date,
    k.root_account_id,
    NULLIF(BTRIM(sr.sale_id), '')::varchar AS owner_sale_id,
    NULLIF(BTRIM(sr.am_id), '')::varchar AS owner_am_id,
    ROW_NUMBER() OVER (
      PARTITION BY k.report_date, k.root_account_id
      ORDER BY sr.relation_start_time DESC, sr.id DESC
    ) AS relation_rank
  FROM card_channel_owner_keys k
  JOIN dim.dim_sale_account_relation_p sr
    ON sr.relation_account_id = k.root_account_id
   AND sr.delete_time IS NULL
   AND sr.relation_start_time <= k.report_date::timestamp
),card_channel_owner_by_date AS (
  SELECT report_date, root_account_id, owner_sale_id, owner_am_id
  FROM card_channel_owner_candidates
  WHERE relation_rank = 1
),card_channel_finance_daily AS (
  -- 成本和返现复用同一归属结果；母户无有效销售时不回退到子户或未归属行。
  SELECT
    f.report_date,
    f.root_account_id,
    f.provider,
    CASE WHEN f.needs_owner_lookup THEN o.owner_sale_id ELSE f.source_sale_id END AS sale_id,
    CASE WHEN f.needs_owner_lookup THEN o.owner_am_id ELSE NULL::varchar END AS am_id,
    SUM(f.source_cost)::numeric(20,4) AS source_cost,
    SUM(f.channel_rebate)::numeric(20,4) AS channel_rebate,
    SUM(f.channel_rebate_sale)::numeric(20,4) AS channel_rebate_sale
  FROM card_channel_finance_raw f
  LEFT JOIN card_channel_owner_by_date o
    ON o.report_date = f.report_date
   AND o.root_account_id = f.root_account_id
  WHERE NOT f.needs_owner_lookup OR o.owner_sale_id IS NOT NULL
  GROUP BY f.report_date, f.root_account_id, f.provider,
           CASE WHEN f.needs_owner_lookup THEN o.owner_sale_id ELSE f.source_sale_id END,
           CASE WHEN f.needs_owner_lookup THEN o.owner_am_id ELSE NULL::varchar END
),
card_channel_finance_rows AS (
  -- 一次读取日汇总结果，分别输出成本行和渠道返现行，保留两类指标的来源标识。
  SELECT
    f.report_date,
    date_trunc('month', f.report_date)::date AS report_month,
    date_trunc('month', f.report_date)::date AS settlement_month,
    f.root_account_id,
    'qbit_card'::varchar AS product,
    f.provider,
    f.sale_id,
    x.metric_code,
    x.source_type,
    x.pref_rev,
    0::numeric(20,4) AS client_rebate,
    0::numeric(20,4) AS client_collection_rebate,
    0::numeric(20,4) AS gross_profit_rebate,
    0::numeric(20,4) AS physical_card_gp,
    x.cost,
    x.cashflow_rev,
    x.cashflow_rev_sale,
    f.am_id
  FROM card_channel_finance_daily f
  CROSS JOIN LATERAL (VALUES
    ('sales_cost'::varchar, 'sales_cost'::varchar,
      0::numeric(20,4), f.source_cost::numeric(20,4),
      0::numeric(20,4), 0::numeric(20,4)),
    ('channel_rebate'::varchar, 'qbit_card_channel_rebate'::varchar,
      f.channel_rebate::numeric(20,4), 0::numeric(20,4),
      f.channel_rebate::numeric(20,4), f.channel_rebate_sale::numeric(20,4))
  ) x(metric_code, source_type, pref_rev, cost, cashflow_rev, cashflow_rev_sale)
  WHERE x.pref_rev <> 0 OR x.cost <> 0 OR x.cashflow_rev <> 0 OR x.cashflow_rev_sale <> 0
),
raw_cost_rows AS (
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
    AND c.report_date >= date_trunc('month', CURRENT_DATE - interval '2 months')::date
    AND c.report_date < date_trunc('month', CURRENT_DATE + interval '1 month')::date
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
    AND s.report_date >= date_trunc('month', CURRENT_DATE - interval '2 months')::date
    AND s.report_date < date_trunc('month', CURRENT_DATE + interval '1 month')::date
  GROUP BY s.report_date::date, COALESCE(aar.root_id, s.account_id), s.sale_id

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
    AND ptr.dt >= date_trunc('month', CURRENT_DATE - interval '2 months')::date
    AND ptr.dt < date_trunc('month', CURRENT_DATE + interval '1 month')::date
    AND ptr.status = 'Closed'
    AND ptr.submit_time >= date_trunc('month', CURRENT_DATE - interval '2 months')::date
    AND ptr.submit_time < date_trunc('month', CURRENT_DATE + interval '1 month')::date
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
    -- 在原始时间列上加范围下界，避免只对表达式过滤导致扫描历史分区/索引范围。
    AND t.statistics_time >= (
      date_trunc('month', CURRENT_DATE - interval '2 months')::date::timestamp
      AT TIME ZONE 'Asia/Shanghai'
    )
    AND t.statistics_time < (
      date_trunc('month', CURRENT_DATE + interval '1 month')::date::timestamp
      AT TIME ZONE 'Asia/Shanghai'
    )
    AND date_trunc('month', t.statistics_time AT TIME ZONE 'Asia/Shanghai')::date
        >= date_trunc('month', CURRENT_DATE - interval '2 months')::date
    AND date_trunc('month', t.statistics_time AT TIME ZONE 'Asia/Shanghai')::date
        < date_trunc('month', CURRENT_DATE + interval '1 month')::date
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
  WHERE NULLIF(BTRIM(sale_id::varchar), '') IS NULL
),cost_owner_candidates AS (
  -- 集合 JOIN 替代逐账户/日期 LATERAL；用窗口排序保持原销售关系优先级。
  SELECT
    d.report_date,
    d.root_account_id,
    sr.sale_id::varchar AS sale_id,
    ROW_NUMBER() OVER (
      PARTITION BY d.report_date, d.root_account_id
      ORDER BY
        CASE WHEN sr.relation_end_time IS NULL OR d.report_date < sr.relation_end_time THEN 0 ELSE 1 END,
        sr.relation_start_time DESC,
        sr.id DESC
    ) AS relation_rank
  FROM cost_account_dates d
  LEFT JOIN "dim"."dim_sale_account_relation_p" sr
    ON sr.relation_account_id = d.root_account_id
   AND sr.delete_time IS NULL
   AND sr.relation_start_time <= d.report_date
),cost_owner_by_date AS (
  SELECT report_date, root_account_id, sale_id
  FROM cost_owner_candidates
  WHERE relation_rank = 1
),mapped_cost_rows AS (
  SELECT
    c.report_date,
    c.root_account_id,
    c.product,
    c.provider,
    COALESCE(NULLIF(BTRIM(c.sale_id::varchar), ''), owner.sale_id)::varchar AS sale_id,
    c.source_cost
  FROM raw_cost_rows c
  LEFT JOIN cost_owner_by_date owner
    ON NULLIF(BTRIM(c.sale_id::varchar), '') IS NULL
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
    -- Cost 只包含真实成本来源；实体卡毛利另计入三类 GP，不进入 Cost 或 Rebate。
    COALESCE(c.source_cost, 0)::numeric(20,4) AS cost,
    m.main_revenue::numeric(20,4) AS cashflow_rev,
    m.main_revenue::numeric(20,4) AS cashflow_rev_sale
  FROM recent_sales_metric m
  LEFT JOIN cost_by_sale_dimension c
    ON c.report_date = m.report_date
   AND c.root_account_id = m.root_account_id
   AND c.product = m.product
   AND c.provider IS NOT DISTINCT FROM m.provider
   AND c.sale_id = m.sale_id
  -- API账单指标会让 recent_sales_metric 出现分组；若这些分组没有任何 main/返现/成本金额，不再重复生成全零 open_api 行。
  WHERE m.product IS DISTINCT FROM 'open_api'
     OR m.main_revenue <> 0
     OR m.client_rebate <> 0
     OR m.client_collection_rebate <> 0
     OR m.physical_card_gp <> 0
     OR COALESCE(c.source_cost, 0) <> 0
),api_actual_received_rows AS (
  -- Open API账单实收使用不区分渠道的实际实收指标；按客户、日期、销售合并成一行。
  SELECT
    m.report_date,
    m.report_month,
    m.settlement_month,
    m.root_account_id,
    m.product,
    NULL::varchar AS provider,
    m.sale_id,
    'api_client_bill_actual_received_amount'::varchar AS metric_code,
    'sales_metric_daily'::varchar AS source_type,
    0::numeric(20,4) AS pref_rev,
    0::numeric(20,4) AS client_rebate,
    0::numeric(20,4) AS client_collection_rebate,
    0::numeric(20,4) AS gross_profit_rebate,
    0::numeric(20,4) AS physical_card_gp,
    0::numeric(20,4) AS cost,
    SUM(m.api_actual_received_amount)::numeric(20,4) AS cashflow_rev,
    SUM(m.api_actual_received_sale_amount)::numeric(20,4) AS cashflow_rev_sale
  FROM recent_sales_metric m
  WHERE m.product = 'open_api'
  GROUP BY m.report_date, m.report_month, m.settlement_month,
           m.root_account_id, m.product, m.sale_id
  HAVING SUM(m.api_actual_received_amount) <> 0
      OR SUM(m.api_actual_received_sale_amount) <> 0
),monthly_revenue_rows AS (
  -- 月度汇总源只有结算月粒度；month_receivable 和离线API收入均按结算月首日入账。
  SELECT
    r.settlement_month::date AS report_date,
    r.settlement_month::date AS report_month,
    r.settlement_month::date AS settlement_month,
    r.root_account_id::varchar AS root_account_id,
    CASE WHEN r.product = 'bi_month_tag' THEN 'open_api' ELSE r.product END::varchar AS product,
    NULLIF(TRIM(r.provider), '')::varchar AS provider,
    r.sale_id::varchar AS sale_id,
    r.metric_code::varchar AS metric_code,
    'sales_revenue_monthly'::varchar AS source_type,
    SUM(CASE
      WHEN r.product = 'open_api' AND r.metric_code = 'month_receivable'
        THEN COALESCE(r.income_value, 0)
      WHEN r.product = 'bi_month_tag' AND r.metric_code = 'offline_api_income_amount'
        THEN COALESCE(r.income_value, 0)
      ELSE 0
    END)::numeric(20,4) AS pref_rev,
    0::numeric(20,4) AS client_rebate,
    0::numeric(20,4) AS client_collection_rebate,
    0::numeric(20,4) AS gross_profit_rebate,
    0::numeric(20,4) AS physical_card_gp,
    0::numeric(20,4) AS cost,
    SUM(CASE
      WHEN r.product = 'bi_month_tag' AND r.metric_code = 'offline_api_income_amount'
        THEN COALESCE(r.income_value, 0)
      ELSE 0
    END)::numeric(20,4) AS cashflow_rev,
    SUM(CASE
      WHEN r.product = 'bi_month_tag' AND r.metric_code = 'offline_api_income_amount'
        THEN COALESCE(r.income_value, 0)
      ELSE 0
    END)::numeric(20,4) AS cashflow_rev_sale
  FROM "dws"."dws_metrics_sales_revenue_monthly" r
  WHERE r.delete_time IS NULL
    AND r.settlement_month >= date_trunc('month', CURRENT_DATE - interval '2 months')::date
    AND r.settlement_month < date_trunc('month', CURRENT_DATE + interval '1 month')::date
    AND ((r.product = 'open_api' AND r.metric_code = 'month_receivable')
      OR (r.product = 'bi_month_tag' AND r.metric_code = 'offline_api_income_amount'))
  GROUP BY r.settlement_month, r.root_account_id, r.product,
           NULLIF(TRIM(r.provider), ''), r.sale_id, r.metric_code
),bi_month_adjustment_source AS (
  -- 先把同一账户、月份、标签的原始调账合并，避免逐条记录查销售关系。
  SELECT
    date_trunc('month', t.statistics_time AT TIME ZONE 'Asia/Shanghai')::date AS report_date,
    COALESCE(aar.root_id, t.account_id)::varchar AS root_account_id,
    t.product_line,
    NULLIF(TRIM(t.provider), '')::varchar AS provider,
    t.tag,
    SUM(COALESCE(t.amount, 0)) AS amount
  FROM ods.ods_bi_month_tag t
  LEFT JOIN account_root_relation aar
    ON aar.account_id = t.account_id::varchar
  WHERE t.delete_time IS NULL
    AND t.account_id IS NOT NULL
    AND t.tag IN (
      'OFFLINE_PHYSICAL_CARD_FEE',
      'INCOME_ADJUSTMENT_INCREASE',
      'INCOME_ADJUSTMENT_DECREASE',
      'API_MINIMUM_CONSUMPTION_ADJUSTMENT_DECREASE',
      'CASHBACK_ADJUSTMENT_INCREASE',
      'CASHBACK_ADJUSTMENT_DECREASE'
    )
    -- 对 timestamptz 原列增加范围条件，便于按 statistics_time 索引/分区裁剪。
    AND t.statistics_time >= (
      date_trunc('month', CURRENT_DATE - interval '2 months')::date::timestamp
      AT TIME ZONE 'Asia/Shanghai'
    )
    AND t.statistics_time < (
      date_trunc('month', CURRENT_DATE + interval '1 month')::date::timestamp
      AT TIME ZONE 'Asia/Shanghai'
    )
    AND date_trunc('month', t.statistics_time AT TIME ZONE 'Asia/Shanghai')::date
        >= date_trunc('month', CURRENT_DATE - interval '2 months')::date
    AND date_trunc('month', t.statistics_time AT TIME ZONE 'Asia/Shanghai')::date
        < date_trunc('month', CURRENT_DATE + interval '1 month')::date
  GROUP BY
    date_trunc('month', t.statistics_time AT TIME ZONE 'Asia/Shanghai')::date,
    COALESCE(aar.root_id, t.account_id), t.product_line,
    NULLIF(TRIM(t.provider), ''), t.tag
),bi_month_adjustment_rows AS (
  -- 调账归属也按业务月份1号查询销售关系；金额保留原有正负口径。
  SELECT
    t.report_date,
    t.report_date AS report_month,
    t.report_date AS settlement_month,
    t.root_account_id,
    CASE t.product_line
      WHEN 'GLOBAL_ACCOUNT' THEN 'group_account'
      WHEN 'QUANTUM_CARD' THEN 'qbit_card'
      WHEN 'CRYPTO_ASSET' THEN 'crypto'
    END::varchar AS product,
    t.provider,
    sale_owner.sale_id::varchar AS sale_id,
    t.tag::varchar AS metric_code,
    'bi_month_tag_adjustment'::varchar AS source_type,
    CASE
      WHEN t.tag IN ('OFFLINE_PHYSICAL_CARD_FEE', 'INCOME_ADJUSTMENT_INCREASE')
        THEN COALESCE(t.amount, 0)
      WHEN t.tag IN ('INCOME_ADJUSTMENT_DECREASE', 'API_MINIMUM_CONSUMPTION_ADJUSTMENT_DECREASE')
        THEN -COALESCE(t.amount, 0)
      ELSE 0
    END::numeric(20,4) AS pref_rev,
    CASE
      WHEN t.tag = 'CASHBACK_ADJUSTMENT_INCREASE' THEN COALESCE(t.amount, 0)
      WHEN t.tag = 'CASHBACK_ADJUSTMENT_DECREASE' THEN -COALESCE(t.amount, 0)
      ELSE 0
    END::numeric(20,4) AS client_rebate,
    0::numeric(20,4) AS client_collection_rebate,
    0::numeric(20,4) AS gross_profit_rebate,
    0::numeric(20,4) AS physical_card_gp,
    0::numeric(20,4) AS cost,
    CASE
      WHEN t.tag IN ('OFFLINE_PHYSICAL_CARD_FEE', 'INCOME_ADJUSTMENT_INCREASE')
        THEN COALESCE(t.amount, 0)
      WHEN t.tag IN ('INCOME_ADJUSTMENT_DECREASE', 'API_MINIMUM_CONSUMPTION_ADJUSTMENT_DECREASE')
        THEN -COALESCE(t.amount, 0)
      ELSE 0
    END::numeric(20,4) AS cashflow_rev,
    CASE
      WHEN t.tag IN ('OFFLINE_PHYSICAL_CARD_FEE', 'INCOME_ADJUSTMENT_INCREASE')
        THEN COALESCE(t.amount, 0)
      WHEN t.tag IN ('INCOME_ADJUSTMENT_DECREASE', 'API_MINIMUM_CONSUMPTION_ADJUSTMENT_DECREASE')
        THEN -COALESCE(t.amount, 0)
      ELSE 0
    END::numeric(20,4) AS cashflow_rev_sale
  FROM bi_month_adjustment_source t
  LEFT JOIN (
    SELECT report_date, root_account_id, product_line, provider, tag, sale_id
    FROM (
      SELECT
        t_owner.report_date,
        t_owner.root_account_id,
        t_owner.product_line,
        t_owner.provider,
        t_owner.tag,
        sr.sale_id::varchar AS sale_id,
        ROW_NUMBER() OVER (
          PARTITION BY t_owner.report_date, t_owner.root_account_id,
                       t_owner.product_line, t_owner.provider, t_owner.tag
          ORDER BY
            CASE WHEN sr.relation_end_time IS NULL OR t_owner.report_date < sr.relation_end_time THEN 0 ELSE 1 END,
            sr.relation_start_time DESC,
            sr.id DESC
        ) AS relation_rank
      FROM bi_month_adjustment_source t_owner
      LEFT JOIN dim.dim_sale_account_relation_p sr
        ON sr.relation_account_id = t_owner.root_account_id
       AND sr.delete_time IS NULL
       AND sr.relation_start_time <= t_owner.report_date::timestamp
    ) ranked_owner
    WHERE relation_rank = 1
  ) sale_owner
    ON sale_owner.report_date = t.report_date
   AND sale_owner.root_account_id = t.root_account_id
   AND sale_owner.product_line = t.product_line
   AND sale_owner.provider IS NOT DISTINCT FROM t.provider
   AND sale_owner.tag = t.tag
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
    0::numeric(20,4) AS cashflow_rev,
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
  SELECT s.*, NULL::varchar AS am_id FROM sales_rows s
  UNION ALL SELECT a.*, NULL::varchar FROM api_actual_received_rows a
  UNION ALL SELECT m.*, NULL::varchar FROM monthly_revenue_rows m
  UNION ALL SELECT b.*, NULL::varchar FROM bi_month_adjustment_rows b
  UNION ALL SELECT c.*, NULL::varchar FROM cost_only_rows c
  UNION ALL SELECT f.* FROM card_channel_finance_rows f
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
    am_id,
    CASE
      WHEN source_type = 'sales_revenue_monthly' AND metric_code = 'month_receivable' THEN 'RECEIVABLE'
      WHEN metric_code = 'api_client_bill_actual_received_amount' THEN 'RECEIVED'
      ELSE NULL
    END::varchar AS api_bill_type,
    pref_rev::numeric(20,4) AS pref_rev,
    client_rebate::numeric(20,4) AS client_rebate,
    client_collection_rebate::numeric(20,4) AS client_collection_rebate,
    gross_profit_rebate::numeric(20,4) AS gross_profit_rebate,
    physical_card_gp::numeric(20,4) AS physical_card_gp,
    (client_rebate + client_collection_rebate + gross_profit_rebate)::numeric(20,4) AS rebate,
    (pref_rev - client_rebate - client_collection_rebate - gross_profit_rebate)::numeric(20,4) AS pref_rev_effective,
    cost::numeric(20,4) AS cost,
    (pref_rev - client_rebate - client_collection_rebate - gross_profit_rebate - cost + physical_card_gp)::numeric(20,4) AS pref_gp,
    cashflow_rev::numeric(20,4) AS cashflow_rev,
    (cashflow_rev - client_rebate - client_collection_rebate - gross_profit_rebate)::numeric(20,4) AS cashflow_rev_effective,
    (cashflow_rev - client_rebate - client_collection_rebate - gross_profit_rebate - cost + physical_card_gp)::numeric(20,4) AS cashflow_gp,
    cashflow_rev_sale::numeric(20,4) AS cashflow_rev_sale,
    (cashflow_rev_sale - client_rebate - client_collection_rebate - gross_profit_rebate)::numeric(20,4) AS cashflow_rev_sale_effective,
    (cashflow_rev_sale - client_rebate - client_collection_rebate - gross_profit_rebate - cost + physical_card_gp)::numeric(20,4) AS cashflow_gp_sale
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
  api_bill_type,
  pref_rev,
  client_rebate,
  client_collection_rebate,
  gross_profit_rebate,
  rebate,
  pref_rev_effective,
  cost,
  pref_gp,
  cashflow_rev,
  cashflow_rev_effective,
  cashflow_gp,
  cashflow_rev_sale,
  cashflow_rev_sale_effective,
  cashflow_gp_sale,
  now() AS refreshed_at,
  c.am_id
FROM calculated c
WHERE NULLIF(BTRIM(sale_id), '') IS NOT NULL
WITH DATA
DISTRIBUTED BY (id);

ALTER MATERIALIZED VIEW "dws"."mv_sales_gross_profit_recent_estimate" OWNER TO "flink_cdc_user";
COMMENT ON MATERIALIZED VIEW "dws"."mv_sales_gross_profit_recent_estimate" IS '销售毛利近3个自然月日粒度估算视图（当前月及前两个月）；补齐API收入及月度调整来源，report_date保留业务日期，负数原样保留';
CREATE INDEX IF NOT EXISTS "idx_mv_sales_gross_profit_recent_estimate_query"
  ON "dws"."mv_sales_gross_profit_recent_estimate" ("report_date", "sale_id", "root_account_id");
CREATE INDEX IF NOT EXISTS "idx_mv_sales_gross_profit_recent_estimate_detail"
  ON "dws"."mv_sales_gross_profit_recent_estimate" ("root_account_id", "report_date", "product", "api_bill_type", "provider");
