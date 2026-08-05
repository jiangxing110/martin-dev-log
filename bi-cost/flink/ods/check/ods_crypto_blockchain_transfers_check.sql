--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-05
-- Updated Time:   2026-08-05 00:00:00
-- Description:    view_crypto_assets_blockchain_transfers -> ods.ods_crypto_blockchain_transfers 数据核对
-- Notes:
--   1. PG 源库执行第 1 段，核对 public.view_crypto_assets_blockchain_transfers 水位。
--   2. ADBPG 目标库执行第 2 段，核对 ods.ods_crypto_blockchain_transfers 水位。
--   3. ADBPG 目标库可执行第 3 段，核对内部等价 MV 与目标表是否一致。
--   4. 口径与 ods_online_crypto_blockchain_transfers-batch-sql.sql 保持一致：dt = create_time::date。
--********************************************************************--

-- ============================================================
-- 1. 源库水位: public.view_crypto_assets_blockchain_transfers
-- ============================================================

SELECT
    COUNT(*) AS source_count,
    MIN(create_time::timestamp) AS source_min_create_time,
    MAX(create_time::timestamp) AS source_max_create_time,
    MAX(completion_time::timestamp) AS source_max_completion_time,
    COUNT(*) FILTER (WHERE create_time IS NULL OR create_time = '') AS source_null_create_time_count,
    COUNT(*) FILTER (
        WHERE create_time IS NOT NULL
          AND create_time <> ''
          AND (create_time::timestamp < TIMESTAMP '2021-01-01 00:00:00'
           OR create_time::timestamp >= TIMESTAMP '2027-01-01 00:00:00')
    ) AS source_out_of_partition_count
FROM public.view_crypto_assets_blockchain_transfers;

-- ============================================================
-- 2. 目标水位: ods.ods_crypto_blockchain_transfers
-- ============================================================

SELECT
    COUNT(*) AS target_count,
    MIN(create_time) AS target_min_create_time,
    MAX(create_time) AS target_max_create_time,
    MAX(completion_time) AS target_max_completion_time,
    COUNT(*) FILTER (WHERE dt IS DISTINCT FROM create_time::date) AS target_dt_mismatch_count
FROM ods.ods_crypto_blockchain_transfers;

-- ============================================================
-- 3. ADBPG 内部 MV 对目标表：判断是否有漏数/残留
-- ============================================================

SELECT
    COUNT(*) AS adbpg_mv_count,
    MIN(create_time::timestamp) AS adbpg_mv_min_create_time,
    MAX(create_time::timestamp) AS adbpg_mv_max_create_time,
    MAX(completion_time::timestamp) AS adbpg_mv_max_completion_time,
    COUNT(*) FILTER (WHERE create_time IS NULL) AS adbpg_mv_null_create_time_count,
    COUNT(*) FILTER (
        WHERE create_time IS NOT NULL
          AND (create_time::timestamp < TIMESTAMP '2021-01-01 00:00:00'
           OR create_time::timestamp >= TIMESTAMP '2027-01-01 00:00:00')
    ) AS adbpg_mv_out_of_partition_count
FROM ods.view_crypto_assets_blockchain_transfers;

SELECT
    COUNT(*) AS mv_has_target_missing_count
FROM ods.view_crypto_assets_blockchain_transfers s
LEFT JOIN ods.ods_crypto_blockchain_transfers t
    ON t.id = s.id
   AND t.dt = s.create_time::timestamp::date
WHERE s.create_time IS NOT NULL
  AND t.id IS NULL;

SELECT
    COUNT(*) AS target_has_mv_missing_count
FROM ods.ods_crypto_blockchain_transfers t
LEFT JOIN ods.view_crypto_assets_blockchain_transfers s
    ON s.id = t.id
   AND s.create_time::timestamp::date = t.dt
WHERE s.id IS NULL;

-- ============================================================
-- 4. 分布检查：水位不一致时再跑
-- ============================================================

-- 源库执行: 按年
SELECT
    TO_CHAR(create_time::timestamp, 'YYYY') AS yy,
    COUNT(*) AS source_count
FROM public.view_crypto_assets_blockchain_transfers
WHERE create_time IS NOT NULL
  AND create_time <> ''
GROUP BY TO_CHAR(create_time::timestamp, 'YYYY')
ORDER BY yy;

-- 目标库执行: 按年
SELECT
    TO_CHAR(create_time, 'YYYY') AS yy,
    COUNT(*) AS target_count
FROM ods.ods_crypto_blockchain_transfers
GROUP BY TO_CHAR(create_time, 'YYYY')
ORDER BY yy;

-- 目标库执行: ADBPG 内部 MV 按年
SELECT
    TO_CHAR(create_time::timestamp, 'YYYY') AS yy,
    COUNT(*) AS adbpg_mv_count
FROM ods.view_crypto_assets_blockchain_transfers
WHERE create_time IS NOT NULL
GROUP BY TO_CHAR(create_time::timestamp, 'YYYY')
ORDER BY yy;
