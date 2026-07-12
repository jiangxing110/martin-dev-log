--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-15
-- 历史名称：sp_init_qi_card_dws_by_fast.sql
-- Description:    Quantum QI v2 DWS 批量初始化/回刷
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性初始化/回刷或调度执行
--   运行参数：start_date, end_date
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑或由上游 CDC ODS/DIM 提供最新数据。
-- Notes:
--   1. 主链路: DWM -> DWS
--   2. 粒度: account_id + report_date + sale_id + am_id
--   3. 新增成本/返现 base 字段，保留旧 vol 字段兼容
--   4. cost_fixed_fee 由 ods_bi_month_tag 月固定成本按当月 DWS 行数均摊
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

CREATE TEMPORARY VIEW v_dws_qi_daily_base AS
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
FROM source_dwm_qi_card_transaction_detail_p
WHERE delete_time IS NULL
GROUP BY CAST(transaction_time AS DATE), account_id, account_type, account_category, system_type, sale_id, am_id;

CREATE TEMPORARY VIEW v_qi_month_scope AS
SELECT DISTINCT CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
FROM v_dws_qi_daily_base;

CREATE TEMPORARY VIEW v_qi_month_row_count AS
SELECT
    CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month,
    COUNT(*) AS row_count
FROM v_dws_qi_daily_base
GROUP BY CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE);

CREATE TEMPORARY VIEW v_qi_month_fixed_fee AS
SELECT report_month, amount AS month_fixed_fee
FROM (
    SELECT
        s.report_month,
        t.amount,
        ROW_NUMBER() OVER (
            PARTITION BY s.report_month
            ORDER BY t.statistics_time DESC, t.update_time DESC, t.id DESC
        ) AS rn
    FROM v_qi_month_scope s
    LEFT JOIN source_bi_month_tag t
        ON t.provider = 'IQ'
       AND t.tag = '量子卡-渠道固定成本'
       AND t.delete_time IS NULL
       AND t.statistics_time < CAST(DATE_FORMAT(CAST(DATE_ADD(s.report_month, 32) AS TIMESTAMP(6)), 'yyyy-MM-01') AS TIMESTAMP(6))
) ranked_fee
WHERE rn = 1;

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
    b.cost_reimbursement_rate,
    b.cost_service_rate,
    b.cost_acs_regular_rate,
    b.cost_acs_vip_rate,
    b.cost_vrm_rate,
    b.rebate_interchange_rate,
    b.rebate_incentive_rate,
    b.cost_reimbursement_vol,
    b.cost_service_vol,
    b.cost_acs_regular_count,
    b.cost_acs_vip_count,
    b.cost_vrm_count,
    b.rebate_interchange_vol,
    b.rebate_incentive_vol,
    COALESCE(f.month_fixed_fee / NULLIF(c.row_count, 0), CAST(0 AS DECIMAL(20, 4))) AS cost_fixed_fee
FROM v_dws_qi_daily_base b
LEFT JOIN v_qi_month_row_count c
    ON CAST(DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = c.report_month
LEFT JOIN v_qi_month_fixed_fee f
    ON CAST(DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = f.report_month;
