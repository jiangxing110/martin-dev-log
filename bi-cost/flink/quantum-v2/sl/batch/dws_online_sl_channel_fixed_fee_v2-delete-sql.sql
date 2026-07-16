--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-16
-- Description:    SL 渠道固定成本批量回刷前置删除脚本
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

CREATE TEMPORARY TABLE sink_dws_sl_card_finance_daily_p (
    id BIGINT,
    report_date DATE,
    account_id STRING,
    account_type STRING,
    account_category STRING,
    system_type STRING,
    version INT,
    remarks STRING,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    sale_id STRING,
    am_id STRING,
    cost_fixed_fee DECIMAL(20, 4),
    special_fee_type STRING,
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

DELETE FROM sink_dws_sl_card_finance_daily_p
WHERE special_fee_type = 'CHANNEL_FIXED_FEE'
  AND report_date >= CAST('${start_time}' AS DATE)
  AND report_date < CAST('${end_time}' AS DATE);
