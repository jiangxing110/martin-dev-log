--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-08-18 00:00:00
-- Description:    按 BB 实际渠道返现及 DW 实际 cashback base
--                 自动反推月度 cashback_rate，并更新 cashback_income
--
-- Notes:
--   1. 月度基数 = SUM(bb_channel_cashback_comm)
--   2. cashback_rate = BB实际渠道返现 / 月度基数
--   3. cashback_rate 保留 8 位小数
--   4. cashback_income = bb_channel_cashback_comm * cashback_rate
--   5. 不再手工维护 cashback_rate，只维护 BB 实际返现
--********************************************************************--

BEGIN;

-- ============================================================
-- 1. 更新前预览：根据当前真实 base 自动计算 cashback_rate
-- ============================================================
WITH actual_month AS (
    SELECT *
    FROM (
        VALUES
            (DATE '2026-01-01', CAST(394407 AS NUMERIC(20, 4))),
            (DATE '2026-02-01', CAST(327341 AS NUMERIC(20, 4))),
            (DATE '2026-03-01', CAST(377910 AS NUMERIC(20, 4))),
            (DATE '2026-04-01', CAST(339556 AS NUMERIC(20, 4))),
            (DATE '2026-05-01', CAST(352991 AS NUMERIC(20, 4))),
            (DATE '2026-06-01', CAST(332480 AS NUMERIC(20, 4))),
            (DATE '2026-07-01', CAST(359663 AS NUMERIC(20, 4)))
    ) AS t(report_month, actual_cashback_income)
),

monthly_base AS (
    SELECT
        DATE_TRUNC('month', report_date)::date AS report_month,

        CAST(
            SUM(COALESCE(bb_channel_cashback_comm, 0))
            AS NUMERIC(20, 4)
        ) AS bb_channel_cashback_base,

        CAST(
            SUM(COALESCE(cashback_income, 0))
            AS NUMERIC(20, 4)
        ) AS old_cashback_income

    FROM dws.dws_bb_card_finance_daily_v2_p
    WHERE delete_time IS NULL
      AND report_date >= DATE '2026-01-01'
      AND report_date <  DATE '2026-08-01'
    GROUP BY
        DATE_TRUNC('month', report_date)::date
),

monthly_rate AS (
    SELECT
        a.report_month,
        b.bb_channel_cashback_base,
        b.old_cashback_income,
        a.actual_cashback_income,

        CAST(
            ROUND(
                a.actual_cashback_income
                / NULLIF(b.bb_channel_cashback_base, 0),
                8
            )
            AS NUMERIC(20, 8)
        ) AS cashback_rate

    FROM actual_month a
    LEFT JOIN monthly_base b
        ON b.report_month = a.report_month
)

SELECT
    TO_CHAR(report_month, 'YYYY-MM') AS report_month,

    bb_channel_cashback_base,

    old_cashback_income,

    actual_cashback_income,

    cashback_rate,

    CAST(
        bb_channel_cashback_base * cashback_rate
        AS NUMERIC(20, 4)
    ) AS expected_cashback_income,

    CAST(
        bb_channel_cashback_base * cashback_rate
        - actual_cashback_income
        AS NUMERIC(20, 4)
    ) AS diff_with_actual

FROM monthly_rate
ORDER BY report_month;


-- ============================================================
-- 2. 正式更新
-- ============================================================
WITH actual_month AS (
    SELECT *
    FROM (
        VALUES
            (DATE '2026-01-01', CAST(394407 AS NUMERIC(20, 4))),
            (DATE '2026-02-01', CAST(327341 AS NUMERIC(20, 4))),
            (DATE '2026-03-01', CAST(377910 AS NUMERIC(20, 4))),
            (DATE '2026-04-01', CAST(339556 AS NUMERIC(20, 4))),
            (DATE '2026-05-01', CAST(352991 AS NUMERIC(20, 4))),
            (DATE '2026-06-01', CAST(332480 AS NUMERIC(20, 4))),
            (DATE '2026-07-01', CAST(359663 AS NUMERIC(20, 4)))
    ) AS t(report_month, actual_cashback_income)
),

monthly_base AS (
    SELECT
        DATE_TRUNC('month', report_date)::date AS report_month,

        SUM(
            COALESCE(bb_channel_cashback_comm, 0)
        )::NUMERIC AS bb_channel_cashback_base

    FROM dws.dws_bb_card_finance_daily_v2_p

    WHERE delete_time IS NULL
      AND report_date >= DATE '2026-01-01'
      AND report_date <  DATE '2026-08-01'

    GROUP BY
        DATE_TRUNC('month', report_date)::date
),

monthly_rate AS (
    SELECT
        a.report_month,

        CAST(
            ROUND(
                a.actual_cashback_income
                / NULLIF(b.bb_channel_cashback_base, 0),
                8
            )
            AS NUMERIC(20, 8)
        ) AS cashback_rate

    FROM actual_month a
    INNER JOIN monthly_base b
        ON b.report_month = a.report_month
)

UPDATE dws.dws_bb_card_finance_daily_v2_p target

SET
    cashback_rate = m.cashback_rate,

    cashback_income = CAST(
        COALESCE(target.bb_channel_cashback_comm, 0)
        * m.cashback_rate
        AS NUMERIC(20, 4)
    ),

    update_time = NOW()

FROM monthly_rate m

WHERE target.delete_time IS NULL
  AND target.report_date >= m.report_month
  AND target.report_date <
      (m.report_month + INTERVAL '1 month')::date;


-- ============================================================
-- 3. 更新后校验
-- ============================================================
WITH actual_month AS (
    SELECT *
    FROM (
        VALUES
            (DATE '2026-01-01', CAST(394407 AS NUMERIC(20, 4))),
            (DATE '2026-02-01', CAST(327341 AS NUMERIC(20, 4))),
            (DATE '2026-03-01', CAST(377910 AS NUMERIC(20, 4))),
            (DATE '2026-04-01', CAST(339556 AS NUMERIC(20, 4))),
            (DATE '2026-05-01', CAST(352991 AS NUMERIC(20, 4))),
            (DATE '2026-06-01', CAST(332480 AS NUMERIC(20, 4))),
            (DATE '2026-07-01', CAST(359663 AS NUMERIC(20, 4)))
    ) AS t(report_month, actual_cashback_income)
)

SELECT
    TO_CHAR(a.report_month, 'YYYY-MM') AS report_month,

    CAST(
        SUM(COALESCE(t.bb_channel_cashback_comm, 0))
        AS NUMERIC(20, 4)
    ) AS bb_channel_cashback_base,

    MAX(t.cashback_rate) AS cashback_rate,

    CAST(
        SUM(COALESCE(t.cashback_income, 0))
        AS NUMERIC(20, 4)
    ) AS updated_cashback_income,

    a.actual_cashback_income,

    CAST(
        SUM(COALESCE(t.cashback_income, 0))
        - a.actual_cashback_income
        AS NUMERIC(20, 4)
    ) AS diff_with_actual

FROM actual_month a

LEFT JOIN dws.dws_bb_card_finance_daily_v2_p t
    ON t.delete_time IS NULL
   AND t.report_date >= a.report_month
   AND t.report_date <
       (a.report_month + INTERVAL '1 month')::date

GROUP BY
    a.report_month,
    a.actual_cashback_income

ORDER BY
    a.report_month;


-- 先看最终结果
ROLLBACK;

-- 确认无误后，将上面的 ROLLBACK 改成：
-- COMMIT;