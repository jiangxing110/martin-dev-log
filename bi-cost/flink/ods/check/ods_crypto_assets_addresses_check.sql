--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-04 17:28:00
-- Description:    crypto_assets_addresses -> ods.ods_crypto_assets_addresses CDC 数据核对
-- 作业元信息：
--   作业类型：检查脚本
--   运行方式：手动执行
--   运行参数：无
-- Notes:
--   1. 源表口径与 ods_online_crypto_assets_addresses-cdc-sql.sql 保持一致。
--   2. ODS 主键为 (id, dt)，其中 dt = CAST(create_time AS DATE)。
--   3. submit_time 口径为 create_time。
--********************************************************************--

-- 1. 总量与时间水位：判断 CDC 是否明显停住
WITH src AS (
    SELECT
        id::text AS id,
        CAST(create_time AS DATE) AS dt,
        create_time,
        update_time,
        delete_time,
        version,
        account_id::text AS account_id,
        wallet_id::text AS wallet_id,
        chain,
        currency,
        address,
        address_tag,
        remarks,
        enable,
        selected,
        platform,
        account_key,
        create_time AS submit_time
    FROM public.crypto_assets_addresses
    WHERE id IS NOT NULL
      AND create_time IS NOT NULL
),
tgt AS (
    SELECT
        id,
        dt,
        create_time,
        update_time,
        delete_time,
        version,
        account_id,
        wallet_id,
        chain,
        currency,
        address,
        address_tag,
        remarks,
        enable,
        selected,
        platform,
        account_key,
        submit_time
    FROM ods.ods_crypto_assets_addresses
)
SELECT 'source_count' AS metric, COUNT(*)::text AS value FROM src
UNION ALL
SELECT 'target_count', COUNT(*)::text FROM tgt
UNION ALL
SELECT 'source_max_create_time', COALESCE(MAX(create_time)::text, 'NULL') FROM src
UNION ALL
SELECT 'target_max_create_time', COALESCE(MAX(create_time)::text, 'NULL') FROM tgt
UNION ALL
SELECT 'source_max_update_time', COALESCE(MAX(update_time)::text, 'NULL') FROM src
UNION ALL
SELECT 'target_max_update_time', COALESCE(MAX(update_time)::text, 'NULL') FROM tgt
UNION ALL
SELECT 'source_deleted_count', COUNT(*)::text FROM src WHERE delete_time IS NOT NULL
UNION ALL
SELECT 'target_deleted_count', COUNT(*)::text FROM tgt WHERE delete_time IS NOT NULL;

-- 2. 源表有、ODS 没有：CDC 漏同步或初始化漏数据
WITH src AS (
    SELECT
        id::text AS id,
        CAST(create_time AS DATE) AS dt,
        create_time,
        update_time,
        delete_time,
        version,
        account_id::text AS account_id,
        wallet_id::text AS wallet_id,
        chain,
        currency,
        address,
        address_tag,
        remarks,
        enable,
        selected,
        platform,
        account_key,
        create_time AS submit_time
    FROM public.crypto_assets_addresses
    WHERE id IS NOT NULL
      AND create_time IS NOT NULL
)
SELECT
    s.*
FROM src s
LEFT JOIN ods.ods_crypto_assets_addresses t
    ON t.id = s.id
   AND t.dt = s.dt
WHERE t.id IS NULL
ORDER BY COALESCE(s.update_time, s.create_time) DESC
LIMIT 200;

-- 3. ODS 有、源表没有：目标多余数据或历史脏数据
WITH src_key AS (
    SELECT
        id::text AS id,
        CAST(create_time AS DATE) AS dt
    FROM public.crypto_assets_addresses
    WHERE id IS NOT NULL
      AND create_time IS NOT NULL
)
SELECT
    t.*
FROM ods.ods_crypto_assets_addresses t
LEFT JOIN src_key s
    ON s.id = t.id
   AND s.dt = t.dt
WHERE s.id IS NULL
ORDER BY COALESCE(t.update_time, t.create_time) DESC
LIMIT 200;

