--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-04
-- Updated Time:   2026-08-05 22:30:25
-- Description:    Quantum SL v2 DWS CDC 按月清理普通汇总行
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'execution.application-management.enabled' = 'true';
SET 'execution.multi-jobs-in-application.enable' = 'true';

CREATE TEMPORARY TABLE source_dwm_sl_card_transaction_detail_p (
    id              STRING,
    settlement_date DATE,
    update_time     TIMESTAMP(6),
    delete_time     TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = 'dwm.dwm_sl_card_transaction_detail_p',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY VIEW v_sl_changed_months AS
SELECT DISTINCT
    report_month,
    CAST(DATE_FORMAT(CAST(DATE_ADD(report_month, 32) AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS next_month
FROM (
    SELECT CAST(DATE_FORMAT(CAST(settlement_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
    FROM source_dwm_sl_card_transaction_detail_p
    WHERE (update_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6)) AND update_time < CAST(CURRENT_DATE AS TIMESTAMP(6)))
       OR (delete_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6)) AND delete_time < CAST(CURRENT_DATE AS TIMESTAMP(6)))
) x
WHERE report_month IS NOT NULL;

CREATE TEMPORARY TABLE sink_dws_sl_card_finance_daily_p (
    id               BIGINT,
    report_date      DATE,
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
WHERE (special_fee_type IS NULL OR special_fee_type <> 'CHANNEL_FIXED_FEE')
  AND EXISTS (SELECT 1 FROM v_sl_changed_months m WHERE report_date >= m.report_month AND report_date < m.next_month);
