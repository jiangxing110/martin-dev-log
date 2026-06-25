--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-22
-- 历史名称：sp_init_crypto_assets_addresses_ods.sql
-- 功能：PG业务表 JDBC 批处理同步到 ODS层 ods_crypto_assets_addresses
-- 作业元信息：
--   作业类型：批处理
--   运行方式：调度执行，按 start_date / end_date 窗口回刷
--   运行参数：start_date, end_date
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑。
--   ODS说明：ODS 原始层保存源表原始数据，用于下游 DWD/DWM/DWS 加工。
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
-- 1. 【临时表】PG 源表 (JDBC 批处理)
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
    'url' = 'jdbc:postgresql://${secret_values.PG_TEST_HOST}:${secret_values.PG_TEST_PORT1}/${secret_values.PG_TEST_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT * FROM crypto_assets_addresses) AS crypto_assets_addresses_f',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
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
