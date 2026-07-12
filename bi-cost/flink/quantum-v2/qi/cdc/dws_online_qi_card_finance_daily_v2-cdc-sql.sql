--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-12
-- Description:    Quantum QI v2 DWS CDC 按月回刷
-- 作业元信息：
--   作业类型：流处理 CDC
--   运行方式：默认按昨天变更扫描，按受影响月份整月删除后重算
--   运行参数：无
--   源库变更响应：源表 update_time / delete_time 变化后，重刷对应月份
-- Notes:
--   1. 主链路: DWM -> DWS
--   2. 粒度: account_id + report_date + sale_id + am_id
--   3. cost_fixed_fee 字段保留在同一条 DWS 写入链路中，值先保持 0
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

SET 'execution.checkpointing.interval' = '10s';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'pipeline.operator-chaining' = 'false';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'execution.checkpointing.timeout' = '30min';

SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';

CREATE TEMPORARY TABLE source_dwm_qi_card_transaction_detail_p (
    id                    STRING,
    transaction_id        STRING,
    account_id            STRING,
    account_type          STRING,
    account_category      STRING,
    system_type           STRING,
    status                STRING,
    transaction_time      TIMESTAMP(6),
    version               INT,
    remarks               STRING,
    create_time           TIMESTAMP(6),
    update_time           TIMESTAMP(6),
    delete_time           TIMESTAMP(6),
    billing_amount        DECIMAL(20, 4),
    is_qbit_provision     BOOLEAN,
    is_hk_region          BOOLEAN,
    is_consumption        BOOLEAN,
    is_reversal_or_credit BOOLEAN,
    has_special_code      BOOLEAN,
    is_vip_account        BOOLEAN,
    business_type         STRING,
    card_id               STRING,
    sale_id               STRING,
    am_id                 STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dwm_qi_card_transaction_detail_p',
    'targetSchema' = 'dwm',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY VIEW v_qi_changed_months AS
SELECT DISTINCT
    CAST(DATE_FORMAT(CAST(transaction_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month,
    CAST(DATE_FORMAT(CAST(DATE_ADD(CAST(DATE_FORMAT(CAST(transaction_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE), 32) AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS next_month
FROM source_dwm_qi_card_transaction_detail_p
WHERE delete_time IS NULL
  AND (
        (update_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6)) AND update_time < CAST(CURRENT_DATE AS TIMESTAMP(6)))
     OR (delete_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6)) AND delete_time < CAST(CURRENT_DATE AS TIMESTAMP(6)))
  );

DELETE FROM sink_dws_qi_card_finance_daily_p
WHERE EXISTS (
    SELECT 1
    FROM v_qi_changed_months m
    WHERE sink_dws_qi_card_finance_daily_p.report_date >= m.report_month
      AND sink_dws_qi_card_finance_daily_p.report_date < m.next_month
);

CREATE TEMPORARY VIEW v_qi_month_scope_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(transaction_time, 'yyyyMMdd'), ':', account_id, ':', COALESCE(sale_id, ''), ':', COALESCE(am_id, '')))) AS BIGINT) AS id,
    CAST(transaction_time AS DATE) AS report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    1 AS version,
    CAST(NULL AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time,
    sale_id,
    am_id,
    CAST(SUM(CASE WHEN is_hk_region = FALSE AND business_type = 'Consumption' AND status IN ('Closed', 'Pending') THEN billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS cost_reimbursement_rate,
    CAST(SUM(CASE WHEN is_hk_region = FALSE AND status IN ('Closed', 'Pending') AND business_type IN ('Consumption', 'Reversal', 'Credit') THEN billing_amount * CASE WHEN business_type = 'Consumption' THEN 1 ELSE -1 END ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS cost_service_rate,
    CAST(SUM(CASE WHEN is_hk_region = FALSE AND business_type = 'Consumption' AND status IN ('Closed', 'Pending') THEN 1 ELSE 0 END) AS DECIMAL(20, 4)) AS cost_acs_regular_rate,
    CAST(SUM(CASE WHEN is_hk_region = FALSE AND business_type = 'Consumption' AND has_special_code = FALSE THEN 1 ELSE 0 END) AS DECIMAL(20, 4)) AS cost_acs_vip_rate,
    CAST(SUM(CASE WHEN is_hk_region = FALSE AND business_type = 'Consumption' AND has_special_code = FALSE THEN 1 ELSE 0 END) AS DECIMAL(20, 4)) AS cost_vrm_rate,
    CAST(SUM(CASE WHEN status IN ('Closed', 'Pending') AND is_hk_region = FALSE AND business_type = 'Consumption' THEN billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS rebate_interchange_rate,
    CAST(SUM(CASE WHEN status IN ('Closed', 'Pending') AND business_type = 'Consumption' THEN billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS rebate_incentive_rate,
    CAST(SUM(CASE WHEN is_hk_region = FALSE AND business_type = 'Consumption' AND status IN ('Closed', 'Pending') THEN billing_amount * CAST(0.0135 AS DECIMAL(20, 4)) ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS cost_reimbursement_vol,
    CAST(SUM(CASE WHEN is_hk_region = FALSE AND status IN ('Closed', 'Pending') AND business_type IN ('Consumption', 'Reversal', 'Credit') THEN
        CASE
            WHEN ABS(billing_amount) < 5 THEN billing_amount * CAST(0.00095 AS DECIMAL(20, 4))
            WHEN ABS(billing_amount) < 10 THEN billing_amount * CAST(0.00145 AS DECIMAL(20, 4))
            WHEN ABS(billing_amount) < 50 THEN billing_amount * CAST(0.0022 AS DECIMAL(20, 4))
            WHEN ABS(billing_amount) < 250 THEN billing_amount * CAST(0.0037 AS DECIMAL(20, 4))
            ELSE billing_amount * CAST(0.00445 AS DECIMAL(20, 4))
        END * CASE WHEN business_type = 'Consumption' THEN 1 ELSE -1 END
        ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS cost_service_vol,
    CAST(SUM(CASE WHEN is_hk_region = FALSE AND business_type = 'Consumption' AND status IN ('Closed', 'Pending') THEN
        CASE
            WHEN billing_amount < 5 THEN 0.01
            WHEN billing_amount < 10 THEN 0.055
            WHEN billing_amount < 50 THEN 0.08
            WHEN billing_amount < 250 THEN 0.12
            ELSE 0.14
        END ELSE 0 END) AS INT) AS cost_acs_regular_count,
    CAST(SUM(CASE WHEN is_hk_region = FALSE AND business_type = 'Consumption' AND has_special_code = FALSE THEN
        CASE
            WHEN billing_amount < 5 THEN 0.04
            WHEN billing_amount < 10 THEN 0.22
            WHEN billing_amount < 50 THEN 0.255
            WHEN billing_amount < 250 THEN 0.48
            ELSE 0.56
        END ELSE 0 END) AS INT) AS cost_acs_vip_count,
    CAST(SUM(CASE WHEN is_hk_region = FALSE AND business_type = 'Consumption' AND has_special_code = FALSE THEN 0.07 ELSE 0 END) AS INT) AS cost_vrm_count,
    CAST(SUM(CASE WHEN status IN ('Closed', 'Pending') AND is_hk_region = FALSE AND business_type = 'Consumption' THEN billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS rebate_interchange_vol,
    CAST(SUM(CASE WHEN status IN ('Closed', 'Pending') AND business_type = 'Consumption' THEN billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS rebate_incentive_vol,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee
FROM source_dwm_qi_card_transaction_detail_p s
INNER JOIN v_qi_changed_months m
    ON CAST(DATE_FORMAT(CAST(s.transaction_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = m.report_month
WHERE s.delete_time IS NULL
GROUP BY CAST(s.transaction_time AS DATE), account_id, account_type, account_category, system_type, sale_id, am_id;

CREATE TEMPORARY TABLE sink_dws_qi_card_finance_daily_p (
    id                        BIGINT,
    report_date               DATE,
    account_id                STRING,
    account_type              STRING,
    account_category          STRING,
    system_type               STRING,
    version                   INT,
    remarks                   STRING,
    create_time               TIMESTAMP(6),
    update_time               TIMESTAMP(6),
    delete_time               TIMESTAMP(6),
    sale_id                   STRING,
    am_id                     STRING,
    cost_reimbursement_rate   DECIMAL(20, 4),
    cost_service_rate         DECIMAL(20, 4),
    cost_acs_regular_rate     DECIMAL(20, 4),
    cost_acs_vip_rate         DECIMAL(20, 4),
    cost_vrm_rate             DECIMAL(20, 4),
    rebate_interchange_rate   DECIMAL(20, 4),
    rebate_incentive_rate     DECIMAL(20, 4),
    cost_reimbursement_vol    DECIMAL(20, 4),
    cost_service_vol          DECIMAL(20, 4),
    cost_acs_regular_count    INT,
    cost_acs_vip_count        INT,
    cost_vrm_count            INT,
    rebate_interchange_vol    DECIMAL(20, 4),
    rebate_incentive_vol      DECIMAL(20, 4),
    cost_fixed_fee            DECIMAL(20, 4),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_qi_card_finance_daily_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dws_qi_card_finance_daily_p
SELECT
    id,
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    version,
    remarks,
    create_time,
    update_time,
    delete_time,
    sale_id,
    am_id,
    cost_reimbursement_rate,
    cost_service_rate,
    cost_acs_regular_rate,
    cost_acs_vip_rate,
    cost_vrm_rate,
    rebate_interchange_rate,
    rebate_incentive_rate,
    cost_reimbursement_vol,
    cost_service_vol,
    cost_acs_regular_count,
    cost_acs_vip_count,
    cost_vrm_count,
    rebate_interchange_vol,
    rebate_incentive_vol,
    cost_fixed_fee
FROM v_qi_month_scope_base;
