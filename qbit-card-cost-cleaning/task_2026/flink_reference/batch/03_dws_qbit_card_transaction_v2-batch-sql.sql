--********************************************************************
-- Author:         martinJiang
-- Created Time:   2026-08-18
-- Updated Time:   2026-08-18
-- Description:    dws_qbit_card_transaction 批处理 作业（quantum-v2 范式：确定性哈希主键 + 先清后写）
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性修复/补数：VVR 作业参数 start_date/end_date 指定回刷区间（含两端，YYYY-MM-DD）；删除函数走修复模式按 create_date 跨分表清理，再由重算 upsert 覆盖（幂等）。
--   运行参数：start_date, end_date（YYYY-MM-DD，含两端）
-- Notes:
--   1. 一次性修复/补数作业：通过 VVR 作业参数 start_date/end_date 指定回刷区间（YYYY-MM-DD，含两端）。
--   2. 删除函数走“修复模式”，按 create_date 区间跨分表整段清理。
--   3. 源聚合仅重算该区间内受影响 key 的当前有效行，upsert 覆盖（幂等）。
--   4. 删除与重算必须严格共用同一 start_date/end_date，否则出现区间缺口或越界残留。
--   5. 上线前需对照线上 Flink catalog 校准列类型（UUID / JSON / boolean 等）。
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
        FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
        WHERE (DATE(tr."createTime") >= CAST(''${start_date}'' AS DATE) AND DATE(tr."createTime") <= CAST(''${end_date}'' AS DATE))
    )
    SELECT CAST(tr."accountId" AS text) AS "account_id", CAST(tr."businessType" AS text) AS "business_type", CAST(tr."status" AS text) AS "status", CAST(tr."provider" AS text) AS "provider", CAST(qc."firstSix" AS text) AS "bin", COALESCE(SUM(tr."originalAmount"), 0) AS "origin_amount", COALESCE(SUM(tr."settleAmount"), 0) AS "settle_amount", COUNT(*) AS "transaction_count", COALESCE(SUM(tr."fee"), 0) AS "fee", tr."createTime"::DATE::TIMESTAMP AS "create_date", 1 AS "version", NOW() AS "create_time", NOW() AS "update_time"
    FROM "qbit_card_transaction" AS tr
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
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_qbit_card_transaction_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

INSERT INTO sink_dws_qbit_card_transaction_2026
SELECT id, account_id, business_type, status, provider, bin, origin_amount, settle_amount, transaction_count, fee, create_date, version, create_time, update_time
FROM v_dws_qbit_card_transaction_base
CROSS JOIN source_delete_dws_qbit_card_transaction_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2026-01-01' AND create_date < DATE '2027-01-01';
