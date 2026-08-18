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

-- 说明：batch 用于一次性修复/补数。删除函数走“修复模式”(传入 p_start/p_end)，按 create_date
--       区间整段清理后由下方重算 upsert 覆盖（幂等）。默认区间 2026-01-01~2026-08-17，按需调整。

CREATE TEMPORARY TABLE source_delete_ods_qbit_card_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_ods_qbit_card_cdc(false, DATE ''2026-01-01'', DATE ''2026-08-17'') AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

CREATE TEMPORARY TABLE source_ods_qbit_card (
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    version BIGINT,
    remarks STRING,
    card_id STRING,
    account_id STRING,
    currency STRING,
    status STRING,
    provider STRING,
    type STRING,
    token STRING,
    user_delete_time STRING,
    delete_card_time STRING,
    first_six STRING,
    card_belong STRING,
    physical_card_status STRING,
    card_mode STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(WITH affected AS (
        SELECT DISTINCT tr."id" AS k0
        FROM "qbitCard" AS tr
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."createTime" < CURRENT_DATE)
    )
    SELECT tr."createTime" AS "create_time", tr."updateTime" AS "update_time", tr."deleteTime" AS "delete_time", tr."version" AS "version", tr."remarks" AS "remarks", tr."id" AS "card_id", tr."accountId" AS "account_id", tr."currency" AS "currency", tr."status" AS "status", tr."provider" AS "provider", tr."type" AS "type", tr."token" AS "token", tr."userDeleteTime" AS "user_delete_time", tr."deleteCardTime" AS "delete_card_time", tr."firstSix" AS "first_six", tr."cardBelong" AS "card_belong", tr."physicalCardStatus" AS "physical_card_status", tr."cardMode" AS "card_mode"
    FROM "qbitCard" AS tr
    JOIN affected a ON (tr."id") IS NOT DISTINCT FROM a.k0
    WHERE tr."deleteTime" IS NULL) AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

CREATE TEMPORARY VIEW v_ods_qbit_card_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(card_id, '')))) AS BIGINT) AS id,
    *
FROM source_ods_qbit_card;

CREATE TEMPORARY TABLE sink_ods_qbit_card_2024 (
    id BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version BIGINT, remarks STRING, card_id STRING, account_id STRING, currency STRING, status STRING, provider STRING, type STRING, token STRING, user_delete_time STRING, delete_card_time STRING, first_six STRING, card_belong STRING, physical_card_status STRING, card_mode STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_qbit_card_2024','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_ods_qbit_card_2025 (
    id BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version BIGINT, remarks STRING, card_id STRING, account_id STRING, currency STRING, status STRING, provider STRING, type STRING, token STRING, user_delete_time STRING, delete_card_time STRING, first_six STRING, card_belong STRING, physical_card_status STRING, card_mode STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_qbit_card_2025','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_ods_qbit_card_2026 (
    id BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version BIGINT, remarks STRING, card_id STRING, account_id STRING, currency STRING, status STRING, provider STRING, type STRING, token STRING, user_delete_time STRING, delete_card_time STRING, first_six STRING, card_belong STRING, physical_card_status STRING, card_mode STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_qbit_card_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_ods_qbit_card_2027 (
    id BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version BIGINT, remarks STRING, card_id STRING, account_id STRING, currency STRING, status STRING, provider STRING, type STRING, token STRING, user_delete_time STRING, delete_card_time STRING, first_six STRING, card_belong STRING, physical_card_status STRING, card_mode STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_qbit_card_2027','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

INSERT INTO sink_ods_qbit_card_2024
SELECT id, create_time, update_time, delete_time, version, remarks, card_id, account_id, currency, status, provider, type, token, user_delete_time, delete_card_time, first_six, card_belong, physical_card_status, card_mode
FROM v_ods_qbit_card_base
CROSS JOIN source_delete_ods_qbit_card_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2024-01-01 00:00:00' AND create_time < TIMESTAMP '2025-01-01 00:00:00';
INSERT INTO sink_ods_qbit_card_2025
SELECT id, create_time, update_time, delete_time, version, remarks, card_id, account_id, currency, status, provider, type, token, user_delete_time, delete_card_time, first_six, card_belong, physical_card_status, card_mode
FROM v_ods_qbit_card_base
CROSS JOIN source_delete_ods_qbit_card_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2025-01-01 00:00:00' AND create_time < TIMESTAMP '2026-01-01 00:00:00';
INSERT INTO sink_ods_qbit_card_2026
SELECT id, create_time, update_time, delete_time, version, remarks, card_id, account_id, currency, status, provider, type, token, user_delete_time, delete_card_time, first_six, card_belong, physical_card_status, card_mode
FROM v_ods_qbit_card_base
CROSS JOIN source_delete_ods_qbit_card_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2026-01-01 00:00:00' AND create_time < TIMESTAMP '2027-01-01 00:00:00';
INSERT INTO sink_ods_qbit_card_2027
SELECT id, create_time, update_time, delete_time, version, remarks, card_id, account_id, currency, status, provider, type, token, user_delete_time, delete_card_time, first_six, card_belong, physical_card_status, card_mode
FROM v_ods_qbit_card_base
CROSS JOIN source_delete_ods_qbit_card_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2027-01-01 00:00:00' AND create_time < TIMESTAMP '2028-01-01 00:00:00';
