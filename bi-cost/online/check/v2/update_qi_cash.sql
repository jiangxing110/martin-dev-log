SELECT
    CAST(SUM(COALESCE(rebate_interchange_base_amt, 0)) AS NUMERIC(20, 4)) AS dws_rebate_interchange_base_amt,
    CAST(SUM(COALESCE(rebate_incentive_base_amt, 0)) AS NUMERIC(20, 4)) AS dws_rebate_incentive_base_amt,
    CAST(SUM(
        COALESCE(rebate_interchange_base_amt, 0) * COALESCE(rebate_interchange_rate, 1)
      + COALESCE(rebate_incentive_base_amt, 0) * COALESCE(rebate_incentive_rate, 1)
    ) AS NUMERIC(20, 4)) AS dws_qi_cashback_income
FROM dws.dws_qi_card_finance_daily_v2_p
WHERE delete_time IS NULL
  AND report_date >= DATE '2026-07-01'
  AND report_date <  DATE '2026-08-01';

530277.8708	325138.4218	853277.7519
528952.1761	325138.4218	854090.5979

528452.92717350+312568.648654
