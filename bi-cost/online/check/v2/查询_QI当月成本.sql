--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-11-09 14:00:00
-- Updated Time:   2026-11-09 16:52:28
-- Description:    按客户和期间查询 QI v2 每项渠道成本及合计，API 子户并入主户
-- Usage:
--   1. 在 PostgreSQL / ADBPG 中直接执行。
--   2. 修改 params 中的 account_id、start_date、end_date；end_date 左闭右开。
--   3. account_id 可传 API 主户或子户；API 子户会解析到主户并合并其有效子户。
--   4. 每项成本输出计费基数、加权费率和金额；固定成本不展示费率。
--   5. Interchange / Incentive 返现收入单独列示，不计入 QI 成本总计。
--********************************************************************--

WITH params AS (
    SELECT
        '替换为accountId'::varchar AS account_id,
        DATE '2026-10-01' AS start_date,
        DATE '2026-11-01' AS end_date
),
api_account_map AS (
    SELECT DISTINCT
        account_id::varchar AS account_id,
        root_id::varchar AS root_id
    FROM public.api_account_relation
    WHERE delete_time IS NULL
),
requested_account AS (
    SELECT
        p.account_id AS input_account_id,
        COALESCE(MAX(api.root_id), p.account_id) AS report_account_id,
        p.start_date,
        p.end_date
    FROM params p
    LEFT JOIN api_account_map api
      ON api.account_id = p.account_id
    GROUP BY p.account_id, p.start_date, p.end_date
),
qi_scope AS (
    SELECT
        qi.*,
        COALESCE(api.root_id, qi.account_id::varchar) AS report_account_id
    FROM dws.dws_qi_card_finance_daily_v2_p qi
    LEFT JOIN api_account_map api
      ON api.account_id = qi.account_id::varchar
    CROSS JOIN requested_account target
    WHERE qi.delete_time IS NULL
      AND qi.report_date >= target.start_date
      AND qi.report_date < target.end_date
      AND COALESCE(api.root_id, qi.account_id::varchar) = target.report_account_id
),
qi_scope_summary AS (
    SELECT
        COUNT(DISTINCT account_id) AS dws_account_count,
        COUNT(*) AS dws_row_count,
        MIN(report_date) AS data_start_date,
        MAX(report_date) AS data_end_date
    FROM qi_scope
),
qi_cost_items AS (
    SELECT 10 AS item_order, '成本'::text AS item_type, 'Reimbursement 费用'::text AS cost_item,
           SUM(COALESCE(cost_reimbursement_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric AS base_amount,
           (SUM(COALESCE(cost_reimbursement_base_amt, 0) * COALESCE(cost_reimbursement_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(cost_reimbursement_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric AS unit_rate,
           SUM(COALESCE(cost_reimbursement_base_amt, 0) * COALESCE(cost_reimbursement_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric AS item_amount
    FROM qi_scope
    UNION ALL SELECT 20, '成本', 'Card Service 费用',
           SUM(COALESCE(cost_service_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric,
           (SUM(COALESCE(cost_service_base_amt, 0) * COALESCE(cost_service_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(cost_service_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric,
           SUM(COALESCE(cost_service_base_amt, 0) * COALESCE(cost_service_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric FROM qi_scope
    UNION ALL SELECT 30, '成本', 'ACS Regular 费用',
           SUM(COALESCE(cost_acs_regular_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric,
           (SUM(COALESCE(cost_acs_regular_base_amt, 0) * COALESCE(cost_acs_regular_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(cost_acs_regular_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric,
           SUM(COALESCE(cost_acs_regular_base_amt, 0) * COALESCE(cost_acs_regular_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric FROM qi_scope
    UNION ALL SELECT 40, '成本', 'ACS VIP 费用',
           SUM(COALESCE(cost_acs_vip_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric,
           (SUM(COALESCE(cost_acs_vip_base_amt, 0) * COALESCE(cost_acs_vip_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(cost_acs_vip_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric,
           SUM(COALESCE(cost_acs_vip_base_amt, 0) * COALESCE(cost_acs_vip_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric FROM qi_scope
    UNION ALL SELECT 50, '成本', 'VRM 费用',
           SUM(COALESCE(cost_vrm_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric,
           (SUM(COALESCE(cost_vrm_base_amt, 0) * COALESCE(cost_vrm_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(cost_vrm_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric,
           SUM(COALESCE(cost_vrm_base_amt, 0) * COALESCE(cost_vrm_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric FROM qi_scope
    UNION ALL SELECT 60, '成本', 'HK Regular 费用',
           SUM(COALESCE(cost_hk_regular_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric,
           (SUM(COALESCE(cost_hk_regular_base_amt, 0) * COALESCE(cost_hk_regular_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(cost_hk_regular_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric,
           SUM(COALESCE(cost_hk_regular_base_amt, 0) * COALESCE(cost_hk_regular_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric FROM qi_scope
    UNION ALL SELECT 70, '成本', 'HK VIP 费用',
           SUM(COALESCE(cost_hk_vip_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric,
           (SUM(COALESCE(cost_hk_vip_base_amt, 0) * COALESCE(cost_hk_vip_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(cost_hk_vip_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric,
           SUM(COALESCE(cost_hk_vip_base_amt, 0) * COALESCE(cost_hk_vip_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric FROM qi_scope
    UNION ALL SELECT 80, '成本', 'DCSF 费用',
           SUM(COALESCE(cost_dcsf_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric,
           (SUM(COALESCE(cost_dcsf_base_amt, 0) * COALESCE(cost_dcsf_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(cost_dcsf_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric,
           SUM(COALESCE(cost_dcsf_base_amt, 0) * COALESCE(cost_dcsf_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric FROM qi_scope
    UNION ALL SELECT 90, '成本', '渠道固定成本', NULL::numeric, NULL::numeric,
           SUM(COALESCE(cost_fixed_fee, 0)) FILTER (WHERE special_fee_type = 'CHANNEL_FIXED_FEE')::numeric FROM qi_scope
),
qi_total AS (
    SELECT 999 AS item_order, '成本'::text AS item_type, 'QI 渠道总成本'::text AS cost_item,
           NULL::numeric AS base_amount, NULL::numeric AS unit_rate,
           COALESCE(SUM(item_amount), 0)::numeric AS item_amount
    FROM qi_cost_items
),
qi_cashback_items AS (
    SELECT 1010 AS item_order, '返现收入'::text AS item_type, 'Interchange 返现收入'::text AS cost_item,
           SUM(COALESCE(rebate_interchange_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric AS base_amount,
           (SUM(COALESCE(rebate_interchange_base_amt, 0) * COALESCE(rebate_interchange_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(rebate_interchange_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric AS unit_rate,
           SUM(COALESCE(rebate_interchange_base_amt, 0) * COALESCE(rebate_interchange_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric AS item_amount
    FROM qi_scope
    UNION ALL SELECT 1020, '返现收入', 'Incentive 返现收入',
           SUM(COALESCE(rebate_incentive_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric,
           (SUM(COALESCE(rebate_incentive_base_amt, 0) * COALESCE(rebate_incentive_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(rebate_incentive_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric,
           SUM(COALESCE(rebate_incentive_base_amt, 0) * COALESCE(rebate_incentive_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric FROM qi_scope
),
all_items AS (
    SELECT * FROM qi_cost_items
    UNION ALL SELECT * FROM qi_total
    UNION ALL SELECT * FROM qi_cashback_items
)
SELECT
    'QI' AS channel,
    target.input_account_id,
    target.report_account_id,
    target.start_date AS query_start_date,
    target.end_date AS query_end_date_exclusive,
    summary.dws_account_count,
    summary.dws_row_count,
    CASE WHEN summary.dws_row_count = 0 THEN 'DWS无数据' ELSE '已查到DWS数据' END AS query_status,
    item.item_type,
    item.cost_item,
    CAST(item.base_amount AS NUMERIC(20, 4)) AS base_amount,
    CAST(item.unit_rate AS NUMERIC(20, 8)) AS weighted_rate,
    CAST(COALESCE(item.item_amount, 0) AS NUMERIC(20, 4)) AS amount
FROM all_items item
CROSS JOIN requested_account target
CROSS JOIN qi_scope_summary summary
ORDER BY item.item_order;
