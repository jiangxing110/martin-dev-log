--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-15
-- Updated Time:   2026-07-15
-- Description:    Quantum QI v2 DWS 批量初始化/回刷
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性初始化/回刷或调度执行
--   运行参数：start_time, end_time
-- Notes:
--   1. 主链路: DWM v2 -> DWS v2
--   2. 粒度: account_id + report_date + sale_id + am_id
--   3. 只记录成本/返现计费基数和对应 rate，结果金额由下游按 base * rate 计算
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'pipeline.operator-chaining' = 'false';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';
SET 'execution.checkpointing.interval' = '10s';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'execution.checkpointing.timeout' = '30min';

CREATE TEMPORARY TABLE source_bi_month_tag (
    id              BIGINT,
    product_line    STRING,
    provider        STRING,
    tag             STRING,
    statistics_time TIMESTAMP(6),
    amount          DECIMAL(20, 4),
    detail          STRING,
    update_time     TIMESTAMP(6),
    delete_time     TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id, product_line, provider, tag, statistics_time, amount, detail, update_time, delete_time FROM ods.ods_bi_month_tag WHERE delete_time IS NULL) AS bi_month_tag_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_dwm_qi_card_transaction_detail_v2_p (
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
    source_update_time    TIMESTAMP(6),
    source_delete_time    TIMESTAMP(6),
    is_current_valid      BOOLEAN,
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
    PRIMARY KEY (id, transaction_time) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id, transaction_id, account_id, account_type, account_category, system_type, status, transaction_time, version, remarks, create_time, update_time, delete_time, source_update_time, source_delete_time, is_current_valid, billing_amount, is_qbit_provision, is_hk_region, is_consumption, is_reversal_or_credit, has_special_code, is_vip_account, business_type, card_id, sale_id, am_id FROM dwm.dwm_qi_card_transaction_detail_v2_p) AS dwm_qi_card_transaction_detail_v2_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_qi_dwm_daily_rows AS
SELECT
    CAST(transaction_time AS DATE) AS report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    sale_id,
    am_id,
    status,
    billing_amount,
    is_hk_region,
    business_type,
    has_special_code
FROM source_dwm_qi_card_transaction_detail_v2_p
WHERE delete_time IS NULL
  AND transaction_time >= CAST('${start_time}' AS TIMESTAMP(6))
  AND transaction_time < CAST('${end_time}' AS TIMESTAMP(6));

