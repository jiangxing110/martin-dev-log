--********************************************************************--
-- Author:         zhanghaoran
-- Created Time:   2026-06-09 13:46:55
-- Description:    Write your description here
-- Hints:          You can use SET statements to modify the configuration
--********************************************************************--
SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
-- SET 'pipeline.operator-chaining' = 'false'; 

-- 重启策略
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

CREATE TEMPORARY TABLE source_dwd_acquiring_clearing (
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
    trans_account_id             STRING,
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
    etl_time                     TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'table-name' = 'dwd.dwd_acquiring_clearing',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_dwm_acquiring_clearing_daily AS
SELECT
    trans_account_id AS account_id,
    create_date,
    CASE
        WHEN account_type = 2 THEN 'income'
        WHEN account_type = 1 THEN 'cost'
    END AS amount_type,
    COUNT(*) AS clearing_count,
    CAST(SUM(COALESCE(acquiring_amount, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS acquiring_amount_total,
    CAST(SUM(COALESCE(acquiring_usd_amount, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS acquiring_usd_amount_total,
    CAST(SUM(COALESCE(card_scheme_fee, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS card_scheme_fee_total,
    CAST(SUM(COALESCE(issuing_bank_fee, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS issuing_bank_fee_total,
    CAST(SUM(COALESCE(tax_fee, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS tax_fee_total,
    CAST(SUM(COALESCE(miscellaneous_fee, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS miscellaneous_fee_total,
    CAST(SUM(COALESCE(fix_fee, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS fix_fee_total,
    CAST(SUM(COALESCE(percent_fee, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS percent_fee_total,
    CAST(SUM(COALESCE(back_fix_fee, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS back_fix_fee_total,
    CAST(SUM(COALESCE(back_percent_fee, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS back_percent_fee_total,
    CAST(SUM(COALESCE(total_fee_amount, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS total_fee_amount_total,
    CAST(SUM(COALESCE(margin_amount, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS margin_amount_total,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM source_dwd_acquiring_clearing
WHERE delete_time IS NULL
  AND trans_account_id IS NOT NULL
  AND create_date IS NOT NULL
  AND account_type IN (1, 2)
GROUP BY
    trans_account_id,
    create_date,
    CASE
        WHEN account_type = 2 THEN 'income'
        WHEN account_type = 1 THEN 'cost'
    END;

CREATE TEMPORARY TABLE sink_dwm_acquiring_clearing_daily (
    account_id                   STRING,
    create_date                  DATE,
    amount_type                  STRING,
    clearing_count               BIGINT,
    acquiring_amount_total       DECIMAL(20, 3),
    acquiring_usd_amount_total   DECIMAL(20, 3),
    card_scheme_fee_total        DECIMAL(20, 3),
    issuing_bank_fee_total       DECIMAL(20, 3),
    tax_fee_total                DECIMAL(20, 3),
    miscellaneous_fee_total      DECIMAL(20, 3),
    fix_fee_total                DECIMAL(20, 3),
    percent_fee_total            DECIMAL(20, 3),
    back_fix_fee_total           DECIMAL(20, 3),
    back_percent_fee_total       DECIMAL(20, 3),
    total_fee_amount_total       DECIMAL(20, 3),
    margin_amount_total          DECIMAL(20, 3),
    create_time                  TIMESTAMP(6),
    update_time                  TIMESTAMP(6),
    delete_time                  TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'dwm.dwm_acquiring_clearing',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'sink.buffer-flush.max-rows' = '1000',
    'sink.buffer-flush.interval' = '3000'
);

INSERT INTO sink_dwm_acquiring_clearing_daily
SELECT * FROM v_dwm_acquiring_clearing_daily;




-- CREATE TEMPORARY TABLE source_dwd_acquiring_clearing (
--     id                           BIGINT,
--     create_time                  BIGINT,
--     update_time                  BIGINT,
--     delete_time                  BIGINT,
--     create_timestamp             TIMESTAMP(3),
--     create_date                  DATE,
--     remarks                      STRING,
--     version                      INT,
--     acquiring_id                 BIGINT,
--     acquiring_pay_index_id       BIGINT,
--     merchant_trade_no            STRING,
--     channel_id                   BIGINT,
--     method_id                    BIGINT,
--     account_id                   BIGINT,
--     account_type                 INT,
--     acquiring_amount             DECIMAL(20, 4),
--     acquiring_usd_amount         DECIMAL(20, 4),
--     acquiring_currency           STRING,
--     settle_currency              STRING,
--     transaction_type             INT,
--     card_scheme_fee              DECIMAL(20, 4),
--     issuing_bank_fee             DECIMAL(20, 4),
--     tax_fee                      DECIMAL(20, 4),
--     miscellaneous_fee            DECIMAL(20, 4),
--     fix_fee                      DECIMAL(20, 4),
--     percent_fee                  DECIMAL(20, 4),
--     back_fix_fee                 DECIMAL(20, 4),
--     back_percent_fee             DECIMAL(20, 4),
--     total_fee_amount             DECIMAL(20, 4),
--     fix_fee_id                   BIGINT,
--     percent_fee_id               BIGINT,
--     fee_currency_rate_id         BIGINT,
--     amount_currency_rate_id      BIGINT,
--     margin_amount                DECIMAL(20, 4),
--     clear_time                   BIGINT,
--     clear_status                 INT,
--     settle_id                    BIGINT,
--     expect_settle_time           BIGINT,
--     settle_time                  BIGINT,
--     settle_status                INT,
--     check_id                     BIGINT,
--     check_time                   BIGINT,
--     check_status                 INT,
--     order_complete_time          BIGINT,
--     second_clear_time            BIGINT,
--     channel_fee_currency_rate_id BIGINT,
--     source_type                  STRING,
--     tenant_id                    BIGINT,
--     etl_time                     TIMESTAMP(6),
--     PRIMARY KEY (id) NOT ENFORCED
-- ) WITH (
--     'connector' = 'jdbc',
--     'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
--     'username' = '${secret_values.ADB_PG_USERNAME}',
--     'password' = '${secret_values.ADB_PG_PASSWORD}',
--     'table-name' = 'dwd.dwd_acquiring_clearing',
--     'scan.fetch-size' = '5000'
-- );

-- CREATE TEMPORARY TABLE source_dim_account_map_qbit (
--     id         BIGINT,
--     account_id STRING,
--     PRIMARY KEY (id) NOT ENFORCED
-- ) WITH (
--     'connector' = 'jdbc',
--     'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
--     'username' = '${secret_values.ADB_PG_USERNAME}',
--     'password' = '${secret_values.ADB_PG_PASSWORD}',
--     'table-name' = 'dim.dim_account_map_qbit',
--     'scan.fetch-size' = '5000'
-- );

-- CREATE TEMPORARY TABLE source_dim_account_qbit (
--     id STRING,
--     PRIMARY KEY (id) NOT ENFORCED
-- ) WITH (
--     'connector' = 'jdbc',
--     'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
--     'username' = '${secret_values.ADB_PG_USERNAME}',
--     'password' = '${secret_values.ADB_PG_PASSWORD}',
--     'table-name' = 'dim.dim_account_qbit',
--     'scan.fetch-size' = '5000'
-- );

-- CREATE TEMPORARY VIEW v_acquiring_clearing_with_qbit_account AS
-- SELECT
--     ac.id,
--     aq.id AS qbit_account_id,
--     ac.create_date,
--     ac.account_type,
--     ac.acquiring_amount,
--     ac.acquiring_usd_amount,
--     ac.card_scheme_fee,
--     ac.issuing_bank_fee,
--     ac.tax_fee,
--     ac.miscellaneous_fee,
--     ac.fix_fee,
--     ac.percent_fee,
--     ac.back_fix_fee,
--     ac.back_percent_fee,
--     ac.total_fee_amount,
--     ac.margin_amount
-- FROM source_dwd_acquiring_clearing ac
-- INNER JOIN source_dim_account_map_qbit amq
--     ON ac.account_id = amq.id
-- INNER JOIN source_dim_account_qbit aq
--     ON amq.account_id = aq.id
-- WHERE ac.delete_time IS NULL
--   AND ac.account_id IS NOT NULL
--   AND ac.create_date IS NOT NULL
--   AND ac.account_type IN (1, 2);

-- CREATE TEMPORARY VIEW v_dwm_acquiring_clearing_daily AS
-- SELECT
--     qbit_account_id AS account_id,
--     create_date,
--     CASE
--         WHEN account_type = 2 THEN 'income'
--         WHEN account_type = 1 THEN 'cost'
--     END AS amount_type,
--     COUNT(*) AS clearing_count,
--     CAST(SUM(COALESCE(acquiring_amount, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS acquiring_amount_total,
--     CAST(SUM(COALESCE(acquiring_usd_amount, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS acquiring_usd_amount_total,
--     CAST(SUM(COALESCE(card_scheme_fee, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS card_scheme_fee_total,
--     CAST(SUM(COALESCE(issuing_bank_fee, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS issuing_bank_fee_total,
--     CAST(SUM(COALESCE(tax_fee, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS tax_fee_total,
--     CAST(SUM(COALESCE(miscellaneous_fee, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS miscellaneous_fee_total,
--     CAST(SUM(COALESCE(fix_fee, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS fix_fee_total,
--     CAST(SUM(COALESCE(percent_fee, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS percent_fee_total,
--     CAST(SUM(COALESCE(back_fix_fee, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS back_fix_fee_total,
--     CAST(SUM(COALESCE(back_percent_fee, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS back_percent_fee_total,
--     CAST(SUM(COALESCE(total_fee_amount, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS total_fee_amount_total,
--     CAST(SUM(COALESCE(margin_amount, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 3)) AS margin_amount_total,
--     CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
--     CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
--     CAST(NULL AS TIMESTAMP(6)) AS delete_time
-- FROM v_acquiring_clearing_with_qbit_account
-- GROUP BY
--     qbit_account_id,
--     create_date,
--     CASE
--         WHEN account_type = 2 THEN 'income'
--         WHEN account_type = 1 THEN 'cost'
--     END;

-- CREATE TEMPORARY TABLE sink_dwm_acquiring_clearing_daily (
--     account_id                   STRING,
--     account_id                   STRING,
--     create_date                  DATE,
--     amount_type                  STRING,
--     clearing_count               BIGINT,
--     acquiring_amount_total       DECIMAL(20, 3),
--     acquiring_usd_amount_total   DECIMAL(20, 3),
--     card_scheme_fee_total        DECIMAL(20, 3),
--     issuing_bank_fee_total       DECIMAL(20, 3),
--     tax_fee_total                DECIMAL(20, 3),
--     miscellaneous_fee_total      DECIMAL(20, 3),
--     fix_fee_total                DECIMAL(20, 3),
--     percent_fee_total            DECIMAL(20, 3),
--     back_fix_fee_total           DECIMAL(20, 3),
--     back_percent_fee_total       DECIMAL(20, 3),
--     total_fee_amount_total       DECIMAL(20, 3),
--     margin_amount_total          DECIMAL(20, 3),
--     create_time                  TIMESTAMP(6),
--     update_time                  TIMESTAMP(6),
--     delete_time                  TIMESTAMP(6)
-- ) WITH (
--     'connector' = 'jdbc',
--     'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
--     'table-name' = 'dwm.dwm_acquiring_clearing_daily',
--     'username' = '${secret_values.ADB_PG_USERNAME}',
--     'password' = '${secret_values.ADB_PG_PASSWORD}',
--     'driver' = 'org.postgresql.Driver',
--     'sink.buffer-flush.max-rows' = '1000',
--     'sink.buffer-flush.interval' = '3000'
-- );

-- INSERT INTO sink_dwm_acquiring_clearing_daily
-- SELECT * FROM v_dwm_acquiring_clearing_daily;
