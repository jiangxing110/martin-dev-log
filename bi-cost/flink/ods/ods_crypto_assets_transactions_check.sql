--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-05
-- Updated Time:   2026-08-05 00:00:00
-- Description:    crypto_assets_transactions -> ods.ods_crypto_assets_transactions CDC 数据核对
-- Notes:
--   1. 先分别在源库和目标库执行第 1 段水位摘要。
--   2. 如果水位不一致，再执行第 2 段分布检查。
--   3. 口径与 ods_online_crypto_assets_transactions-cdc-sql.sql 保持一致：dt = create_time::date。
--********************************************************************--

-- ============================================================
-- 1. 水位摘要
-- ============================================================

-- 源库执行: public.crypto_assets_transactions
SELECT
    COUNT(*) AS source_count,
    MIN(create_time) AS source_min_create_time,
    MAX(create_time) AS source_max_create_time,
    MAX(update_time) AS source_max_update_time,
    COUNT(*) FILTER (WHERE delete_time IS NOT NULL) AS source_deleted_count,
    COUNT(*) FILTER (WHERE create_time IS NULL) AS source_null_create_time_count
FROM public.crypto_assets_transactions;

-- 目标库执行: ods.ods_crypto_assets_transactions
SELECT
    COUNT(*) AS target_count,
    MIN(create_time) AS target_min_create_time,
    MAX(create_time) AS target_max_create_time,
    MAX(update_time) AS target_max_update_time,
    COUNT(*) FILTER (WHERE delete_time IS NOT NULL) AS target_deleted_count,
    COUNT(*) FILTER (WHERE dt IS DISTINCT FROM create_time::date) AS target_dt_mismatch_count
FROM ods.ods_crypto_assets_transactions;

-- ============================================================
-- 2. 分布检查：水位不一致时再跑
-- ============================================================

-- 源库执行: 按年
SELECT
    TO_CHAR(create_time, 'YYYY') AS yy,
    COUNT(*) AS source_count
FROM public.crypto_assets_transactions
WHERE create_time IS NOT NULL
GROUP BY TO_CHAR(create_time, 'YYYY')
ORDER BY yy;

-- 源库执行: 2026 按月
SELECT
    TO_CHAR(create_time, 'YYYY-MM') AS ym,
    COUNT(*) AS source_count
FROM public.crypto_assets_transactions
WHERE create_time >= TIMESTAMP '2026-01-01 00:00:00'
  AND create_time < TIMESTAMP '2027-01-01 00:00:00'
GROUP BY TO_CHAR(create_time, 'YYYY-MM')
ORDER BY ym;

-- 源库执行: 金额字段异常值
SELECT
    COUNT(*) AS source_invalid_numeric_count
FROM public.crypto_assets_transactions
WHERE (amount IS NOT NULL AND amount !~ '^-?[0-9]+(\.[0-9]+)?$')
   OR (fee IS NOT NULL AND fee !~ '^-?[0-9]+(\.[0-9]+)?$')
   OR (total_amount IS NOT NULL AND total_amount !~ '^-?[0-9]+(\.[0-9]+)?$');

-- 目标库执行: 按年
SELECT
    TO_CHAR(create_time, 'YYYY') AS yy,
    COUNT(*) AS target_count
FROM ods.ods_crypto_assets_transactions
GROUP BY TO_CHAR(create_time, 'YYYY')
ORDER BY yy;

-- 目标库执行: 2026 按月
SELECT
    TO_CHAR(create_time, 'YYYY-MM') AS ym,
    COUNT(*) AS target_count
FROM ods.ods_crypto_assets_transactions
WHERE create_time >= TIMESTAMP '2026-01-01 00:00:00'
  AND create_time < TIMESTAMP '2027-01-01 00:00:00'
GROUP BY TO_CHAR(create_time, 'YYYY-MM')
ORDER BY ym;
