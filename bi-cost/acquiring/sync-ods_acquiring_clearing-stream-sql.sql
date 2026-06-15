--********************************************************************--
-- Author:         zhanghaoran
-- Created Time:   2026-06-01 16:22:45
-- Description:    收单
-- Hints:          You can use SET statements to modify the configuration
--********************************************************************--


-- 配置
SET 'parallelism.default' = '1';

SET 'execution.checkpointing.mode' = 'EXACTLY_ONCE';
SET 'execution.checkpointing.interval' = '30s';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'execution.checkpointing.timeout' = '10min';

SET 'table.exec.mini-batch.enabled' = 'false';

-- SET 'table.exec.mini-batch.enabled' = 'true';
-- SET 'table.exec.mini-batch.allow-latency' = '5s';
-- SET 'table.exec.mini-batch.size' = '4000';
--source

CREATE TEMPORARY TABLE tmp_acquiring_clearing (
    id BIGINT,
    create_time BIGINT, -- STRING
    update_time BIGINT,
    delete_time BIGINT,
    remarks STRING,
    version INT,

    acquiring_id BIGINT,
    acquiring_pay_index_id BIGINT,
    merchant_trade_no STRING,
    channel_id BIGINT,
    method_id BIGINT,
    account_id BIGINT,
    account_type SMALLINT,

    acquiring_amount STRING, --DECIMAL(38, 18),
    acquiring_usd_amount STRING, --DECIMAL(38, 18),
    acquiring_currency STRING,
    settle_currency STRING,
    transaction_type SMALLINT,

    card_scheme_fee STRING, --DECIMAL(38, 18),
    issuing_bank_fee STRING, --DECIMAL(38, 18),
    tax_fee STRING, --DECIMAL(38, 18),
    miscellaneous_fee STRING, --DECIMAL(38, 18),
    fix_fee STRING, --DECIMAL(38, 18),
    percent_fee STRING, --DECIMAL(38, 18),
    back_fix_fee STRING, --DECIMAL(38, 18),
    back_percent_fee STRING, --DECIMAL(38, 18),

    fix_fee_id BIGINT,
    percent_fee_id BIGINT,
    fee_currency_rate_id BIGINT,
    amount_currency_rate_id BIGINT,
    margin_amount STRING, --DECIMAL(38, 18),

    clear_time BIGINT,
    clear_status SMALLINT,
    settle_id BIGINT,
    expect_settle_time BIGINT,
    settle_time BIGINT,
    settle_status SMALLINT,

    check_id BIGINT,
    check_time BIGINT,
    check_status SMALLINT,
    order_complete_time BIGINT,
    second_clear_time BIGINT,
    channel_fee_currency_rate_id BIGINT,
    source_type STRING,
    tenant_id BIGINT,

    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = '${secret_values.PG_PAY_PROD_HOST_TEST}',
    'port' = '${secret_values.PG_PAY_PROD_PORT_TEST}',
    'username' = '${secret_values.PG_PAY_PROD_USERNAME_TEST}',
    'password' = '${secret_values.PG_PAY_PROD_PWD_TEST}',
    'database-name' = '${secret_values.PG_PAY_PROD_DATABASE_TEST}',
    'schema-name' = 'public',
    'table-name' = 'acquiring_clearing',

    'slot.name' = 'flink_slot_ods_acquiring_clearing',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.slot.drop.on.stop' = 'true',

    'debezium.decimal.handling.mode' = 'string',-- 所有 decimal 字段将以字符串形式传递，下游 Calc 算子或 Sink 里再进行转换，就不会再抛出反序列化异常。
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'false',  -- true
    -- 'scan.incremental.snapshot.chunk.key-column' = 'id',
    'scan.incremental.snapshot.chunk.size' = '10000',
    'scan.snapshot.fetch.size' = '5000'
);


