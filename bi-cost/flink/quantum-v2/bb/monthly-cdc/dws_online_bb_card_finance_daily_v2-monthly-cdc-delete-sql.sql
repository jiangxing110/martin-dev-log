--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-04
-- Updated Time:   2026-08-05 22:30:25
-- Description:    Quantum BB v2 DWS 月度补偿清理普通汇总行
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'execution.application-management.enabled' = 'true';
SET 'execution.multi-jobs-in-application.enable' = 'true';

CREATE TEMPORARY VIEW v_month_scope AS
SELECT
    CAST(DATE_FORMAT(CAST(CURRENT_DATE - INTERVAL '1' MONTH AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month,
    CAST(DATE_FORMAT(CAST(CURRENT_DATE AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS next_month;

CREATE TEMPORARY TABLE sink_dws_bb_card_finance_daily_v2_p (
    id               BIGINT,
    report_date      DATE,
    special_fee_type STRING,
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_bb_card_finance_daily_v2_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

DELETE FROM sink_dws_bb_card_finance_daily_v2_p
WHERE (special_fee_type IS NULL OR special_fee_type NOT IN ('ACTIVE_CARD_ACCOUNT_FEE', 'CHANNEL_FIXED_FEE'))
  AND EXISTS (SELECT 1 FROM v_month_scope m WHERE report_date >= m.report_month AND report_date < m.next_month);
