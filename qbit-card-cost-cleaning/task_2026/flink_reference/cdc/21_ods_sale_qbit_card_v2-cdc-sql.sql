-- [TODO] ods_sale_qbit_card 检测到嵌套/非标准 FROM（"qbitCard" AS tr
LEFT JOIN (
    SELECT ...），
--        删除函数的变更窗口与聚合子查询的源别名引用可能需要人工校准，上线前务必核对。
--********************************************************************
-- Author:         martinJiang
-- Created Time:   2026-08-18
-- Updated Time:   2026-08-18
-- Description:    ods_sale_qbit_card 流处理(CDC) 作业（quantum-v2 范式：确定性哈希主键 + 先清后写）
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

-- ==============================================
-- 0. 先调用删除函数：按唯一业务键精准清空受影响分表行（先清后写，保证幂等）
-- ==============================================
CREATE TEMPORARY TABLE source_delete_ods_sale_qbit_card_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_ods_sale_qbit_card_cdc(false) AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

-- ==============================================
-- 1. 源聚合（留在 PostgreSQL 内执行，复用原版聚合逻辑；只回传受影响 key 的聚合结果）
-- ==============================================
CREATE TEMPORARY TABLE source_ods_sale_qbit_card (
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    version BIGINT,
    remarks STRING,
    sale_or_am_id STRING,
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
        SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account FROM "qbitCard" AS tr
LEFT JOIN (
    SELECT sar."createTime", sar."deleteTime", sar."salesId", sar."amId", sar."accountId" AS "accountId"   
    FROM "salesAccountRelation" AS sar
    UNION ALL
    SELECT sar."createTime", sar."deleteTime", sar."salesId", sar."amId", account.id AS "accountId"   
    FROM account
    INNER JOIN "salesAccountRelation" AS sar ON sar."accountId"::UUID = account."parentAccountId"::UUID
    WHERE account."parentAccountId" != ''00000000-0000-0000-0000-000000000000''
) AS sar ON tr."accountId"::UUID = sar."accountId"::UUID
AND tr."createTime" >= sar."createTime" AND (tr."createTime" <= sar."deleteTime" OR sar."deleteTime" IS NULL)
LEFT JOIN LATERAL (SELECT unnest(ARRAY[sar."salesId"::uuid, sar."amId"::uuid]) AS sale_or_am_id) AS ids ON TRUE WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."deleteTime" < CURRENT_DATE)
    )
    SELECT tr."createTime" AS "create_time", tr."updateTime" AS "update_time", tr."deleteTime" AS "delete_time", tr."version" AS "version", tr."remarks" AS "remarks", ids."sale_or_am_id" AS "sale_or_am_id", tr."id" AS "card_id", tr."accountId" AS "account_id", tr."currency" AS "currency", tr."status" AS "status", tr."provider" AS "provider", tr."type" AS "type", tr."token" AS "token", tr."userDeleteTime" AS "user_delete_time", tr."deleteCardTime" AS "delete_card_time", tr."firstSix" AS "first_six", tr."cardBelong" AS "card_belong", tr."physicalCardStatus" AS "physical_card_status", tr."cardMode" AS "card_mode"
    FROM "qbitCard" AS tr
LEFT JOIN (
    SELECT sar."createTime", sar."deleteTime", sar."salesId", sar."amId", sar."accountId" AS "accountId"   
    FROM "salesAccountRelation" AS sar
    UNION ALL
    SELECT sar."createTime", sar."deleteTime", sar."salesId", sar."amId", account.id AS "accountId"   
    FROM account
    INNER JOIN "salesAccountRelation" AS sar ON sar."accountId"::UUID = account."parentAccountId"::UUID
    WHERE account."parentAccountId" != ''00000000-0000-0000-0000-000000000000''
) AS sar ON tr."accountId"::UUID = sar."accountId"::UUID
AND tr."createTime" >= sar."createTime" AND (tr."createTime" <= sar."deleteTime" OR sar."deleteTime" IS NULL)
LEFT JOIN LATERAL (SELECT unnest(ARRAY[sar."salesId"::uuid, sar."amId"::uuid]) AS sale_or_am_id) AS ids ON TRUE
    JOIN affected a ON (DATE(tr."createTime")) = a.scope_date AND (tr."accountId") = a.scope_account
    WHERE tr."deleteTime" IS NULL) AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

