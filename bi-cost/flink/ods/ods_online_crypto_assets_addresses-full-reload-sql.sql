--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-04
-- Updated Time:   2026-08-04 18:20:00
-- Description:    crypto_assets_addresses -> ods.ods_crypto_assets_addresses 全量重洗
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性全量重洗
--   运行参数：无
--   源库变更响应：本脚本不消费 CDC WAL；持续增量仍由 ods_online_crypto_assets_addresses-cdc-sql.sql 承担。
--   ODS说明：字段映射与 CDC 脚本保持一致，dt = create_time::DATE，submit_time = create_time。
-- Notes:
--   1. 运行前先暂停 ods_online_crypto_assets_addresses CDC 作业，避免全量清理与实时写入并发。
--   2. 本脚本先删除 ods.ods_crypto_assets_addresses 现有 2022-2026 分区数据，再从源库全量插入。
--   3. 运行完成并核对数据后，再重新启动 CDC 作业。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'sink.parallelism' = '1';
SET 'table.dml-sync' = 'true';
SET 'execution.application-management.enabled' = 'true';
SET 'execution.multi-jobs-in-application.enable' = 'true';
SET 'pipeline.operator-chaining' = 'false';
SET 'execution.checkpointing.interval' = '5min';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'execution.checkpointing.timeout' = '30min';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '1';
SET 'restart-strategy.fixed-delay.delay' = '60s';

-- ==============================================
-- 1. PG 源表（JDBC 批读），字段口径对齐 CDC 源表
-- ==============================================
CREATE TEMPORARY TABLE source_crypto_assets_addresses (
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
    'table-name' = '(SELECT id, create_time, update_time, delete_time, version, account_id, wallet_id, chain, currency, address, address_tag, remarks, enable, selected, platform, account_key FROM public.crypto_assets_addresses WHERE create_time IS NOT NULL) AS crypto_assets_addresses_f',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

-- ==============================================
-- 2. ADBPG 目标表 ods.ods_crypto_assets_addresses
-- ==============================================
CREATE TEMPORARY TABLE sink_ods_crypto_assets_addresses (
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
    'batchSize' = '2000'
);

-- ==============================================
-- 3. 清理目标历史数据
-- ==============================================
DELETE FROM sink_ods_crypto_assets_addresses
WHERE dt >= DATE '2022-01-01'
  AND dt < DATE '2027-01-01';

-- ==============================================
-- 4. 全量重插，映射与 CDC 保持一致
-- ==============================================
INSERT INTO sink_ods_crypto_assets_addresses
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
FROM source_crypto_assets_addresses;
