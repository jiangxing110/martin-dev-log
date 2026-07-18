--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-07-16
-- Description:    Quantum QI 老表固定渠道成本批量回刷
-- 作业元信息：
--   作业类型：批处理
--   运行方式：按 start_date/end_date 覆盖月份重算 cost_fixed_fee
--   运行参数：start_date, end_date
-- Notes:
--   1. 老表没有 special_fee_type，固定成本直接回写已有 DWS 明细行的 cost_fixed_fee。
--   2. 不新增额外特殊费用行；只更新已有 (id, report_date)。
--   3. 固定成本来源 ods.ods_bi_month_tag，tag = CHANNEL_COST，provider = IQ。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';

CREATE TEMPORARY TABLE source_bi_month_tag (
    id              BIGINT,
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
    'table-name' = '(SELECT id, provider, tag, statistics_time, amount, detail, update_time, delete_time FROM ods.ods_bi_month_tag WHERE delete_time IS NULL) AS bi_month_tag_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_dws_qi_card_finance_daily_p (
    id                     BIGINT,
    report_date            DATE,
    account_id             STRING,
    account_type           STRING,
    account_category       STRING,
    system_type            STRING,
    version                INT,
    remarks                STRING,
    create_time            TIMESTAMP(6),
    update_time            TIMESTAMP(6),
    delete_time            TIMESTAMP(6),
    sale_id                STRING,
    am_id                  STRING,
    cost_reimbursement_vol DECIMAL(20, 4),
    cost_service_vol       DECIMAL(20, 4),
    cost_acs_regular_count INT,
    cost_acs_vip_count     INT,
    cost_vrm_count         INT,
    rebate_interchange_vol DECIMAL(20, 4),
    rebate_incentive_vol   DECIMAL(20, 4),
    cost_fixed_fee         DECIMAL(20, 4),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id, report_date, account_id, account_type, account_category, system_type, version, remarks, create_time, update_time, delete_time, sale_id, am_id, cost_reimbursement_vol, cost_service_vol, cost_acs_regular_count, cost_acs_vip_count, cost_vrm_count, rebate_interchange_vol, rebate_incentive_vol, cost_fixed_fee FROM dws.dws_qi_card_finance_daily_p WHERE report_date >= CAST(''${start_date}'' AS date) AND report_date < CAST(''${end_date}'' AS date)) AS dws_qi_card_finance_daily_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_month_scope AS
SELECT DISTINCT
    CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month,
    CAST(DATE_FORMAT(CAST(DATE_ADD(CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE), 32) AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS next_month
FROM source_dws_qi_card_finance_daily_p
WHERE report_date >= CAST('${start_date}' AS DATE)
  AND report_date < CAST('${end_date}' AS DATE)
  AND delete_time IS NULL;

CREATE TEMPORARY VIEW v_month_channel_cost AS
SELECT report_month, amount AS month_fixed_fee
FROM (
    SELECT
        m.report_month,
        t.amount,
        ROW_NUMBER() OVER (
            PARTITION BY m.report_month
            ORDER BY
                CASE WHEN t.detail = 'DEFAULT_FALLBACK' THEN 1 ELSE 0 END,
                t.statistics_time DESC,
                t.update_time DESC,
                t.id DESC
        ) AS rn
    FROM v_month_scope m
    LEFT JOIN source_bi_month_tag t
        ON t.tag = 'CHANNEL_COST'
       AND t.provider = 'IQ'
       AND t.delete_time IS NULL
       AND (
              CAST(DATE_FORMAT(CAST(t.statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = m.report_month
           OR CAST(DATE_FORMAT(CAST(t.statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = DATE '2099-01-01'
           OR t.detail = 'DEFAULT_FALLBACK'
       )
) ranked
WHERE rn = 1;

CREATE TEMPORARY VIEW v_month_row_count AS
SELECT
    CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month,
    COUNT(*) AS row_count
FROM source_dws_qi_card_finance_daily_p
WHERE delete_time IS NULL
GROUP BY CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE);

CREATE TEMPORARY VIEW v_fixed_fee_update_rows AS
SELECT
    d.id,
    d.report_date,
    d.account_id,
    d.account_type,
    d.account_category,
    d.system_type,
    d.version,
    d.remarks,
    d.create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    d.delete_time,
    d.sale_id,
    d.am_id,
    d.cost_reimbursement_vol,
    d.cost_service_vol,
    d.cost_acs_regular_count,
    d.cost_acs_vip_count,
    d.cost_vrm_count,
    d.rebate_interchange_vol,
    d.rebate_incentive_vol,
    CAST(COALESCE(c.month_fixed_fee / NULLIF(rc.row_count, 0), 0) AS DECIMAL(20, 4)) AS cost_fixed_fee
FROM source_dws_qi_card_finance_daily_p d
LEFT JOIN v_month_row_count rc
    ON CAST(DATE_FORMAT(CAST(d.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = rc.report_month
LEFT JOIN v_month_channel_cost c
    ON c.report_month = rc.report_month
WHERE d.delete_time IS NULL;

CREATE TEMPORARY TABLE sink_dws_qi_card_finance_daily_p (
    id                     BIGINT,
    report_date            DATE,
    account_id             STRING,
    account_type           STRING,
    account_category       STRING,
    system_type            STRING,
    version                INT,
    remarks                STRING,
    create_time            TIMESTAMP(6),
    update_time            TIMESTAMP(6),
    delete_time            TIMESTAMP(6),
    sale_id                STRING,
    am_id                  STRING,
    cost_reimbursement_vol DECIMAL(20, 4),
    cost_service_vol       DECIMAL(20, 4),
    cost_acs_regular_count INT,
    cost_acs_vip_count     INT,
    cost_vrm_count         INT,
    rebate_interchange_vol DECIMAL(20, 4),
    rebate_incentive_vol   DECIMAL(20, 4),
    cost_fixed_fee         DECIMAL(20, 4),
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
    cost_reimbursement_vol,
    cost_service_vol,
    cost_acs_regular_count,
    cost_acs_vip_count,
    cost_vrm_count,
    rebate_interchange_vol,
    rebate_incentive_vol,
    cost_fixed_fee
FROM v_fixed_fee_update_rows;
