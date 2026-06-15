--********************************************************************--
-- Author:         zhanghaoran
-- Created Time:   2026-06-02 18:13:45
-- Description:    Write your description here
-- Hints:          You can use SET statements to modify the configuration
--********************************************************************--


-- 核心配置
SET 'parallelism.default' = '1';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.sink.upsert-materialize' = 'NONE'; 
SET 'table.dynamic-table-options.enabled' = 'true';
SET 'sql-client.execution.result-mode' = 'tableau';
SET 'table.exec.sink.not-null-enforcer' = 'DROP';
-- 重启策略
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';


CREATE TEMPORARY TABLE source_acquiring_clearing (
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
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.PG_TEST_HOST}:${secret_values.PG_TEST_PORT1}/${secret_values.PG_TEST_DATABASE}?stringtype=unspecified',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'table-name' = 'public.acquiring_clearing',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_dwd_acquiring_clearing AS
SELECT
    id,
    create_time,
    update_time,
    delete_time,
    CAST(TO_TIMESTAMP_LTZ(create_time, 3) AS TIMESTAMP(3)) AS create_timestamp,
    CAST(TO_TIMESTAMP_LTZ(create_time, 3) AS DATE) AS create_date,
    remarks,
    version,
    acquiring_id,
    acquiring_pay_index_id,
    merchant_trade_no,
    channel_id,
    method_id,
    account_id,
    account_type,
    CAST(COALESCE(acquiring_amount, CAST(0 AS DECIMAL(38, 18))) AS DECIMAL(20, 4)) AS acquiring_amount,
    CAST(COALESCE(acquiring_usd_amount, CAST(0 AS DECIMAL(38, 18))) AS DECIMAL(20, 4)) AS acquiring_usd_amount,
    acquiring_currency,
    settle_currency,
    transaction_type,
    CAST(COALESCE(card_scheme_fee, CAST(0 AS DECIMAL(38, 18))) AS DECIMAL(20, 4)) AS card_scheme_fee,
    CAST(COALESCE(issuing_bank_fee, CAST(0 AS DECIMAL(38, 18))) AS DECIMAL(20, 4)) AS issuing_bank_fee,
    CAST(COALESCE(tax_fee, CAST(0 AS DECIMAL(38, 18))) AS DECIMAL(20, 4)) AS tax_fee,
    CAST(COALESCE(miscellaneous_fee, CAST(0 AS DECIMAL(38, 18))) AS DECIMAL(20, 4)) AS miscellaneous_fee,
    CAST(COALESCE(fix_fee, CAST(0 AS DECIMAL(38, 18))) AS DECIMAL(20, 4)) AS fix_fee,
    CAST(COALESCE(percent_fee, CAST(0 AS DECIMAL(38, 18))) AS DECIMAL(20, 4)) AS percent_fee,
    CAST(COALESCE(back_fix_fee, CAST(0 AS DECIMAL(38, 18))) AS DECIMAL(20, 4)) AS back_fix_fee,
    CAST(COALESCE(back_percent_fee, CAST(0 AS DECIMAL(38, 18))) AS DECIMAL(20, 4)) AS back_percent_fee,
    CAST(COALESCE(card_scheme_fee, CAST(0 AS DECIMAL(38, 18)))
      + COALESCE(issuing_bank_fee, CAST(0 AS DECIMAL(38, 18)))
      + COALESCE(tax_fee, CAST(0 AS DECIMAL(38, 18)))
      + COALESCE(miscellaneous_fee, CAST(0 AS DECIMAL(38, 18)))
      + COALESCE(fix_fee, CAST(0 AS DECIMAL(38, 18)))
      + COALESCE(percent_fee, CAST(0 AS DECIMAL(38, 18)))
      + COALESCE(back_fix_fee, CAST(0 AS DECIMAL(38, 18)))
      + COALESCE(back_percent_fee, CAST(0 AS DECIMAL(38, 18))) AS DECIMAL(20, 4)) AS total_fee_amount,
    fix_fee_id,
    percent_fee_id,
    fee_currency_rate_id,
    amount_currency_rate_id,
    CAST(COALESCE(margin_amount, CAST(0 AS DECIMAL(38, 18))) AS DECIMAL(20, 4)) AS margin_amount,
    clear_time,
    clear_status,
    settle_id,
    expect_settle_time,
    settle_time,
    settle_status,
    check_id,
    check_time,
    check_status,
    order_complete_time,
    second_clear_time,
    channel_fee_currency_rate_id,
    source_type,
    tenant_id,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS etl_time
FROM source_acquiring_clearing;

CREATE TEMPORARY TABLE sink_ods_acquiring_clearing (
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
    tenant_id                    BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'ods.ods_acquiring_clearing',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'sink.buffer-flush.max-rows' = '2000',
    'sink.buffer-flush.interval' = '3000'
);

CREATE TEMPORARY TABLE sink_dwd_acquiring_clearing (
    id                           BIGINT,
    create_time                  BIGINT,
    update_time                  BIGINT,
    delete_time                  BIGINT,
    create_timestamp             TIMESTAMP(3),
    create_date                  DATE,
    remarks                      STRING,
    version                      INT,
    acquiring_id                 BIGINT,
    acquiring_pay_index_id       BIGINT,
    merchant_trade_no            STRING,
    channel_id                   BIGINT,
    method_id                    BIGINT,
    account_id                   BIGINT,
    account_type                 INT,
    acquiring_amount             DECIMAL(20, 4),
    acquiring_usd_amount         DECIMAL(20, 4),
    acquiring_currency           STRING,
    settle_currency              STRING,
    transaction_type             INT,
    card_scheme_fee              DECIMAL(20, 4),
    issuing_bank_fee             DECIMAL(20, 4),
    tax_fee                      DECIMAL(20, 4),
    miscellaneous_fee            DECIMAL(20, 4),
    fix_fee                      DECIMAL(20, 4),
    percent_fee                  DECIMAL(20, 4),
    back_fix_fee                 DECIMAL(20, 4),
    back_percent_fee             DECIMAL(20, 4),
    total_fee_amount             DECIMAL(20, 4),
    fix_fee_id                   BIGINT,
    percent_fee_id               BIGINT,
    fee_currency_rate_id         BIGINT,
    amount_currency_rate_id      BIGINT,
    margin_amount                DECIMAL(20, 4),
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
    etl_time                     TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'dwd.dwd_acquiring_clearing',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'sink.buffer-flush.max-rows' = '2000',
    'sink.buffer-flush.interval' = '3000'
);

BEGIN STATEMENT SET;

INSERT INTO sink_ods_acquiring_clearing
SELECT
    id, create_time, update_time, delete_time, remarks, version, acquiring_id,
    acquiring_pay_index_id, merchant_trade_no, channel_id, method_id, account_id,
    account_type, acquiring_amount, acquiring_usd_amount, acquiring_currency,
    settle_currency, transaction_type, card_scheme_fee, issuing_bank_fee, tax_fee,
    miscellaneous_fee, fix_fee, percent_fee, back_fix_fee, back_percent_fee,
    fix_fee_id, percent_fee_id, fee_currency_rate_id, amount_currency_rate_id,
    margin_amount, clear_time, clear_status, settle_id, expect_settle_time,
    settle_time, settle_status, check_id, check_time, check_status,
    order_complete_time, second_clear_time, channel_fee_currency_rate_id,
    source_type, tenant_id
FROM source_acquiring_clearing;

INSERT INTO sink_dwd_acquiring_clearing
SELECT * FROM v_dwd_acquiring_clearing;

END;
