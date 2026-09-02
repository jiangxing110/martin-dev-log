--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-09-02
-- Description:    合伙人客户毛利月度快照批处理
-- Parameters:     snapshot_date=yyyy-MM-dd, settlement_month=yyyy-MM
--********************************************************************--

SET 'parallelism.default' = '2';
SET 'table.dml-sync' = 'true';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';

CREATE TEMPORARY TABLE source_profit (
  id BIGINT,
  report_date DATE,
  settlement_month DATE,
  root_account_id STRING,
  root_account_referral_id STRING,
  product STRING,
  source_product STRING,
  provider STRING,
  item STRING,
  source_type STRING,
  effective_revenue DECIMAL(20,4),
  cogs DECIMAL(20,4),
  gp DECIMAL(20,4),
  PRIMARY KEY (id) NOT ENFORCED
) WITH (
  'connector' = 'jdbc',
  'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
  'table-name' = '(SELECT id, report_date, settlement_month, root_account_id, root_account_referral_id, product, source_product, provider, item, source_type, effective_revenue, cogs, gp FROM dws.mv_partner_account_profit_recent_estimate WHERE settlement_month = CAST(CONCAT(''${settlement_month}'', ''-01'') AS date)) AS profit_f',
  'username' = '${secret_values.ADB_PG_USERNAME}',
  'password' = '${secret_values.ADB_PG_PASSWORD}',
  'driver' = 'org.postgresql.Driver',
  'scan.fetch-size' = '5000',
  'scan.auto-commit' = 'false'
);

CREATE TEMPORARY VIEW v_detail AS
SELECT
  CAST(ABS(HASH_CODE(CONCAT(
    '${snapshot_date}', ':', DATE_FORMAT(CAST(settlement_month AS TIMESTAMP(6)), 'yyyyMM'), ':',
    COALESCE(root_account_referral_id, ''), ':', root_account_id, ':', product, ':', source_product, ':',
    COALESCE(provider, ''), ':', COALESCE(item, ''), ':', source_type
  ))) AS BIGINT) AS id,
  CAST('${snapshot_date}' AS DATE) AS snapshot_date,
  report_date, settlement_month, root_account_id, root_account_referral_id,
  product, source_product, provider, item, source_type,
  effective_revenue, cogs, gp,
  1 AS version, CAST('partner account profit snapshot batch' AS STRING) AS remarks,
  CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
  CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
  CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM source_profit;

CREATE TEMPORARY VIEW v_snapshot AS
SELECT
  CAST(ABS(HASH_CODE(CONCAT(
    '${snapshot_date}', ':', DATE_FORMAT(CAST(settlement_month AS TIMESTAMP(6)), 'yyyyMM'), ':',
    COALESCE(root_account_referral_id, ''), ':', root_account_id, ':', product
  ))) AS BIGINT) AS id,
  CAST('${snapshot_date}' AS DATE) AS snapshot_date,
  settlement_month, root_account_referral_id, root_account_id, product,
  CAST(SUM(effective_revenue) AS DECIMAL(20,4)) AS total_effective_revenue,
  CAST(SUM(cogs) AS DECIMAL(20,4)) AS total_cogs,
  CAST(SUM(gp) AS DECIMAL(20,4)) AS total_gp,
  1 AS version, CAST('partner account profit snapshot batch' AS STRING) AS remarks,
  CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
  CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
  CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM source_profit
GROUP BY settlement_month, root_account_referral_id, root_account_id, product;

CREATE TEMPORARY TABLE sink_detail (
  id BIGINT, snapshot_date DATE, report_date DATE, settlement_month DATE,
  root_account_id STRING, root_account_referral_id STRING, product STRING, source_product STRING,
  provider STRING, item STRING, source_type STRING,
  effective_revenue DECIMAL(20,4), cogs DECIMAL(20,4), gp DECIMAL(20,4), version INT,
  remarks STRING, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6),
  PRIMARY KEY (id, snapshot_date) NOT ENFORCED
) WITH (
  'connector' = 'adbpg', 'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
  'tableName' = 'dws_partner_account_profit_snapshot_detail_p', 'targetSchema' = 'dws',
  'userName' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}',
  'writeMode' = 'upsert', 'batchSize' = '2000'
);

CREATE TEMPORARY TABLE sink_snapshot (
  id BIGINT, snapshot_date DATE, settlement_month DATE, root_account_referral_id STRING,
  root_account_id STRING, product STRING, total_effective_revenue DECIMAL(20,4),
  total_cogs DECIMAL(20,4), total_gp DECIMAL(20,4), version INT, remarks STRING,
  create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6),
  PRIMARY KEY (id, snapshot_date) NOT ENFORCED
) WITH (
  'connector' = 'adbpg', 'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
  'tableName' = 'dws_partner_account_profit_snapshot_p', 'targetSchema' = 'dws',
  'userName' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}',
  'writeMode' = 'upsert', 'batchSize' = '1000'
);

EXECUTE STATEMENT SET
BEGIN
  INSERT INTO sink_detail SELECT * FROM v_detail;
  INSERT INTO sink_snapshot SELECT * FROM v_snapshot;
END;
