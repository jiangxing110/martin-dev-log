--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-02
-- Description:    销售毛利每月20号后API月账单补入任务
-- 作业元信息：
--   作业类型：月度批式CDC固化任务
--   运行方式：每月20号账单生成后调度；补跑仍写入本月8号快照分区
--   运行参数：无
-- Notes:
--   1. 读取当前日期上个月结算月，等API月账单同步并刷新预估视图后执行。
--   2. snapshot_date 固定为当前月份8号，与8号首份快照相同。
--   3. 按完整月视图重算并upsert汇总、明细；不是将API金额累加到旧快照。
--   4. 汇总表和明细表在同一个 Statement Set 内 upsert。
--********************************************************************--

SET 'parallelism.default' = '2';
SET 'pipeline.operator-chaining' = 'false';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';
SET 'table.dml-sync' = 'true';

CREATE TEMPORARY TABLE source_recent_estimate (
    id BIGINT,
    report_month DATE,
    settlement_month DATE,
    root_account_id STRING,
    product STRING,
    provider STRING,
    sale_id STRING,
    metric_code STRING,
    source_type STRING,
    pref_rev DECIMAL(20,4),
    client_rebate DECIMAL(20,4),
    client_collection_rebate DECIMAL(20,4),
    gross_profit_rebate DECIMAL(20,4),
    rebate DECIMAL(20,4),
    pref_rev_effective DECIMAL(20,4),
    cost DECIMAL(20,4),
    pref_gp DECIMAL(20,4),
    cashflow_rev_sale DECIMAL(20,4),
    cashflow_rev_sale_effective DECIMAL(20,4),
    cashflow_gp_sale DECIMAL(20,4),
    refreshed_at TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id, report_month, settlement_month, root_account_id, product, provider, sale_id, metric_code, source_type, pref_rev, client_rebate, client_collection_rebate, gross_profit_rebate, rebate, pref_rev_effective, cost, pref_gp, cashflow_rev_sale, cashflow_rev_sale_effective, cashflow_gp_sale, refreshed_at FROM dws.mv_sales_gross_profit_recent_estimate WHERE settlement_month = date_trunc(''month'', CURRENT_DATE - interval ''1 month'')::date) AS gross_profit_estimate_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY VIEW v_snapshot_detail AS