CREATE TEMPORARY VIEW v_dws_qi_daily_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', account_id, ':', COALESCE(sale_id, ''), ':', COALESCE(am_id, '')))) AS BIGINT) AS id,
    report_date,
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
    CAST(SUM(CASE WHEN is_hk_region = FALSE AND business_type = 'Consumption' AND status IN ('Closed', 'Pending') THEN billing_amount * CAST(0.0135 AS DECIMAL(20, 4)) ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS cost_reimbursement_base_amt,
    CAST(SUM(CASE WHEN is_hk_region = FALSE AND status IN ('Closed', 'Pending') AND business_type IN ('Consumption', 'Reversal', 'Credit') THEN
        CASE
            WHEN ABS(billing_amount) < 5 THEN billing_amount * CAST(0.00095 AS DECIMAL(20, 4))
            WHEN ABS(billing_amount) < 10 THEN billing_amount * CAST(0.00145 AS DECIMAL(20, 4))
            WHEN ABS(billing_amount) < 50 THEN billing_amount * CAST(0.0022 AS DECIMAL(20, 4))
            WHEN ABS(billing_amount) < 250 THEN billing_amount * CAST(0.0037 AS DECIMAL(20, 4))
            ELSE billing_amount * CAST(0.00445 AS DECIMAL(20, 4))
        END * CASE WHEN business_type = 'Consumption' THEN 1 ELSE -1 END
        ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS cost_service_base_amt,
    CAST(SUM(CASE WHEN is_hk_region = FALSE AND business_type = 'Consumption' AND status IN ('Closed', 'Pending') THEN
        CASE
            WHEN billing_amount < 5 THEN 0.01
            WHEN billing_amount < 10 THEN 0.055
            WHEN billing_amount < 50 THEN 0.08
            WHEN billing_amount < 250 THEN 0.12
            ELSE 0.14
        END ELSE 0 END) AS DECIMAL(20, 4)) AS cost_acs_regular_base_amt,
    CAST(SUM(CASE WHEN is_hk_region = FALSE AND business_type = 'Consumption' AND has_special_code = FALSE THEN
        CASE
            WHEN billing_amount < 5 THEN 0.04
            WHEN billing_amount < 10 THEN 0.22
            WHEN billing_amount < 50 THEN 0.255
            WHEN billing_amount < 250 THEN 0.48
            ELSE 0.56
        END ELSE 0 END) AS DECIMAL(20, 4)) AS cost_acs_vip_base_amt,
    CAST(SUM(CASE WHEN is_hk_region = FALSE AND business_type = 'Consumption' AND has_special_code = FALSE THEN 0.09 ELSE 0 END) AS DECIMAL(20, 4)) AS cost_vrm_base_amt,
    CAST(SUM(CASE WHEN status IN ('Closed', 'Pending') AND is_hk_region = FALSE AND business_type = 'Consumption' THEN billing_amount * CAST(0.02 AS DECIMAL(20, 4)) ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS rebate_interchange_base_amt,
    CAST(SUM(CASE WHEN status IN ('Closed', 'Pending') AND business_type = 'Consumption' THEN billing_amount * CAST(0.0118 AS DECIMAL(20, 4)) ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS rebate_incentive_base_amt
FROM v_qi_dwm_daily_rows
GROUP BY report_date, account_id, account_type, account_category, system_type, sale_id, am_id;

CREATE TEMPORARY VIEW v_qi_month_scope AS
SELECT DISTINCT CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
FROM v_dws_qi_daily_base;

CREATE TEMPORARY VIEW v_qi_month_row_count AS
SELECT
    CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month,
    COUNT(*) AS row_count
FROM v_dws_qi_daily_base
GROUP BY CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE);

CREATE TEMPORARY VIEW v_qi_month_tag_ranked AS
SELECT report_month, tag, amount
FROM (
    SELECT
        s.report_month,
        t.tag,
        t.amount,
        ROW_NUMBER() OVER (
            PARTITION BY s.report_month, t.tag
            ORDER BY
                CASE WHEN t.detail = 'DEFAULT_FALLBACK' THEN 1 ELSE 0 END,
                t.statistics_time DESC,
                t.update_time DESC,
                t.id DESC
        ) AS rn
    FROM v_qi_month_scope s
    LEFT JOIN source_bi_month_tag t
        ON t.provider = 'IQ'
       AND t.delete_time IS NULL
       AND (
            t.statistics_time < CAST(DATE_FORMAT(CAST(DATE_ADD(s.report_month, 32) AS TIMESTAMP(6)), 'yyyy-MM-01') AS TIMESTAMP(6))
         OR t.detail = 'DEFAULT_FALLBACK'
       )
) ranked_tag
WHERE rn = 1;

CREATE TEMPORARY VIEW v_qi_month_rates AS
SELECT
    report_month,
    MAX(CASE WHEN tag = 'QI_COST_REIMBURSEMENT_RATE' THEN amount END) AS cost_reimbursement_rate,
    MAX(CASE WHEN tag = 'QI_COST_SERVICE_RATE' THEN amount END) AS cost_service_rate,
    MAX(CASE WHEN tag = 'QI_COST_ACS_REGULAR_RATE' THEN amount END) AS cost_acs_regular_rate,
    MAX(CASE WHEN tag = 'QI_COST_ACS_VIP_RATE' THEN amount END) AS cost_acs_vip_rate,
    MAX(CASE WHEN tag = 'QI_COST_VRM_RATE' THEN amount END) AS cost_vrm_rate,
    MAX(CASE WHEN tag = 'QI_REBATE_INTERCHANGE_RATE' THEN amount END) AS rebate_interchange_rate,
    MAX(CASE WHEN tag = 'QI_REBATE_INCENTIVE_RATE' THEN amount END) AS rebate_incentive_rate
FROM v_qi_month_tag_ranked
GROUP BY report_month;

CREATE TEMPORARY TABLE sink_dws_qi_card_finance_daily_v2_p (
    id                            BIGINT,
    report_date                   DATE,
    account_id                    STRING,
    account_type                  STRING,
    account_category              STRING,
    system_type                   STRING,
    version                       INT,
    remarks                       STRING,
    create_time                   TIMESTAMP(6),
    update_time                   TIMESTAMP(6),
    delete_time                   TIMESTAMP(6),
    sale_id                       STRING,
    am_id                         STRING,
    cost_reimbursement_base_amt   DECIMAL(20, 4),
    cost_service_base_amt         DECIMAL(20, 4),
    cost_acs_regular_base_amt     DECIMAL(20, 4),
    cost_acs_vip_base_amt         DECIMAL(20, 4),
    cost_vrm_base_amt             DECIMAL(20, 4),
    rebate_interchange_base_amt   DECIMAL(20, 4),
    rebate_incentive_base_amt     DECIMAL(20, 4),
    cost_reimbursement_rate       DECIMAL(20, 8),
    cost_service_rate             DECIMAL(20, 8),
    cost_acs_regular_rate         DECIMAL(20, 8),
    cost_acs_vip_rate             DECIMAL(20, 8),
    cost_vrm_rate                 DECIMAL(20, 8),
    rebate_interchange_rate       DECIMAL(20, 8),
    rebate_incentive_rate         DECIMAL(20, 8),
    cost_fixed_fee                DECIMAL(20, 4),
    special_fee_type              STRING,
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_qi_card_finance_daily_v2_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dws_qi_card_finance_daily_v2_p
SELECT
    b.id,
    b.report_date,
    b.account_id,
    b.account_type,
    b.account_category,
    b.system_type,
    b.version,
    b.remarks,
    b.create_time,
    b.update_time,
    b.delete_time,
    b.sale_id,
    b.am_id,
    b.cost_reimbursement_base_amt,
    b.cost_service_base_amt,
    b.cost_acs_regular_base_amt,
    b.cost_acs_vip_base_amt,
    b.cost_vrm_base_amt,
    b.rebate_interchange_base_amt,
    b.rebate_incentive_base_amt,
    CAST(COALESCE(r.cost_reimbursement_rate, 1) AS DECIMAL(20, 8)) AS cost_reimbursement_rate,
    CAST(COALESCE(r.cost_service_rate, 1) AS DECIMAL(20, 8)) AS cost_service_rate,
    CAST(COALESCE(r.cost_acs_regular_rate, 1) AS DECIMAL(20, 8)) AS cost_acs_regular_rate,
    CAST(COALESCE(r.cost_acs_vip_rate, 1) AS DECIMAL(20, 8)) AS cost_acs_vip_rate,
    CAST(COALESCE(r.cost_vrm_rate, 1) AS DECIMAL(20, 8)) AS cost_vrm_rate,
    CAST(COALESCE(r.rebate_interchange_rate, 1) AS DECIMAL(20, 8)) AS rebate_interchange_rate,
    CAST(COALESCE(r.rebate_incentive_rate, 1) AS DECIMAL(20, 8)) AS rebate_incentive_rate,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee,
    CAST(NULL AS STRING) AS special_fee_type
FROM v_dws_qi_daily_base b
LEFT JOIN v_qi_month_rates r
    ON CAST(DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = r.report_month;
