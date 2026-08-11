-- Notes:
--   1. v2 在同一个 Flink SQL 作业中通过 JDBC source 调用 dws.fn_delete_qi_card_finance_daily_v2_cdc(false) 先清理目标数据。
--   2. 部署时需要在“附加依赖文件”添加 PostgreSQL JDBC driver，例如 postgresql-42.7.4.jar。
--   3. 首次执行可将函数参数 false 改为 true 做 dry-run。
--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-12
-- Updated Time:   2026-08-09 11:44:08
-- Description:    Quantum QI v2 DWS CDC 按月重算写入 v2
-- 作业元信息：
--   作业类型：批式 CDC 修复任务
--   运行方式：默认扫描昨天 DWM/source tag 变更，按受影响月份整月删除后重算
--   运行参数：无
-- Notes:
--   1. 主链路: DWM v2 -> DWS v2
--   2. 主干事实变化和 ods_bi_month_tag 配置变化都会进入 affected months
--   3. 只记录成本/返现计费基数和对应 rate，结果金额由下游按 base * rate 计算
--********************************************************************--

SET 'parallelism.default' = '4';
SET 'pipeline.default-parallelism' = '4';
SET 'table.exec.resource.default-parallelism' = '4';
SET 'pipeline.operator-chaining' = 'true';
SET 'taskmanager.memory.network.min' = '1gb';
SET 'taskmanager.memory.network.max' = '3gb';
SET 'taskmanager.memory.network.fraction' = '0.2';
SET 'taskmanager.network.sort-shuffle.min-buffers' = '512';
SET 'heartbeat.timeout' = '600000';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

-- ==============================================
-- 0. 【临时表】ADBPG 删除函数调用结果
-- ==============================================
CREATE TEMPORARY TABLE source_delete_qi_card_finance_daily_v2_cdc_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT dws.fn_delete_qi_card_finance_daily_v2_cdc(false) AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);
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