SELECT
    CAST(ABS(CAST(HASH_CODE(CONCAT(
        DATE_FORMAT(CAST(CAST(CONCAT(DATE_FORMAT(CAST(CURRENT_DATE AS TIMESTAMP(6)), 'yyyy-MM'), '-08') AS DATE) AS TIMESTAMP(6)), 'yyyyMMdd'), ':',
        CAST(id AS STRING)
    )) AS BIGINT)) AS BIGINT) AS id,
    CAST(CONCAT(DATE_FORMAT(CAST(CURRENT_DATE AS TIMESTAMP(6)), 'yyyy-MM'), '-08') AS DATE) AS snapshot_date,
    settlement_month,
    report_month,
    sale_id,
    root_account_id,
    product,
    provider,
    metric_code,
    source_type,
    pref_rev,
    client_rebate,
    client_collection_rebate,
    gross_profit_rebate,
    rebate,
    pref_rev_effective,
    cost,
    pref_gp,
    cashflow_rev_sale,
    cashflow_rev_sale_effective,
    cashflow_gp_sale,
    1 AS version,
    CAST('sales gross profit API monthly billing supplement' AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM source_recent_estimate;

CREATE TEMPORARY VIEW v_snapshot AS
SELECT
    CAST(ABS(CAST(HASH_CODE(CONCAT(
        DATE_FORMAT(CAST(CAST(CONCAT(DATE_FORMAT(CAST(CURRENT_DATE AS TIMESTAMP(6)), 'yyyy-MM'), '-08') AS DATE) AS TIMESTAMP(6)), 'yyyyMMdd'), ':',
        DATE_FORMAT(CAST(settlement_month AS TIMESTAMP(6)), 'yyyyMM'), ':', COALESCE(sale_id, '<NULL>')
    )) AS BIGINT)) AS BIGINT) AS id,
    CAST(CONCAT(DATE_FORMAT(CAST(CURRENT_DATE AS TIMESTAMP(6)), 'yyyy-MM'), '-08') AS DATE) AS snapshot_date,
    settlement_month,
    sale_id,
    CAST(SUM(pref_rev) AS DECIMAL(20,4)) AS pref_rev,
    CAST(SUM(client_rebate) AS DECIMAL(20,4)) AS client_rebate,
    CAST(SUM(client_collection_rebate) AS DECIMAL(20,4)) AS client_collection_rebate,
    CAST(SUM(gross_profit_rebate) AS DECIMAL(20,4)) AS gross_profit_rebate,
    CAST(SUM(rebate) AS DECIMAL(20,4)) AS rebate,
    CAST(SUM(pref_rev_effective) AS DECIMAL(20,4)) AS pref_rev_effective,
    CAST(SUM(cost) AS DECIMAL(20,4)) AS cost,
    CAST(SUM(pref_gp) AS DECIMAL(20,4)) AS pref_gp,
    CAST(SUM(cashflow_rev_sale) AS DECIMAL(20,4)) AS cashflow_rev_sale,
    CAST(SUM(cashflow_rev_sale_effective) AS DECIMAL(20,4)) AS cashflow_rev_sale_effective,
    CAST(SUM(cashflow_gp_sale) AS DECIMAL(20,4)) AS cashflow_gp_sale,
    1 AS version,
    CAST('sales gross profit API monthly billing supplement' AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM source_recent_estimate
GROUP BY settlement_month, sale_id;

CREATE TEMPORARY TABLE sink_snapshot_detail (
    id BIGINT,
    snapshot_date DATE,
    settlement_month DATE,
    report_month DATE,
    sale_id STRING,
    root_account_id STRING,
    product STRING,
    provider STRING,
    metric_code STRING,
    source_type STRING,
    pref_rev DECIMAL(20,4),
    client_rebate DECIMAL(20,4),
    client_collection_rebate DECIMAL(20,4),
    gross_profit_rebate DECIMAL(20,4),
    rebate DECIMAL(20,4),
    pref_rev_effective DECIMAL(20,4),
    cost DECIMAL(20,4),
    pref_gp DECIMAL(20,4),
    cashflow_rev_sale DECIMAL(20,4),
    cashflow_rev_sale_effective DECIMAL(20,4),
    cashflow_gp_sale DECIMAL(20,4),
    version INT,
    remarks STRING,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    PRIMARY KEY (id, snapshot_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_sales_gross_profit_snapshot_detail_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

CREATE TEMPORARY TABLE sink_snapshot (
    id BIGINT,
    snapshot_date DATE,
    settlement_month DATE,
    sale_id STRING,
    pref_rev DECIMAL(20,4),
    client_rebate DECIMAL(20,4),
    client_collection_rebate DECIMAL(20,4),
    gross_profit_rebate DECIMAL(20,4),
    rebate DECIMAL(20,4),
    pref_rev_effective DECIMAL(20,4),
    cost DECIMAL(20,4),
    pref_gp DECIMAL(20,4),
    cashflow_rev_sale DECIMAL(20,4),
    cashflow_rev_sale_effective DECIMAL(20,4),
    cashflow_gp_sale DECIMAL(20,4),
    version INT,
    remarks STRING,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    PRIMARY KEY (id, snapshot_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_sales_gross_profit_snapshot_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '1000'
);

EXECUTE STATEMENT SET
BEGIN
INSERT INTO sink_snapshot_detail SELECT * FROM v_snapshot_detail;
INSERT INTO sink_snapshot SELECT * FROM v_snapshot;
END;
