ROLLBACK;

UPDATE dws.dws_bb_card_finance_daily_v2_p
SET cashback_rate = 0.021195,
    cashback_income = CAST(COALESCE(bb_channel_cashback_comm, 0) * 0.021195 AS NUMERIC(20, 4)),
    update_time = NOW()
WHERE delete_time IS NULL
  AND report_date >= DATE '2026-01-01'
  AND report_date <  DATE '2026-09-01';


SELECT
    TO_CHAR(report_date, 'YYYY-MM') AS report_month,
    CAST(SUM(COALESCE(bb_channel_cashback_comm, 0)) AS NUMERIC(20, 4)) AS bb_channel_cashback_base,
    CAST(SUM(COALESCE(cashback_income, 0)) AS NUMERIC(20, 4)) AS bb_cashback_income
FROM dws.dws_bb_card_finance_daily_v2_p
WHERE delete_time IS NULL
  AND report_date >= DATE '2026-01-01'
  AND report_date <  DATE '2026-09-01'
GROUP BY TO_CHAR(report_date, 'YYYY-MM')
ORDER BY report_month;


SELECT
    TO_CHAR(report_date, 'YYYY-MM') AS report_month,
    SUM(bb_channel_cashback_comm) AS bb_channel_cashback_base,
    SUM(cashback_income) AS old_cashback_income,
    SUM(bb_channel_cashback_comm * 0.021195) AS new_cashback_income
FROM dws.dws_bb_card_finance_daily_v2_p
WHERE delete_time IS NULL
  AND report_date >= DATE '2026-01-01'
  AND report_date <  DATE '2026-08-01'
GROUP BY TO_CHAR(report_date, 'YYYY-MM')
ORDER BY report_month;


WITH params AS (
    SELECT
        DATE '2026-07-01' AS start_date,
        DATE '2026-08-01' AS end_date
)
SELECT
    COUNT(*) AS raw_rows,

    COUNT(*) FILTER (
        WHERE t.business_type IN ('Credit', 'Consumption')
    ) AS business_type_rows,

    COUNT(*) FILTER (
        WHERE t.business_type IN ('Credit', 'Consumption')
          AND t.card_org IN ('Master', 'VISA')
    ) AS card_org_rows,

    COUNT(*) FILTER (
        WHERE t.business_type IN ('Credit', 'Consumption')
          AND t.card_org IN ('Master', 'VISA')
          AND t.transaction_type IN ('authorization.clearing', 'refund.clearing')
    ) AS tx_type_rows,

    COUNT(*) FILTER (
        WHERE t.business_type IN ('Credit', 'Consumption')
          AND t.card_org IN ('Master', 'VISA')
          AND t.transaction_type IN ('authorization.clearing', 'refund.clearing')
          AND t.settlement_match_type = 'card_transaction_id'
    ) AS match_type_rows,

    COUNT(*) FILTER (
        WHERE t.business_type IN ('Credit', 'Consumption')
          AND t.card_org IN ('Master', 'VISA')
          AND t.transaction_type IN ('authorization.clearing', 'refund.clearing')
          AND t.settlement_match_type = 'card_transaction_id'
          AND t.resp_code = 'APPROVE'
    ) AS approve_rows,

    CAST(SUM(CASE
        WHEN t.business_type IN ('Credit', 'Consumption')
         AND t.card_org IN ('Master', 'VISA')
         AND t.transaction_type IN ('authorization.clearing', 'refund.clearing')
         AND t.settlement_match_type = 'card_transaction_id'
         AND t.resp_code = 'APPROVE'
            THEN -COALESCE(t.billing_amount, 0)
        ELSE 0
    END) AS NUMERIC(20, 4)) AS base_before_excluded
FROM dwm.dwm_bb_card_transaction_detail_v2_p t
CROSS JOIN params p
WHERE t.delete_time IS NULL
  AND t.original_completion_time >= p.start_date::timestamp
  AND t.original_completion_time <  p.end_date::timestamp;

SELECT
    TO_CHAR(report_date, 'YYYY-MM') AS report_month,
    CAST(SUM(COALESCE(bb_channel_cashback_comm, 0)) AS NUMERIC(20, 4)) AS bb_channel_cashback_base,
    CAST(SUM(COALESCE(cashback_income, 0)) AS NUMERIC(20, 4)) AS cashback_income,
    CAST(SUM(COALESCE(bb_channel_cashback_comm, 0) * CAST(0.02057316 AS NUMERIC(20, 8))) AS NUMERIC(20, 4)) AS expected_cashback_income
FROM dws.dws_bb_card_finance_daily_v2_p
WHERE delete_time IS NULL
  AND report_date >= DATE '2026-01-01'
  AND report_date <  DATE '2026-08-01'
GROUP BY TO_CHAR(report_date, 'YYYY-MM')
ORDER BY report_month;