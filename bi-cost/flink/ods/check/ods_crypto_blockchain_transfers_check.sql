--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-05
-- Updated Time:   2026-08-05 12:35:00
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

-- PG 源库执行：定位是否存在超过 ADBPG 原 varchar(255) 限制的字段
SELECT
    MAX(LENGTH(transaction_display_id::text)) AS max_transaction_display_id_len,
    MAX(LENGTH(action::text)) AS max_action_len,
    MAX(LENGTH(source_address::text)) AS max_source_address_len,
    MAX(LENGTH(destination_address::text)) AS max_destination_address_len,
    MAX(LENGTH(amount::text)) AS max_amount_len,
    MAX(LENGTH(gas_fee::text)) AS max_gas_fee_len,
    MAX(LENGTH(cross_chain_fee::text)) AS max_cross_chain_fee_len,
    MAX(LENGTH(status::text)) AS max_status_len,
    MAX(LENGTH(transaction_hash::text)) AS max_transaction_hash_len,
    MAX(LENGTH(risk_level::text)) AS max_risk_level_len,
    MAX(LENGTH(third_party_id::text)) AS max_third_party_id_len
FROM public.view_crypto_assets_blockchain_transfers
WHERE create_time IS NOT NULL
  AND create_time <> '';

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
-- 3. 源库主键粒度检查：判断 source_count > target_count 是否来自 upsert 覆盖
-- ============================================================

-- PG 源库执行：如果 source_distinct_sink_key_count 接近 target_count，
-- 说明差异主要来自源视图在目标主键 (id, dt) 粒度上有重复行。
SELECT
    COUNT(*) AS source_count,
    COUNT(DISTINCT (id::text, create_time::timestamp::date)) AS source_distinct_sink_key_count,
    COUNT(*) - COUNT(DISTINCT (id::text, create_time::timestamp::date)) AS source_duplicate_sink_key_count
FROM public.view_crypto_assets_blockchain_transfers
WHERE create_time IS NOT NULL
  AND create_time <> '';

-- PG 源库执行：重复主键样例
SELECT
    id::text AS id,
    create_time::timestamp::date AS dt,
    COUNT(*) AS duplicate_count,
    MIN(transaction_hash::text) AS min_transaction_hash,
    MAX(transaction_hash::text) AS max_transaction_hash
FROM public.view_crypto_assets_blockchain_transfers
WHERE create_time IS NOT NULL
  AND create_time <> ''
GROUP BY id::text, create_time::timestamp::date
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, dt DESC
LIMIT 20;

-- ============================================================
-- 4. ADBPG 内部 MV 对目标表：判断是否有漏数/残留
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
-- 5. 分布检查：水位不一致时再跑
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

-- ADBPG 目标库执行：按月看目标分布
SELECT
    TO_CHAR(create_time, 'YYYY-MM') AS ym,
    COUNT(*) AS target_count
FROM ods.ods_crypto_blockchain_transfers
GROUP BY TO_CHAR(create_time, 'YYYY-MM')
ORDER BY ym;

-- ADBPG 目标库执行：按月看 ADBPG 内部 MV 分布
SELECT
    TO_CHAR(create_time::timestamp, 'YYYY-MM') AS ym,
    COUNT(*) AS adbpg_mv_count,
    COUNT(DISTINCT (id::text, create_time::timestamp::date)) AS adbpg_mv_distinct_sink_key_count,
    COUNT(*) - COUNT(DISTINCT (id::text, create_time::timestamp::date)) AS adbpg_mv_duplicate_sink_key_count
FROM ods.view_crypto_assets_blockchain_transfers
WHERE create_time IS NOT NULL
GROUP BY TO_CHAR(create_time::timestamp, 'YYYY-MM')
ORDER BY ym;
