--********************************************************************--
-- Author:         martin-dev-log
-- Created Time:   2026-06-16
-- 功能：PG业务表 qbitCardSettlement 实时同步到 ODS层 ods_qbit_card_settlement
-- 作业元信息：
--   作业类型：流处理 CDC
--   运行方式：全量初始化 + 增量实时同步
--   运行参数：无
--   源库变更响应：源库表 INSERT/UPDATE/DELETE 通过 postgres-cdc 同步到 ODS。
--   ODS说明：ODS 原始层优先使用 postgres-cdc，确保原始库表变更能同步到 ods 表。
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
CREATE TEMPORARY TABLE flink_source_qbit_card_settlement (
    id                      STRING,
    remarks                 STRING,
    createTime              TIMESTAMP(6),
    updateTime              TIMESTAMP(6),
    deleteTime              TIMESTAMP(6),
    version                 INT,
    cardHashId              STRING,
    transactionId           STRING,
    referenceNumber         STRING,
    recordType              STRING,
    effectiveDate           STRING,
    batchDate               STRING,
    transactionType         STRING,
    transactionCode         STRING,
    billingAmount           DOUBLE,
    billingCurrencyCode     STRING,
    transactionAmount       DOUBLE,
    transactionCurrencyCode STRING,
    authorizationCode       STRING,
    description             STRING,
    cardAcceptorId          STRING,
    interchangeReference    STRING,
    visaTransactionId       STRING,
    tokenRequestorId        STRING,
    tokenNumber             STRING,
    billingAmountRaw        STRING,
    transactionAmountRaw    STRING,
    rawData                 STRING,
    settlementDay           STRING,
    `hash`                  STRING,
    provider                STRING,
    settleCompleted         BOOLEAN,
    qbitCardTransactionId   STRING,
    compareTime             TIMESTAMP(6),
    id_                     BIGINT,
    statusMessage           STRING,
    country                 STRING,
    mid                     STRING,
    merchantCountry         STRING,
    channel                 STRING,
    wallet                  STRING,
    mcc                     STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = '${secret_values.PG_TEST_HOST}',
    'port' = '${secret_values.PG_TEST_PORT1}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'database-name' = '${secret_values.PG_TEST_DATABASE}',
    'schema-name' = 'public',
    'table-name' = 'qbitCardSettlement',

    'slot.name' = 'flink_slot_qbit_card_settlement_ods_v1',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.connector.pgout.publication.autocreate' = 'false',
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'true',
    'scan.snapshot.fetch.size' = '4096',
    'debezium.field.name.adjustment.mode' = 'none'
);

-- ==============================================
-- 2. 【临时表】ADBPG 目标表 (snake_case)
-- ==============================================
CREATE TEMPORARY TABLE flink_sink_ods_qbit_card_settlement (
    id                      VARCHAR(64) NOT NULL,
    dt                      DATE NOT NULL,
    remarks                 STRING,
    create_time             TIMESTAMP(6),
    update_time             TIMESTAMP(6),
    delete_time             TIMESTAMP(6),
    version                 INTEGER NOT NULL,
    card_hash_id            VARCHAR,
    transaction_id          VARCHAR,
    reference_number        VARCHAR,
    record_type             VARCHAR,
    effective_date          VARCHAR,
    batch_date              VARCHAR,
    transaction_type        VARCHAR,
    transaction_code        VARCHAR,
    billing_amount          DOUBLE PRECISION,
    billing_currency_code   VARCHAR(16),
    transaction_amount      DOUBLE PRECISION,
    transaction_currency_code VARCHAR(16),
    authorization_code      VARCHAR,
    description             STRING,
    card_acceptor_id        VARCHAR,
    interchange_reference   VARCHAR,
    visa_transaction_id     VARCHAR,
    token_requestor_id      VARCHAR,
    token_number            VARCHAR,
    billing_amount_raw      VARCHAR,
    transaction_amount_raw  VARCHAR,
    raw_data                STRING,
    settlement_day          VARCHAR,
    `hash`                  VARCHAR,
    provider                VARCHAR,
    settle_completed        BOOLEAN,
    qbit_card_transaction_id VARCHAR,
    compare_time            TIMESTAMP(6),
    id_                     BIGINT,
    status_message          VARCHAR(255),
    country                 VARCHAR(255),
    mid                     VARCHAR(40),
    merchant_country        VARCHAR(255),
    channel                 VARCHAR(255),
    wallet                  VARCHAR(40),
    mcc                     VARCHAR,
    PRIMARY KEY (id, dt) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'ods_qbit_card_settlement',
    'targetSchema' = 'ods',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '200'
);

-- ==============================================
-- 3. 数据同步：小驼峰 → 蛇形映射 + 字段截断
-- ==============================================
BEGIN STATEMENT SET;
INSERT INTO flink_sink_ods_qbit_card_settlement
SELECT
    id,
    CAST(createTime AS DATE) AS dt,
    CASE WHEN LENGTH(remarks) > 2000 THEN SUBSTRING(remarks, 1, 2000) ELSE remarks END AS remarks,
    createTime                AS create_time,
    updateTime                AS update_time,
    deleteTime                AS delete_time,
    version,
    cardHashId                AS card_hash_id,
    transactionId             AS transaction_id,
    referenceNumber           AS reference_number,
    recordType                AS record_type,
    effectiveDate             AS effective_date,
    batchDate                 AS batch_date,
    transactionType           AS transaction_type,
    transactionCode           AS transaction_code,
    billingAmount             AS billing_amount,
    billingCurrencyCode       AS billing_currency_code,
    transactionAmount         AS transaction_amount,
    transactionCurrencyCode   AS transaction_currency_code,
    authorizationCode         AS authorization_code,
    description,
    cardAcceptorId            AS card_acceptor_id,
    interchangeReference      AS interchange_reference,
    visaTransactionId         AS visa_transaction_id,
    tokenRequestorId          AS token_requestor_id,
    tokenNumber               AS token_number,
    billingAmountRaw          AS billing_amount_raw,
    transactionAmountRaw      AS transaction_amount_raw,
    rawData                   AS raw_data,
    settlementDay             AS settlement_day,
    `hash`,
    provider,
    settleCompleted           AS settle_completed,
    qbitCardTransactionId     AS qbit_card_transaction_id,
    compareTime               AS compare_time,
    id_,
    statusMessage             AS status_message,
    country,
    mid,
    merchantCountry           AS merchant_country,
    channel,
    wallet,
    mcc
FROM flink_source_qbit_card_settlement
WHERE createTime > '2026-06-1'
;
END;
