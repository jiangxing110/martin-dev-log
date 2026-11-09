-- 目的：清除销售佣金 2026-10 结算月快照，供刷新后重新固化。
-- 注意：BB 返佣已并入有效收入/毛利/佣金，故需同时替换整月明细和汇总，不能只删返佣行。
-- 执行位置：ADBPG SQL 客户端。删除后需运行 sales-commission 快照 Flink 批处理：
--   snapshot_date = 2026-11-08
--   settlement_month = 2026-10
-- 建议先刷新 dws.mv_sales_commission_recent_estimate，再执行本脚本。

BEGIN;

-- 删除前记录目标范围行数
SELECT 'detail_before' AS check_point, COUNT(*) AS row_count
FROM dws.dws_sales_commission_snapshot_detail_p
WHERE settlement_month = DATE '2026-10-01';

SELECT 'summary_before' AS check_point, COUNT(*) AS row_count
FROM dws.dws_sales_commission_snapshot_p
WHERE settlement_month = DATE '2026-10-01';

-- 先删明细，再删汇总
DELETE FROM dws.dws_sales_commission_snapshot_detail_p
WHERE settlement_month = DATE '2026-10-01';

DELETE FROM dws.dws_sales_commission_snapshot_p
WHERE settlement_month = DATE '2026-10-01';

-- 应为 0；确认后提交，否则执行 ROLLBACK
SELECT 'detail_remaining' AS check_point, COUNT(*) AS row_count
FROM dws.dws_sales_commission_snapshot_detail_p
WHERE settlement_month = DATE '2026-10-01';

SELECT 'summary_remaining' AS check_point, COUNT(*) AS row_count
FROM dws.dws_sales_commission_snapshot_p
WHERE settlement_month = DATE '2026-10-01';

-- 检查两项 remaining 均为 0 后执行：
-- COMMIT;
-- 若结果不符合预期，执行：
-- ROLLBACK;
