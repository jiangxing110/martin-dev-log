--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-04 16:05:00
-- Description:    salesAccountRelation -> dim_sale_account_relation_p CDC 数据核对
-- 作业元信息：
--   作业类型：检查脚本
--   运行方式：手动执行
--   运行参数：无
-- Notes:
--   1. 源表口径与 dim_online_sale_account_relation-batch-sql.sql / CDC 脚本保持一致。
--   2. 只检查 accountId/createTime 非空的销售关系时间线。
--   3. 目标表不展开 api_account_relation 子户。
--********************************************************************--

-- 1. 总量与更新时间水位：先看 CDC 有没有明显停住
WITH src AS (
    SELECT
        id::text AS id,
        "accountId"::text AS relation_account_id,
        "salesId"::text AS sale_id,
        "amId"::text AS am_id,
        "operationManagerId"::text AS operation_manager_id,
        "createTime" AS relation_start_time,
        "deleteTime" AS relation_end_time,
        COALESCE(version, 1) AS version,
        remarks,
        "createTime" AS create_time,
        COALESCE("updateTime", "createTime") AS update_time,
        "deleteTime" AS delete_time
    FROM public."salesAccountRelation"
    WHERE "accountId" IS NOT NULL
      AND "createTime" IS NOT NULL
),
tgt AS (
    SELECT
        id,
        relation_account_id,
        sale_id,
        am_id,
        operation_manager_id,
        relation_start_time,
        relation_end_time,
        version,
        remarks,
        create_time,
        update_time,
        delete_time
    FROM dim.dim_sale_account_relation_p
)
SELECT 'source_eligible_count' AS metric, COUNT(*)::text AS value FROM src
UNION ALL
SELECT 'target_count', COUNT(*)::text FROM tgt
UNION ALL
SELECT 'source_max_update_time', COALESCE(MAX(update_time)::text, 'NULL') FROM src
UNION ALL
SELECT 'target_max_update_time', COALESCE(MAX(update_time)::text, 'NULL') FROM tgt
UNION ALL
SELECT 'source_max_create_time', COALESCE(MAX(create_time)::text, 'NULL') FROM src
UNION ALL
SELECT 'target_max_create_time', COALESCE(MAX(create_time)::text, 'NULL') FROM tgt
UNION ALL
SELECT 'source_deleted_count', COUNT(*)::text FROM src WHERE delete_time IS NOT NULL
UNION ALL
SELECT 'target_deleted_count', COUNT(*)::text FROM tgt WHERE delete_time IS NOT NULL;

-- 2. 源表有、目标 DIM 没有：CDC 漏同步或初始化漏数据
WITH src AS (
    SELECT
        id::text AS id,
        "accountId"::text AS relation_account_id,
        "salesId"::text AS sale_id,
        "amId"::text AS am_id,
        "operationManagerId"::text AS operation_manager_id,
        "createTime" AS relation_start_time,
        "deleteTime" AS relation_end_time,
        COALESCE(version, 1) AS version,
        remarks,
        "createTime" AS create_time,
        COALESCE("updateTime", "createTime") AS update_time,
        "deleteTime" AS delete_time
    FROM public."salesAccountRelation"
    WHERE "accountId" IS NOT NULL
      AND "createTime" IS NOT NULL
)
SELECT
    s.*
FROM src s
LEFT JOIN dim.dim_sale_account_relation_p t
    ON t.id = s.id
   AND t.relation_start_time = s.relation_start_time
WHERE t.id IS NULL
ORDER BY s.update_time DESC, s.create_time DESC
LIMIT 200;

-- 3. 目标 DIM 有、源表没有：历史脏数据或源口径变化
WITH src_key AS (
    SELECT
        id::text AS id,
        "createTime" AS relation_start_time
    FROM public."salesAccountRelation"
    WHERE "accountId" IS NOT NULL
      AND "createTime" IS NOT NULL
)
SELECT
    t.*
FROM dim.dim_sale_account_relation_p t
LEFT JOIN src_key s
    ON s.id = t.id
   AND s.relation_start_time = t.relation_start_time
WHERE s.id IS NULL
ORDER BY t.update_time DESC, t.create_time DESC
LIMIT 200;

-- 4. 主键命中但字段不一致：CDC 有消费但 upsert 字段没更新，或字段映射不一致
WITH src AS (
    SELECT
        id::text AS id,
        "accountId"::text AS relation_account_id,
        "salesId"::text AS sale_id,
        "amId"::text AS am_id,
        "operationManagerId"::text AS operation_manager_id,
        "createTime" AS relation_start_time,
        "deleteTime" AS relation_end_time,
        COALESCE(version, 1) AS version,
        remarks,
        "createTime" AS create_time,
        COALESCE("updateTime", "createTime") AS update_time,
        "deleteTime" AS delete_time
    FROM public."salesAccountRelation"
    WHERE "accountId" IS NOT NULL
      AND "createTime" IS NOT NULL
)
SELECT
    s.id,
    s.relation_start_time,
    s.relation_account_id AS src_relation_account_id,
    t.relation_account_id AS tgt_relation_account_id,
    s.sale_id AS src_sale_id,
    t.sale_id AS tgt_sale_id,
    s.am_id AS src_am_id,
    t.am_id AS tgt_am_id,
    s.operation_manager_id AS src_operation_manager_id,
    t.operation_manager_id AS tgt_operation_manager_id,
    s.relation_end_time AS src_relation_end_time,
    t.relation_end_time AS tgt_relation_end_time,
    s.version AS src_version,
    t.version AS tgt_version,
    s.remarks AS src_remarks,
    t.remarks AS tgt_remarks,
    s.update_time AS src_update_time,
    t.update_time AS tgt_update_time,
    s.delete_time AS src_delete_time,
    t.delete_time AS tgt_delete_time
