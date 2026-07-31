--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-07-16
-- Description:    量子卡 BB / QI 渠道成本明细查询
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
bb_detail AS (
    SELECT
        'BB' AS channel,
        SUM(COALESCE(m_dom_auth_count, 0) * 0.1090) AS m_dom_auth_cost,
        SUM(COALESCE(av_m_dom_count, 0) * 0.1090) AS av_m_dom_cost,
        SUM(COALESCE(m_int_auth_count, 0) * 0.4845) AS m_int_auth_cost,
        SUM(COALESCE(av_m_int_count, 0) * 0.4845) AS av_m_int_cost,
        SUM(COALESCE(v_dom_auth_count, 0) * 0.0725) AS v_dom_auth_cost,
        SUM(COALESCE(av_v_dom_count, 0) * 0.0725) AS av_v_dom_cost,
        SUM(COALESCE(v_int_auth_count, 0) * 0.4700) AS v_int_auth_cost,
        SUM(COALESCE(av_v_int_count, 0) * 0.4770) AS av_v_int_cost,
        SUM(COALESCE(m_int_decline_count, 0) * 0.3595) AS m_int_decline_cost,
        SUM(COALESCE(v_int_decline_count, 0) * 0.3570) AS v_int_decline_cost,
        SUM(COALESCE(dom_decline_count, 0) * 0.0890) AS dom_decline_cost,
        SUM(COALESCE(m_int_reversal_count, 0) * 0.7190) AS m_int_reversal_cost,
        SUM(COALESCE(v_int_reversal_count, 0) * 0.7140) AS v_int_reversal_cost,
        SUM(COALESCE(dom_reversal_count, 0) * 0.0890) AS dom_reversal_cost,
        SUM(COALESCE(m_int_refund_count, 0) * 0.4845) AS m_int_refund_cost,
        SUM(COALESCE(v_int_refund_count, 0) * 0.4770) AS v_int_refund_cost,
        SUM(COALESCE(dom_refund_count, 0) * 0.1090) AS dom_refund_cost,
        SUM(COALESCE(active_card_count, 0) * 0.1000) AS active_card_cost,
        SUM(COALESCE(cost_fixed_fee, 0)) AS fixed_fee_cost
    FROM dws.dws_bb_card_finance_daily_p bb
    CROSS JOIN params p
    WHERE bb.delete_time IS NULL
      AND bb.report_date >= p.start_date
      AND bb.report_date < p.end_date
),
bb_unpivot AS (
    SELECT channel, 'm_dom_auth_cost' AS cost_item, m_dom_auth_cost AS cost_amount FROM bb_detail
    UNION ALL SELECT channel, 'av_m_dom_cost', av_m_dom_cost FROM bb_detail
    UNION ALL SELECT channel, 'm_int_auth_cost', m_int_auth_cost FROM bb_detail
    UNION ALL SELECT channel, 'av_m_int_cost', av_m_int_cost FROM bb_detail
    UNION ALL SELECT channel, 'v_dom_auth_cost', v_dom_auth_cost FROM bb_detail
    UNION ALL SELECT channel, 'av_v_dom_cost', av_v_dom_cost FROM bb_detail
    UNION ALL SELECT channel, 'v_int_auth_cost', v_int_auth_cost FROM bb_detail
    UNION ALL SELECT channel, 'av_v_int_cost', av_v_int_cost FROM bb_detail
    UNION ALL SELECT channel, 'm_int_decline_cost', m_int_decline_cost FROM bb_detail
    UNION ALL SELECT channel, 'v_int_decline_cost', v_int_decline_cost FROM bb_detail
    UNION ALL SELECT channel, 'dom_decline_cost', dom_decline_cost FROM bb_detail
    UNION ALL SELECT channel, 'm_int_reversal_cost', m_int_reversal_cost FROM bb_detail
    UNION ALL SELECT channel, 'v_int_reversal_cost', v_int_reversal_cost FROM bb_detail
    UNION ALL SELECT channel, 'dom_reversal_cost', dom_reversal_cost FROM bb_detail
    UNION ALL SELECT channel, 'm_int_refund_cost', m_int_refund_cost FROM bb_detail
    UNION ALL SELECT channel, 'v_int_refund_cost', v_int_refund_cost FROM bb_detail
    UNION ALL SELECT channel, 'dom_refund_cost', dom_refund_cost FROM bb_detail
    UNION ALL SELECT channel, 'active_card_cost', active_card_cost FROM bb_detail
    UNION ALL SELECT channel, 'fixed_fee_cost', fixed_fee_cost FROM bb_detail
),
qi_detail AS (
    SELECT
        'QI' AS channel,
        SUM(COALESCE(cost_reimbursement_vol, 0)) AS cost_reimbursement_cost,
        SUM(COALESCE(cost_service_vol, 0)) AS cost_service_cost,
        SUM(COALESCE(cost_acs_regular_count, 0)) AS cost_acs_regular_cost,
        SUM(COALESCE(cost_acs_vip_count, 0)) AS cost_acs_vip_cost,
        SUM(COALESCE(cost_vrm_count, 0)) AS cost_vrm_cost,
        SUM(COALESCE(cost_fixed_fee, 0)) AS fixed_fee_cost
    FROM dws.dws_qi_card_finance_daily_p qi
    CROSS JOIN params p
    WHERE qi.delete_time IS NULL
      AND qi.report_date >= p.start_date
      AND qi.report_date < p.end_date
),
qi_unpivot AS (
    SELECT channel, 'cost_reimbursement_cost' AS cost_item, cost_reimbursement_cost AS cost_amount FROM qi_detail
    UNION ALL SELECT channel, 'cost_service_cost', cost_service_cost FROM qi_detail
    UNION ALL SELECT channel, 'cost_acs_regular_cost', cost_acs_regular_cost FROM qi_detail
    UNION ALL SELECT channel, 'cost_acs_vip_cost', cost_acs_vip_cost FROM qi_detail
    UNION ALL SELECT channel, 'cost_vrm_cost', cost_vrm_cost FROM qi_detail
    UNION ALL SELECT channel, 'fixed_fee_cost', fixed_fee_cost FROM qi_detail
),
result_detail AS (
    SELECT
        channel,
        cost_item,
        CAST(COALESCE(cost_amount, 0) AS NUMERIC(20, 4)) AS cost_amount
    FROM bb_unpivot

    UNION ALL

    SELECT
        channel,
        cost_item,
        CAST(COALESCE(cost_amount, 0) AS NUMERIC(20, 4)) AS cost_amount
    FROM qi_unpivot

    UNION ALL

    SELECT
        channel,
        'TOTAL' AS cost_item,
        CAST(COALESCE(SUM(cost_amount), 0) AS NUMERIC(20, 4)) AS cost_amount
    FROM (
        SELECT channel, cost_amount FROM bb_unpivot
        UNION ALL
        SELECT channel, cost_amount FROM qi_unpivot
    ) detail_total
    GROUP BY channel
)
SELECT
    channel,
    cost_item,
    cost_amount
FROM result_detail
ORDER BY
    CASE channel WHEN 'BB' THEN 1 WHEN 'QI' THEN 2 ELSE 99 END,
    CASE cost_item WHEN 'TOTAL' THEN 999 ELSE 1 END,
    cost_item;
