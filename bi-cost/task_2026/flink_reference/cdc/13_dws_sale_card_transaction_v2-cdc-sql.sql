--********************************************************************
-- Author:         martinJiang
-- Created Time:   2026-09-01
-- Updated Time:   2026-09-02 19:00:00
-- Description:    dws_sale_card_transaction 流处理(CDC) 作业（quantum-v2 范式：确定性哈希主键 + 先清后写）
-- 作业元信息：
--   作业类型：流处理(CDC)
--   运行方式：每日增量（BATCH 定时触发）：自动按昨天变更窗口(CDC 模式)精准删受影响 key 后 upsert 覆盖。
--   运行参数：（无；CDC 模式自动按昨天变更窗口）
-- Notes:
--   1. 聚合逻辑留在 PostgreSQL（JDBC source 子查询），Flink 仅算 id + upsert，类型转换最少。
--   2. 删除函数按唯一业务键 / 作用域精准删受影响 key，先清后写保证幂等。
--   3. 按 create_date 年份动态路由分表（_YYYY），跨年安全。
--   4. 上线前需对照线上 Flink catalog 校准列类型（UUID / JSON / boolean 等）。
--********************************************************************
SET 'parallelism.default' = '2';
SET 'table.exec.resource.default-parallelism' = '2';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'sink.parallelism' = '1';
SET 'table.dml-sync' = 'true';
SET 'execution.checkpointing.interval' = '5min';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'execution.checkpointing.timeout' = '30min';
SET 'table.optimizer.reuse-source-enabled' = 'true';
SET 'table.optimizer.reuse-sub-plan-enabled' = 'true';
SET 'execution.application-management.enabled' = 'true';
SET 'execution.multi-jobs-in-application.enable' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

-- ==============================================
-- 0. 先调用删除函数：按唯一业务键精准清空受影响分表行（先清后写，保证幂等）
-- ==============================================
CREATE TEMPORARY TABLE source_delete_dws_sale_card_transaction_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_dws_sale_card_transaction_cdc(false) AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

-- ==============================================
-- 1. 源聚合（留在 PostgreSQL 内执行，复用原版聚合逻辑；只回传受影响 key 的聚合结果）
-- ==============================================
CREATE TEMPORARY TABLE source_dws_sale_card_transaction (
    account_id STRING,
    sale_or_am_id STRING,
    business_type STRING,
    status STRING,
    provider STRING,
    bin STRING,
    origin_amount DECIMAL(18,2),
    settle_amount DECIMAL(18,2),
    transaction_count INT,
    fee DECIMAL(18,2),
    create_date TIMESTAMP(6),
    version INT,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(WITH affected AS (
        SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account FROM (SELECT * FROM "qbit_card_transaction" WHERE ("createTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND "createTime" < CURRENT_DATE) OR ("updateTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND "updateTime" < CURRENT_DATE) OR ("deleteTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND "deleteTime" < CURRENT_DATE)) AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."deleteTime" < CURRENT_DATE)
    )
    SELECT CAST(tr."accountId" AS text) AS "account_id", CAST(ids."sale_or_am_id" AS text) AS "sale_or_am_id", CAST(tr."businessType" AS text) AS "business_type", CAST(tr."status" AS text) AS "status", CAST(tr."provider" AS text) AS "provider", CAST(qc."firstSix" AS text) AS "bin", CAST(COALESCE(SUM(tr."originalAmount"), 0) AS numeric(18,2)) AS "origin_amount", CAST(COALESCE(SUM(tr."settleAmount"), 0) AS numeric(18,2)) AS "settle_amount", CAST(COUNT(*) AS integer) AS "transaction_count", CAST(COALESCE(SUM(tr."fee"), 0) AS numeric(18,2)) AS "fee", tr."createTime"::DATE::TIMESTAMP AS "create_date", CAST(1 AS integer) AS "version", NOW() AS "create_time", NOW() AS "update_time"
    FROM (SELECT * FROM "qbit_card_transaction" WHERE ("createTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND "createTime" < CURRENT_DATE) OR ("updateTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND "updateTime" < CURRENT_DATE) OR ("deleteTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND "deleteTime" < CURRENT_DATE)) AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
    JOIN affected a ON (DATE(tr."createTime")) = a.scope_date AND (tr."accountId") = a.scope_account
    WHERE tr."deleteTime" IS NULL
    GROUP BY tr."accountId", ids."sale_or_am_id", tr."businessType", tr."status", tr."provider", qc."firstSix", tr."createTime"::DATE::TIMESTAMP) AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

-- ==============================================
-- 2. 聚合结果视图：计算确定性主键 id = HASH(业务键)
--    （source_dws_sale_card_transaction 已输出聚合列，此处只补 id；列名与 DWS 表一致）
-- ==============================================
CREATE TEMPORARY VIEW v_dws_sale_card_transaction_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(account_id, ''), ': ', COALESCE(sale_or_am_id, ''), ': ', COALESCE(business_type, ''), ': ', COALESCE(status, ''), ': ', COALESCE(provider, ''), ': ', COALESCE(bin, ''), ': ', DATE_FORMAT(create_date, 'yyyy-MM-dd')))) AS BIGINT) AS id,
    *
FROM source_dws_sale_card_transaction;

-- source1：先读取昨日变更交易；销售/AM关系在 Flink 算子层匹配
CREATE TEMPORARY TABLE source1_transaction (
    transaction_id STRING,
    account_id STRING,
    business_type STRING,
    status STRING,
    provider STRING,
    bin STRING,
    origin_amount DECIMAL(18,2),
    settle_amount DECIMAL(18,2),
    fee DECIMAL(18,2),
    create_time TIMESTAMP(6),
    delete_time TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT CAST(tr.id AS text) AS transaction_id, CAST(tr."accountId" AS text) AS account_id, CAST(tr."businessType" AS text) AS business_type, CAST(tr."status" AS text) AS status, CAST(tr."provider" AS text) AS provider, CAST(qc."firstSix" AS text) AS bin, CAST(tr."originalAmount" AS numeric(18,2)) AS origin_amount, CAST(tr."settleAmount" AS numeric(18,2)) AS settle_amount, CAST(tr."fee" AS numeric(18,2)) AS fee, tr."createTime" AS create_time, tr."deleteTime" AS delete_time FROM "qbit_card_transaction" tr LEFT JOIN "qbitCard" qc ON tr."cardId" = qc."id" WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."deleteTime" < CURRENT_DATE)) AS tx',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

