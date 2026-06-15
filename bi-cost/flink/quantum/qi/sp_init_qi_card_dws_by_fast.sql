--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-15
-- Description:    Quantum QI DWS 批量初始化/回刷
-- Notes:
--   1. 主链路: DWM -> DWS
--   2. 粒度: account_id + report_date + sale_id + am_id
--   3. cost_fixed_fee 后续通过 bi_month_tag 单独更新
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

CREATE TEMPORARY TABLE source_dwm_qi_card_transaction_detail_p (
    id                    STRING,
    transaction_id        STRING,
    account_id            STRING,
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
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = 'public.dwm_qi_card_transaction_detail_p',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_dws_qi_daily_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(transaction_time, 'yyyyMMdd'), ':', account_id, ':', COALESCE(sale_id, ''), ':', COALESCE(am_id, '')))) AS BIGINT) AS id,
    CAST(transaction_time AS DATE) AS report_date,
    account_id,
    1 AS version,
    CAST(NULL AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time,
    sale_id,
    am_id,
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
FROM source_dwm_qi_card_transaction_detail_p
WHERE delete_time IS NULL
GROUP BY CAST(transaction_time AS DATE), account_id, sale_id, am_id;

CREATE TEMPORARY TABLE sink_dws_qi_card_finance_daily_p (
    id                        BIGINT,
    report_date               DATE,
    account_id                STRING,
    version                   INT,
    remarks                   STRING,
    create_time               TIMESTAMP(6),
    update_time               TIMESTAMP(6),
    delete_time               TIMESTAMP(6),
    sale_id                   STRING,
    am_id                     STRING,
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
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'public.dws_qi_card_finance_daily_p',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'sink.buffer-flush.max-rows' = '2000',
    'sink.buffer-flush.interval' = '3000'
);

INSERT INTO sink_dws_qi_card_finance_daily_p
SELECT * FROM v_dws_qi_daily_base;