FROM src s
INNER JOIN dim.dim_sale_account_relation_p t
    ON t.id = s.id
   AND t.relation_start_time = s.relation_start_time
WHERE s.relation_account_id IS DISTINCT FROM t.relation_account_id
   OR s.sale_id IS DISTINCT FROM t.sale_id
   OR s.am_id IS DISTINCT FROM t.am_id
   OR s.operation_manager_id IS DISTINCT FROM t.operation_manager_id
   OR s.relation_end_time IS DISTINCT FROM t.relation_end_time
   OR s.version IS DISTINCT FROM t.version
   OR s.remarks IS DISTINCT FROM t.remarks
   OR s.create_time IS DISTINCT FROM t.create_time
   OR s.update_time IS DISTINCT FROM t.update_time
   OR s.delete_time IS DISTINCT FROM t.delete_time
ORDER BY GREATEST(s.update_time, t.update_time) DESC
LIMIT 200;

-- 5. 最近 7 天源表变更是否都同步到 DIM
WITH src AS (
    SELECT
        id::text AS id,
        "accountId"::text AS relation_account_id,
        "salesId"::text AS sale_id,
        "amId"::text AS am_id,
        "operationManagerId"::text AS operation_manager_id,
        "createTime" AS relation_start_time,
        "deleteTime" AS relation_end_time,
        COALESCE(version, 1) AS version,
        remarks,
        "createTime" AS create_time,
        COALESCE("updateTime", "createTime") AS update_time,
        "deleteTime" AS delete_time
    FROM public."salesAccountRelation"
    WHERE "accountId" IS NOT NULL
      AND "createTime" IS NOT NULL
      AND (
            COALESCE("updateTime", "createTime") >= CURRENT_TIMESTAMP - INTERVAL '7 days'
         OR "deleteTime" >= CURRENT_TIMESTAMP - INTERVAL '7 days'
      )
)
SELECT
    s.id,
    s.relation_account_id,
    s.sale_id,
    s.am_id,
    s.relation_start_time,
    s.relation_end_time,
    s.update_time AS src_update_time,
    t.update_time AS tgt_update_time,
    CASE
        WHEN t.id IS NULL THEN 'MISSING_IN_TARGET'
        WHEN s.update_time IS DISTINCT FROM t.update_time
          OR s.delete_time IS DISTINCT FROM t.delete_time
          OR s.sale_id IS DISTINCT FROM t.sale_id
          OR s.am_id IS DISTINCT FROM t.am_id
        THEN 'FIELD_MISMATCH'
        ELSE 'OK'
    END AS check_result
FROM src s
LEFT JOIN dim.dim_sale_account_relation_p t
    ON t.id = s.id
   AND t.relation_start_time = s.relation_start_time
WHERE t.id IS NULL
   OR s.update_time IS DISTINCT FROM t.update_time
   OR s.delete_time IS DISTINCT FROM t.delete_time
   OR s.sale_id IS DISTINCT FROM t.sale_id
   OR s.am_id IS DISTINCT FROM t.am_id
ORDER BY s.update_time DESC
LIMIT 200;

-- 6. 目标 DIM 主键重复检查：理论上应为 0
SELECT
    id,
    relation_start_time,
    COUNT(*) AS duplicate_count
FROM dim.dim_sale_account_relation_p
GROUP BY id, relation_start_time
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, relation_start_time DESC
LIMIT 200;

-- 7. 同一个 relation_account_id 时间线重叠检查：用于发现销售归属历史是否冲突
WITH timeline AS (
    SELECT
        id,
        relation_account_id,
        sale_id,
        am_id,
        relation_start_time,
        relation_end_time,
        LEAD(relation_start_time) OVER (
            PARTITION BY relation_account_id
            ORDER BY relation_start_time, id
        ) AS next_relation_start_time
    FROM dim.dim_sale_account_relation_p
    WHERE relation_account_id IS NOT NULL
)
SELECT
    *
FROM timeline
WHERE relation_end_time IS NOT NULL
  AND next_relation_start_time IS NOT NULL
  AND relation_end_time > next_relation_start_time
ORDER BY relation_account_id, relation_start_time
LIMIT 200;

-- 8. 按天看源表和目标 DIM 的 update_time 分布，快速判断 CDC 停在哪天
WITH src_daily AS (
    SELECT
        COALESCE("updateTime", "createTime")::date AS dt,
        COUNT(*) AS src_count
    FROM public."salesAccountRelation"
    WHERE "accountId" IS NOT NULL
      AND "createTime" IS NOT NULL
      AND COALESCE("updateTime", "createTime") >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY COALESCE("updateTime", "createTime")::date
),
tgt_daily AS (
    SELECT
        update_time::date AS dt,
        COUNT(*) AS tgt_count
    FROM dim.dim_sale_account_relation_p
    WHERE update_time >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY update_time::date
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
