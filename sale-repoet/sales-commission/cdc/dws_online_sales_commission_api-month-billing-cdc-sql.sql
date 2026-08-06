--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-06
-- Updated Time:   2026-08-06 16:48:08
-- Description:    销售佣金API月账单20号后补入任务
-- 作业元信息：
--   作业类型：月度批式CDC补入任务
--   运行方式：每月20号账单生成后调度执行；当月内补跑仍写入当月8号快照分区
--   运行参数：无
-- Notes:
--   1. settlement_month 自动取当前日期上个月月初，例如2026-06-20处理2026-05。
--   2. 只补 open_api 月账单 future_payout 明细，不更新 dws_sales_commission_snapshot_p 汇总。
--   3. 当前物化视图中 open_api/month_receivable 映射为 api_monthly_billing，本任务补入时改写为 api_monthly_billing/future_payout。
--   4. payable_settlement_month = settlement_month + 1个月，对应下下月12号发薪展示。
--********************************************************************--

SET 'parallelism.default' = '2';
SET 'pipeline.operator-chaining' = 'false';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';
SET 'table.dml-sync' = 'true';

CREATE TEMPORARY TABLE source_recent_estimate (
    id BIGINT,
    report_date DATE,
    settlement_month DATE,
    root_account_id STRING,
    product STRING,
    provider STRING,
    item STRING,
    source_type STRING,
    commission_stage STRING,
    sale_id STRING,
    am_id STRING,
    department_id STRING,
    invite_type STRING,
    activity_month DATE,
    collection_month DATE,
    payable_settlement_month DATE,
    effective_revenue DECIMAL(20, 4),
    cogs DECIMAL(20, 4),
    gp DECIMAL(20, 4),
    commission_base DECIMAL(20, 4),
    commission_rate DECIMAL(10, 6),
    estimated_commission DECIMAL(20, 4),
    active_days INT,
    rule_code STRING,
    version INT,
    remarks STRING,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id, report_date, settlement_month, root_account_id, product, provider, item, source_type, commission_stage, sale_id, am_id, department_id, invite_type, activity_month, collection_month, payable_settlement_month, effective_revenue, cogs, gp, commission_base, commission_rate, estimated_commission, active_days, rule_code, 1 AS version, ''snapshot source from materialized view'' AS remarks, refreshed_at AS create_time, refreshed_at AS update_time, NULL::timestamp AS delete_time FROM dws.mv_sales_commission_recent_estimate WHERE settlement_month = date_trunc(''month'', CURRENT_DATE - interval ''1 month'')::date AND product = ''open_api'' AND source_type = ''api_monthly_billing'') AS recent_estimate_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY VIEW v_api_month_billing_detail AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(
        DATE_FORMAT(CAST(CAST(CONCAT(DATE_FORMAT(CAST(CURRENT_DATE AS TIMESTAMP(6)), 'yyyy-MM'), '-08') AS DATE) AS TIMESTAMP(6)), 'yyyyMMdd'), ':',
        DATE_FORMAT(CAST(settlement_month AS TIMESTAMP(6)), 'yyyyMM'), ':',
        root_account_id, ':', product, ':', COALESCE(provider, ''), ':', COALESCE(item, ''), ':',
        COALESCE(sale_id, ''), ':', 'api_monthly_billing', ':', 'future_payout'
    ))) AS BIGINT) AS id,
    CAST(CONCAT(DATE_FORMAT(CAST(CURRENT_DATE AS TIMESTAMP(6)), 'yyyy-MM'), '-08') AS DATE) AS snapshot_date,
    settlement_month,
    root_account_id,
    product,
    provider,
    item,
    CAST('api_monthly_billing' AS STRING) AS source_type,
    CAST('future_payout' AS STRING) AS commission_stage,
    sale_id,
    am_id,
    department_id,
    invite_type,
    activity_month,
    collection_month,
    CAST(settlement_month + INTERVAL '1' MONTH AS DATE) AS payable_settlement_month,
    effective_revenue,
    cogs,
    gp,
    commission_base,
    commission_rate,
    estimated_commission AS commission_amount,
    active_days,
    rule_code,
    1 AS version,
    CAST('api monthly billing cdc' AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM source_recent_estimate
WHERE delete_time IS NULL;

CREATE TEMPORARY TABLE sink_snapshot_detail (
    id BIGINT,
    snapshot_date DATE,
    settlement_month DATE,
    root_account_id STRING,
    product STRING,
    provider STRING,
    item STRING,
    source_type STRING,
    commission_stage STRING,
    sale_id STRING,
    am_id STRING,
    department_id STRING,
    invite_type STRING,
    activity_month DATE,
    collection_month DATE,
    payable_settlement_month DATE,
    effective_revenue DECIMAL(20, 4),
    cogs DECIMAL(20, 4),
    gp DECIMAL(20, 4),
    commission_base DECIMAL(20, 4),
    commission_rate DECIMAL(10, 6),
    commission_amount DECIMAL(20, 4),
    active_days INT,
    rule_code STRING,
    version INT,
    remarks STRING,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    PRIMARY KEY (id, snapshot_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_sales_commission_snapshot_detail_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_snapshot_detail
SELECT * FROM v_api_month_billing_detail;
