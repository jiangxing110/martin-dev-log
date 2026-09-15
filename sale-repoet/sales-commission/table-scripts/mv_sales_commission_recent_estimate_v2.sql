--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-20
-- Description:    销售佣金8号前预估物化视图 v2
-- Notes:
--   1. 基于 v1，新增结汇成本、线下退款、收入调整、返现调整、线下API收入、线下实体卡制卡费的支持。
--   2. 结汇成本 SETTLEMENT_COST 从 dwm_finance_channel_cost_p 读取，按 usdAmount 金额均摊。
--   3. bi_month_tag 中含 account_id 的指标（收入/调整/退款）直接读取，不需经过分摊 pipeline。
--   4. 全球账户 offline fee_cost 从 ods_payment_transaction_record 直接查询（数据量小）。
--   5. 收入类指标通过 UNION ALL 模拟为 revenue_base 行；成本类归入 v_cost_by_account_product。
--   6. 调整项 sale_id 通过 dim_sale_account_relation_p 关联。
--   7. 本物化视图承载8号前页面查询结果。
--   8. 每次刷新保留近半年展示结算月数据；API实收按report_date归属展示结算月。
--   9. 每月8号快照任务从本物化视图读取目标 settlement_month 并固化到快照表。
--   10. 成本按 settlement_month + root_account_id + product + provider 汇总后，再按收入占比分摊到明细行。
--   11. 量子卡渠道返现金作为收入加回；海外销售二部允许客户间毛利抵扣，其余部门单客户/渠道负毛利按 0 计佣。
--   12. 读取 dws.dws_metrics_sales_revenue_monthly，收入仅使用 income_value。
--   13. v1 额外扣减 public.cash_back_bonuses 中 QuantumAccountHandlingFeeOnBehalf 且 Closed 的量子卡客户返现成本。
--   14. v2 新增：SETTLEMENT_COST、OFFLINE_REFUND、OFFLINE_API_INCOME、OFFLINE_PHYSICAL_CARD_FEE、
--       CASHBACK_ADJUSTMENT、INCOME_ADJUSTMENT、payment_transaction_record fee_cost。
--********************************************************************--

DROP MATERIALIZED VIEW IF EXISTS "dws"."mv_sales_commission_recent_estimate";

