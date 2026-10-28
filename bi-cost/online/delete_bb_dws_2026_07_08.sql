--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-10-28 10:42:49
-- Description:    删除 BB DWS 2026-07、2026-08 数据
-- Notes:
--   1. 仅删除 dws.dws_bb_card_finance_daily_v2_p，不涉及 DWM 或 QI。
--   2. 删除窗口为 [2026-07-01, 2026-09-01)，包含 7、8 月全部普通行和特殊费用行。
--   3. 执行前先暂停 BB DWS CDC/批处理任务，避免数据被并发写回。
--********************************************************************--

BEGIN;

-- 删除前确认目标行数。
SELECT
    COALESCE(special_fee_type, 'NORMAL') AS special_fee_type,
    COUNT(*) AS row_count
FROM dws.dws_bb_card_finance_daily_v2_p
WHERE report_date >= DATE '2026-07-01'
  AND report_date <  DATE '2026-09-01'
GROUP BY COALESCE(special_fee_type, 'NORMAL')
ORDER BY special_fee_type;

-- 仅删除 BB DWS 的 7、8 月数据。
DELETE FROM dws.dws_bb_card_finance_daily_v2_p
WHERE report_date >= DATE '2026-07-01'
  AND report_date <  DATE '2026-09-01';

-- 删除后应返回 0。
SELECT COUNT(*) AS remaining_count
FROM dws.dws_bb_card_finance_daily_v2_p
WHERE report_date >= DATE '2026-07-01'
  AND report_date <  DATE '2026-09-01';

COMMIT;