CREATE TEMPORARY TABLE source_qi_changed_keys (
    report_date DATE,
    account_id  STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(WITH fact_changed_keys AS (SELECT DISTINCT transaction_time::date AS report_date, account_id FROM dwm.dwm_qi_card_transaction_detail_v2_p WHERE transaction_time IS NOT NULL AND account_id IS NOT NULL AND ((source_update_time >= CURRENT_DATE - INTERVAL ''1 day'' AND source_update_time < CURRENT_DATE) OR (source_delete_time >= CURRENT_DATE - INTERVAL ''1 day'' AND source_delete_time < CURRENT_DATE) OR (update_time >= CURRENT_DATE - INTERVAL ''1 day'' AND update_time < CURRENT_DATE) OR (delete_time >= CURRENT_DATE - INTERVAL ''1 day'' AND delete_time < CURRENT_DATE))), config_changed_months AS (SELECT DISTINCT DATE_TRUNC(''month'', statistics_time)::date AS report_month FROM ods.ods_bi_month_tag WHERE delete_time IS NULL AND provider = ''IQ'' AND tag IN (''QI_COST_REIMBURSEMENT_RATE'', ''QI_COST_SERVICE_RATE'', ''QI_COST_ACS_REGULAR_RATE'', ''QI_COST_ACS_VIP_RATE'', ''QI_COST_VRM_RATE'', ''QI_COST_HK_REGULAR_RATE'', ''QI_COST_HK_VIP_RATE'', ''QI_COST_DCSF_RATE'', ''QI_REBATE_INTERCHANGE_RATE'', ''QI_REBATE_INCENTIVE_RATE'') AND update_time >= CURRENT_DATE - INTERVAL ''1 day'' AND update_time < CURRENT_DATE AND statistics_time IS NOT NULL), config_changed_keys AS (SELECT DISTINCT s.transaction_time::date AS report_date, s.account_id FROM dwm.dwm_qi_card_transaction_detail_v2_p s JOIN config_changed_months m ON s.transaction_time >= m.report_month AND s.transaction_time < m.report_month + INTERVAL ''1 month'' WHERE s.delete_time IS NULL AND s.transaction_time IS NOT NULL AND s.account_id IS NOT NULL), changed_keys AS (SELECT report_date, account_id FROM fact_changed_keys UNION SELECT report_date, account_id FROM config_changed_keys) SELECT report_date, account_id FROM changed_keys) AS qi_changed_keys_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '100'
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
    -- CDC 按受影响 report_date + account_id 重算，避免整月全账户重刷导致 TM heartbeat timeout。
    'table-name' = '(WITH fact_changed_keys AS (SELECT DISTINCT transaction_time::date AS report_date, account_id FROM dwm.dwm_qi_card_transaction_detail_v2_p WHERE transaction_time IS NOT NULL AND account_id IS NOT NULL AND ((source_update_time >= CURRENT_DATE - INTERVAL ''1 day'' AND source_update_time < CURRENT_DATE) OR (source_delete_time >= CURRENT_DATE - INTERVAL ''1 day'' AND source_delete_time < CURRENT_DATE) OR (update_time >= CURRENT_DATE - INTERVAL ''1 day'' AND update_time < CURRENT_DATE) OR (delete_time >= CURRENT_DATE - INTERVAL ''1 day'' AND delete_time < CURRENT_DATE))), config_changed_months AS (SELECT DISTINCT DATE_TRUNC(''month'', statistics_time)::date AS report_month FROM ods.ods_bi_month_tag WHERE delete_time IS NULL AND provider = ''IQ'' AND tag IN (''QI_COST_REIMBURSEMENT_RATE'', ''QI_COST_SERVICE_RATE'', ''QI_COST_ACS_REGULAR_RATE'', ''QI_COST_ACS_VIP_RATE'', ''QI_COST_VRM_RATE'', ''QI_COST_HK_REGULAR_RATE'', ''QI_COST_HK_VIP_RATE'', ''QI_COST_DCSF_RATE'', ''QI_REBATE_INTERCHANGE_RATE'', ''QI_REBATE_INCENTIVE_RATE'') AND update_time >= CURRENT_DATE - INTERVAL ''1 day'' AND update_time < CURRENT_DATE AND statistics_time IS NOT NULL), config_changed_keys AS (SELECT DISTINCT s.transaction_time::date AS report_date, s.account_id FROM dwm.dwm_qi_card_transaction_detail_v2_p s JOIN config_changed_months m ON s.transaction_time >= m.report_month AND s.transaction_time < m.report_month + INTERVAL ''1 month'' WHERE s.delete_time IS NULL AND s.transaction_time IS NOT NULL AND s.account_id IS NOT NULL), changed_keys AS (SELECT report_date, account_id FROM fact_changed_keys UNION SELECT report_date, account_id FROM config_changed_keys) SELECT id, transaction_id, account_id, account_type, account_category, system_type, status, transaction_time, version, remarks, create_time, update_time, delete_time, source_update_time, source_delete_time, is_current_valid, billing_amount, is_qbit_provision, is_hk_region, is_consumption, is_reversal_or_credit, has_special_code, is_vip_account, business_type, card_id, sale_id, am_id FROM dwm.dwm_qi_card_transaction_detail_v2_p s WHERE s.delete_time IS NULL AND EXISTS (SELECT 1 FROM changed_keys k WHERE s.transaction_time >= k.report_date AND s.transaction_time < k.report_date + INTERVAL ''1 day'' AND s.account_id = k.account_id)) AS dwm_qi_card_transaction_detail_v2_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY VIEW v_qi_changed_months AS
SELECT DISTINCT
    CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month,
    CAST(DATE_FORMAT(CAST(DATE_ADD(CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE), 32) AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS next_month
FROM source_qi_changed_keys;

CREATE TEMPORARY VIEW v_qi_dwm_month_rows AS
SELECT
    CAST(s.transaction_time AS DATE) AS report_date,
    s.account_id,
    s.account_type,
    s.account_category,
    s.system_type,
    s.status,
    s.billing_amount,
    s.is_hk_region,
    s.business_type,
    s.has_special_code,
    s.sale_id,
    s.am_id
FROM source_dwm_qi_card_transaction_detail_v2_p s
INNER JOIN source_qi_changed_keys k
    ON CAST(s.transaction_time AS DATE) = k.report_date
   AND s.account_id = k.account_id
WHERE s.delete_time IS NULL;

CREATE TEMPORARY VIEW v_dws_qi_month_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', account_id, ':', COALESCE(sale_id, ''), ':', COALESCE(am_id, '')))) AS BIGINT) AS id,
    report_date,
    s.account_id,
    s.account_type,
    s.account_category,
    s.system_type,
    1 AS version,
    CAST(NULL AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time,
    s.sale_id,
    s.am_id,
    CAST(SUM(CASE WHEN s.is_hk_region = FALSE AND s.business_type = 'Consumption' AND s.status IN ('Closed', 'Pending') THEN s.billing_amount * CAST(0.0135 AS DECIMAL(20, 4)) ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS cost_reimbursement_base_amt,
    CAST(SUM(CASE WHEN s.is_hk_region = FALSE AND s.status IN ('Closed', 'Pending') AND s.business_type IN ('Consumption', 'Reversal', 'Credit') THEN
        CASE
            WHEN ABS(s.billing_amount) < 5 THEN s.billing_amount * CAST(0.00095 AS DECIMAL(20, 4))
            WHEN ABS(s.billing_amount) < 10 THEN s.billing_amount * CAST(0.00145 AS DECIMAL(20, 4))
            WHEN ABS(s.billing_amount) < 50 THEN s.billing_amount * CAST(0.0022 AS DECIMAL(20, 4))
            WHEN ABS(s.billing_amount) < 250 THEN s.billing_amount * CAST(0.0037 AS DECIMAL(20, 4))
            ELSE s.billing_amount * CAST(0.00445 AS DECIMAL(20, 4))
        END * CASE WHEN s.business_type = 'Consumption' THEN 1 ELSE -1 END
        ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS cost_service_base_amt,
    CAST(SUM(CASE WHEN s.is_hk_region = FALSE AND s.business_type = 'Consumption' AND s.status IN ('Closed', 'Pending') THEN
        CASE
            WHEN s.billing_amount < 5 THEN 0.01
            WHEN s.billing_amount < 10 THEN 0.055
            WHEN s.billing_amount < 50 THEN 0.08
            WHEN s.billing_amount < 250 THEN 0.12
            ELSE 0.14
        END ELSE 0 END) AS DECIMAL(20, 4)) AS cost_acs_regular_base_amt,
    CAST(SUM(CASE WHEN s.is_hk_region = FALSE AND s.business_type = 'Consumption' AND s.has_special_code = FALSE THEN
        CASE
            WHEN s.billing_amount < 5 THEN 0.04
            WHEN s.billing_amount < 10 THEN 0.22
            WHEN s.billing_amount < 50 THEN 0.255
            WHEN s.billing_amount < 250 THEN 0.48
            ELSE 0.56
        END ELSE 0 END) AS DECIMAL(20, 4)) AS cost_acs_vip_base_amt,
    CAST(SUM(CASE WHEN s.is_hk_region = FALSE AND s.business_type = 'Consumption' AND s.has_special_code = FALSE THEN 0.09 ELSE 0 END) AS DECIMAL(20, 4)) AS cost_vrm_base_amt,
    CAST(SUM(CASE WHEN s.is_hk_region = TRUE AND s.business_type = 'Consumption' AND s.status IN ('Closed', 'Pending') THEN
        CASE
            WHEN s.billing_amount < 5 THEN 0.004
            WHEN s.billing_amount < 50 THEN 0.018
            ELSE 0.032
        END ELSE 0 END) AS DECIMAL(20, 4)) AS cost_hk_regular_base_amt,
    CAST(SUM(CASE WHEN s.is_hk_region = TRUE AND s.business_type = 'Consumption' AND s.status IN ('Closed', 'Pending') AND s.has_special_code = FALSE THEN
        CASE
            WHEN s.billing_amount < 5 THEN 0.006
            WHEN s.billing_amount < 50 THEN 0.027
            ELSE 0.048
        END ELSE 0 END) AS DECIMAL(20, 4)) AS cost_hk_vip_base_amt,
    CAST(SUM(CASE WHEN s.is_hk_region = FALSE AND s.business_type = 'Consumption' AND s.has_special_code = FALSE THEN
        CASE
            WHEN s.billing_amount <= 50 THEN 0.025
            WHEN s.billing_amount <= 1000 THEN s.billing_amount * CAST(0.0005 AS DECIMAL(20, 4))
            WHEN s.billing_amount > 1000 THEN 0.5
            ELSE 0
        END ELSE 0 END) AS DECIMAL(20, 4)) AS cost_dcsf_base_amt,
    CAST(SUM(CASE WHEN s.status IN ('Closed', 'Pending') AND s.is_hk_region = FALSE AND s.business_type = 'Consumption' THEN s.billing_amount * CAST(0.02 AS DECIMAL(20, 4)) ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS rebate_interchange_base_amt,
    CAST(SUM(CASE WHEN s.status IN ('Closed', 'Pending') AND s.business_type = 'Consumption' THEN s.billing_amount * CAST(0.0118 AS DECIMAL(20, 4)) ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS rebate_incentive_base_amt
FROM v_qi_dwm_month_rows s
GROUP BY report_date, s.account_id, s.account_type, s.account_category, s.system_type, s.sale_id, s.am_id;

CREATE TEMPORARY VIEW v_qi_month_row_count AS
SELECT
    CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month,
    COUNT(*) AS row_count
FROM v_dws_qi_month_base
GROUP BY CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE);

CREATE TEMPORARY VIEW v_qi_month_tag_ranked AS
SELECT report_month, tag, amount
FROM (
    SELECT
        m.report_month,
        t.tag,
        t.amount,
        ROW_NUMBER() OVER (
            PARTITION BY m.report_month, t.tag
            ORDER BY
                CASE WHEN t.detail = 'DEFAULT_FALLBACK' THEN 1 ELSE 0 END,
                t.statistics_time DESC,
                t.update_time DESC,
                t.id DESC
        ) AS rn
    FROM v_qi_changed_months m
    LEFT JOIN source_bi_month_tag t
        ON t.provider = 'IQ'
       AND t.delete_time IS NULL
       AND (
              CAST(DATE_FORMAT(CAST(t.statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = m.report_month
           OR CAST(DATE_FORMAT(CAST(t.statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = DATE '2099-01-01'
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
    MAX(CASE WHEN tag = 'QI_COST_HK_REGULAR_RATE' THEN amount END) AS cost_hk_regular_rate,
    MAX(CASE WHEN tag = 'QI_COST_HK_VIP_RATE' THEN amount END) AS cost_hk_vip_rate,
    MAX(CASE WHEN tag = 'QI_COST_DCSF_RATE' THEN amount END) AS cost_dcsf_rate,
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
    cost_hk_regular_base_amt      DECIMAL(20, 4),
    cost_hk_vip_base_amt          DECIMAL(20, 4),
    cost_dcsf_base_amt            DECIMAL(20, 4),
    rebate_interchange_base_amt   DECIMAL(20, 4),
    rebate_incentive_base_amt     DECIMAL(20, 4),
    cost_reimbursement_rate       DECIMAL(20, 8),
    cost_service_rate             DECIMAL(20, 8),
    cost_acs_regular_rate         DECIMAL(20, 8),
    cost_acs_vip_rate             DECIMAL(20, 8),
    cost_vrm_rate                 DECIMAL(20, 8),
    cost_hk_regular_rate          DECIMAL(20, 8),
    cost_hk_vip_rate              DECIMAL(20, 8),
    cost_dcsf_rate                DECIMAL(20, 8),
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
    b.cost_hk_regular_base_amt,
    b.cost_hk_vip_base_amt,
    b.cost_dcsf_base_amt,
    b.rebate_interchange_base_amt,
    b.rebate_incentive_base_amt,
    CAST(COALESCE(r.cost_reimbursement_rate, 1) AS DECIMAL(20, 8)) AS cost_reimbursement_rate,
    CAST(COALESCE(r.cost_service_rate, 1) AS DECIMAL(20, 8)) AS cost_service_rate,
    CAST(COALESCE(r.cost_acs_regular_rate, 1) AS DECIMAL(20, 8)) AS cost_acs_regular_rate,
    CAST(COALESCE(r.cost_acs_vip_rate, 1) AS DECIMAL(20, 8)) AS cost_acs_vip_rate,
    CAST(COALESCE(r.cost_vrm_rate, 1) AS DECIMAL(20, 8)) AS cost_vrm_rate,
    CAST(COALESCE(r.cost_hk_regular_rate, 1) AS DECIMAL(20, 8)) AS cost_hk_regular_rate,
    CAST(COALESCE(r.cost_hk_vip_rate, 1) AS DECIMAL(20, 8)) AS cost_hk_vip_rate,
    CAST(COALESCE(r.cost_dcsf_rate, 1) AS DECIMAL(20, 8)) AS cost_dcsf_rate,
    CAST(COALESCE(r.rebate_interchange_rate, 1) AS DECIMAL(20, 8)) AS rebate_interchange_rate,
    CAST(COALESCE(r.rebate_incentive_rate, 1) AS DECIMAL(20, 8)) AS rebate_incentive_rate,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee,
    CAST(NULL AS STRING) AS special_fee_type
FROM v_dws_qi_month_base b
LEFT JOIN v_qi_month_rates r
    ON CAST(DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = r.report_month
CROSS JOIN source_delete_qi_card_finance_daily_v2_cdc_result AS delete_result
WHERE delete_result.affected_rows >= 0;