CREATE MATERIALIZED VIEW "dws"."mv_sales_commission_recent_estimate" AS
WITH account_root_relation AS (
  SELECT
    account_id,
    root_id
  FROM "ods"."ods_api_account_relation"
  WHERE delete_time IS NULL
),
rule_departments AS (
  SELECT DISTINCT department_id
  FROM "dim"."dim_sales_commission_rule"
  WHERE enabled = true
    AND delete_time IS NULL
),
crypto_rule_departments AS (
  SELECT DISTINCT department_id
  FROM "dim"."dim_sales_commission_rule"
  WHERE enabled = true
    AND delete_time IS NULL
    AND (product = 'crypto' OR product IS NULL)
),
sale_department_mapping AS (
  SELECT
    sale_id,
    department_id
  FROM (
    SELECT
      sud.user_id::text AS sale_id,
      sud.department_id::text AS department_id,
      ROW_NUMBER() OVER (
        PARTITION BY sud.user_id::text
        ORDER BY
          CASE WHEN rd.department_id IS NOT NULL THEN 0 ELSE 1 END,
          sud.update_time DESC,
          sud.id DESC
      ) AS rn
    FROM "public"."system_user_department" sud
    LEFT JOIN rule_departments rd
      ON rd.department_id = sud.department_id::text
    WHERE sud.delete_time IS NULL
  ) ranked
  WHERE rn = 1
),
crypto_sale_department_mapping AS (
  SELECT sale_id, department_id
  FROM (
    SELECT
      sud.user_id::text AS sale_id,
      sud.department_id::text AS department_id,
      ROW_NUMBER() OVER (
        PARTITION BY sud.user_id::text
        ORDER BY sud.update_time DESC, sud.id DESC
      ) AS rn
    FROM "public"."system_user_department" sud
    JOIN crypto_rule_departments crd
      ON crd.department_id = sud.department_id::text
    WHERE sud.delete_time IS NULL
  ) ranked
  WHERE rn = 1
),
revenue_base AS (
  SELECT
    CURRENT_DATE AS report_date,
    CASE
      WHEN r.product = 'open_api' AND r.metric_code = 'month_revenue'
        THEN date_trunc('month', r.report_date)::date
      ELSE r.settlement_month
    END AS settlement_month,
    r.root_account_id,
    CASE WHEN r.product = 'crypto_connect' THEN 'crypto' WHEN r.product = 'global_account' THEN 'group_account' ELSE r.product END AS product,
    r.provider,
    CASE
      WHEN r.product = 'open_api' AND r.metric_code IN ('month_revenue', 'month_receivable') THEN r.metric_code
      ELSE NULL
    END AS item,
    CASE
      WHEN r.product = 'open_api' AND r.metric_code = 'month_receivable' THEN 'api_monthly_billing'
      WHEN r.product = 'open_api' AND r.metric_code = 'month_revenue'
       AND r.settlement_month = date_trunc('month', r.report_date - interval '1 month')::date THEN 'billing_decline_fee'
      WHEN r.product = 'open_api' AND r.metric_code = 'month_revenue' THEN 'past_due_invoice'
      WHEN r.metric_code = 'past_due_invoice' THEN 'past_due_invoice'
      WHEN r.metric_code = 'billing_decline_fee' THEN 'billing_decline_fee'
      ELSE 'real_time_processing_fee'
    END AS source_type,
    CASE
      WHEN r.product = 'open_api' AND r.metric_code = 'month_receivable' THEN 'future_payout'
      ELSE 'current_payout'
    END AS commission_stage,
    r.sale_id,
    CASE WHEN r.product = 'crypto_connect' THEN csdm.department_id ELSE sdm.department_id END AS department_id,
    r.am_id,
    r.settlement_month AS activity_month,
    CASE
      WHEN r.product = 'open_api' AND r.metric_code = 'month_revenue'
        THEN date_trunc('month', r.report_date)::date
      ELSE r.settlement_month
    END AS collection_month,
    CASE
      WHEN r.product = 'open_api' AND r.metric_code = 'month_revenue'
        THEN date_trunc('month', r.report_date + interval '1 month')::date
      WHEN r.product = 'open_api' AND r.metric_code = 'month_receivable'
        THEN date_trunc('month', r.settlement_month + interval '1 month')::date
      ELSE r.settlement_month
    END AS payable_settlement_month,
    SUM(COALESCE(r.income_value, 0))::numeric(20,4) AS effective_revenue
  FROM "dws"."dws_metrics_sales_revenue_monthly" r
  LEFT JOIN sale_department_mapping sdm
    ON sdm.sale_id = COALESCE(r.sale_id, r.am_id)
  LEFT JOIN crypto_sale_department_mapping csdm
    ON csdm.sale_id = COALESCE(r.sale_id, r.am_id)
  WHERE r.delete_time IS NULL
    AND (
      (r.product = 'open_api' AND r.metric_code = 'month_revenue'
       AND r.report_date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date)
      OR (r.product = 'open_api' AND r.metric_code = 'month_receivable'
          AND r.settlement_month >= date_trunc('month', CURRENT_DATE - interval '6 months')::date)
      OR (r.product = 'crypto_connect' AND r.metric_code = 'main'
          AND r.settlement_month >= date_trunc('month', CURRENT_DATE - interval '6 months')::date)
      OR (r.product = 'global_account' AND r.metric_code = 'main'
          AND r.settlement_month >= date_trunc('month', CURRENT_DATE - interval '6 months')::date)
      OR (r.product = 'qbit_card' AND r.metric_code = 'main'
          AND r.settlement_month >= date_trunc('month', CURRENT_DATE - interval '6 months')::date)
    )
  GROUP BY
    CASE WHEN r.product = 'open_api' AND r.metric_code = 'month_revenue' THEN date_trunc('month', r.report_date)::date ELSE r.settlement_month END,
    r.settlement_month,
    date_trunc('month', r.report_date)::date,
    date_trunc('month', r.report_date - interval '1 month')::date,
    date_trunc('month', r.report_date + interval '1 month')::date,
    r.root_account_id,
    r.product,
    CASE WHEN r.product = 'crypto_connect' THEN 'crypto' WHEN r.product = 'global_account' THEN 'group_account' ELSE r.product END,
    r.provider,
    r.metric_code,
    r.sale_id,
    CASE WHEN r.product = 'crypto_connect' THEN csdm.department_id ELSE sdm.department_id END,
    r.am_id

  -- v2: 量子卡线下收入 / 实体卡制卡费 / 收入调整增加
  UNION ALL
  SELECT
    CURRENT_DATE AS report_date,
    date_trunc('month', t.statistics_time)::date AS settlement_month,
    COALESCE(aar.root_id, t.account_id) AS root_account_id,
    CASE t.product_line
      WHEN 'GLOBAL_ACCOUNT' THEN 'group_account'
      WHEN 'QUANTUM_CARD' THEN 'qbit_card'
      WHEN 'CRYPTO_ASSET' THEN 'crypto'
    END AS product,
    CAST(t.provider AS VARCHAR) AS provider,
    NULL AS item,
    'real_time_processing_fee' AS source_type,
    'current_payout' AS commission_stage,
    sr.sale_id,
    sr.department_id,
    sr.am_id,
    date_trunc('month', t.statistics_time)::date AS activity_month,
    date_trunc('month', t.statistics_time)::date AS collection_month,
    date_trunc('month', t.statistics_time)::date AS payable_settlement_month,
    SUM(COALESCE(t.amount, 0))::numeric(20,4) AS effective_revenue
  FROM ods.ods_bi_month_tag t
  LEFT JOIN account_root_relation aar ON aar.account_id = t.account_id
  LEFT JOIN LATERAL (
    SELECT
      sr_inner.sale_id,
      sdm_inner.department_id,
      sr_inner.am_id
    FROM dim.dim_sale_account_relation_p sr_inner
    LEFT JOIN sale_department_mapping sdm_inner ON sdm_inner.sale_id = sr_inner.sale_id
    WHERE sr_inner.relation_account_id = COALESCE(aar.root_id, t.account_id)
      AND sr_inner.delete_time IS NULL
      AND date_trunc('month', t.statistics_time)::date >= sr_inner.relation_start_time
      AND (date_trunc('month', t.statistics_time)::date < sr_inner.relation_end_time OR sr_inner.relation_end_time IS NULL)
    ORDER BY sr_inner.relation_start_time DESC
    LIMIT 1
  ) sr ON true
  WHERE t.delete_time IS NULL
    AND t.account_id IS NOT NULL
    AND t.tag IN ('OFFLINE_API_INCOME', 'OFFLINE_PHYSICAL_CARD_FEE', 'INCOME_ADJUSTMENT_INCREASE')
    AND date_trunc('month', t.statistics_time)::date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY
    date_trunc('month', t.statistics_time)::date,
    COALESCE(aar.root_id, t.account_id),
    t.product_line,
    t.tag,
    t.provider,
    sr.sale_id,
    sr.department_id,
    sr.am_id

  -- v2: 收入调整减少 / API客户低消调整减少（负数冲减收入）
  UNION ALL
  SELECT
    CURRENT_DATE AS report_date,
    date_trunc('month', t.statistics_time)::date AS settlement_month,
    COALESCE(aar.root_id, t.account_id) AS root_account_id,
    CASE t.product_line
      WHEN 'GLOBAL_ACCOUNT' THEN 'group_account'
      WHEN 'QUANTUM_CARD' THEN 'qbit_card'
      WHEN 'CRYPTO_ASSET' THEN 'crypto'
    END AS product,
    CAST(t.provider AS VARCHAR) AS provider,
    NULL AS item,
    'real_time_processing_fee' AS source_type,
    'current_payout' AS commission_stage,
    sr.sale_id,
    sr.department_id,
    sr.am_id,
    date_trunc('month', t.statistics_time)::date AS activity_month,
    date_trunc('month', t.statistics_time)::date AS collection_month,
    date_trunc('month', t.statistics_time)::date AS payable_settlement_month,
    (-SUM(COALESCE(t.amount, 0)))::numeric(20,4) AS effective_revenue
  FROM ods.ods_bi_month_tag t
  LEFT JOIN account_root_relation aar ON aar.account_id = t.account_id
  LEFT JOIN LATERAL (
    SELECT
      sr_inner.sale_id,
      sdm_inner.department_id,
      sr_inner.am_id
    FROM dim.dim_sale_account_relation_p sr_inner
    LEFT JOIN sale_department_mapping sdm_inner ON sdm_inner.sale_id = sr_inner.sale_id
    WHERE sr_inner.relation_account_id = COALESCE(aar.root_id, t.account_id)
      AND sr_inner.delete_time IS NULL
      AND date_trunc('month', t.statistics_time)::date >= sr_inner.relation_start_time
      AND (date_trunc('month', t.statistics_time)::date < sr_inner.relation_end_time OR sr_inner.relation_end_time IS NULL)
    ORDER BY sr_inner.relation_start_time DESC
    LIMIT 1
  ) sr ON true
  WHERE t.delete_time IS NULL
    AND t.account_id IS NOT NULL
    AND t.tag IN (
      'INCOME_ADJUSTMENT_DECREASE',
      'API_MINIMUM_CONSUMPTION_ADJUSTMENT_DECREASE'
    )
    AND date_trunc('month', t.statistics_time)::date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY
    date_trunc('month', t.statistics_time)::date,
    COALESCE(aar.root_id, t.account_id),
    t.product_line,
    t.tag,
    t.provider,
    sr.sale_id,
    sr.department_id,
    sr.am_id

  -- v2: 返现调整增加
  UNION ALL
  SELECT
    CURRENT_DATE AS report_date,
    date_trunc('month', t.statistics_time)::date AS settlement_month,
    COALESCE(aar.root_id, t.account_id) AS root_account_id,
    CASE t.product_line
      WHEN 'GLOBAL_ACCOUNT' THEN 'group_account'
      WHEN 'QUANTUM_CARD' THEN 'qbit_card'
      WHEN 'CRYPTO_ASSET' THEN 'crypto'
    END AS product,
    CAST(t.provider AS VARCHAR) AS provider,
    NULL AS item,
    'real_time_processing_fee' AS source_type,
    'current_payout' AS commission_stage,
    sr.sale_id,
    sr.department_id,
    sr.am_id,
    date_trunc('month', t.statistics_time)::date AS activity_month,
    date_trunc('month', t.statistics_time)::date AS collection_month,
    date_trunc('month', t.statistics_time)::date AS payable_settlement_month,
    SUM(COALESCE(t.amount, 0))::numeric(20,4) AS effective_revenue
  FROM ods.ods_bi_month_tag t
  LEFT JOIN account_root_relation aar ON aar.account_id = t.account_id
  LEFT JOIN LATERAL (
    SELECT
      sr_inner.sale_id,
      sdm_inner.department_id,
      sr_inner.am_id
    FROM dim.dim_sale_account_relation_p sr_inner
    LEFT JOIN sale_department_mapping sdm_inner ON sdm_inner.sale_id = sr_inner.sale_id
    WHERE sr_inner.relation_account_id = COALESCE(aar.root_id, t.account_id)
      AND sr_inner.delete_time IS NULL
      AND date_trunc('month', t.statistics_time)::date >= sr_inner.relation_start_time
      AND (date_trunc('month', t.statistics_time)::date < sr_inner.relation_end_time OR sr_inner.relation_end_time IS NULL)
    ORDER BY sr_inner.relation_start_time DESC
    LIMIT 1
  ) sr ON true
  WHERE t.delete_time IS NULL
    AND t.account_id IS NOT NULL
    AND t.tag = 'CASHBACK_ADJUSTMENT_INCREASE'
    AND date_trunc('month', t.statistics_time)::date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY
    date_trunc('month', t.statistics_time)::date,
    COALESCE(aar.root_id, t.account_id),
    t.product_line,
    t.tag,
    t.provider,
    sr.sale_id,
    sr.department_id,
    sr.am_id

  -- v2: 返现调整减少（负数）
  UNION ALL
  SELECT
    CURRENT_DATE AS report_date,
    date_trunc('month', t.statistics_time)::date AS settlement_month,
    COALESCE(aar.root_id, t.account_id) AS root_account_id,
    CASE t.product_line
      WHEN 'GLOBAL_ACCOUNT' THEN 'group_account'
      WHEN 'QUANTUM_CARD' THEN 'qbit_card'
      WHEN 'CRYPTO_ASSET' THEN 'crypto'
    END AS product,
    CAST(t.provider AS VARCHAR) AS provider,
    NULL AS item,
    'real_time_processing_fee' AS source_type,
    'current_payout' AS commission_stage,
    sr.sale_id,
    sr.department_id,
    sr.am_id,
    date_trunc('month', t.statistics_time)::date AS activity_month,
    date_trunc('month', t.statistics_time)::date AS collection_month,
    date_trunc('month', t.statistics_time)::date AS payable_settlement_month,
    (-SUM(COALESCE(t.amount, 0)))::numeric(20,4) AS effective_revenue
  FROM ods.ods_bi_month_tag t
  LEFT JOIN account_root_relation aar ON aar.account_id = t.account_id
  LEFT JOIN LATERAL (
    SELECT
      sr_inner.sale_id,
      sdm_inner.department_id,
      sr_inner.am_id
    FROM dim.dim_sale_account_relation_p sr_inner
    LEFT JOIN sale_department_mapping sdm_inner ON sdm_inner.sale_id = sr_inner.sale_id
    WHERE sr_inner.relation_account_id = COALESCE(aar.root_id, t.account_id)
      AND sr_inner.delete_time IS NULL
      AND date_trunc('month', t.statistics_time)::date >= sr_inner.relation_start_time
      AND (date_trunc('month', t.statistics_time)::date < sr_inner.relation_end_time OR sr_inner.relation_end_time IS NULL)
    ORDER BY sr_inner.relation_start_time DESC
    LIMIT 1
  ) sr ON true
  WHERE t.delete_time IS NULL
    AND t.account_id IS NOT NULL
    AND t.tag = 'CASHBACK_ADJUSTMENT_DECREASE'
    AND date_trunc('month', t.statistics_time)::date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY
    date_trunc('month', t.statistics_time)::date,
    COALESCE(aar.root_id, t.account_id),
    t.product_line,
    t.tag,
    t.provider,
    sr.sale_id,
    sr.department_id,
    sr.am_id
),
global_account_channel_cost AS (
  SELECT
    source_month AS settlement_month,
    COALESCE(aar.root_id, c.account_id) AS root_account_id,
    'group_account' AS product,
    c.provider,
    SUM(COALESCE(c.cost_amount, 0))::numeric(20,4) AS cogs
  FROM "dwm"."dwm_finance_channel_cost_p" c
  LEFT JOIN account_root_relation aar
    ON aar.account_id = c.account_id
  WHERE c.delete_time IS NULL
    AND c.source_month >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
    AND c.product_line = 'GLOBAL_ACCOUNT'
    AND c.provider IN ('BZ', 'CL')
  GROUP BY c.source_month, COALESCE(aar.root_id, c.account_id), c.provider
),
-- v2: 结汇成本 SETTLEMENT_COST（从 dwm_finance_channel_cost_p 读取分摊后的成本）
global_account_settlement_cost AS (
  SELECT
    source_month AS settlement_month,
    COALESCE(aar.root_id, c.account_id) AS root_account_id,
    'group_account' AS product,
    c.provider,
    SUM(COALESCE(c.cost_amount, 0))::numeric(20,4) AS cogs
  FROM "dwm"."dwm_finance_channel_cost_p" c
  LEFT JOIN account_root_relation aar
    ON aar.account_id = c.account_id
  WHERE c.delete_time IS NULL
    AND c.source_month >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
    AND c.product_line = 'GLOBAL_ACCOUNT'
    AND c.cost_type = 'SETTLEMENT_COST'
  GROUP BY c.source_month, COALESCE(aar.root_id, c.account_id), c.provider
),
qbit_card_bb_month_net_amount AS (
  SELECT
    date_trunc('month', report_date)::date AS settlement_month,
    SUM(COALESCE(total_net_amount, 0))::numeric(20,4) AS month_total_net_amount
  FROM "dws"."dws_bb_card_finance_daily_v2_p"
  WHERE delete_time IS NULL
    AND report_date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY date_trunc('month', report_date)::date
),
qbit_card_bb_cost AS (
  SELECT
    date_trunc('month', b.report_date)::date AS settlement_month,
    COALESCE(aar.root_id, b.account_id) AS root_account_id,
    'qbit_card' AS product,
    'BB' AS provider,
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
    )::numeric(20,4) AS cogs
  FROM "dws"."dws_bb_card_finance_daily_v2_p" b
  LEFT JOIN account_root_relation aar
    ON aar.account_id = b.account_id
  LEFT JOIN qbit_card_bb_month_net_amount mn
    ON mn.settlement_month = date_trunc('month', b.report_date)::date
  WHERE b.delete_time IS NULL
    AND b.report_date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY date_trunc('month', b.report_date)::date, COALESCE(aar.root_id, b.account_id)
),
qbit_card_qi_cost AS (
  SELECT
    date_trunc('month', q.report_date)::date AS settlement_month,
    COALESCE(aar.root_id, q.account_id) AS root_account_id,
    'qbit_card' AS product,
    'IQ' AS provider,
    SUM(
        COALESCE(q.cost_reimbursement_base_amt, 0) * COALESCE(q.cost_reimbursement_rate, 0)
      + COALESCE(q.cost_service_base_amt, 0) * COALESCE(q.cost_service_rate, 0)
      + COALESCE(q.cost_acs_regular_base_amt, 0) * COALESCE(q.cost_acs_regular_rate, 0)
      + COALESCE(q.cost_acs_vip_base_amt, 0) * COALESCE(q.cost_acs_vip_rate, 0)
      + COALESCE(q.cost_vrm_base_amt, 0) * COALESCE(q.cost_vrm_rate, 0)
      + COALESCE(q.cost_hk_regular_base_amt, 0) * COALESCE(q.cost_hk_regular_rate, 0)
      + COALESCE(q.cost_hk_vip_base_amt, 0) * COALESCE(q.cost_hk_vip_rate, 0)
      + COALESCE(q.cost_dcsf_base_amt, 0) * COALESCE(q.cost_dcsf_rate, 0)
      + COALESCE(q.cost_fixed_fee, 0)
    )::numeric(20,4) AS cogs
  FROM "dws"."dws_qi_card_finance_daily_v2_p" q
  LEFT JOIN account_root_relation aar
    ON aar.account_id = q.account_id
  WHERE q.delete_time IS NULL
    AND q.report_date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY date_trunc('month', q.report_date)::date, COALESCE(aar.root_id, q.account_id)
),
qbit_card_sl_cost AS (
  SELECT
    date_trunc('month', s.report_date)::date AS settlement_month,
    COALESCE(aar.root_id, s.account_id) AS root_account_id,
    'qbit_card' AS product,
    'SL' AS provider,
    SUM(COALESCE(s.cost_fixed_fee, 0))::numeric(20,4) AS cogs
  FROM "dws"."dws_sl_card_finance_daily_p" s
  LEFT JOIN account_root_relation aar
    ON aar.account_id = s.account_id
  WHERE s.delete_time IS NULL
    AND s.report_date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY date_trunc('month', s.report_date)::date, COALESCE(aar.root_id, s.account_id)
),
qbit_card_bpc_cost AS (
  SELECT
    source_month AS settlement_month,
    COALESCE(aar.root_id, c.account_id) AS root_account_id,
    'qbit_card' AS product,
    'QI' AS provider,
    SUM(COALESCE(c.cost_amount, 0))::numeric(20,4) AS cogs
  FROM "dwm"."dwm_finance_channel_cost_p" c
  LEFT JOIN account_root_relation aar
    ON aar.account_id = c.account_id
  WHERE c.delete_time IS NULL
    AND c.source_month >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
    AND c.product_line = 'QUANTUM_CARD'
    AND c.provider = 'BPC'
  GROUP BY c.source_month, COALESCE(aar.root_id, c.account_id)
),
qbit_card_bz_cost AS (
  SELECT
    date_trunc('month', z.report_date)::date AS settlement_month,
    COALESCE(aar.root_id, z.account_id) AS root_account_id,
    'qbit_card' AS product,
    'BZ' AS provider,
    SUM(
        COALESCE(z.clearing_base_amt, 0) * COALESCE(z.reimbursement_rate, 0)
      + COALESCE(z.refund_base_amt, 0) * COALESCE(z.reimbursement_rate, 0)
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
    )::numeric(20,4) AS cogs
  FROM "dws"."dws_bz_card_finance_daily_v2_p" z
  LEFT JOIN account_root_relation aar
    ON aar.account_id = z.account_id
  WHERE z.delete_time IS NULL
    AND z.report_date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY date_trunc('month', z.report_date)::date, COALESCE(aar.root_id, z.account_id)
),
qbit_card_physical_cost AS (
  SELECT
    r.settlement_month,
    r.root_account_id,
    'qbit_card' AS product,
    r.provider,
    SUM(COALESCE(r.income_value, 0))::numeric(20,4) AS cogs
  FROM "dws"."dws_metrics_sales_revenue_monthly" r
  LEFT JOIN sale_department_mapping sdm
    ON sdm.sale_id = COALESCE(r.sale_id, r.am_id)
  WHERE r.delete_time IS NULL
    AND r.settlement_month >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
    AND r.product = 'qbit_card'
    AND r.provider = 'QI'
    AND r.metric_code = 'physical_card_cost'
    AND sdm.department_id IN ('1740319905791647746', '1740319923059597313')
  GROUP BY r.settlement_month, r.root_account_id, r.provider
),
-- v2: 全球账户离线 fee_cost（从 payment_transaction_record 直接查询）
global_account_offline_fee_cost AS (
  SELECT
    date_trunc('month', ptr.submit_time)::date AS settlement_month,
    COALESCE(aar.root_id, ptr.account_id) AS root_account_id,
    'group_account' AS product,
    'OFFLINE' AS provider,
    SUM(
      COALESCE(
        NULLIF(
          (regexp_match(
            ptr.extra,
            '"fee_cost"[[:space:]]*:[[:space:]]*"?([-+]?[0-9]+([.][0-9]+)?)"?'
          ))[1],
          ''
        )::numeric,
        0
      )
    )::numeric(20,4) AS cogs
  FROM ods.ods_payment_transaction_record ptr
  LEFT JOIN account_root_relation aar ON aar.account_id = ptr.account_id
  WHERE ptr.delete_time IS NULL
    AND ptr.dt >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
    AND ptr.status = 'Closed'
    AND COALESCE(
      NULLIF(
        (regexp_match(
          ptr.extra,
          '"fee_cost"[[:space:]]*:[[:space:]]*"?([-+]?[0-9]+([.][0-9]+)?)"?'
        ))[1],
        ''
      )::numeric,
      0
    ) > 0
    AND date_trunc('month', ptr.submit_time)::date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY date_trunc('month', ptr.submit_time)::date, COALESCE(aar.root_id, ptr.account_id)
),
-- v2: bi_month_tag 中的线下退款（含 account_id，按 product_line 区分归属）
offline_refund_cost AS (
  SELECT
    date_trunc('month', t.statistics_time)::date AS settlement_month,
    COALESCE(aar.root_id, t.account_id) AS root_account_id,
    CASE t.product_line
      WHEN 'GLOBAL_ACCOUNT' THEN 'group_account'
      WHEN 'QUANTUM_CARD' THEN 'qbit_card'
      WHEN 'CRYPTO_ASSET' THEN 'crypto'
    END AS product,
    'OFFLINE_REFUND' AS provider,
    SUM(COALESCE(t.amount, 0))::numeric(20,4) AS cogs
  FROM ods.ods_bi_month_tag t
  LEFT JOIN account_root_relation aar ON aar.account_id = t.account_id
  WHERE t.delete_time IS NULL
    AND t.account_id IS NOT NULL
    AND t.tag = 'OFFLINE_REFUND'
    AND date_trunc('month', t.statistics_time)::date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY date_trunc('month', t.statistics_time)::date, COALESCE(aar.root_id, t.account_id), t.product_line
),
-- 量子卡/加密专项成本指标；provider 为空时由分摊逻辑跨渠道分配。
commission_metric_cost AS (
  SELECT
    r.settlement_month,
    r.root_account_id,
    CASE r.metric_code
      WHEN 'qbit_card_collection_fee' THEN 'qbit_card'
      WHEN 'crypto_connect_income' THEN 'crypto'
    END AS product,
    NULLIF(TRIM(r.provider), '') AS provider,
    SUM(COALESCE(r.income_value, 0))::numeric(20,4) AS cogs
  FROM "dws"."dws_metrics_sales_revenue_monthly" r
  WHERE r.delete_time IS NULL
    AND r.settlement_month >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
    AND (
      (r.product = 'qbit_card' AND r.metric_code = 'qbit_card_collection_fee')
      OR (r.product = 'crypto_connect' AND r.metric_code = 'crypto_connect_income')
    )
  GROUP BY r.settlement_month, r.root_account_id, r.metric_code, NULLIF(TRIM(r.provider), '')
),
crypto_acceptance_cost AS (
  SELECT
    r.settlement_month,
    r.root_account_id,
    'crypto' AS product,
    r.provider,
    SUM(
      CASE
        WHEN csdm.department_id = '1851130772357509121'
         AND r.metric_code IN ('assets_acceptance_fee_gt_zero', 'assets_acceptance_fee_eq_zero')
          THEN COALESCE(r.income_value, 0) * 0.0009
        WHEN COALESCE(csdm.department_id, '') <> '1851130772357509121'
         AND r.metric_code = 'assets_acceptance_fee_gt_zero'
          THEN COALESCE(r.income_value, 0) * 0.0009
        ELSE 0
      END
    )::numeric(20,4) AS cogs
  FROM "dws"."dws_metrics_sales_revenue_monthly" r
  LEFT JOIN sale_department_mapping sdm
    ON sdm.sale_id = COALESCE(r.sale_id, r.am_id)
  LEFT JOIN crypto_sale_department_mapping csdm
    ON csdm.sale_id = COALESCE(r.sale_id, r.am_id)
  WHERE r.delete_time IS NULL
    AND r.settlement_month >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
    AND r.product = 'crypto_connect'
    AND r.metric_code IN ('assets_acceptance_fee_gt_zero', 'assets_acceptance_fee_eq_zero')
  GROUP BY r.settlement_month, r.root_account_id, r.provider
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
      ABS(SUM(COALESCE(b.bb_rebate_base_amt, 0) * 0.021195))::numeric(20,4) AS channel_rebate
    FROM "dws"."dws_bb_card_finance_daily_v2_p" b
    LEFT JOIN account_root_relation aar
      ON aar.account_id = b.account_id
    WHERE b.delete_time IS NULL
      AND b.report_date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
    GROUP BY date_trunc('month', b.report_date)::date, COALESCE(aar.root_id, b.account_id)
    UNION ALL
    SELECT
      date_trunc('month', q.report_date)::date AS settlement_month,
      COALESCE(aar.root_id, q.account_id) AS root_account_id,
      'qbit_card' AS product,
      'IQ' AS provider,
      ABS(SUM(
          COALESCE(q.rebate_interchange_base_amt, 0) * COALESCE(q.rebate_interchange_rate, 0)
          + COALESCE(q.rebate_incentive_base_amt, 0) * COALESCE(q.rebate_incentive_rate, 0)
      ))::numeric(20,4) AS channel_rebate
    FROM "dws"."dws_qi_card_finance_daily_v2_p" q
    LEFT JOIN account_root_relation aar
      ON aar.account_id = q.account_id
    WHERE q.delete_time IS NULL
      AND q.report_date >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
    GROUP BY date_trunc('month', q.report_date)::date, COALESCE(aar.root_id, q.account_id)
  ) rebate_union
  GROUP BY settlement_month, root_account_id, product, provider
),
qbit_card_customer_rebate_cost AS (
  SELECT
    to_date(cbb."month" || '-01', 'YYYY-MM-DD') AS settlement_month,
    cbb.account_id::text AS root_account_id,
    'qbit_card' AS product,
    SUM(COALESCE(cbb.cash_back_amount, 0))::numeric(20,4) AS customer_rebate_cost
  FROM "public"."cash_back_bonuses" cbb
  WHERE cbb.delete_time IS NULL
    AND cbb.project = 'QuantumAccountHandlingFeeOnBehalf'
    AND cbb.status = 'Closed'
    AND to_date(cbb."month" || '-01', 'YYYY-MM-DD') >= date_trunc('month', CURRENT_DATE - interval '6 months')::date
  GROUP BY to_date(cbb."month" || '-01', 'YYYY-MM-DD'), cbb.account_id::text
),
v_cost_by_account_product AS (
  SELECT
    settlement_month,
    root_account_id,
    product,
    provider,
    SUM(cogs)::numeric(20,4) AS cogs
  FROM (
    SELECT settlement_month, root_account_id, product, provider, cogs FROM global_account_channel_cost
    UNION ALL
    -- v2: 结汇成本
    SELECT settlement_month, root_account_id, product, provider, cogs FROM global_account_settlement_cost
    UNION ALL
    SELECT settlement_month, root_account_id, product, provider, cogs FROM qbit_card_bb_cost
    UNION ALL
    SELECT settlement_month, root_account_id, product, provider, cogs FROM qbit_card_qi_cost
    UNION ALL
    SELECT settlement_month, root_account_id, product, provider, cogs FROM qbit_card_sl_cost
    UNION ALL
    SELECT settlement_month, root_account_id, product, provider, cogs FROM qbit_card_bpc_cost
    UNION ALL
    SELECT settlement_month, root_account_id, product, provider, cogs FROM qbit_card_bz_cost
    UNION ALL
    SELECT settlement_month, root_account_id, product, provider, cogs FROM crypto_acceptance_cost
    UNION ALL
    -- v2: 全球账户离线 fee_cost
    SELECT settlement_month, root_account_id, product, provider, cogs FROM global_account_offline_fee_cost
    UNION ALL
    -- v2: 线下退款（所有 product_line）
    SELECT settlement_month, root_account_id, product, provider, cogs FROM offline_refund_cost
    UNION ALL
    SELECT settlement_month, root_account_id, product, provider, cogs FROM commission_metric_cost
  ) cost_union
  GROUP BY settlement_month, root_account_id, product, provider
),
revenue_cost_allocated AS (
  SELECT
    x.*,
    GREATEST((
      x.effective_revenue
      + CASE
          WHEN x.product_effective_revenue <> 0 THEN x.total_channel_rebate * x.effective_revenue / x.product_effective_revenue
          ELSE 0
        END
      - CASE
          WHEN x.product = 'qbit_card' AND x.qbit_card_effective_revenue <> 0
            THEN x.total_customer_rebate_cost * x.effective_revenue / x.qbit_card_effective_revenue
          ELSE 0
        END
    ), 0)::numeric(20,4) AS allocated_effective_revenue,
    (
      CASE
        WHEN x.product_effective_revenue <> 0 THEN x.provider_cogs * x.effective_revenue / x.product_effective_revenue
        WHEN x.cost_allocation_rn = 1 THEN x.provider_cogs
        ELSE 0
      END
      + CASE
        WHEN x.all_product_effective_revenue <> 0 THEN x.unscoped_cogs * x.effective_revenue / x.all_product_effective_revenue
        WHEN x.all_cost_allocation_rn = 1 THEN x.unscoped_cogs
        ELSE 0
      END
    )::numeric(20,4) AS allocated_cogs
  FROM (
    SELECT
      b.*,
      COALESCE(c.provider_cogs, 0)::numeric(20,4) AS provider_cogs,
      COALESCE(c.unscoped_cogs, 0)::numeric(20,4) AS unscoped_cogs,
      COALESCE(r.channel_rebate, 0)::numeric(20,4) AS total_channel_rebate,
      COALESCE(cr.customer_rebate_cost, 0)::numeric(20,4) AS total_customer_rebate_cost,
      SUM(b.effective_revenue) OVER (
        PARTITION BY b.settlement_month, b.root_account_id, b.product, COALESCE(b.provider, '')
      )::numeric(20,4) AS product_effective_revenue,
      SUM(b.effective_revenue) OVER (
        PARTITION BY b.settlement_month, b.root_account_id, b.product
      )::numeric(20,4) AS all_product_effective_revenue,
      SUM(CASE WHEN b.product = 'qbit_card' THEN b.effective_revenue ELSE 0 END) OVER (
        PARTITION BY b.settlement_month, b.root_account_id, b.product
      )::numeric(20,4) AS qbit_card_effective_revenue,
      ROW_NUMBER() OVER (
        PARTITION BY b.settlement_month, b.root_account_id, b.product, COALESCE(b.provider, '')
        ORDER BY CASE WHEN b.effective_revenue <> 0 THEN 0 ELSE 1 END, b.sale_id NULLS LAST, b.department_id NULLS LAST
      ) AS cost_allocation_rn,
      ROW_NUMBER() OVER (
        PARTITION BY b.settlement_month, b.root_account_id, b.product
        ORDER BY CASE WHEN b.effective_revenue <> 0 THEN 0 ELSE 1 END, b.sale_id NULLS LAST, b.department_id NULLS LAST
      ) AS all_cost_allocation_rn
    FROM revenue_base b
    LEFT JOIN LATERAL (
      SELECT
        SUM(CASE
          WHEN NULLIF(TRIM(c.provider), '') IS NULL THEN c.cogs
          ELSE 0
        END) AS unscoped_cogs,
        SUM(CASE
          WHEN NULLIF(TRIM(c.provider), '') IS NOT NULL
           AND NULLIF(TRIM(c.provider), '') = NULLIF(TRIM(b.provider), '')
            THEN c.cogs
          ELSE 0
        END) AS provider_cogs
      FROM v_cost_by_account_product c
      WHERE c.settlement_month = b.settlement_month
        AND c.root_account_id = b.root_account_id
        AND c.product = b.product
    ) c ON true
    LEFT JOIN qbit_card_channel_rebate r
      ON r.settlement_month = b.settlement_month
     AND r.root_account_id = b.root_account_id
     AND r.product = b.product
     AND COALESCE(r.provider, '') = COALESCE(b.provider, '')
    LEFT JOIN qbit_card_customer_rebate_cost cr
      ON cr.settlement_month = b.settlement_month
     AND cr.root_account_id = b.root_account_id
     AND cr.product = b.product
  ) x
),
estimate_base AS (
  SELECT
    b.report_date,
    b.settlement_month,
    b.root_account_id,
    b.product,
    b.provider,
    b.item,
    b.source_type,
    b.commission_stage,
    b.sale_id,
    b.department_id,
    b.am_id,
    b.activity_month,
    b.collection_month,
    b.payable_settlement_month,
    b.allocated_effective_revenue AS effective_revenue,
    b.allocated_cogs AS cogs,
    CASE
      WHEN b.department_id = '1851130772357509121'
        THEN (b.allocated_effective_revenue - b.allocated_cogs)::numeric(20,4)
      ELSE GREATEST(b.allocated_effective_revenue - b.allocated_cogs, 0)::numeric(20,4)
    END AS gp,
    CASE
      WHEN b.product = 'qbit_card'
       AND (a.card_active_time IS NULL OR a.card_active_time::date > (b.settlement_month + interval '1 month')::date)
        THEN 0
      WHEN b.product = 'qbit_card'
        THEN ((b.settlement_month + interval '1 month')::date - a.card_active_time::date)
      WHEN b.product = 'group_account'
       AND (a.global_active_time IS NULL OR a.global_active_time::date > (b.settlement_month + interval '1 month')::date)
        THEN 0
      WHEN b.product = 'group_account'
        THEN ((b.settlement_month + interval '1 month')::date - a.global_active_time::date)
      WHEN b.product = 'crypto'
       AND (a.crypto_active_time IS NULL OR a.crypto_active_time::date > (b.settlement_month + interval '1 month')::date)
        THEN 0
      WHEN b.product = 'crypto'
        THEN ((b.settlement_month + interval '1 month')::date - a.crypto_active_time::date)
      WHEN b.product = 'open_api'
       AND (a.api_active_time IS NULL OR a.api_active_time::date > (b.settlement_month + interval '1 month')::date)
        THEN 0
      WHEN b.product = 'open_api'
        THEN ((b.settlement_month + interval '1 month')::date - a.api_active_time::date)
      WHEN b.product = 'treasury'
       AND (a.treasury_active_time IS NULL OR a.treasury_active_time::date > (b.settlement_month + interval '1 month')::date)
        THEN 0
      WHEN b.product = 'treasury'
        THEN ((b.settlement_month + interval '1 month')::date - a.treasury_active_time::date)
      ELSE NULL
    END AS active_days,
    CASE
      WHEN a.referral_user_id IS NOT NULL AND a.referral_user_id = b.sale_id THEN 'direct'
    ELSE 'non_direct'
    END AS invite_type
  FROM revenue_cost_allocated b
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
WITH DATA
DISTRIBUTED BY (id);

ALTER MATERIALIZED VIEW "dws"."mv_sales_commission_recent_estimate"
  OWNER TO "flink_cdc_user";

COMMENT ON MATERIALIZED VIEW "dws"."mv_sales_commission_recent_estimate" IS '销售佣金8号前预估物化视图 v2，新增SETTLEMENT_COST/线下退款/收入&返现调整/线下API收入/线下制卡费/离线fee_cost';

CREATE INDEX IF NOT EXISTS "idx_mv_sales_commission_recent_estimate_query" ON "dws"."mv_sales_commission_recent_estimate" (
  "settlement_month",
  "sale_id",
  "am_id",
  "commission_stage"
);

CREATE INDEX IF NOT EXISTS "idx_mv_sales_commission_recent_estimate_payable" ON "dws"."mv_sales_commission_recent_estimate" (
  "payable_settlement_month",
  "sale_id",
  "am_id"
);

CREATE INDEX IF NOT EXISTS "idx_mv_sales_commission_recent_estimate_account" ON "dws"."mv_sales_commission_recent_estimate" (
  "root_account_id",
  "settlement_month"
);
