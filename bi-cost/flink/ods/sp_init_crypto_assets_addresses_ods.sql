--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-22
-- 功能：PG业务表 crypto_assets_addresses 实时同步到 ODS层 ods_crypto_assets_addresses
-- 模式：全量初始化 + 增量实时同步 | 支持 Upsert/Delete
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
    'connector' = 'postgres-cdc',
    'hostname' = '${secret_values.PG_TEST_HOST}',
    'port' = '${secret_values.PG_TEST_PORT1}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'database-name' = '${secret_values.PG_TEST_DATABASE}',
    'schema-name' = 'public',
    'table-name' = 'crypto_assets_addresses',

    'slot.name' = 'flink_slot_crypto_assets_addresses_ods_v1',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.connector.pgout.publication.autocreate' = 'false',
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'true',
    'scan.snapshot.fetch.size' = '4096',
    'debezium.field.name.adjustment.mode' = 'none'
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
