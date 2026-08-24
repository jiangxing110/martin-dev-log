--********************************************************************--
-- Author: Codex
-- Description: BB V5 成本与渠道实际成本按月差值对比
-- 说明：calculated_cost 不包含 cashback，cost_diff = actual_channel_cost - calculated_cost。
--       calculated_cashback = 月度 cashback base * cashback_rate。
--       cashback_diff = calculated_cashback - actual_cashback。
--********************************************************************--

WITH params AS (
    SELECT
        DATE '2026-01-01' AS start_date,
        DATE '2026-08-01' AS end_date
),
bb_actual_cost AS (
    SELECT *
    FROM (
        VALUES
            ('2026-01', 694143.68::NUMERIC),
            ('2026-02', 528265.38::NUMERIC),
            ('2026-03', 581667.94::NUMERIC),
            ('2026-04', 493871.00::NUMERIC),
            ('2026-05', 458271.00::NUMERIC),
            ('2026-06', 413824.00::NUMERIC),
            ('2026-07', 432056.00::NUMERIC)
    ) AS t(month, actual_channel_cost)
),
bb_actual_cashback AS (
    SELECT *
    FROM (
        VALUES
            ('2026-01', 394407.00::NUMERIC),
            ('2026-02', 327341.00::NUMERIC),
            ('2026-03', 377910.00::NUMERIC),
            ('2026-04', 339556.00::NUMERIC),
            ('2026-05', 352991.00::NUMERIC),
            ('2026-06', 332480.00::NUMERIC),
            ('2026-07', 359663.00::NUMERIC)
    ) AS t(month, actual_cashback)
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
        COALESCE(SUM(bb.volume_fee_cost), 0) AS volume_fee_cost,
        COALESCE(SUM(bb.bb_channel_cashback_comm), 0) AS bb_channel_cashback_comm,
        MAX(bb.cashback_rate) AS cashback_rate,
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
    SELECT *
    FROM bb_base
),
bb_total AS (
    SELECT
        month,
        mastercard_domestic_count_fee + mastercard_international_count_fee
        + visa_domestic_count_fee + visa_international_count_fee
        + ac_mastercard_domestic_count_fee + ac_mastercard_international_count_fee
        + ac_visa_domestic_count_fee + ac_visa_international_count_fee
        + mastercard_domestic_dollar_volume_fee + mastercard_international_dollar_volume_fee
        + visa_domestic_dollar_volume_fee + visa_international_dollar_volume_fee
        + mastercard_international_reversal_fee + visa_international_reversal_fee
        + domestic_reversal_fee + mastercard_international_refund_fee
        + visa_international_refund_fee + domestic_refund_fee
        + mastercard_international_decline_fee + visa_international_decline_fee
        + domestic_decline_fee + ac_mastercard_international_decline_fee
        + ac_visa_international_decline_fee + ac_domestic_decline_fee
        + active_card_account_fee + volume_fee_cost + fixed_fee AS total_cost,
        bb_channel_cashback_comm,
        cashback_rate,
        cashback_income
    FROM bb_detail
)
SELECT
    t.month,
    CAST(COALESCE(t.total_cost, 0) AS NUMERIC(20, 4)) AS calculated_cost,
    CAST(COALESCE(a.actual_channel_cost, 0) AS NUMERIC(20, 4)) AS actual_channel_cost,
    CAST(COALESCE(a.actual_channel_cost, 0) - COALESCE(t.total_cost, 0) AS NUMERIC(20, 4)) AS cost_diff,
    CAST(
        COALESCE(t.bb_channel_cashback_comm, 0) * COALESCE(t.cashback_rate, 0)
        AS NUMERIC(20, 8)
    ) AS calculated_cashback,
    CAST(COALESCE(c.actual_cashback, 0) AS NUMERIC(20, 8)) AS actual_cashback,
    CAST(
        COALESCE(t.bb_channel_cashback_comm, 0) * COALESCE(t.cashback_rate, 0)
        - COALESCE(c.actual_cashback, 0)
        AS NUMERIC(20, 4)
    ) AS cashback_diff
FROM bb_total t
LEFT JOIN bb_actual_cost a ON a.month = t.month
LEFT JOIN bb_actual_cashback c ON c.month = t.month
ORDER BY t.month;
