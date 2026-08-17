SELECT
    TO_CHAR(report_date, 'YYYY-MM') AS report_month,
    CAST(SUM(COALESCE(rebate_interchange_base_amt, 0)) AS NUMERIC(20, 4)) AS interchange_part,
    CAST(SUM(COALESCE(rebate_incentive_base_amt, 0)) AS NUMERIC(20, 4)) AS incentive_part,
    CAST(SUM(COALESCE(rebate_interchange_base_amt, 0) * COALESCE(rebate_interchange_rate, 1)) AS NUMERIC(20, 4)) AS interchange_income,
    CAST(SUM(COALESCE(rebate_incentive_base_amt, 0) * COALESCE(rebate_incentive_rate, 1)) AS NUMERIC(20, 4)) AS incentive_income,
    CAST(SUM(
        COALESCE(rebate_interchange_base_amt, 0) * COALESCE(rebate_interchange_rate, 1)
      + COALESCE(rebate_incentive_base_amt, 0) * COALESCE(rebate_incentive_rate, 1)
    ) AS NUMERIC(20, 4)) AS qi_cashback_income
FROM dws.dws_qi_card_finance_daily_v2_p
WHERE delete_time IS NULL
  AND report_date >= DATE '2026-01-01'
  AND report_date <  DATE '2026-08-01'
GROUP BY TO_CHAR(report_date, 'YYYY-MM')
ORDER BY report_month;