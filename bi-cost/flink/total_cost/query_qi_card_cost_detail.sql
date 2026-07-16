--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-07-16
-- Description:    量子卡 QI 渠道成本明细查询
-- Usage:
--   1. 修改 params 中的 start_date / end_date。
--   2. end_date 使用左闭右开，不包含当天。
--   3. 计算口径对齐 flink/total_cost/dws_online_total_channel_cost_daily-batch-sql.sql。
--********************************************************************--

WITH params AS (
    SELECT
        DATE '2026-05-01' AS start_date,
        DATE '2026-06-01' AS end_date
),
qi_detail AS (
    SELECT
        SUM(COALESCE(qi.cost_reimbursement_vol, 0)) AS cost_reimbursement_cost,
        SUM(COALESCE(qi.cost_service_vol, 0)) AS cost_service_cost,
        SUM(COALESCE(qi.cost_acs_regular_count, 0)) AS cost_acs_regular_cost,
        SUM(COALESCE(qi.cost_acs_vip_count, 0)) AS cost_acs_vip_cost,
        SUM(COALESCE(qi.cost_vrm_count, 0)) AS cost_vrm_cost,
        SUM(COALESCE(qi.cost_fixed_fee, 0)) AS fixed_fee_cost
    FROM dws.dws_qi_card_finance_daily_p qi
    CROSS JOIN params p
    WHERE qi.delete_time IS NULL
      AND qi.report_date >= p.start_date
      AND qi.report_date < p.end_date
),
qi_cost_item AS (
    SELECT 'cost_reimbursement_cost' AS cost_item, cost_reimbursement_cost AS cost_amount FROM qi_detail
    UNION ALL SELECT 'cost_service_cost', cost_service_cost FROM qi_detail
    UNION ALL SELECT 'cost_acs_regular_cost', cost_acs_regular_cost FROM qi_detail
    UNION ALL SELECT 'cost_acs_vip_cost', cost_acs_vip_cost FROM qi_detail
    UNION ALL SELECT 'cost_vrm_cost', cost_vrm_cost FROM qi_detail
    UNION ALL SELECT 'fixed_fee_cost', fixed_fee_cost FROM qi_detail
),
result_detail AS (
    SELECT cost_item, CAST(COALESCE(cost_amount, 0) AS NUMERIC(20, 4)) AS cost_amount
    FROM qi_cost_item

    UNION ALL

    SELECT 'TOTAL' AS cost_item, CAST(COALESCE(SUM(cost_amount), 0) AS NUMERIC(20, 4)) AS cost_amount
    FROM qi_cost_item
)
SELECT
    cost_item,
    cost_amount
FROM result_detail
ORDER BY
    CASE cost_item WHEN 'TOTAL' THEN 999 ELSE 1 END,
    cost_item;
