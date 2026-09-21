


WITH params AS (
    SELECT
        DATE '2026-08-01' AS start_date,
        DATE '2026-09-01' AS end_date,
        '95d362d7-56fe-4f50-82cb-f97a51afc263'::varchar AS root_account_id
),
account_scope AS (
    SELECT root_account_id AS account_id
    FROM params

    UNION

    SELECT r.account_id::varchar
    FROM api_account_relation r
    CROSS JOIN params p
    WHERE r.delete_time IS NULL
      AND r.root_id::varchar = p.root_account_id
),
bb_base AS (
    SELECT
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
        COALESCE(SUM(bb.dom_refund_count * 0.1090), 0) AS domestic_refund_fee,

        COALESCE(SUM(bb.dom_decline_count * 0.0890), 0) AS domestic_decline_fee,
        COALESCE(SUM(bb.m_int_decline_count * 0.3595), 0) AS mastercard_international_decline_fee,
        COALESCE(SUM(bb.v_int_decline_count * 0.3570), 0) AS visa_international_decline_fee,
        COALESCE(SUM(bb.ac_m_int_decline_count * 0.3595), 0) AS ac_mastercard_international_decline_fee,
        COALESCE(SUM(bb.ac_v_int_decline_count * 0.3570), 0) AS ac_visa_international_decline_fee,
        COALESCE(SUM(bb.ac_dom_decline_count * 0.0890), 0) AS ac_domestic_decline_fee,

        COALESCE(SUM(bb.m_dom_clearing_vol * 0.0021), 0) AS mastercard_domestic_dollar_volume_fee,
        COALESCE(SUM(bb.m_int_clearing_vol * 0.0111), 0) AS mastercard_international_dollar_volume_fee,
        COALESCE(SUM(bb.v_dom_clearing_vol * 0.0016), 0) AS visa_domestic_dollar_volume_fee,
        COALESCE(SUM(bb.v_int_clearing_vol * 0.0116), 0) AS visa_international_dollar_volume_fee,

        COALESCE(SUM(bb.active_card_count * 0.1), 0) AS active_card_account_fee,
        COALESCE(SUM(bb.volume_fee_cost), 0) AS volume_fee_cost,
        COALESCE(SUM(bb.cost_fixed_fee), 0) AS fixed_fee
    FROM dws.dws_bb_card_finance_daily_v2_p bb
    JOIN account_scope s
      ON s.account_id = bb.account_id::varchar
    CROSS JOIN params p
    WHERE bb.delete_time IS NULL
      AND bb.report_date >= p.start_date
      AND bb.report_date < p.end_date
),
bb_cost_item AS (
    SELECT 1 AS sort_no, 'Mastercard Domestic Count Fee' AS cost_item, mastercard_domestic_count_fee AS cost_amount FROM bb_base
    UNION ALL SELECT 2, 'Mastercard International Count Fee', mastercard_international_count_fee FROM bb_base
    UNION ALL SELECT 3, 'VISA Domestic Count Fee', visa_domestic_count_fee FROM bb_base
    UNION ALL SELECT 4, 'VISA International Count Fee', visa_international_count_fee FROM bb_base
    UNION ALL SELECT 5, 'AC Mastercard Domestic Count Fee', ac_mastercard_domestic_count_fee FROM bb_base
    UNION ALL SELECT 6, 'AC Mastercard International Count Fee', ac_mastercard_international_count_fee FROM bb_base
    UNION ALL SELECT 7, 'AC VISA Domestic Count Fee', ac_visa_domestic_count_fee FROM bb_base
    UNION ALL SELECT 8, 'AC VISA International Count Fee', ac_visa_international_count_fee FROM bb_base
    UNION ALL SELECT 9, 'Mastercard Domestic Dollar Volume Fee', mastercard_domestic_dollar_volume_fee FROM bb_base
    UNION ALL SELECT 10, 'Mastercard International Dollar Volume Fee', mastercard_international_dollar_volume_fee FROM bb_base
    UNION ALL SELECT 11, 'Visa Domestic Dollar Volume Fee', visa_domestic_dollar_volume_fee FROM bb_base
    UNION ALL SELECT 12, 'Visa International Dollar Volume Fee', visa_international_dollar_volume_fee FROM bb_base
    UNION ALL SELECT 13, 'Mastercard International Reversal Fee', mastercard_international_reversal_fee FROM bb_base
    UNION ALL SELECT 14, 'Visa International Reversal Fee', visa_international_reversal_fee FROM bb_base
    UNION ALL SELECT 15, 'Domestic Reversal Fee', domestic_reversal_fee FROM bb_base
    UNION ALL SELECT 16, 'Mastercard International Refund Fee', mastercard_international_refund_fee FROM bb_base
    UNION ALL SELECT 17, 'VISA International Refund Fee', visa_international_refund_fee FROM bb_base
    UNION ALL SELECT 18, 'Domestic Refund Fee', domestic_refund_fee FROM bb_base
    UNION ALL SELECT 19, 'Mastercard International Decline Fee', mastercard_international_decline_fee FROM bb_base
    UNION ALL SELECT 20, 'Visa International Decline Fee', visa_international_decline_fee FROM bb_base
    UNION ALL SELECT 21, 'Domestic Decline Fee', domestic_decline_fee FROM bb_base
    UNION ALL SELECT 22, 'AC Mastercard International Decline Fee', ac_mastercard_international_decline_fee FROM bb_base
    UNION ALL SELECT 23, 'AC Visa International Decline Fee', ac_visa_international_decline_fee FROM bb_base
    UNION ALL SELECT 24, 'AC Domestic Decline Fee', ac_domestic_decline_fee FROM bb_base
    UNION ALL SELECT 25, 'Active Card Account Fee', active_card_account_fee FROM bb_base
    UNION ALL SELECT 26, 'Volume Fee Cost', volume_fee_cost FROM bb_base
    UNION ALL SELECT 27, 'Fixed Fee', fixed_fee FROM bb_base
),
result_detail AS (
    SELECT
        sort_no,
        cost_item,
        CAST(COALESCE(cost_amount, 0) AS numeric(20, 4)) AS cost_amount
    FROM bb_cost_item

    UNION ALL

    SELECT
        999,
        'TOTAL',
        CAST(COALESCE(SUM(cost_amount), 0) AS numeric(20, 4))
    FROM bb_cost_item
)
SELECT
    cost_item,
    cost_amount
FROM result_detail
ORDER BY sort_no;