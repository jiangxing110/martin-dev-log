--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-07-17
-- Description:    查询 QI v2 渠道成本明细，来源 dws.dws_qi_card_finance_daily_v2_p
-- Usage:
--   1. 修改 params 中的 start_date / end_date。
--   2. end_date 使用左闭右开，示例表示查询 2026-05 整月。
--   3. 普通成本行 special_fee_type IS NULL，渠道固定成本行 special_fee_type = 'CHANNEL_FIXED_FEE'。
--   4. cost_rate 为加权费率：SUM(base * rate) / SUM(base)，跨月查询时不会被单个月份费率误导。
--********************************************************************--

WITH params AS (
    SELECT
        DATE '2026-05-01' AS start_date,
        DATE '2026-06-01' AS end_date
),
qi_normal_detail AS (
    SELECT
        SUM(COALESCE(qi.cost_reimbursement_base_amt, 0)) AS cost_reimbursement_base,
        SUM(COALESCE(qi.cost_reimbursement_base_amt, 0) * COALESCE(qi.cost_reimbursement_rate, 1)) AS cost_reimbursement_amount,

        SUM(COALESCE(qi.cost_service_base_amt, 0)) AS cost_service_base,
        SUM(COALESCE(qi.cost_service_base_amt, 0) * COALESCE(qi.cost_service_rate, 1)) AS cost_service_amount,

        SUM(COALESCE(qi.cost_acs_regular_base_amt, 0)) AS cost_acs_regular_base,
        SUM(COALESCE(qi.cost_acs_regular_base_amt, 0) * COALESCE(qi.cost_acs_regular_rate, 1)) AS cost_acs_regular_amount,

        SUM(COALESCE(qi.cost_acs_vip_base_amt, 0)) AS cost_acs_vip_base,
        SUM(COALESCE(qi.cost_acs_vip_base_amt, 0) * COALESCE(qi.cost_acs_vip_rate, 1)) AS cost_acs_vip_amount,

        SUM(COALESCE(qi.cost_vrm_base_amt, 0)) AS cost_vrm_base,
        SUM(COALESCE(qi.cost_vrm_base_amt, 0) * COALESCE(qi.cost_vrm_rate, 1)) AS cost_vrm_amount,

        SUM(COALESCE(qi.cost_hk_regular_base_amt, 0)) AS cost_hk_regular_base,
        SUM(COALESCE(qi.cost_hk_regular_base_amt, 0) * COALESCE(qi.cost_hk_regular_rate, 1)) AS cost_hk_regular_amount,

        SUM(COALESCE(qi.cost_hk_vip_base_amt, 0)) AS cost_hk_vip_base,
        SUM(COALESCE(qi.cost_hk_vip_base_amt, 0) * COALESCE(qi.cost_hk_vip_rate, 1)) AS cost_hk_vip_amount,

        SUM(COALESCE(qi.cost_dcsf_base_amt, 0)) AS cost_dcsf_base,
        SUM(COALESCE(qi.cost_dcsf_base_amt, 0) * COALESCE(qi.cost_dcsf_rate, 1)) AS cost_dcsf_amount,

        SUM(COALESCE(qi.rebate_interchange_base_amt, 0)) AS rebate_interchange_base,
        SUM(COALESCE(qi.rebate_interchange_base_amt, 0) * COALESCE(qi.rebate_interchange_rate, 1)) AS rebate_interchange_amount,

        SUM(COALESCE(qi.rebate_incentive_base_amt, 0)) AS rebate_incentive_base,
        SUM(COALESCE(qi.rebate_incentive_base_amt, 0) * COALESCE(qi.rebate_incentive_rate, 1)) AS rebate_incentive_amount
    FROM dws.dws_qi_card_finance_daily_v2_p qi
    CROSS JOIN params p
    WHERE qi.delete_time IS NULL
      AND qi.report_date >= p.start_date
      AND qi.report_date < p.end_date
      AND qi.special_fee_type IS NULL
),
qi_fixed_fee_detail AS (
    SELECT
        SUM(COALESCE(qi.cost_fixed_fee, 0)) AS fixed_fee_amount
    FROM dws.dws_qi_card_finance_daily_v2_p qi
    CROSS JOIN params p
    WHERE qi.delete_time IS NULL
      AND qi.report_date >= p.start_date
      AND qi.report_date < p.end_date
      AND qi.special_fee_type = 'CHANNEL_FIXED_FEE'
),
qi_cost_item AS (
    SELECT 10 AS item_order, 'qiReimbursement' AS cost_item, cost_reimbursement_base AS base_amount, cost_reimbursement_amount AS cost_amount FROM qi_normal_detail
    UNION ALL SELECT 20, 'qiCardService', cost_service_base, cost_service_amount FROM qi_normal_detail
    UNION ALL SELECT 30, 'qiSettleAuth', cost_acs_regular_base, cost_acs_regular_amount FROM qi_normal_detail
    UNION ALL SELECT 40, 'qiSettleVip', cost_acs_vip_base, cost_acs_vip_amount FROM qi_normal_detail
    UNION ALL SELECT 50, 'qiVrmFee', cost_vrm_base, cost_vrm_amount FROM qi_normal_detail
    UNION ALL SELECT 60, 'qiHkRegular', cost_hk_regular_base, cost_hk_regular_amount FROM qi_normal_detail
    UNION ALL SELECT 70, 'qiHkVip', cost_hk_vip_base, cost_hk_vip_amount FROM qi_normal_detail
    UNION ALL SELECT 80, 'qiDcsf', cost_dcsf_base, cost_dcsf_amount FROM qi_normal_detail
    UNION ALL SELECT 90, 'qiVisaIncentive', rebate_interchange_base, rebate_interchange_amount FROM qi_normal_detail
    UNION ALL SELECT 100, 'qiVisaReimbursement', rebate_incentive_base, rebate_incentive_amount FROM qi_normal_detail
    UNION ALL SELECT 900, 'fixed_fee_cost', fixed_fee_amount, fixed_fee_amount FROM qi_fixed_fee_detail
),
result_detail AS (
    SELECT
        item_order,
        cost_item,
        CAST(COALESCE(base_amount, 0) AS NUMERIC(20, 4)) AS base_amount,
        CAST(
            CASE
                WHEN COALESCE(base_amount, 0) = 0 THEN NULL
                ELSE COALESCE(cost_amount, 0) / base_amount
            END AS NUMERIC(20, 8)
        ) AS cost_rate,
        CAST(COALESCE(cost_amount, 0) AS NUMERIC(20, 4)) AS cost_amount
    FROM qi_cost_item

    UNION ALL

    SELECT
        999 AS item_order,
        'TOTAL' AS cost_item,
        CAST(COALESCE(SUM(base_amount), 0) AS NUMERIC(20, 4)) AS base_amount,
        CAST(NULL AS NUMERIC(20, 8)) AS cost_rate,
        CAST(COALESCE(SUM(cost_amount), 0) AS NUMERIC(20, 4)) AS cost_amount
    FROM qi_cost_item
)
SELECT
    cost_item,
    base_amount,
    cost_rate,
    cost_amount
FROM result_detail
ORDER BY item_order;
