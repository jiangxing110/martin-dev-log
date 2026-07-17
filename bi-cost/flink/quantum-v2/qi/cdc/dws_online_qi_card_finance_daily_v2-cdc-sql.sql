--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-12
-- Updated Time:   2026-07-15
-- Description:    Quantum QI v2 DWS CDC 按月回刷
-- 作业元信息：
--   作业类型：批式 CDC 修复任务
--   运行方式：默认扫描昨天 DWM/source tag 变更，按受影响月份整月删除后重算
--   运行参数：无
-- Notes:
--   1. 主链路: DWM v2 -> DWS v2
--   2. 主干事实变化和 ods_bi_month_tag 配置变化都会进入 affected months
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
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dwm_qi_card_transaction_detail_v2_p',
    'targetSchema' = 'dwm',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY VIEW v_qi_fact_changed_months AS
SELECT DISTINCT
    CAST(DATE_FORMAT(CAST(transaction_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
FROM source_dwm_qi_card_transaction_detail_v2_p
WHERE (
        (source_update_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6)) AND source_update_time < CAST(CURRENT_DATE AS TIMESTAMP(6)))
     OR (source_delete_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6)) AND source_delete_time < CAST(CURRENT_DATE AS TIMESTAMP(6)))
     OR (update_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6)) AND update_time < CAST(CURRENT_DATE AS TIMESTAMP(6)))
     OR (delete_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6)) AND delete_time < CAST(CURRENT_DATE AS TIMESTAMP(6)))
  );

CREATE TEMPORARY VIEW v_qi_config_changed_months AS
SELECT DISTINCT
    CAST(DATE_FORMAT(CAST(statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
FROM source_bi_month_tag
WHERE provider = 'IQ'
  AND update_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6))
  AND update_time < CAST(CURRENT_DATE AS TIMESTAMP(6));

CREATE TEMPORARY VIEW v_qi_changed_months AS
SELECT
    report_month,
    CAST(DATE_FORMAT(CAST(DATE_ADD(report_month, 32) AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS next_month
FROM (
    SELECT report_month FROM v_qi_fact_changed_months
    UNION
    SELECT report_month FROM v_qi_config_changed_months
) changed;

CREATE TEMPORARY VIEW v_dws_qi_month_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(s.transaction_time, 'yyyyMMdd'), ':', s.account_id, ':', COALESCE(s.sale_id, ''), ':', COALESCE(s.am_id, '')))) AS BIGINT) AS id,
    CAST(s.transaction_time AS DATE) AS report_date,
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
FROM source_dwm_qi_card_transaction_detail_v2_p s
INNER JOIN v_qi_changed_months m
    ON CAST(DATE_FORMAT(CAST(s.transaction_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = m.report_month
WHERE s.delete_time IS NULL
GROUP BY CAST(s.transaction_time AS DATE), s.account_id, s.account_type, s.account_category, s.system_type, s.sale_id, s.am_id;

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

DELETE FROM sink_dws_qi_card_finance_daily_v2_p
WHERE (special_fee_type IS NULL OR special_fee_type <> 'CHANNEL_FIXED_FEE')
  AND EXISTS (
    SELECT 1
    FROM v_qi_changed_months m
    WHERE sink_dws_qi_card_finance_daily_v2_p.report_date >= m.report_month
      AND sink_dws_qi_card_finance_daily_v2_p.report_date < m.next_month
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
    ON CAST(DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = r.report_month;
