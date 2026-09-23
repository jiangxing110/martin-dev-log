TRUNCATE TABLE
    dws.dws_sales_commission_snapshot_detail_p,
    dws.dws_sales_commission_snapshot_p;


SELECT
    'detail' AS table_name,
    COUNT(*) AS row_count
FROM dws.dws_sales_commission_snapshot_detail_p

UNION ALL

SELECT
    'snapshot' AS table_name,
    COUNT(*) AS row_count
FROM dws.dws_sales_commission_snapshot_p;    