--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-23
-- 历史名称：sp_init_crypto_assets_transactions_ods.sql
-- 功能：PG业务表 JDBC 批处理同步到 ODS层 ods_crypto_assets_transactions
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
CREATE TEMPORARY TABLE flink_source_crypto_assets_transactions (
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
    'table-name' = '(SELECT * FROM crypto_assets_transactions) AS crypto_assets_transactions_f',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

-- ==============================================
-- 2. 【临时表】ADBPG 目标表 ods.ods_crypto_assets_transactions
-- ==============================================
CREATE TEMPORARY TABLE flink_sink_ods_crypto_assets_transactions (
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
-- 3. 数据同步: submit_time = create_time, dt = create_time::DATE
-- ==============================================
INSERT INTO flink_sink_ods_crypto_assets_transactions
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
FROM flink_source_crypto_assets_transactions;
