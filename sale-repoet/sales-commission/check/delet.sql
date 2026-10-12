BEGIN;

-- 删除前确认数量
SELECT 'detail' AS table_name, COUNT(*) AS row_count
FROM dws.dws_sales_commission_snapshot_detail_p
WHERE settlement_month = DATE '2026-09-01';

SELECT 'summary' AS table_name, COUNT(*) AS row_count
FROM dws.dws_sales_commission_snapshot_p
WHERE settlement_month = DATE '2026-09-01';

-- 先删明细，再删主表
DELETE FROM dws.dws_sales_commission_snapshot_detail_p
WHERE settlement_month = DATE '2026-09-01';

DELETE FROM dws.dws_sales_commission_snapshot_p
WHERE settlement_month = DATE '2026-09-01';

-- 确认两张表中 9 月结算数据已清空
SELECT 'detail' AS table_name, COUNT(*) AS remaining_count
FROM dws.dws_sales_commission_snapshot_detail_p
WHERE settlement_month = DATE '2026-09-01';

SELECT 'summary' AS table_name, COUNT(*) AS remaining_count
FROM dws.dws_sales_commission_snapshot_p
WHERE settlement_month = DATE '2026-09-01';

-- 确认无误后提交；若不对，执行 ROLLBACK;
COMMIT;