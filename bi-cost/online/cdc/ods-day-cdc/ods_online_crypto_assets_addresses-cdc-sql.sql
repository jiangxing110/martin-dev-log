--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-22
-- 历史名称：sp_init_crypto_assets_addresses_ods.sql
-- 功能：PG业务表 crypto_assets_addresses 实时同步到 ODS层 ods_crypto_assets_addresses
-- 作业元信息：
--   作业类型：批处理
--   运行方式：JDBC 批读 + ADBPG upsert
--   运行参数：无（固定同步前一天）
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑。
--   ODS说明：用于初始化、补数和全量回刷 ODS 原始层。
-- 模式：JDBC 批读 + ADBPG upsert | 全量刷新
----------------------------------------------------------------------

SET 'parallelism.default' = '1';
SET 'execution.checkpointing.interval' = '10s';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'execution.checkpointing.timeout' = '30min';

SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';

-- ==============================================
-- 1. 【临时表】PG CDC 源表
-- ==============================================
CREATE TEMPORARY TABLE flink_source_crypto_assets_addresses (
    id                       STRING,
    create_time              TIMESTAMP(6),
    update_time              TIMESTAMP(6),
    delete_time              TIMESTAMP(6),
    version                  INT,
    account_id               STRING,
    wallet_id                STRING,
    chain                    STRING,
    currency                 STRING,
    address                  STRING,
    address_tag              STRING,
    remarks                  STRING,
    enable                   BOOLEAN,
    selected                 BOOLEAN,
    platform                 STRING,
    account_key              STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.PG_TEST_HOST}:${secret_values.PG_TEST_PORT1}/${secret_values.PG_TEST_DATABASE}',
    'table-name' = '(SELECT "id"::text AS "id", "create_time", "update_time", "delete_time", "version", "account_id"::text AS "account_id", "wallet_id"::text AS "wallet_id", "chain"::text AS "chain", "currency"::text AS "currency", "address"::text AS "address", "address_tag"::text AS "address_tag", "remarks"::text AS "remarks", "enable", "selected", "platform"::text AS "platform", "account_key"::text AS "account_key" FROM public."crypto_assets_addresses" WHERE (("create_time" >= CURRENT_DATE - INTERVAL ''1 day'' AND "create_time" < CURRENT_DATE) OR ("update_time" >= CURRENT_DATE - INTERVAL ''1 day'' AND "update_time" < CURRENT_DATE))) AS ods_online_crypto_assets_addresses_f',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000',
    'scan.auto-commit' = 'false'
);

-- ==============================================
-- 2. 【临时表】ADBPG 目标表 ods.ods_crypto_assets_addresses
-- ==============================================
CREATE TEMPORARY TABLE flink_sink_ods_crypto_assets_addresses (
    id                       STRING,
    dt                       DATE,
    create_time              TIMESTAMP(6),
    update_time              TIMESTAMP(6),
    delete_time              TIMESTAMP(6),
    version                  INT,
    account_id               STRING,
    wallet_id                STRING,
    chain                    STRING,
    currency                 STRING,
    address                  STRING,
    address_tag              STRING,
    remarks                  STRING,
    enable                   BOOLEAN,
    selected                 BOOLEAN,
    platform                 STRING,
    account_key              STRING,
    submit_time              TIMESTAMP(6),
    PRIMARY KEY (id, dt) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'ods_crypto_assets_addresses',
    'targetSchema' = 'ods',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '200'
);

-- ==============================================
-- 3. 数据同步: submit_time = create_time, dt = create_time::DATE
-- ==============================================
INSERT INTO flink_sink_ods_crypto_assets_addresses
SELECT
    id,
    CAST(create_time AS DATE) AS dt,
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
    create_time AS submit_time
FROM flink_source_crypto_assets_addresses;
