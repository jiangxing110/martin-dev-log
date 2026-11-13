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




UPDATE public.api_client_bill_statement
SET delete_time = NOW()
WHERE bill_id = 2120494276851281921
  AND account_id = 'e6f7db49-c103-455e-930a-acdc22f64889'
  AND bill_month = '2026-10'
  AND delete_time IS NULL

UPDATE public.api_client_bill
SET delete_time = NOW()
WHERE account_id = 'e6f7db49-c103-455e-930a-acdc22f64889'
  AND bill_month = '2026-10'
  AND delete_time IS NULL

