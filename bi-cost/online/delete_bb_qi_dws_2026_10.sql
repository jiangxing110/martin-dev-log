-- Author:         Codex
-- Created Time:   2026-11-06 00:00:00
-- Updated Time:   2026-11-06 00:00:00
-- Description:    删除 BB/QI 2026-10 DWS 成本结果
-- Notes:
--   1. 执行前暂停 BB/QI DWS CDC/批处理任务，避免删除后被并发写回。
--   2. 仅删除 DWS 结果表 2026-10 的普通行和特殊费用行；保留 DWM 交易明细作为回填输入。
--   3. 删除范围为 [2026-10-01, 2026-11-01)，左闭右开。
--   4. 先核对删除前数量，再执行事务中的 DELETE；提交后复查剩余数量应为 0。

BEGIN;

-- 删除前核对 BB / QI 目标月份行数，含特殊费用行。
SELECT
    'dws.dws_bb_card_finance_daily_v2_p' AS table_name,
    COALESCE(special_fee_type, 'NORMAL') AS special_fee_type,
    COUNT(*) AS row_count
FROM dws.dws_bb_card_finance_daily_v2_p
WHERE report_date >= DATE '2026-10-01'
  AND report_date <  DATE '2026-11-01'
GROUP BY COALESCE(special_fee_type, 'NORMAL')
ORDER BY special_fee_type;

SELECT
    'dws.dws_qi_card_finance_daily_v2_p' AS table_name,
    COALESCE(special_fee_type, 'NORMAL') AS special_fee_type,
    COUNT(*) AS row_count
FROM dws.dws_qi_card_finance_daily_v2_p
WHERE report_date >= DATE '2026-10-01'
  AND report_date <  DATE '2026-11-01'
GROUP BY COALESCE(special_fee_type, 'NORMAL')
ORDER BY special_fee_type;

-- 仅删除 BB / QI 的 2026-10 DWS 结果，不删除 DWM。
DELETE FROM dws.dws_bb_card_finance_daily_v2_p
WHERE report_date >= DATE '2026-10-01'
  AND report_date <  DATE '2026-11-01';

DELETE FROM dws.dws_qi_card_finance_daily_v2_p
WHERE report_date >= DATE '2026-10-01'
  AND report_date <  DATE '2026-11-01';

COMMIT;

-- 删除后 BB / QI 都应返回 0。
SELECT
    'dws.dws_bb_card_finance_daily_v2_p' AS table_name,
    COUNT(*) AS remaining_count
FROM dws.dws_bb_card_finance_daily_v2_p
WHERE report_date >= DATE '2026-10-01'
  AND report_date <  DATE '2026-11-01'
UNION ALL
SELECT
    'dws.dws_qi_card_finance_daily_v2_p' AS table_name,
    COUNT(*) AS remaining_count
FROM dws.dws_qi_card_finance_daily_v2_p
WHERE report_date >= DATE '2026-10-01'
  AND report_date <  DATE '2026-11-01';
