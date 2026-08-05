--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-04
-- Updated Time:   2026-08-05 22:30:25
-- Description:    Quantum BB v2 DWS CDC 按月清理普通汇总行
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'execution.application-management.enabled' = 'true';
SET 'execution.multi-jobs-in-application.enable' = 'true';

CREATE TEMPORARY TABLE source_dwm_bb_card_transaction_detail_v2_p (
    id                       STRING,
    transaction_time         TIMESTAMP(6),
    original_completion_time TIMESTAMP(6),
    settlement_post_date     TIMESTAMP(6),
    update_time              TIMESTAMP(6),
    delete_time              TIMESTAMP(6),
    PRIMARY KEY (id, transaction_time) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dwm_bb_card_transaction_detail_v2_p',
    'targetSchema' = 'dwm',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY TABLE source_dwm_bb_card_auth_detail_v2_p (
    id          STRING,
    auth_time   TIMESTAMP(6),
    update_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    PRIMARY KEY (id, auth_time) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dwm_bb_card_auth_detail_v2_p',
    'targetSchema' = 'dwm',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY VIEW v_bb_changed_months AS
SELECT DISTINCT
    report_month,
    CAST(DATE_FORMAT(CAST(DATE_ADD(report_month, 32) AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS next_month
FROM (
    SELECT CAST(DATE_FORMAT(CAST(transaction_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
    FROM source_dwm_bb_card_transaction_detail_v2_p
    WHERE (update_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6)) AND update_time < CAST(CURRENT_DATE AS TIMESTAMP(6)))
       OR (delete_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6)) AND delete_time < CAST(CURRENT_DATE AS TIMESTAMP(6)))
    UNION ALL
    SELECT CAST(DATE_FORMAT(CAST(original_completion_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
    FROM source_dwm_bb_card_transaction_detail_v2_p
    WHERE (update_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6)) AND update_time < CAST(CURRENT_DATE AS TIMESTAMP(6)))
       OR (delete_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6)) AND delete_time < CAST(CURRENT_DATE AS TIMESTAMP(6)))
    UNION ALL
    SELECT CAST(DATE_FORMAT(CAST(settlement_post_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
    FROM source_dwm_bb_card_transaction_detail_v2_p
    WHERE (update_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6)) AND update_time < CAST(CURRENT_DATE AS TIMESTAMP(6)))
       OR (delete_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6)) AND delete_time < CAST(CURRENT_DATE AS TIMESTAMP(6)))
    UNION ALL
    SELECT CAST(DATE_FORMAT(CAST(auth_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
    FROM source_dwm_bb_card_auth_detail_v2_p
    WHERE (update_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6)) AND update_time < CAST(CURRENT_DATE AS TIMESTAMP(6)))
       OR (delete_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6)) AND delete_time < CAST(CURRENT_DATE AS TIMESTAMP(6)))
) x
WHERE report_month IS NOT NULL;

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
  AND EXISTS (SELECT 1 FROM v_bb_changed_months m WHERE report_date >= m.report_month AND report_date < m.next_month);