-- source2：销售/AM关系；同一账户优先取直接关系，再取 root 关系
CREATE TEMPORARY TABLE source2_sale_relation (
    relation_account_id STRING,
    sale_id STRING,
    am_id STRING,
    relation_start_time TIMESTAMP(6),
    relation_end_time TIMESTAMP(6),
    priority INT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(WITH filtered_txn AS (SELECT DISTINCT "accountId"::text AS account_id FROM public."qbit_card_transaction" WHERE ("createTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND "createTime" < CURRENT_DATE) OR ("updateTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND "updateTime" < CURRENT_DATE) OR ("deleteTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND "deleteTime" < CURRENT_DATE)), related_account AS (SELECT account_id FROM filtered_txn UNION SELECT aar.root_id::text FROM public.api_account_relation aar JOIN filtered_txn ft ON ft.account_id = aar.account_id::text WHERE aar.delete_time IS NULL) SELECT sr.relation_account_id::text AS relation_account_id, sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, sr.relation_start_time, sr.relation_end_time, 1 AS priority FROM dim.dim_sale_account_relation_p sr JOIN related_account ra ON ra.account_id = sr.relation_account_id::text WHERE sr.delete_time IS NULL AND sr.relation_start_time < CURRENT_DATE AND (sr.relation_end_time IS NULL OR sr.relation_end_time > CURRENT_DATE - INTERVAL ''1 day'') UNION ALL SELECT aar.account_id::text AS relation_account_id, sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, sr.relation_start_time, sr.relation_end_time, 2 AS priority FROM public.api_account_relation aar JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text JOIN filtered_txn ft ON ft.account_id = aar.account_id::text WHERE aar.delete_time IS NULL AND sr.delete_time IS NULL AND sr.relation_start_time < CURRENT_DATE AND (sr.relation_end_time IS NULL OR sr.relation_end_time > CURRENT_DATE - INTERVAL ''1 day'')) AS rel',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

CREATE TEMPORARY VIEW v_sale_card_transaction_matched AS
SELECT tr.*, sr.sale_id, sr.am_id,
       ROW_NUMBER() OVER (PARTITION BY tr.transaction_id ORDER BY sr.priority, sr.relation_start_time DESC) AS rn
FROM source1_transaction tr
JOIN source2_sale_relation sr
  ON tr.account_id = sr.relation_account_id
 AND tr.create_time >= sr.relation_start_time
 AND (tr.create_time < sr.relation_end_time OR sr.relation_end_time IS NULL)
WHERE tr.delete_time IS NULL;

CREATE TEMPORARY VIEW v_sale_card_transaction_expanded AS
SELECT transaction_id, account_id, business_type, status, provider, bin, origin_amount, settle_amount, fee, create_time, sale_id AS sale_or_am_id
FROM v_sale_card_transaction_matched WHERE rn = 1 AND sale_id IS NOT NULL
UNION ALL
SELECT transaction_id, account_id, business_type, status, provider, bin, origin_amount, settle_amount, fee, create_time, am_id AS sale_or_am_id
FROM v_sale_card_transaction_matched WHERE rn = 1 AND am_id IS NOT NULL;

CREATE TEMPORARY VIEW v_sale_card_transaction_expanded_daily AS
SELECT transaction_id, account_id, business_type, status, provider, bin, origin_amount, settle_amount, fee, sale_or_am_id,
       CAST(create_time AS DATE) AS create_date
FROM v_sale_card_transaction_expanded;

CREATE TEMPORARY VIEW v_dws_sale_card_transaction_operator AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(account_id, ''), ': ', COALESCE(sale_or_am_id, ''), ': ', COALESCE(business_type, ''), ': ', COALESCE(status, ''), ': ', COALESCE(provider, ''), ': ', COALESCE(bin, ''), ': ', DATE_FORMAT(CAST(create_date AS TIMESTAMP), 'yyyy-MM-dd')))) AS BIGINT) AS id,
    account_id, sale_or_am_id, business_type, status, provider, bin,
    CAST(SUM(origin_amount) AS DECIMAL(18,2)) AS origin_amount,
    CAST(SUM(settle_amount) AS DECIMAL(18,2)) AS settle_amount,
    CAST(COUNT(*) AS INT) AS transaction_count,
    CAST(SUM(fee) AS DECIMAL(18,2)) AS fee,
    CAST(create_date AS TIMESTAMP) AS create_date,
    CAST(1 AS INT) AS version,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time
