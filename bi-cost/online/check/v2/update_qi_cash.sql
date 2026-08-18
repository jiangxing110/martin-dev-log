--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-08-17 00:00:00
-- Description:    按 QI 实际 Interchange Income 反推 rebate_interchange_rate，并更新 DWS QI
-- Notes:
--   1. rebate_interchange_rate = 实际 interchange_income / rebate_interchange_base_amt。
--   2. 当前只更新 dws.dws_qi_card_finance_daily_v2_p.rebate_interchange_rate。
--   3. 对应 bi_month_tag: QI_REBATE_INTERCHANGE_RATE。
--   4. Incentive rate 不在本脚本调整范围内。
--********************************************************************--

ROLLBACK;

-- =========================
-- 1. 月度 Interchange rate 预览
-- =========================
WITH monthly_rate AS (
    SELECT *
    FROM (
        VALUES
            (DATE '2026-01-01', CAST(0.99515367 AS NUMERIC(20, 8)), CAST(1211352 AS NUMERIC(20, 4))),
            (DATE '2026-02-01', CAST(1.00409524 AS NUMERIC(20, 8)), CAST(544674 AS NUMERIC(20, 4))),
            (DATE '2026-03-01', CAST(0.99644608 AS NUMERIC(20, 8)), CAST(580906 AS NUMERIC(20, 4))),
            (DATE '2026-04-01', CAST(0.99655666 AS NUMERIC(20, 8)), CAST(548641 AS NUMERIC(20, 4))),
            (DATE '2026-05-01', CAST(0.99477075 AS NUMERIC(20, 8)), CAST(456436 AS NUMERIC(20, 4))),
            (DATE '2026-06-01', CAST(0.99128878 AS NUMERIC(20, 8)), CAST(507538 AS NUMERIC(20, 4))),
            (DATE '2026-07-01', CAST(0.99804844 AS NUMERIC(20, 8)), CAST(529243 AS NUMERIC(20, 4)))
    ) AS t(report_month, rebate_interchange_rate, actual_interchange_income)
),
dws_month AS (
    SELECT
        DATE_TRUNC('month', report_date)::date AS report_month,
        CAST(SUM(COALESCE(rebate_interchange_base_amt, 0)) AS NUMERIC(20, 4)) AS interchange_part,
        CAST(SUM(COALESCE(rebate_interchange_base_amt, 0) * COALESCE(rebate_interchange_rate, 1)) AS NUMERIC(20, 4)) AS old_interchange_income
    FROM dws.dws_qi_card_finance_daily_v2_p
    WHERE delete_time IS NULL
      AND report_date >= DATE '2026-01-01'
      AND report_date <  DATE '2026-08-01'
    GROUP BY DATE_TRUNC('month', report_date)::date
)
SELECT
    TO_CHAR(m.report_month, 'YYYY-MM') AS report_month,
    d.interchange_part,
    d.old_interchange_income,
    m.rebate_interchange_rate,
    CAST(d.interchange_part * m.rebate_interchange_rate AS NUMERIC(20, 4)) AS new_interchange_income,
    m.actual_interchange_income,
    CAST(d.interchange_part * m.rebate_interchange_rate - m.actual_interchange_income AS NUMERIC(20, 4)) AS diff_with_actual
FROM monthly_rate m
LEFT JOIN dws_month d
    ON d.report_month = m.report_month
ORDER BY m.report_month;

-- =========================
-- 2. 更新 bi_month_tag
-- =========================
WITH monthly_rate AS (
    SELECT *
    FROM (
        VALUES
            ('202607300108', CAST(0.99515367 AS NUMERIC(20, 8))),
            ('202607300208', CAST(1.00409524 AS NUMERIC(20, 8))),
            ('202607300308', CAST(0.99644608 AS NUMERIC(20, 8))),
            ('202607300408', CAST(0.99655666 AS NUMERIC(20, 8))),
            ('202607300508', CAST(0.99477075 AS NUMERIC(20, 8))),
            ('202607300608', CAST(0.99128878 AS NUMERIC(20, 8))),
            ('202608100708', CAST(0.99804844 AS NUMERIC(20, 8)))
    ) AS t(id, rebate_interchange_rate)
)
UPDATE ods.ods_bi_month_tag target
SET amount = m.rebate_interchange_rate,
    update_time = NOW()
FROM monthly_rate m
WHERE target.id::text = m.id
  AND target.provider = 'IQ'
  AND target.tag = 'QI_REBATE_INTERCHANGE_RATE'
  AND target.delete_time IS NULL;

