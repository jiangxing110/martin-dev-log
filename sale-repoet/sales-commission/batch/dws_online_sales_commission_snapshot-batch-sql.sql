--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-29
-- Updated Time:   2026-07-30 17:18:14
-- Description:    销售佣金快照批量固化/回刷
-- 作业元信息：
--   作业类型：批处理
--   运行方式：手动回刷或初始化指定结算月
--   运行参数：snapshot_date, settlement_month
-- Notes:
--   1. 从 dws.mv_sales_commission_recent_estimate 固化指定 settlement_month。
--   2. snapshot_date 通常为每月8号。
--   3. settlement_month 参数使用 yyyy-MM 格式，例如 2026-05；脚本内部转成 2026-05-01。
--********************************************************************--

SET 'parallelism.default' = '2';
SET 'pipeline.default-parallelism' = '2';
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
    operation_manager_id STRING,
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
    'table-name' = '(SELECT id, report_date, settlement_month, root_account_id, product, provider, item, source_type, commission_stage, sale_id, operation_manager_id, am_id, department_id, invite_type, activity_month, collection_month, payable_settlement_month, effective_revenue, cogs, gp, commission_base, commission_rate, estimated_commission, active_days, rule_code, 1 AS version, ''snapshot source from materialized view'' AS remarks, refreshed_at AS create_time, refreshed_at AS update_time, NULL::timestamp AS delete_time FROM dws.mv_sales_commission_recent_estimate WHERE settlement_month = CAST(CONCAT(''${settlement_month}'', ''-01'') AS date)) AS recent_estimate_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY VIEW v_snapshot_detail AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(
        DATE_FORMAT(CAST(CAST('${snapshot_date}' AS DATE) AS TIMESTAMP(6)), 'yyyyMMdd'), ':',
        DATE_FORMAT(CAST(settlement_month AS TIMESTAMP(6)), 'yyyyMM'), ':',
        root_account_id, ':', product, ':', COALESCE(provider, ''), ':', COALESCE(item, ''), ':',
        COALESCE(sale_id, ''), ':', source_type, ':', commission_stage
    ))) AS BIGINT) AS id,
    CAST('${snapshot_date}' AS DATE) AS snapshot_date,
    settlement_month,
    root_account_id,
    product,
    provider,
    item,
    source_type,
    commission_stage,
    sale_id,
    operation_manager_id,
    am_id,
    department_id,
    invite_type,
    activity_month,
    collection_month,
    payable_settlement_month,
    effective_revenue,
    cogs,
    gp,
    commission_base,
    commission_rate,
    estimated_commission AS commission_amount,
    active_days,
    rule_code,
    1 AS version,
    CAST('snapshot batch' AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM source_recent_estimate
WHERE delete_time IS NULL;

CREATE TEMPORARY VIEW v_snapshot AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(
        DATE_FORMAT(CAST(CAST('${snapshot_date}' AS DATE) AS TIMESTAMP(6)), 'yyyyMMdd'), ':',
        DATE_FORMAT(CAST(settlement_month AS TIMESTAMP(6)), 'yyyyMM'), ':',
        COALESCE(sale_id, ''), ':', COALESCE(am_id, '')
    ))) AS BIGINT) AS id,
    CAST('${snapshot_date}' AS DATE) AS snapshot_date,
    settlement_month,
    sale_id,
    operation_manager_id,
    am_id,
    CAST(SUM(CASE WHEN commission_stage = 'current_payout' THEN effective_revenue ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS total_effective_revenue,
    CAST(SUM(CASE WHEN commission_stage = 'current_payout' THEN cogs ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS total_cogs,
    CAST(SUM(CASE WHEN commission_stage = 'current_payout' THEN gp ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS total_gp,
    CAST(SUM(CASE WHEN commission_stage = 'current_payout' THEN estimated_commission ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS total_commission,
    1 AS version,
    CAST('snapshot batch' AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM source_recent_estimate
WHERE delete_time IS NULL
GROUP BY settlement_month, sale_id, operation_manager_id, am_id;

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
    operation_manager_id STRING,
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

CREATE TEMPORARY TABLE sink_snapshot (
    id BIGINT,
    snapshot_date DATE,
    settlement_month DATE,
    sale_id STRING,
    operation_manager_id STRING,
    am_id STRING,
    total_effective_revenue DECIMAL(20, 4),
    total_cogs DECIMAL(20, 4),
    total_gp DECIMAL(20, 4),
    total_commission DECIMAL(20, 4),
    version INT,
    remarks STRING,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    PRIMARY KEY (id, snapshot_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_sales_commission_snapshot_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '1000'
);

-- 两张快照表必须在同一个 Flink 作业里提交，避免 batch application 模式下多 INSERT 报错。
EXECUTE STATEMENT SET
BEGIN
INSERT INTO sink_snapshot_detail
SELECT * FROM v_snapshot_detail;

INSERT INTO sink_snapshot
SELECT * FROM v_snapshot;
END;
