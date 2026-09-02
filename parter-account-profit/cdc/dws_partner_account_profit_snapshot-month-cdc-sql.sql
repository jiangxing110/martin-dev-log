--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-09-02
-- Description:    合伙人客户毛利每月21号快照任务
-- Notes: 当前月21号执行，固定当前月上个月数据；补跑仍使用当月21号作为snapshot_date。
--********************************************************************--

-- 本脚本与 batch 版本逻辑一致，使用当前日期自动计算参数。
-- 例：2026-09-21 执行时 snapshot_date=2026-09-21，settlement_month=2026-08。

SET 'parallelism.default' = '2';
SET 'table.dml-sync' = 'true';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';

CREATE TEMPORARY TABLE source_profit (
  id BIGINT, report_date DATE, settlement_month DATE, root_account_id STRING,
  root_account_referral_id STRING, product STRING, source_product STRING,
  provider STRING, item STRING, source_type STRING,
  effective_revenue DECIMAL(20,4), cogs DECIMAL(20,4), gp DECIMAL(20,4),
  PRIMARY KEY (id) NOT ENFORCED
) WITH (
  'connector' = 'jdbc',
  'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
  'table-name' = '(SELECT id, report_date, settlement_month, root_account_id, root_account_referral_id, product, source_product, provider, item, source_type, effective_revenue, cogs, gp FROM dws.mv_partner_account_profit_recent_estimate WHERE settlement_month = date_trunc(''month'', CURRENT_DATE - interval ''1 month'')::date) AS profit_f',
  'username' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}',
  'driver' = 'org.postgresql.Driver', 'scan.fetch-size' = '5000', 'scan.auto-commit' = 'false'
);

CREATE TEMPORARY VIEW v_detail AS
SELECT
  CAST(ABS(HASH_CODE(CONCAT(
    DATE_FORMAT(CAST(CURRENT_DATE AS TIMESTAMP(6)), 'yyyy-MM-dd'), ':',
    DATE_FORMAT(CAST(settlement_month AS TIMESTAMP(6)), 'yyyyMM'), ':',
    COALESCE(root_account_referral_id, ''), ':', root_account_id, ':', product, ':', source_product, ':',
    COALESCE(provider, ''), ':', COALESCE(item, ''), ':', source_type
  ))) AS BIGINT) AS id,
  CAST(CONCAT(DATE_FORMAT(CAST(CURRENT_DATE AS TIMESTAMP(6)), 'yyyy-MM'), '-21') AS DATE) AS snapshot_date,
  report_date, settlement_month, root_account_id, root_account_referral_id,
  product, source_product, provider, item, source_type, effective_revenue, cogs, gp,
  1 AS version, CAST('partner account profit snapshot month cdc' AS STRING) AS remarks,
  CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time, CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
  CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM source_profit;

CREATE TEMPORARY VIEW v_snapshot AS
SELECT
  CAST(ABS(HASH_CODE(CONCAT(
    DATE_FORMAT(CAST(CURRENT_DATE AS TIMESTAMP(6)), 'yyyy-MM-dd'), ':',
    DATE_FORMAT(CAST(settlement_month AS TIMESTAMP(6)), 'yyyyMM'), ':',
    COALESCE(root_account_referral_id, ''), ':', root_account_id, ':', product
  ))) AS BIGINT) AS id,
  CAST(CONCAT(DATE_FORMAT(CAST(CURRENT_DATE AS TIMESTAMP(6)), 'yyyy-MM'), '-21') AS DATE) AS snapshot_date,
  settlement_month, root_account_referral_id, root_account_id, product,
  CAST(SUM(effective_revenue) AS DECIMAL(20,4)), CAST(SUM(cogs) AS DECIMAL(20,4)),
  CAST(SUM(gp) AS DECIMAL(20,4)), 1,
  CAST('partner account profit snapshot month cdc' AS STRING),
  CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)), CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)), CAST(NULL AS TIMESTAMP(6))
FROM source_profit
GROUP BY settlement_month, root_account_referral_id, root_account_id, product;

CREATE TEMPORARY TABLE sink_detail (
  id BIGINT, snapshot_date DATE, report_date DATE, settlement_month DATE, root_account_id STRING,
  root_account_referral_id STRING, product STRING, source_product STRING, provider STRING, item STRING,
  source_type STRING, effective_revenue DECIMAL(20,4), cogs DECIMAL(20,4), gp DECIMAL(20,4), version INT,
  remarks STRING, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6),
  PRIMARY KEY (id, snapshot_date) NOT ENFORCED
) WITH (
  'connector' = 'adbpg', 'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
  'tableName' = 'dws_partner_account_profit_snapshot_detail_p', 'targetSchema' = 'dws',
  'userName' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}', 'writeMode' = 'upsert', 'batchSize' = '2000'
);

CREATE TEMPORARY TABLE sink_snapshot (
  id BIGINT, snapshot_date DATE, settlement_month DATE, root_account_referral_id STRING, root_account_id STRING,
  product STRING, total_effective_revenue DECIMAL(20,4), total_cogs DECIMAL(20,4), total_gp DECIMAL(20,4), version INT,
  remarks STRING, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6),
  PRIMARY KEY (id, snapshot_date) NOT ENFORCED
) WITH (
  'connector' = 'adbpg', 'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
  'tableName' = 'dws_partner_account_profit_snapshot_p', 'targetSchema' = 'dws',
  'userName' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}', 'writeMode' = 'upsert', 'batchSize' = '1000'
);

EXECUTE STATEMENT SET
BEGIN
  INSERT INTO sink_detail SELECT * FROM v_detail;
  INSERT INTO sink_snapshot SELECT * FROM v_snapshot;
END;
