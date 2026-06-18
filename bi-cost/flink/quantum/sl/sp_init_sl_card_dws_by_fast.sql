--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-15
-- Description:    Quantum SL DWS 批量初始化/回刷
-- Notes:
--   1. 主链路: qbitCardSettlement -> DWM -> DWS
--   2. 粒度: account_id + report_date + sale_id + am_id
--   3. cost_fixed_fee 后续通过 bi_month_tag 单独更新
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

CREATE TEMPORARY TABLE source_dwm_sl_card_transaction_detail_p (
    id                         STRING,
    account_id                 STRING,
    version                    INT,
    remarks                    STRING,
    create_time                TIMESTAMP(6),
    update_time                TIMESTAMP(6),
    delete_time                TIMESTAMP(6),
    settlement_date            DATE,
    settlement_transaction_id  STRING,
    qbit_card_transaction_id   STRING,
    qbit_transaction_id        STRING,
    provider                   STRING,
    billing_amount             DECIMAL(20, 4),
    billing_currency_code      STRING,
    transaction_amount         DECIMAL(20, 4),
    transaction_currency_code  STRING,
    country                    STRING,
    sale_id                    STRING,
    am_id                      STRING,
    raw_data                   STRING,
    etl_time                   TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = 'dwm.dwm_sl_card_transaction_detail_p',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_dws_sl_daily_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(CAST(settlement_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', account_id, ':', COALESCE(sale_id, ''), ':', COALESCE(am_id, '')))) AS BIGINT) AS id,
    settlement_date AS report_date,
    account_id,
    1 AS version,
    CAST(NULL AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time,
    sale_id,
    am_id,
    CAST(SUM(COALESCE(billing_amount, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 4)) AS rebate_base,
    CAST(SUM(
        CASE
            WHEN country = 'US' THEN COALESCE(billing_amount, CAST(0 AS DECIMAL(20, 4))) * CAST(0.02 AS DECIMAL(20, 4))
            ELSE COALESCE(billing_amount, CAST(0 AS DECIMAL(20, 4))) * CAST(0.005 AS DECIMAL(20, 4))
        END
    ) AS DECIMAL(20, 4)) AS rebate_amt,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee
FROM source_dwm_sl_card_transaction_detail_p
WHERE delete_time IS NULL
GROUP BY settlement_date, account_id, sale_id, am_id;

CREATE TEMPORARY TABLE sink_dws_sl_card_finance_daily_p (
    id              BIGINT,
    report_date     DATE,
    account_id      STRING,
    version         INT,
    remarks         STRING,
    create_time     TIMESTAMP(6),
    update_time     TIMESTAMP(6),
    delete_time     TIMESTAMP(6),
    sale_id         STRING,
    am_id           STRING,
    rebate_base     DECIMAL(20, 4),
    rebate_amt      DECIMAL(20, 4),
    cost_fixed_fee  DECIMAL(20, 4),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_sl_card_finance_daily_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dws_sl_card_finance_daily_p
SELECT
    id,
    report_date,
    account_id,
    version,
    remarks,
    create_time,
    update_time,
    delete_time,
    sale_id,
    am_id,
    rebate_base,
    rebate_amt,
    cost_fixed_fee
FROM v_dws_sl_daily_base;
