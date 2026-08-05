--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-04
-- Updated Time:   2026-08-05 22:30:25
-- Description:    SL 渠道固定成本 CDC 每日清理
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'execution.application-management.enabled' = 'true';
SET 'execution.multi-jobs-in-application.enable' = 'true';

CREATE TEMPORARY TABLE source_bi_month_tag (
    id BIGINT,
    provider STRING,
    tag STRING,
    statistics_time TIMESTAMP(6),
    update_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id, provider, tag, statistics_time, update_time, delete_time FROM ods.ods_bi_month_tag WHERE delete_time IS NULL) AS bi_month_tag_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY VIEW v_month_scope AS
SELECT DISTINCT
    report_month,
    CAST(DATE_FORMAT(CAST(DATE_ADD(report_month, 32) AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS next_month
FROM (
    SELECT CAST(DATE_FORMAT(CAST(statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
    FROM source_bi_month_tag
    WHERE tag = 'CHANNEL_COST'
      AND provider = 'LS'
      AND update_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6))
      AND update_time < CAST(CURRENT_DATE AS TIMESTAMP(6))
) m
WHERE report_month IS NOT NULL;

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
  AND EXISTS (SELECT 1 FROM v_month_scope m WHERE report_date >= m.report_month AND report_date < m.next_month);