-- 4. 主键命中但字段不一致：CDC 有消费但字段没更新，或映射不一致
WITH src AS (
    SELECT
        id::text AS id,
        CAST(create_time AS DATE) AS dt,
        create_time,
        update_time,
        delete_time,
        version,
        account_id::text AS account_id,
        wallet_id::text AS wallet_id,
        chain,
        currency,
        address,
        address_tag,
        remarks,
        enable,
        selected,
        platform,
        account_key,
        create_time AS submit_time
    FROM public.crypto_assets_addresses
    WHERE id IS NOT NULL
      AND create_time IS NOT NULL
)
SELECT
    s.id,
    s.dt,
    s.create_time AS src_create_time,
    t.create_time AS tgt_create_time,
    s.update_time AS src_update_time,
    t.update_time AS tgt_update_time,
    s.delete_time AS src_delete_time,
    t.delete_time AS tgt_delete_time,
    s.version AS src_version,
    t.version AS tgt_version,
    s.account_id AS src_account_id,
    t.account_id AS tgt_account_id,
    s.wallet_id AS src_wallet_id,
    t.wallet_id AS tgt_wallet_id,
    s.chain AS src_chain,
    t.chain AS tgt_chain,
    s.currency AS src_currency,
    t.currency AS tgt_currency,
    s.address AS src_address,
    t.address AS tgt_address,
    s.address_tag AS src_address_tag,
    t.address_tag AS tgt_address_tag,
    s.remarks AS src_remarks,
    t.remarks AS tgt_remarks,
    s.enable AS src_enable,
    t.enable AS tgt_enable,
    s.selected AS src_selected,
    t.selected AS tgt_selected,
    s.platform AS src_platform,
    t.platform AS tgt_platform,
    s.account_key AS src_account_key,
    t.account_key AS tgt_account_key,
    s.submit_time AS src_submit_time,
    t.submit_time AS tgt_submit_time
FROM src s
INNER JOIN ods.ods_crypto_assets_addresses t
    ON t.id = s.id
   AND t.dt = s.dt
WHERE s.create_time IS DISTINCT FROM t.create_time
   OR s.update_time IS DISTINCT FROM t.update_time
   OR s.delete_time IS DISTINCT FROM t.delete_time
   OR s.version IS DISTINCT FROM t.version
   OR s.account_id IS DISTINCT FROM t.account_id
   OR s.wallet_id IS DISTINCT FROM t.wallet_id
   OR s.chain IS DISTINCT FROM t.chain
   OR s.currency IS DISTINCT FROM t.currency
   OR s.address IS DISTINCT FROM t.address
   OR s.address_tag IS DISTINCT FROM t.address_tag
   OR s.remarks IS DISTINCT FROM t.remarks
   OR s.enable IS DISTINCT FROM t.enable
   OR s.selected IS DISTINCT FROM t.selected
   OR s.platform IS DISTINCT FROM t.platform
   OR s.account_key IS DISTINCT FROM t.account_key
   OR s.submit_time IS DISTINCT FROM t.submit_time
ORDER BY GREATEST(COALESCE(s.update_time, s.create_time), COALESCE(t.update_time, t.create_time)) DESC
LIMIT 200;