CREATE TEMPORARY TABLE ods_acquiring_clearing
(
    id                           BIGINT,
    create_time                  BIGINT,
    update_time                  BIGINT,
    delete_time                  BIGINT,
    remarks                      STRING,
    version                      INT,

    acquiring_id                 BIGINT,
    acquiring_pay_index_id       BIGINT,
    merchant_trade_no            STRING,
    channel_id                   BIGINT,
    method_id                    BIGINT,
    account_id                   BIGINT,
    account_type                 INT,

    acquiring_amount             DECIMAL(38, 18),
    acquiring_usd_amount         DECIMAL(38, 18),
    acquiring_currency           STRING,
    settle_currency              STRING,
    transaction_type             INT,

    card_scheme_fee              DECIMAL(38, 18),
    issuing_bank_fee             DECIMAL(38, 18),
    tax_fee                      DECIMAL(38, 18),
    miscellaneous_fee            DECIMAL(38, 18),
    fix_fee                      DECIMAL(38, 18),
    percent_fee                  DECIMAL(38, 18),
    back_fix_fee                 DECIMAL(38, 18),
    back_percent_fee             DECIMAL(38, 18),

    fix_fee_id                   BIGINT,
    percent_fee_id               BIGINT,
    fee_currency_rate_id         BIGINT,
    amount_currency_rate_id      BIGINT,
    margin_amount                DECIMAL(38, 18),

    clear_time                   BIGINT,
    clear_status                 INT,
    settle_id                    BIGINT,
    expect_settle_time           BIGINT,
    settle_time                  BIGINT,
    settle_status                INT,

    check_id                     BIGINT,
    check_time                   BIGINT,
    check_status                 INT,
    order_complete_time          BIGINT,
    second_clear_time            BIGINT,
    channel_fee_currency_rate_id BIGINT,

    source_type                  STRING,
    tenant_id                    BIGINT,

    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'tableName' = 'ods_acquiring_clearing',
    'targetSchema' = 'ods',
    'writeMode' = 'upsert',
    'conflictMode' = 'upsert',
    'batchSize' = '2000',
    'flushIntervalMs' = '3000',
    'connectionMaxActive' = '2',
    'maxRetryTimes' = '3'
);



INSERT INTO ods_acquiring_clearing
SELECT
    id,
    create_time,
    update_time,
    delete_time,
    remarks,
    version,

    acquiring_id,
    acquiring_pay_index_id,
    merchant_trade_no,
    channel_id,
    method_id,
    account_id,
    CAST(account_type AS INT) AS account_type,

    -- acquiring_amount,
    -- acquiring_usd_amount,
    CAST(acquiring_amount AS DECIMAL(38,18)) AS acquiring_amount,
    CAST(acquiring_usd_amount AS DECIMAL(38,18)) AS acquiring_usd_amount,
    acquiring_currency,
    settle_currency,
    CAST(transaction_type AS INT) AS transaction_type,
    -- card_scheme_fee,
    -- issuing_bank_fee,
    -- tax_fee,
    -- miscellaneous_fee,
    -- fix_fee,
    -- percent_fee,
    -- back_fix_fee,
    -- back_percent_fee,
    CAST(card_scheme_fee AS DECIMAL(38,18)) AS card_scheme_fee,
    CAST(issuing_bank_fee AS DECIMAL(38,18)) AS issuing_bank_fee,
    CAST(tax_fee AS DECIMAL(38,18)) AS tax_fee,
    CAST(miscellaneous_fee AS DECIMAL(38,18)) AS miscellaneous_fee,
    CAST(fix_fee AS DECIMAL(38,18)) AS fix_fee,
    CAST(percent_fee AS DECIMAL(38,18)) AS percent_fee,
    CAST(back_fix_fee AS DECIMAL(38,18)) AS back_fix_fee,
    CAST(back_percent_fee AS DECIMAL(38,18)) AS back_percent_fee,

    fix_fee_id,
    percent_fee_id,
    fee_currency_rate_id,
    amount_currency_rate_id,
    -- margin_amount,
    CAST(margin_amount AS DECIMAL(38,18)) AS margin_amount,

    clear_time,
    CAST(clear_status AS INT) AS clear_status,
    settle_id,
    expect_settle_time,
    settle_time,
    CAST(settle_status AS INT) AS settle_status,

    check_id,
    check_time,
    CAST(check_status AS INT) AS check_status,
    order_complete_time,
    second_clear_time,
    channel_fee_currency_rate_id,

    source_type,
    tenant_id
FROM tmp_acquiring_clearing;
-- WHERE create_time >= 1767225600000; -- 大于等于2026-01-01