-- ==============================================
-- 2. 聚合结果视图：计算确定性主键 id = HASH(业务键)
--    （source_ods_sale_qbit_card 已输出聚合列，此处只补 id；列名与 DWS 表一致）
-- ==============================================
CREATE TEMPORARY VIEW v_ods_sale_qbit_card_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(card_id, '')))) AS BIGINT) AS id,
    *
FROM source_ods_sale_qbit_card;

-- ==============================================
-- 3. 分表 SINK（每个 _YYYY 一个，upsert 按 key 幂等）
-- ==============================================
CREATE TEMPORARY TABLE sink_ods_sale_qbit_card_2024 (
    id BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version BIGINT, remarks STRING, sale_or_am_id STRING, card_id STRING, account_id STRING, currency STRING, status STRING, provider STRING, type STRING, token STRING, user_delete_time STRING, delete_card_time STRING, first_six STRING, card_belong STRING, physical_card_status STRING, card_mode STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_sale_qbit_card_2024','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_ods_sale_qbit_card_2025 (
    id BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version BIGINT, remarks STRING, sale_or_am_id STRING, card_id STRING, account_id STRING, currency STRING, status STRING, provider STRING, type STRING, token STRING, user_delete_time STRING, delete_card_time STRING, first_six STRING, card_belong STRING, physical_card_status STRING, card_mode STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_sale_qbit_card_2025','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_ods_sale_qbit_card_2026 (
    id BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version BIGINT, remarks STRING, sale_or_am_id STRING, card_id STRING, account_id STRING, currency STRING, status STRING, provider STRING, type STRING, token STRING, user_delete_time STRING, delete_card_time STRING, first_six STRING, card_belong STRING, physical_card_status STRING, card_mode STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_sale_qbit_card_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_ods_sale_qbit_card_2027 (
    id BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version BIGINT, remarks STRING, sale_or_am_id STRING, card_id STRING, account_id STRING, currency STRING, status STRING, provider STRING, type STRING, token STRING, user_delete_time STRING, delete_card_time STRING, first_six STRING, card_belong STRING, physical_card_status STRING, card_mode STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_sale_qbit_card_2027','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

-- ==============================================
-- 4. 写入（CROSS JOIN 确保删除函数先执行；upsert 覆盖同 key / 新增异 key）
-- ==============================================
INSERT INTO sink_ods_sale_qbit_card_2024
SELECT id, create_time, update_time, delete_time, version, remarks, sale_or_am_id, card_id, account_id, currency, status, provider, type, token, user_delete_time, delete_card_time, first_six, card_belong, physical_card_status, card_mode
FROM v_ods_sale_qbit_card_base
CROSS JOIN source_delete_ods_sale_qbit_card_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2024-01-01 00:00:00' AND create_time < TIMESTAMP '2025-01-01 00:00:00';
INSERT INTO sink_ods_sale_qbit_card_2025
SELECT id, create_time, update_time, delete_time, version, remarks, sale_or_am_id, card_id, account_id, currency, status, provider, type, token, user_delete_time, delete_card_time, first_six, card_belong, physical_card_status, card_mode
FROM v_ods_sale_qbit_card_base
CROSS JOIN source_delete_ods_sale_qbit_card_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2025-01-01 00:00:00' AND create_time < TIMESTAMP '2026-01-01 00:00:00';
INSERT INTO sink_ods_sale_qbit_card_2026
SELECT id, create_time, update_time, delete_time, version, remarks, sale_or_am_id, card_id, account_id, currency, status, provider, type, token, user_delete_time, delete_card_time, first_six, card_belong, physical_card_status, card_mode
FROM v_ods_sale_qbit_card_base
CROSS JOIN source_delete_ods_sale_qbit_card_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2026-01-01 00:00:00' AND create_time < TIMESTAMP '2027-01-01 00:00:00';
INSERT INTO sink_ods_sale_qbit_card_2027
SELECT id, create_time, update_time, delete_time, version, remarks, sale_or_am_id, card_id, account_id, currency, status, provider, type, token, user_delete_time, delete_card_time, first_six, card_belong, physical_card_status, card_mode
FROM v_ods_sale_qbit_card_base
CROSS JOIN source_delete_ods_sale_qbit_card_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2027-01-01 00:00:00' AND create_time < TIMESTAMP '2028-01-01 00:00:00';