FROM v_sale_card_transaction_expanded_daily
GROUP BY account_id, sale_or_am_id, business_type, status, provider, bin, create_date;

-- ==============================================
-- 3. 分表 SINK（每个 _YYYY 一个，upsert 按 key 幂等）
-- ==============================================
CREATE TEMPORARY TABLE sink_dws_sale_card_transaction_2024 (
    id BIGINT, account_id STRING, sale_or_am_id STRING, business_type STRING, status STRING, provider STRING, bin STRING, origin_amount DECIMAL(18,2), settle_amount DECIMAL(18,2), transaction_count INT, fee DECIMAL(18,2), create_date TIMESTAMP(6), version INT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='dws_sale_card_transaction_2024','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_sale_card_transaction_2025 (
    id BIGINT, account_id STRING, sale_or_am_id STRING, business_type STRING, status STRING, provider STRING, bin STRING, origin_amount DECIMAL(18,2), settle_amount DECIMAL(18,2), transaction_count INT, fee DECIMAL(18,2), create_date TIMESTAMP(6), version INT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='dws_sale_card_transaction_2025','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_sale_card_transaction_2026 (
    id BIGINT, account_id STRING, sale_or_am_id STRING, business_type STRING, status STRING, provider STRING, bin STRING, origin_amount DECIMAL(18,2), settle_amount DECIMAL(18,2), transaction_count INT, fee DECIMAL(18,2), create_date TIMESTAMP(6), version INT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='dws_sale_card_transaction_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

-- ==============================================
-- 4. 写入（CROSS JOIN 确保删除函数先执行；upsert 覆盖同 key / 新增异 key）
-- ==============================================
INSERT INTO sink_dws_sale_card_transaction_2024
SELECT id, account_id, sale_or_am_id, business_type, status, provider, bin, origin_amount, settle_amount, transaction_count, fee, create_date, version, create_time, update_time
FROM v_dws_sale_card_transaction_operator
CROSS JOIN source_delete_dws_sale_card_transaction_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2024-01-01' AND create_date < DATE '2025-01-01';
INSERT INTO sink_dws_sale_card_transaction_2025
SELECT id, account_id, sale_or_am_id, business_type, status, provider, bin, origin_amount, settle_amount, transaction_count, fee, create_date, version, create_time, update_time
FROM v_dws_sale_card_transaction_operator
CROSS JOIN source_delete_dws_sale_card_transaction_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2025-01-01' AND create_date < DATE '2026-01-01';
INSERT INTO sink_dws_sale_card_transaction_2026
SELECT id, account_id, sale_or_am_id, business_type, status, provider, bin, origin_amount, settle_amount, transaction_count, fee, create_date, version, create_time, update_time
FROM v_dws_sale_card_transaction_operator
CROSS JOIN source_delete_dws_sale_card_transaction_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2026-01-01' AND create_date < DATE '2027-01-01';
