--********************************************************************
-- Author:         martinJiang
-- Created Time:   2026-08-18
-- Updated Time:   2026-08-18
-- Description:    ods_sale_am_transaction 批处理 作业（quantum-v2 范式：确定性哈希主键 + 先清后写）
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

CREATE TEMPORARY TABLE source_delete_ods_sale_am_transaction_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_ods_sale_am_transaction_cdc(false, CAST(''${start_date}'' AS DATE), CAST(''${end_date}'' AS DATE)) AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

CREATE TEMPORARY TABLE source_ods_sale_am_transaction (
    sale_id STRING,
    am_id STRING,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    remarks STRING,
    version INT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(WITH affected AS (
        SELECT DISTINCT tr.ID AS k0
        FROM "Transaction" tr
LEFT JOIN (
select sar."createTime",sar."deleteTime",sar."salesId",sar."amId",sar."accountId" as "accountId"   
FROM "salesAccountRelation" as sar
UNION ALL
SELECT sar."createTime",sar."deleteTime",sar."salesId",sar."amId",account.id as "accountId"   
FROM account
INNER JOIN "salesAccountRelation" as sar ON sar."accountId"::UUID=account."parentAccountId"::UUID
where account."parentAccountId" !=''00000000-0000-0000-0000-000000000000''   
) AS sar ON tr."accountId" :: UUID = sar."accountId" :: UUID AND tr."createTime" >= sar."createTime" AND ( tr."createTime" <= sar."deleteTime" OR sar."deleteTime" IS NULL )
        WHERE (DATE(tr."createTime") >= CAST(''${start_date}'' AS DATE) AND DATE(tr."createTime") <= CAST(''${end_date}'' AS DATE))
    )
    SELECT sar."salesId" AS sale_id, sar."amId" AS am_id, tr."createTime" as "create_time", NOW( ) AS update_time, -- 默认当前时间
        NULL AS delete_time, -- 逻辑删除字段，默认 NULL
        NULL AS remarks, -- 备注字段，默认 NULL
        1 AS VERSION -- 版本号，默认 1 AS "version"
    FROM "Transaction" tr
LEFT JOIN (
select sar."createTime",sar."deleteTime",sar."salesId",sar."amId",sar."accountId" as "accountId"   
FROM "salesAccountRelation" as sar
UNION ALL
SELECT sar."createTime",sar."deleteTime",sar."salesId",sar."amId",account.id as "accountId"   
FROM account
INNER JOIN "salesAccountRelation" as sar ON sar."accountId"::UUID=account."parentAccountId"::UUID
where account."parentAccountId" !=''00000000-0000-0000-0000-000000000000''   
) AS sar ON tr."accountId" :: UUID = sar."accountId" :: UUID AND tr."createTime" >= sar."createTime" AND ( tr."createTime" <= sar."deleteTime" OR sar."deleteTime" IS NULL )
    JOIN affected a ON (tr.ID) IS NOT DISTINCT FROM a.k0
    WHERE tr."deleteTime" IS NULL) AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

CREATE TEMPORARY VIEW v_ods_sale_am_transaction_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(transaction_id, '')))) AS BIGINT) AS id,
    *
FROM source_ods_sale_am_transaction;

CREATE TEMPORARY TABLE sink_ods_sale_am_transaction_2024 (
    id BIGINT, sale_id STRING, am_id STRING, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), remarks STRING, version INT,
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_sale_am_transaction_2024','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_ods_sale_am_transaction_2025 (
    id BIGINT, sale_id STRING, am_id STRING, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), remarks STRING, version INT,
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_sale_am_transaction_2025','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_ods_sale_am_transaction_2026 (
    id BIGINT, sale_id STRING, am_id STRING, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), remarks STRING, version INT,
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_sale_am_transaction_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

INSERT INTO sink_ods_sale_am_transaction_2024
SELECT id, sale_id, am_id, create_time, update_time, delete_time, remarks, version
FROM v_ods_sale_am_transaction_base
CROSS JOIN source_delete_ods_sale_am_transaction_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2024-01-01 00:00:00' AND create_time < TIMESTAMP '2025-01-01 00:00:00';
INSERT INTO sink_ods_sale_am_transaction_2025
SELECT id, sale_id, am_id, create_time, update_time, delete_time, remarks, version
FROM v_ods_sale_am_transaction_base
CROSS JOIN source_delete_ods_sale_am_transaction_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2025-01-01 00:00:00' AND create_time < TIMESTAMP '2026-01-01 00:00:00';
INSERT INTO sink_ods_sale_am_transaction_2026
SELECT id, sale_id, am_id, create_time, update_time, delete_time, remarks, version
FROM v_ods_sale_am_transaction_base
CROSS JOIN source_delete_ods_sale_am_transaction_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2026-01-01 00:00:00' AND create_time < TIMESTAMP '2027-01-01 00:00:00';
