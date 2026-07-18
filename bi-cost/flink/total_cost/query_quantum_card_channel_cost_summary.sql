--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-07-16
-- Description:    量子卡 BB / QI / SL 渠道成本总金额查询
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
channel_cost AS (
    SELECT
        'BB' AS channel,
        SUM(
            COALESCE(bb.m_dom_auth_count, 0) * 0.1090
          + COALESCE(bb.m_int_auth_count, 0) * 0.4845
          + COALESCE(bb.v_dom_auth_count, 0) * 0.0725
          + COALESCE(bb.v_int_auth_count, 0) * 0.4700
          + COALESCE(bb.m_int_decline_count, 0) * 0.3595
          + COALESCE(bb.v_int_decline_count, 0) * 0.3570
          + COALESCE(bb.dom_decline_count, 0) * 0.0890
          + COALESCE(bb.m_int_reversal_count, 0) * 0.7190
          + COALESCE(bb.v_int_reversal_count, 0) * 0.7140
          + COALESCE(bb.dom_reversal_count, 0) * 0.1780
          + COALESCE(bb.m_int_refund_count, 0) * 0.4845
          + COALESCE(bb.v_int_refund_count, 0) * 0.4770
          + COALESCE(bb.dom_refund_count, 0) * 0.1090
          + COALESCE(bb.av_m_dom_count, 0) * 0.1090
          + COALESCE(bb.av_m_int_count, 0) * 0.4845
          + COALESCE(bb.av_v_dom_count, 0) * 0.0725
          + COALESCE(bb.av_v_int_count, 0) * 0.4770
          + COALESCE(bb.m_int_decline_count, 0) * 0.3595
          + COALESCE(bb.v_int_decline_count, 0) * 0.3570
          + COALESCE(bb.dom_decline_count, 0) * 0.0890
          + COALESCE(bb.m_dom_clearing_vol, 0) * -0.0021
          + COALESCE(bb.m_int_clearing_vol, 0) * -0.0111
          + COALESCE(bb.v_dom_clearing_vol, 0) * -0.0016
          + COALESCE(bb.v_int_clearing_vol, 0) * -0.0116
          + COALESCE(bb.active_card_count, 0) * 0.1000
          + COALESCE(bb.cost_fixed_fee, 0)
        ) AS cost_amount
    FROM dws.dws_bb_card_finance_daily_p bb
    CROSS JOIN params p
    WHERE bb.delete_time IS NULL
      AND bb.report_date >= p.start_date
      AND bb.report_date < p.end_date

    UNION ALL

    SELECT
        'QI' AS channel,
        SUM(
            COALESCE(qi.cost_reimbursement_vol, 0)
          + COALESCE(qi.cost_service_vol, 0)
          + COALESCE(qi.cost_acs_regular_count, 0)
          + COALESCE(qi.cost_acs_vip_count, 0)
          + COALESCE(qi.cost_vrm_count, 0)
          + COALESCE(qi.cost_fixed_fee, 0)
        ) AS cost_amount
    FROM dws.dws_qi_card_finance_daily_p qi
    CROSS JOIN params p
    WHERE qi.delete_time IS NULL
      AND qi.report_date >= p.start_date
      AND qi.report_date < p.end_date

    UNION ALL

    SELECT
        'SL' AS channel,
        SUM(COALESCE(sl.cost_fixed_fee, 0)) AS cost_amount
    FROM dws.dws_sl_card_finance_daily_p sl
    CROSS JOIN params p
    WHERE sl.delete_time IS NULL
      AND sl.report_date >= p.start_date
      AND sl.report_date < p.end_date
)
SELECT
    channel,
    CAST(COALESCE(cost_amount, 0) AS NUMERIC(20, 4)) AS cost_amount
FROM channel_cost

UNION ALL

SELECT
    'TOTAL' AS channel,
    CAST(COALESCE(SUM(cost_amount), 0) AS NUMERIC(20, 4)) AS cost_amount
FROM channel_cost
ORDER BY
    CASE channel
        WHEN 'BB' THEN 1
        WHEN 'QI' THEN 2
        WHEN 'SL' THEN 3
        WHEN 'TOTAL' THEN 4
        ELSE 99
    END;
