--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-10
-- Description:    按 params.start_date/end_date 删除 BB/QI DWM + DWS 数据
-- Notes:
--   1. 执行前先停止相关 BB/QI DWM、DWS CDC/编排任务，避免删除后被任务写回。
--   2. 删除窗口: [params.start_date, params.end_date)。
--   3. BB DWS 会删除普通行、ACTIVE_CARD_ACCOUNT_FEE、CHANNEL_FIXED_FEE。
--   4. QI DWS 会删除普通行、CHANNEL_FIXED_FEE。
--   5. BB transaction DWM 按 transaction_time/original_completion_time/settlement_post_date 三个归月字段删除。
-- Usage:
--   1. 修改 params 中的 start_date / end_date。
--   2. end_date 使用左闭右开，不包含当天。
--********************************************************************--

DROP VIEW IF EXISTS params;

CREATE TEMPORARY VIEW params AS
SELECT
    DATE '2026-07-01' AS start_date,
    DATE '2026-09-01' AS end_date;

-- =========================
-- 1. 删除前检查
-- =========================
SELECT
    'dwm.dwm_bb_card_transaction_detail_v2_p' AS table_name,
    COUNT(*) AS row_count
FROM dwm.dwm_bb_card_transaction_detail_v2_p
CROSS JOIN params p
WHERE (
        transaction_time >= CAST(p.start_date AS TIMESTAMP(6))
    AND transaction_time <  CAST(p.end_date AS TIMESTAMP(6))
)
OR (
        original_completion_time >= CAST(p.start_date AS TIMESTAMP(6))
    AND original_completion_time <  CAST(p.end_date AS TIMESTAMP(6))
)
OR (
        settlement_post_date >= CAST(p.start_date AS TIMESTAMP(6))
    AND settlement_post_date <  CAST(p.end_date AS TIMESTAMP(6))
);

SELECT
    'dwm.dwm_bb_card_auth_detail_v2_p' AS table_name,
    COUNT(*) AS row_count
FROM dwm.dwm_bb_card_auth_detail_v2_p
CROSS JOIN params p
WHERE auth_time >= CAST(p.start_date AS TIMESTAMP(6))
  AND auth_time <  CAST(p.end_date AS TIMESTAMP(6));

SELECT
    'dwm.dwm_qi_card_transaction_detail_v2_p' AS table_name,
    COUNT(*) AS row_count
FROM dwm.dwm_qi_card_transaction_detail_v2_p
CROSS JOIN params p
WHERE transaction_time >= CAST(p.start_date AS TIMESTAMP(6))
  AND transaction_time <  CAST(p.end_date AS TIMESTAMP(6));

SELECT
    'dws.dws_bb_card_finance_daily_v2_p' AS table_name,
    COALESCE(special_fee_type, 'NORMAL') AS special_fee_type,
    COUNT(*) AS row_count
FROM dws.dws_bb_card_finance_daily_v2_p
CROSS JOIN params p
WHERE report_date >= p.start_date
  AND report_date <  p.end_date
GROUP BY COALESCE(special_fee_type, 'NORMAL')
ORDER BY special_fee_type;

SELECT
    'dws.dws_qi_card_finance_daily_v2_p' AS table_name,
    COALESCE(special_fee_type, 'NORMAL') AS special_fee_type,
    COUNT(*) AS row_count
FROM dws.dws_qi_card_finance_daily_v2_p
CROSS JOIN params p
WHERE report_date >= p.start_date
  AND report_date <  p.end_date
GROUP BY COALESCE(special_fee_type, 'NORMAL')
ORDER BY special_fee_type;

-- =========================
-- 2. 正式删除
-- =========================
BEGIN;

DELETE FROM dwm.dwm_bb_card_auth_detail_v2_p target
USING params p
WHERE target.auth_time >= CAST(p.start_date AS TIMESTAMP(6))
  AND target.auth_time <  CAST(p.end_date AS TIMESTAMP(6));

DELETE FROM dwm.dwm_bb_card_transaction_detail_v2_p target
USING params p
WHERE (
        target.transaction_time >= CAST(p.start_date AS TIMESTAMP(6))
    AND target.transaction_time <  CAST(p.end_date AS TIMESTAMP(6))
)
OR (
        target.original_completion_time >= CAST(p.start_date AS TIMESTAMP(6))
    AND target.original_completion_time <  CAST(p.end_date AS TIMESTAMP(6))
)
OR (
        target.settlement_post_date >= CAST(p.start_date AS TIMESTAMP(6))
    AND target.settlement_post_date <  CAST(p.end_date AS TIMESTAMP(6))
);

DELETE FROM dwm.dwm_qi_card_transaction_detail_v2_p target
USING params p
WHERE target.transaction_time >= CAST(p.start_date AS TIMESTAMP(6))
  AND target.transaction_time <  CAST(p.end_date AS TIMESTAMP(6));

DELETE FROM dws.dws_bb_card_finance_daily_v2_p target
USING params p
WHERE target.report_date >= p.start_date
  AND target.report_date <  p.end_date;

DELETE FROM dws.dws_qi_card_finance_daily_v2_p target
USING params p
WHERE target.report_date >= p.start_date
  AND target.report_date <  p.end_date;

COMMIT;

-- =========================
-- 3. 删除后复查
-- =========================
SELECT
    'dwm.dwm_bb_card_transaction_detail_v2_p' AS table_name,
    COUNT(*) AS remaining_count
FROM dwm.dwm_bb_card_transaction_detail_v2_p
CROSS JOIN params p
WHERE (
        transaction_time >= CAST(p.start_date AS TIMESTAMP(6))
    AND transaction_time <  CAST(p.end_date AS TIMESTAMP(6))
)
OR (
        original_completion_time >= CAST(p.start_date AS TIMESTAMP(6))
    AND original_completion_time <  CAST(p.end_date AS TIMESTAMP(6))
)
OR (
        settlement_post_date >= CAST(p.start_date AS TIMESTAMP(6))
    AND settlement_post_date <  CAST(p.end_date AS TIMESTAMP(6))
);

SELECT
    'dwm.dwm_bb_card_auth_detail_v2_p' AS table_name,
    COUNT(*) AS remaining_count
FROM dwm.dwm_bb_card_auth_detail_v2_p
CROSS JOIN params p
WHERE auth_time >= CAST(p.start_date AS TIMESTAMP(6))
  AND auth_time <  CAST(p.end_date AS TIMESTAMP(6));

SELECT
    'dwm.dwm_qi_card_transaction_detail_v2_p' AS table_name,
    COUNT(*) AS remaining_count
FROM dwm.dwm_qi_card_transaction_detail_v2_p
CROSS JOIN params p
WHERE transaction_time >= CAST(p.start_date AS TIMESTAMP(6))
  AND transaction_time <  CAST(p.end_date AS TIMESTAMP(6));

SELECT
    'dws.dws_bb_card_finance_daily_v2_p' AS table_name,
    COUNT(*) AS remaining_count
FROM dws.dws_bb_card_finance_daily_v2_p
CROSS JOIN params p
WHERE report_date >= p.start_date
  AND report_date <  p.end_date;

SELECT
    'dws.dws_qi_card_finance_daily_v2_p' AS table_name,
    COUNT(*) AS remaining_count
FROM dws.dws_qi_card_finance_daily_v2_p
CROSS JOIN params p
WHERE report_date >= p.start_date
  AND report_date <  p.end_date;

DROP VIEW IF EXISTS params;
