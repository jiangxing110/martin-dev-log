--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-08-17 00:00:00
-- Description:    查询 QI v3 渠道成本汇总，按月份透视，每月一行展示成本与两项返现（interchange / incentive，不合计）
-- Usage:
--   1. 修改 params 中的 start_date / end_date。
--   2. end_date 使用左闭右开，示例表示查询 2026-05 整月。
--   3. TOTAL 不包含 QI Channel Rebate Base / QI Channel Rebate Income。
--   4. 结果按月份分组，month 取自数据的 report_date，支持跨多月查询。
--********************************************************************--

WITH params AS (
    SELECT
        DATE '2026-05-01' AS start_date,
        DATE '2026-06-01' AS end_date
),
qi_normal_detail AS (
    SELECT
        TO_CHAR(qi.report_date, 'YYYY-MM') AS month,
        SUM(COALESCE(qi.cost_reimbursement_base_amt, 0) * COALESCE(qi.cost_reimbursement_rate, 1)) AS cost_reimbursement_amount,
        SUM(COALESCE(qi.cost_service_base_amt, 0) * COALESCE(qi.cost_service_rate, 1)) AS cost_service_amount,
        SUM(COALESCE(qi.cost_acs_regular_base_amt, 0) * COALESCE(qi.cost_acs_regular_rate, 1)) AS cost_acs_regular_amount,
        SUM(COALESCE(qi.cost_acs_vip_base_amt, 0) * COALESCE(qi.cost_acs_vip_rate, 1)) AS cost_acs_vip_amount,
        SUM(COALESCE(qi.cost_vrm_base_amt, 0) * COALESCE(qi.cost_vrm_rate, 1)) AS cost_vrm_amount,
        SUM(COALESCE(qi.cost_hk_regular_base_amt, 0) * COALESCE(qi.cost_hk_regular_rate, 1)) AS cost_hk_regular_amount,
        SUM(COALESCE(qi.cost_hk_vip_base_amt, 0) * COALESCE(qi.cost_hk_vip_rate, 1)) AS cost_hk_vip_amount,
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
    GROUP BY TO_CHAR(qi.report_date, 'YYYY-MM')
),
qi_fixed_fee_detail AS (
    SELECT
        TO_CHAR(qi.report_date, 'YYYY-MM') AS month,
        SUM(COALESCE(qi.cost_fixed_fee, 0)) AS fixed_fee_amount
    FROM dws.dws_qi_card_finance_daily_v2_p qi
    CROSS JOIN params p
    WHERE qi.delete_time IS NULL
      AND qi.report_date >= p.start_date
      AND qi.report_date < p.end_date
      AND qi.special_fee_type = 'CHANNEL_FIXED_FEE'
    GROUP BY TO_CHAR(qi.report_date, 'YYYY-MM')
),
qi_total AS (
    SELECT
        COALESCE(n.cost_reimbursement_amount, 0)
        + COALESCE(n.cost_service_amount, 0)
        + COALESCE(n.cost_acs_regular_amount, 0)
        + COALESCE(n.cost_acs_vip_amount, 0)
        + COALESCE(n.cost_vrm_amount, 0)
        + COALESCE(n.cost_hk_regular_amount, 0)
        + COALESCE(n.cost_hk_vip_amount, 0)
        + COALESCE(n.cost_dcsf_amount, 0)
        + COALESCE(f.fixed_fee_amount, 0) AS total_cost,
        COALESCE(n.rebate_interchange_amount, 0) AS interchange_income,
        COALESCE(n.rebate_incentive_amount, 0) AS incentive_income,
        COALESCE(n.month, f.month) AS month
    FROM qi_normal_detail n
    FULL JOIN qi_fixed_fee_detail f ON n.month = f.month
)
SELECT
    month,
    CAST(COALESCE(total_cost, 0) AS NUMERIC(20, 4)) AS cost,
    CAST(COALESCE(interchange_income, 0) AS NUMERIC(20, 4)) AS interchange_income,
    CAST(COALESCE(incentive_income, 0) AS NUMERIC(20, 4)) AS incentive_income
FROM qi_total
ORDER BY month;
