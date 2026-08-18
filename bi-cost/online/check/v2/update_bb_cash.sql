--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-08-17 00:00:00
-- Description:    按 BB 实际渠道返现反推月度 cashback_rate，并更新 DWS BB cashback_income
-- Notes:
--   1. cashback_rate = 实际渠道返现 / bb_channel_cashback_comm。
--   2. cashback_rate 保留 8 位小数，对齐 dws.dws_bb_card_finance_daily_v2_p.cashback_rate。
--   3. cashback_income 按 bb_channel_cashback_comm * cashback_rate 重新计算。
--   4. 执行前建议先跑 preview 查询确认 base 与实际返现。
--********************************************************************--

ROLLBACK;

-- =========================
-- 1. 月度 rate 预览
-- =========================
WITH monthly_rate AS (
    SELECT *
    FROM (
        VALUES
            (DATE '2026-01-01', CAST(0.02208623 AS NUMERIC(20, 8)), CAST(394407 AS NUMERIC(20, 4))),
            (DATE '2026-02-01', CAST(0.02203995 AS NUMERIC(20, 8)), CAST(327341 AS NUMERIC(20, 4))),
            (DATE '2026-03-01', CAST(0.02183594 AS NUMERIC(20, 8)), CAST(377910 AS NUMERIC(20, 4))),
            (DATE '2026-04-01', CAST(0.02161743 AS NUMERIC(20, 8)), CAST(339556 AS NUMERIC(20, 4))),
            (DATE '2026-05-01', CAST(0.02121173 AS NUMERIC(20, 8)), CAST(352991 AS NUMERIC(20, 4))),
            (DATE '2026-06-01', CAST(0.02173632 AS NUMERIC(20, 8)), CAST(332480 AS NUMERIC(20, 4))),
            (DATE '2026-07-01', CAST(0.02057242 AS NUMERIC(20, 8)), CAST(359663 AS NUMERIC(20, 4)))
    ) AS t(report_month, cashback_rate, actual_cashback_income)
),
dws_month AS (
    SELECT
        DATE_TRUNC('month', report_date)::date AS report_month,
        CAST(SUM(COALESCE(bb_channel_cashback_comm, 0)) AS NUMERIC(20, 4)) AS bb_channel_cashback_base,
        CAST(SUM(COALESCE(cashback_income, 0)) AS NUMERIC(20, 4)) AS old_cashback_income
    FROM dws.dws_bb_card_finance_daily_v2_p
    WHERE delete_time IS NULL
      AND report_date >= DATE '2026-01-01'
      AND report_date <  DATE '2026-08-01'
    GROUP BY DATE_TRUNC('month', report_date)::date
)
SELECT
    TO_CHAR(m.report_month, 'YYYY-MM') AS report_month,
    d.bb_channel_cashback_base,
    d.old_cashback_income,
    m.cashback_rate,
    CAST(d.bb_channel_cashback_base * m.cashback_rate AS NUMERIC(20, 4)) AS new_cashback_income,
    m.actual_cashback_income,
    CAST(d.bb_channel_cashback_base * m.cashback_rate - m.actual_cashback_income AS NUMERIC(20, 4)) AS diff_with_actual
FROM monthly_rate m
LEFT JOIN dws_month d
    ON d.report_month = m.report_month
ORDER BY m.report_month;

-- =========================
-- 2. 正式更新
-- =========================
WITH monthly_rate AS (
    SELECT *
    FROM (
        VALUES
            (DATE '2026-01-01', CAST(0.02208623 AS NUMERIC(20, 8))),
            (DATE '2026-02-01', CAST(0.02203995 AS NUMERIC(20, 8))),
            (DATE '2026-03-01', CAST(0.02183594 AS NUMERIC(20, 8))),
            (DATE '2026-04-01', CAST(0.02161743 AS NUMERIC(20, 8))),
            (DATE '2026-05-01', CAST(0.02121173 AS NUMERIC(20, 8))),
            (DATE '2026-06-01', CAST(0.02173632 AS NUMERIC(20, 8))),
            (DATE '2026-07-01', CAST(0.02057242 AS NUMERIC(20, 8)))
    ) AS t(report_month, cashback_rate)
)
UPDATE dws.dws_bb_card_finance_daily_v2_p target
SET cashback_rate = m.cashback_rate,
    cashback_income = CAST(COALESCE(target.bb_channel_cashback_comm, 0) * m.cashback_rate AS NUMERIC(20, 4)),
    update_time = NOW()
FROM monthly_rate m
WHERE target.delete_time IS NULL
  AND target.report_date >= m.report_month
  AND target.report_date <  (m.report_month + INTERVAL '1 month')::date;

-- =========================
-- 3. 更新后校验
-- =========================
WITH monthly_rate AS (
    SELECT *
    FROM (
        VALUES
            (DATE '2026-01-01', CAST(0.02208623 AS NUMERIC(20, 8)), CAST(394407 AS NUMERIC(20, 4))),
            (DATE '2026-02-01', CAST(0.02203995 AS NUMERIC(20, 8)), CAST(327341 AS NUMERIC(20, 4))),
            (DATE '2026-03-01', CAST(0.02183594 AS NUMERIC(20, 8)), CAST(377910 AS NUMERIC(20, 4))),
            (DATE '2026-04-01', CAST(0.02161743 AS NUMERIC(20, 8)), CAST(339556 AS NUMERIC(20, 4))),
            (DATE '2026-05-01', CAST(0.02121173 AS NUMERIC(20, 8)), CAST(352991 AS NUMERIC(20, 4))),
            (DATE '2026-06-01', CAST(0.02173632 AS NUMERIC(20, 8)), CAST(332480 AS NUMERIC(20, 4))),
            (DATE '2026-07-01', CAST(0.02057242 AS NUMERIC(20, 8)), CAST(359663 AS NUMERIC(20, 4)))
    ) AS t(report_month, cashback_rate, actual_cashback_income)
)
SELECT
    TO_CHAR(m.report_month, 'YYYY-MM') AS report_month,
    CAST(SUM(COALESCE(t.bb_channel_cashback_comm, 0)) AS NUMERIC(20, 4)) AS bb_channel_cashback_base,
    m.cashback_rate,
    CAST(SUM(COALESCE(t.cashback_income, 0)) AS NUMERIC(20, 4)) AS updated_cashback_income,
    m.actual_cashback_income,
    CAST(SUM(COALESCE(t.cashback_income, 0)) - m.actual_cashback_income AS NUMERIC(20, 4)) AS diff_with_actual
FROM monthly_rate m
LEFT JOIN dws.dws_bb_card_finance_daily_v2_p t
    ON t.delete_time IS NULL
   AND t.report_date >= m.report_month
   AND t.report_date <  (m.report_month + INTERVAL '1 month')::date
GROUP BY
    m.report_month,
    m.cashback_rate,
    m.actual_cashback_income
ORDER BY m.report_month;
