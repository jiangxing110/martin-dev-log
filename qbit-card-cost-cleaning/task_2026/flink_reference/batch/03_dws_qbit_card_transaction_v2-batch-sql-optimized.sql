--********************************************************************
-- Author:         martinJiang
-- Created Time:   2026-08-19
-- Updated Time:   2026-08-19
-- Description:    dws_qbit_card_transaction 批处理作业优化版本（直接查询分区表）
-- 优化点：
--   1. 显式指定分区表，避免主表扫描，利用分区剪裁
--   2. 仅查询受影响日期范围内的分区，减少数据量
--   3. 保持原有的"修复模式"逻辑：删除 → 聚合 → upsert
-- Notes:
--   1. 分区表命名规则：qbit_card_transaction_YYYYqN（如 2026q1, 2026q2）
--   2. 需要根据 start_date/end_date 手动调整 UNION ALL 的分区表
--   3. 建议按季度分批执行，避免单次跨过多分区
--********************************************************************
SET 'parallelism.default' = '1';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'sink.parallelism' = '1';
SET 'table.dml-sync' = 'true';
SET 'execution.checkpointing.interval' = '5min';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'execution.checkpointing.timeout' = '30min';
SET 'table.optimizer.reuse-source-enabled' = 'true';
SET 'table.optimizer.reuse-sub-plan-enabled' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

CREATE TEMPORARY TABLE source_delete_dws_qbit_card_transaction_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_dws_qbit_card_transaction_cdc(false, CAST(''${start_date}'' AS DATE), CAST(''${end_date}'' AS DATE)) AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

-- 根据日期范围调整以下 UNION ALL 的分区表
-- 2026 全年示例：qbit_card_transaction_2026q1 ~ 2026q4
CREATE TEMPORARY TABLE source_dws_qbit_card_transaction (
    account_id STRING,
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
        SELECT DISTINCT tr."accountId" AS k0, tr."provider" AS k1, qc."firstSix" AS k2, tr."businessType" AS k3, tr."createTime"::DATE::TIMESTAMP AS k4, tr."status" AS k5
        FROM (
            -- Q1 2026
            SELECT * FROM "qbit_card_transaction_2026q1"
            UNION ALL
            -- Q2 2026
            SELECT * FROM "qbit_card_transaction_2026q2"
            UNION ALL
            -- Q3 2026
            SELECT * FROM "qbit_card_transaction_2026q3"
            UNION ALL
            -- Q4 2026
            SELECT * FROM "qbit_card_transaction_2026q4"
            -- 根据实际日期范围添加/移除分区表
        ) AS tr
        LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
        WHERE (DATE(tr."createTime") >= CAST(''${start_date}'' AS DATE) AND DATE(tr."createTime") <= CAST(''${end_date}'' AS DATE))
    )
    SELECT CAST(tr."accountId" AS text) AS "account_id", CAST(tr."businessType" AS text) AS "business_type", CAST(tr."status" AS text) AS "status", CAST(tr."provider" AS text) AS "provider", CAST(qc."firstSix" AS text) AS "bin", CAST(COALESCE(SUM(tr."originalAmount"), 0) AS DECIMAL(18,2)) AS "origin_amount", CAST(COALESCE(SUM(tr."settleAmount"), 0) AS DECIMAL(18,2)) AS "settle_amount", CAST(COUNT(*) AS INTEGER) AS "transaction_count", CAST(COALESCE(SUM(tr."fee"), 0) AS DECIMAL(18,2)) AS "fee", tr."createTime"::DATE::TIMESTAMP AS "create_date", 1 AS "version", NOW() AS "create_time", NOW() AS "update_time"
    FROM (
        -- Q1 2026
        SELECT * FROM "qbit_card_transaction_2026q1"
        UNION ALL
        -- Q2 2026
        SELECT * FROM "qbit_card_transaction_2026q2"
        UNION ALL
        -- Q3 2026
        SELECT * FROM "qbit_card_transaction_2026q3"
        UNION ALL
        -- Q4 2026
        SELECT * FROM "qbit_card_transaction_2026q4"
        -- 根据实际日期范围添加/移除分区表
    ) AS tr
    LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
    JOIN affected a ON (tr."accountId") IS NOT DISTINCT FROM a.k0 AND (tr."provider") IS NOT DISTINCT FROM a.k1 AND (qc."firstSix") IS NOT DISTINCT FROM a.k2 AND (tr."businessType") IS NOT DISTINCT FROM a.k3 AND (tr."createTime"::DATE::TIMESTAMP) IS NOT DISTINCT FROM a.k4 AND (tr."status") IS NOT DISTINCT FROM a.k5
    WHERE tr."deleteTime" IS NULL
    GROUP BY tr."accountId", tr."provider", qc."firstSix", tr."businessType", create_date, tr."status") AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

CREATE TEMPORARY VIEW v_dws_qbit_card_transaction_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(account_id, ''), ': ', COALESCE(provider, ''), ': ', COALESCE(bin, ''), ': ', COALESCE(business_type, ''), ': ', DATE_FORMAT(create_date, 'yyyy-MM-dd'), ': ', COALESCE(status, '')))) AS BIGINT) AS id,
    *
FROM source_dws_qbit_card_transaction;

CREATE TEMPORARY TABLE sink_dws_qbit_card_transaction_2026 (
    id BIGINT, account_id STRING, business_type STRING, status STRING, provider STRING, bin STRING, origin_amount DECIMAL(18,2), settle_amount DECIMAL(18,2), transaction_count INT, fee DECIMAL(18,2), create_date TIMESTAMP(6), version INT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='dws_qbit_card_transaction_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

INSERT INTO sink_dws_qbit_card_transaction_2026
SELECT id, account_id, business_type, status, provider, bin, origin_amount, settle_amount, transaction_count, fee, create_date, version, create_time, update_time
FROM v_dws_qbit_card_transaction_base
CROSS JOIN source_delete_dws_qbit_card_transaction_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2026-01-01' AND create_date < DATE '2027-01-01';
