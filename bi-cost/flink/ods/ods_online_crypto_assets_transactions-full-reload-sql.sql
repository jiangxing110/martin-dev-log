--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-05
-- Updated Time:   2026-08-05 00:00:00
-- Description:    crypto_assets_transactions -> ods.ods_crypto_assets_transactions 全量回灌
-- 作业元信息：
--   作业类型：批处理
--   运行方式：手动清表后一次性全量回灌
--   运行参数：无
--   源库变更响应：本脚本不消费 CDC WAL；持续增量仍由 ods_online_crypto_assets_transactions-cdc-sql.sql 承担。
--   ODS说明：字段映射与 CDC 脚本保持一致，dt = create_time::DATE，submit_time = create_time。
-- Notes:
--   1. 运行前先暂停 ods_online_crypto_assets_transactions CDC 作业。
--   2. 先在 ADBPG 手动执行：
--      DELETE FROM ods.ods_crypto_assets_transactions WHERE dt >= DATE '1970-01-01' AND dt < DATE '2027-01-01';
--   3. 再运行本脚本全量回灌。
--   4. 运行完成并核对数据后，再重新启动 CDC 作业。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'sink.parallelism' = '1';
SET 'table.dml-sync' = 'true';
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
CREATE TEMPORARY TABLE source_crypto_assets_transactions (
    id                       STRING,
    trade_id                 STRING,
    source_type              STRING,
    source_id                STRING,
    destination_type         STRING,
    destination_id           STRING,
    destination_address      STRING,
    amount                   STRING,
    fee                      STRING,
    total_amount             STRING,
    transaction_hash         STRING,
    status                   STRING,
    create_time              TIMESTAMP(6),
    update_time              TIMESTAMP(6),
    delete_time              TIMESTAMP(6),
    version                  INT,
    chain                    STRING,
    currency                 STRING,
    source_address           STRING,
    platform                 STRING,
    aggregation              BOOLEAN,
    remarks                  STRING,
    aml_lock                 BOOLEAN,
    risk_level               STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.PG_TEST_HOST}:${secret_values.PG_TEST_PORT1}/${secret_values.PG_TEST_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, trade_id, source_type, source_id, destination_type, destination_id, destination_address, amount::text AS amount, fee::text AS fee, total_amount::text AS total_amount, transaction_hash, status, create_time, update_time, delete_time, version, chain, currency, source_address, platform, aggregation, remarks, aml_lock, risk_level FROM public.crypto_assets_transactions WHERE create_time IS NOT NULL) AS crypto_assets_transactions_f',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

-- ==============================================
-- 2. ADBPG 目标表 ods.ods_crypto_assets_transactions
-- ==============================================
CREATE TEMPORARY TABLE sink_ods_crypto_assets_transactions (
    id                       STRING,
    dt                       DATE,
    trade_id                 STRING,
    source_type              STRING,
    source_id                STRING,
    destination_type         STRING,
    destination_id           STRING,
    destination_address      STRING,
    amount                   DECIMAL(38, 18),
    fee                      DECIMAL(38, 18),
    total_amount             DECIMAL(38, 18),
    transaction_hash         STRING,
    status                   STRING,
    create_time              TIMESTAMP(6),
    update_time              TIMESTAMP(6),
    delete_time              TIMESTAMP(6),
    version                  INT,
    chain                    STRING,
    currency                 STRING,
    source_address           STRING,
    platform                 STRING,
    aggregation              BOOLEAN,
    remarks                  STRING,
    aml_lock                 BOOLEAN,
    risk_level               STRING,
    submit_time              TIMESTAMP(6),
    PRIMARY KEY (id, dt) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'ods_crypto_assets_transactions',
    'targetSchema' = 'ods',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

-- ==============================================
-- 3. 全量回灌，映射与 CDC 保持一致
-- ==============================================
INSERT INTO sink_ods_crypto_assets_transactions
SELECT
    id,
    CAST(create_time AS DATE) AS dt,
    trade_id,
    source_type,
    source_id,
    destination_type,
    destination_id,
    destination_address,
    CAST(amount AS DECIMAL(38, 18)) AS amount,
    CAST(fee AS DECIMAL(38, 18)) AS fee,
    CAST(total_amount AS DECIMAL(38, 18)) AS total_amount,
    transaction_hash,
    status,
    create_time,
    update_time,
    delete_time,
    version,
    chain,
    currency,
    source_address,
    platform,
    aggregation,
    remarks,
    aml_lock,
    risk_level,
    create_time AS submit_time
FROM source_crypto_assets_transactions;
