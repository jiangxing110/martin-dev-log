--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-08-17 00:00:00
-- Description:    量子卡 BB V4 渠道成本汇总查询，按月份透视，每月一行展示成本与返现（取 BB Cashback Income）
-- Usage:
--   1. 修改 params 中的 start_date / end_date。
--   2. end_date 使用左闭右开，不包含当天。
--   3. TOTAL 不包含 BB Channel Cashback Base / BB Cashback Income。
--   4. 结果按月份分组，month 取自数据的 report_date，支持跨多月查询。
--********************************************************************--

WITH params AS (
    SELECT
        DATE '2026-05-01' AS start_date,
        DATE '2026-06-01' AS end_date
),
bb_base AS (
    SELECT
        TO_CHAR(bb.report_date, 'YYYY-MM') AS month,
        COALESCE(SUM(bb.m_dom_auth_count * 0.1090), 0) AS mastercard_domestic_count_fee,
        COALESCE(SUM(bb.m_int_auth_count * 0.4845), 0) AS mastercard_international_count_fee,
        COALESCE(SUM(bb.v_dom_auth_count * 0.0725), 0) AS visa_domestic_count_fee,
        COALESCE(SUM(bb.v_int_auth_count * 0.4770), 0) AS visa_international_count_fee,
        COALESCE(SUM(bb.av_m_dom_count * 0.1090), 0) AS ac_mastercard_domestic_count_fee,
        COALESCE(SUM(bb.av_m_int_count * 0.4845), 0) AS ac_mastercard_international_count_fee,
        COALESCE(SUM(bb.av_v_dom_count * 0.0725), 0) AS ac_visa_domestic_count_fee,
        COALESCE(SUM(bb.av_v_int_count * 0.4770), 0) AS ac_visa_international_count_fee,
        COALESCE(SUM(bb.m_int_reversal_count * 0.7190), 0) AS mastercard_international_reversal_fee,
        COALESCE(SUM(bb.v_int_reversal_count * 0.7140), 0) AS visa_international_reversal_fee,
        COALESCE(SUM(bb.dom_reversal_count * 0.1780), 0) AS domestic_reversal_fee,
        COALESCE(SUM(bb.m_int_refund_count * 0.4845), 0) AS mastercard_international_refund_fee,
        COALESCE(SUM(bb.v_int_refund_count * 0.4770), 0) AS visa_international_refund_fee,
        COALESCE(SUM(bb.dom_decline_count * 0.0890), 0) AS domestic_decline_fee,
        COALESCE(SUM(bb.m_dom_clearing_vol * 0.0021), 0) AS mastercard_domestic_dollar_volume_fee,
        COALESCE(SUM(bb.m_int_clearing_vol * 0.0111), 0) AS mastercard_international_dollar_volume_fee,
        COALESCE(SUM(bb.v_dom_clearing_vol * 0.0016), 0) AS visa_domestic_dollar_volume_fee,
        COALESCE(SUM(bb.v_int_clearing_vol * 0.0116), 0) AS visa_international_dollar_volume_fee,
        COALESCE(SUM(bb.m_int_decline_count * 0.3595), 0) AS mastercard_international_decline_fee,
        COALESCE(SUM(bb.v_int_decline_count * 0.3570), 0) AS visa_international_decline_fee,
        COALESCE(SUM(bb.dom_refund_count * 0.1090), 0) AS domestic_refund_fee,
        COALESCE(SUM(bb.ac_m_int_decline_count * 0.3595), 0) AS ac_mastercard_international_decline_fee,
        COALESCE(SUM(bb.ac_v_int_decline_count * 0.3570), 0) AS ac_visa_international_decline_fee,
        COALESCE(SUM(bb.ac_dom_decline_count * 0.0890), 0) AS ac_domestic_decline_fee,
        COALESCE(SUM(bb.active_card_count * 0.1), 0) AS active_card_account_fee,
        COALESCE(SUM(bb.total_net_amount), 0) AS total_net_amount,
        COALESCE(SUM(bb.bb_channel_cashback_comm), 0) AS bb_channel_cashback_comm,
        COALESCE(SUM(bb.cashback_income), 0) AS cashback_income,
        COALESCE(SUM(bb.cost_fixed_fee), 0) AS fixed_fee
    FROM dws.dws_bb_card_finance_daily_v2_p bb
    CROSS JOIN params p
    WHERE bb.delete_time IS NULL
      AND bb.report_date >= p.start_date
      AND bb.report_date < p.end_date
    GROUP BY TO_CHAR(bb.report_date, 'YYYY-MM')
),
bb_detail AS (
    SELECT
        *,
        CASE
            WHEN total_net_amount = 0 THEN 0
            WHEN total_net_amount <= 5000000 THEN total_net_amount * 0.0055
            WHEN total_net_amount <= 10000000 THEN 5000000 * 0.0055 + (total_net_amount - 5000000) * 0.0045
            ELSE 5000000 * 0.0055 + 5000000 * 0.0045 + (total_net_amount - 10000000) * 0.004
        END AS volume_fee_cost
    FROM bb_base
),
bb_total AS (
    SELECT
        month,
        mastercard_domestic_count_fee
        + mastercard_international_count_fee
        + visa_domestic_count_fee
        + visa_international_count_fee
        + ac_mastercard_domestic_count_fee
        + ac_mastercard_international_count_fee
        + ac_visa_domestic_count_fee
        + ac_visa_international_count_fee
        + mastercard_domestic_dollar_volume_fee
        + mastercard_international_dollar_volume_fee
        + visa_domestic_dollar_volume_fee
        + visa_international_dollar_volume_fee
        + mastercard_international_reversal_fee
        + visa_international_reversal_fee
        + domestic_reversal_fee
        + mastercard_international_refund_fee
        + visa_international_refund_fee
        + domestic_refund_fee
        + mastercard_international_decline_fee
        + visa_international_decline_fee
        + domestic_decline_fee
        + ac_mastercard_international_decline_fee
        + ac_visa_international_decline_fee
        + ac_domestic_decline_fee
        + active_card_account_fee
        + volume_fee_cost
        + fixed_fee AS total_cost,
        bb_channel_cashback_comm,
        cashback_income
    FROM bb_detail
)
SELECT
    month,
    CAST(COALESCE(total_cost, 0) AS NUMERIC(20, 4)) AS cost,
    CAST(COALESCE(cashback_income, 0) AS NUMERIC(20, 4)) AS cashback
FROM bb_total
ORDER BY month;
