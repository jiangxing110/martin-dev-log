--********************************************************************--
-- Author:         martin-dev-log
-- Created Time:   2026-06-16
-- 历史名称：sp_sync_qbit_card_settlement_ods.sql
-- 功能：PG业务表 JDBC 批处理同步到 ODS层 ods_qbit_card_settlement
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
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.PG_TEST_HOST}:${secret_values.PG_TEST_PORT1}/${secret_values.PG_TEST_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT * FROM "qbitCardSettlement") AS qbitCardSettlement_f',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
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
WHERE createTime >= CAST('${start_time}' AS TIMESTAMP(6))
  AND createTime < CAST('${end_time}' AS TIMESTAMP(6))
;