-- =========================
-- 3. 正式更新 DWS
-- =========================
WITH monthly_rate AS (
    SELECT *
    FROM (
        VALUES
            (DATE '2026-01-01', CAST(0.99515367 AS NUMERIC(20, 8))),
            (DATE '2026-02-01', CAST(1.00409524 AS NUMERIC(20, 8))),
            (DATE '2026-03-01', CAST(0.99644608 AS NUMERIC(20, 8))),
            (DATE '2026-04-01', CAST(0.99655666 AS NUMERIC(20, 8))),
            (DATE '2026-05-01', CAST(0.99477075 AS NUMERIC(20, 8))),
            (DATE '2026-06-01', CAST(0.99128878 AS NUMERIC(20, 8))),
            (DATE '2026-07-01', CAST(0.99804844 AS NUMERIC(20, 8)))
    ) AS t(report_month, rebate_interchange_rate)
)
UPDATE dws.dws_qi_card_finance_daily_v2_p target
SET rebate_interchange_rate = m.rebate_interchange_rate,
    update_time = NOW()
FROM monthly_rate m
WHERE target.delete_time IS NULL
  AND target.report_date >= m.report_month
  AND target.report_date <  (m.report_month + INTERVAL '1 month')::date;

-- =========================
-- 4. 更新后校验
-- =========================
WITH monthly_rate AS (
    SELECT *
    FROM (
        VALUES
            (DATE '2026-01-01', CAST(0.99515367 AS NUMERIC(20, 8)), CAST(1211352 AS NUMERIC(20, 4))),
            (DATE '2026-02-01', CAST(1.00409524 AS NUMERIC(20, 8)), CAST(544674 AS NUMERIC(20, 4))),
            (DATE '2026-03-01', CAST(0.99644608 AS NUMERIC(20, 8)), CAST(580906 AS NUMERIC(20, 4))),
            (DATE '2026-04-01', CAST(0.99655666 AS NUMERIC(20, 8)), CAST(548641 AS NUMERIC(20, 4))),
            (DATE '2026-05-01', CAST(0.99477075 AS NUMERIC(20, 8)), CAST(456436 AS NUMERIC(20, 4))),
            (DATE '2026-06-01', CAST(0.99128878 AS NUMERIC(20, 8)), CAST(507538 AS NUMERIC(20, 4))),
            (DATE '2026-07-01', CAST(0.99804844 AS NUMERIC(20, 8)), CAST(529243 AS NUMERIC(20, 4)))
    ) AS t(report_month, rebate_interchange_rate, actual_interchange_income)
)
SELECT
    TO_CHAR(m.report_month, 'YYYY-MM') AS report_month,
    CAST(SUM(COALESCE(t.rebate_interchange_base_amt, 0)) AS NUMERIC(20, 4)) AS interchange_part,
    m.rebate_interchange_rate,
    CAST(SUM(COALESCE(t.rebate_interchange_base_amt, 0) * COALESCE(t.rebate_interchange_rate, 1)) AS NUMERIC(20, 4)) AS updated_interchange_income,
    m.actual_interchange_income,
    CAST(SUM(COALESCE(t.rebate_interchange_base_amt, 0) * COALESCE(t.rebate_interchange_rate, 1)) - m.actual_interchange_income AS NUMERIC(20, 4)) AS diff_with_actual,
    CAST(SUM(COALESCE(t.rebate_incentive_base_amt, 0) * COALESCE(t.rebate_incentive_rate, 1)) AS NUMERIC(20, 4)) AS incentive_income,
    CAST(SUM(
        COALESCE(t.rebate_interchange_base_amt, 0) * COALESCE(t.rebate_interchange_rate, 1)
      + COALESCE(t.rebate_incentive_base_amt, 0) * COALESCE(t.rebate_incentive_rate, 1)
    ) AS NUMERIC(20, 4)) AS qi_cashback_income
FROM monthly_rate m
LEFT JOIN dws.dws_qi_card_finance_daily_v2_p t
    ON t.delete_time IS NULL
   AND t.report_date >= m.report_month
   AND t.report_date <  (m.report_month + INTERVAL '1 month')::date
GROUP BY
    m.report_month,
    m.rebate_interchange_rate,
    m.actual_interchange_income
ORDER BY m.report_month;

-- =========================
-- 5. 原始汇总查询
-- =========================
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