-- 5. 最近 7 天变更检查：优先判断 CDC 是否同步最新变化
WITH src AS (
    SELECT
        id::text AS id,
        CAST(create_time AS DATE) AS dt,
        create_time,
        update_time,
        delete_time,
        version,
        account_id::text AS account_id,
        wallet_id::text AS wallet_id,
        chain,
        currency,
        address,
        address_tag,
        remarks,
        enable,
        selected,
        platform,
        account_key,
        create_time AS submit_time
    FROM public.crypto_assets_addresses
    WHERE id IS NOT NULL
      AND create_time IS NOT NULL
      AND (
            COALESCE(update_time, create_time) >= CURRENT_TIMESTAMP - INTERVAL '7 days'
         OR delete_time >= CURRENT_TIMESTAMP - INTERVAL '7 days'
      )
)
SELECT
    s.id,
    s.dt,
    s.account_id,
    s.wallet_id,
    s.chain,
    s.currency,
    s.address,
    s.create_time,
    s.update_time AS src_update_time,
    t.update_time AS tgt_update_time,
    s.delete_time AS src_delete_time,
    t.delete_time AS tgt_delete_time,
    CASE
        WHEN t.id IS NULL THEN 'MISSING_IN_TARGET'
        WHEN s.update_time IS DISTINCT FROM t.update_time
          OR s.delete_time IS DISTINCT FROM t.delete_time
          OR s.version IS DISTINCT FROM t.version
          OR s.account_id IS DISTINCT FROM t.account_id
          OR s.wallet_id IS DISTINCT FROM t.wallet_id
          OR s.chain IS DISTINCT FROM t.chain
          OR s.currency IS DISTINCT FROM t.currency
          OR s.address IS DISTINCT FROM t.address
          OR s.address_tag IS DISTINCT FROM t.address_tag
          OR s.enable IS DISTINCT FROM t.enable
          OR s.selected IS DISTINCT FROM t.selected
          OR s.platform IS DISTINCT FROM t.platform
          OR s.account_key IS DISTINCT FROM t.account_key
        THEN 'FIELD_MISMATCH'
        ELSE 'OK'
    END AS check_result
FROM src s
LEFT JOIN ods.ods_crypto_assets_addresses t
    ON t.id = s.id
   AND t.dt = s.dt
WHERE t.id IS NULL
   OR s.update_time IS DISTINCT FROM t.update_time
   OR s.delete_time IS DISTINCT FROM t.delete_time
   OR s.version IS DISTINCT FROM t.version
   OR s.account_id IS DISTINCT FROM t.account_id
   OR s.wallet_id IS DISTINCT FROM t.wallet_id
   OR s.chain IS DISTINCT FROM t.chain
   OR s.currency IS DISTINCT FROM t.currency
   OR s.address IS DISTINCT FROM t.address
   OR s.address_tag IS DISTINCT FROM t.address_tag
   OR s.enable IS DISTINCT FROM t.enable
   OR s.selected IS DISTINCT FROM t.selected
   OR s.platform IS DISTINCT FROM t.platform
   OR s.account_key IS DISTINCT FROM t.account_key
ORDER BY COALESCE(s.update_time, s.create_time) DESC
LIMIT 200;

-- 6. 目标主键重复检查：理论上应为 0
SELECT
    id,
    dt,
    COUNT(*) AS duplicate_count
FROM ods.ods_crypto_assets_addresses
GROUP BY id, dt
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, dt DESC
LIMIT 200;

-- 7. dt 口径检查：ODS dt 应等于 create_time::date
SELECT
    id,
    dt,
    create_time,
    CAST(create_time AS DATE) AS expected_dt
FROM ods.ods_crypto_assets_addresses
WHERE create_time IS NOT NULL
  AND dt IS DISTINCT FROM CAST(create_time AS DATE)
ORDER BY create_time DESC
LIMIT 200;

-- 8. 最近 30 天按天分布：快速判断 CDC 停在哪天
WITH src_daily AS (
    SELECT
        COALESCE(update_time, create_time)::date AS dt,
        COUNT(*) AS src_count
    FROM public.crypto_assets_addresses
    WHERE id IS NOT NULL
      AND create_time IS NOT NULL
      AND COALESCE(update_time, create_time) >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY COALESCE(update_time, create_time)::date
),
tgt_daily AS (
    SELECT
        COALESCE(update_time, create_time)::date AS dt,
        COUNT(*) AS tgt_count
    FROM ods.ods_crypto_assets_addresses
    WHERE COALESCE(update_time, create_time) >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY COALESCE(update_time, create_time)::date
)
SELECT
    COALESCE(s.dt, t.dt) AS dt,
    COALESCE(s.src_count, 0) AS src_count,
    COALESCE(t.tgt_count, 0) AS tgt_count,
    COALESCE(s.src_count, 0) - COALESCE(t.tgt_count, 0) AS diff_count
FROM src_daily s
FULL OUTER JOIN tgt_daily t
    ON t.dt = s.dt
ORDER BY dt DESC;
