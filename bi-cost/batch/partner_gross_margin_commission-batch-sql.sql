--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-09-02
-- Description:    合伙人客户业务线毛利返佣计算批任务
-- Parameters:     snapshot_date=yyyy-MM-dd, settlement_month=yyyy-MM
-- Notes:
--   1. 从合伙人客户毛利快照主表读取客户业务线毛利。
--   2. QUANTUM_ACCOUNT 使用 qbit_card；CRYPTO_ASSETS 使用 crypto。
--   3. 采用超额累进；负毛利不产生返佣。
--********************************************************************--

SET 'parallelism.default' = '2';
SET 'table.dml-sync' = 'true';

CREATE TEMPORARY TABLE source_profit (
  id BIGINT,
  snapshot_date DATE,
  settlement_month DATE,
  root_account_referral_id STRING,
  root_account_id STRING,
  product STRING,
  total_gp DECIMAL(20,4),
  PRIMARY KEY (id, snapshot_date) NOT ENFORCED
) WITH (
  'connector' = 'jdbc',
  'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
  'table-name' = '(SELECT id, snapshot_date, settlement_month, root_account_referral_id, root_account_id, product, total_gp FROM dws.dws_partner_account_profit_snapshot_p WHERE snapshot_date = CAST(''${snapshot_date}'' AS date) AND settlement_month = CAST(CONCAT(''${settlement_month}'', ''-01'') AS date)) AS profit_f',
  'username' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}',
  'driver' = 'org.postgresql.Driver', 'scan.fetch-size' = '5000', 'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_config (
  id BIGINT,
  partner_id STRING,
  account_id STRING,
  product_line_type STRING,
  effective_time TIMESTAMP(6),
  expiration_time TIMESTAMP(6),
  PRIMARY KEY (id) NOT ENFORCED
) WITH (
  'connector' = 'jdbc',
  'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
  'table-name' = '(SELECT id, partner_id, account_id, product_line_type, effective_time::timestamp AS effective_time, expiration_time::timestamp AS expiration_time FROM public.partner_gross_margin_config WHERE delete_time IS NULL) AS config_f',
  'username' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}',
  'driver' = 'org.postgresql.Driver', 'scan.fetch-size' = '1000', 'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_config_detail (
  id BIGINT,
  config_id BIGINT,
  ladder_min_amount DECIMAL(20,12),
  ladder_max_amount DECIMAL(20,12),
  rate_value DECIMAL(20,12),
  effective_time TIMESTAMP(6),
  expiration_time TIMESTAMP(6),
  PRIMARY KEY (id) NOT ENFORCED
) WITH (
  'connector' = 'jdbc',
  'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
  'table-name' = '(SELECT id, config_id, ladder_min_amount, ladder_max_amount, rate_value, effective_time::timestamp AS effective_time, expiration_time::timestamp AS expiration_time FROM public.partner_gross_margin_config_detail WHERE delete_time IS NULL) AS config_detail_f',
  'username' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}',
  'driver' = 'org.postgresql.Driver', 'scan.fetch-size' = '2000', 'scan.auto-commit' = 'false'
);

CREATE TEMPORARY VIEW v_profit AS
SELECT
  snapshot_date, settlement_month, root_account_referral_id AS partner_id, root_account_id AS account_id,
  CASE WHEN product = 'qbit_card' THEN 'QUANTUM_ACCOUNT' WHEN product = 'crypto' THEN 'CRYPTO_ASSETS' ELSE NULL END AS product_line_type,
  total_gp AS gross_profit
FROM source_profit
WHERE root_account_referral_id IS NOT NULL
  AND product IN ('qbit_card', 'crypto');

CREATE TEMPORARY VIEW v_config_match AS
SELECT
  p.snapshot_date, p.settlement_month, p.partner_id, p.account_id, p.product_line_type, p.gross_profit,
  c.id AS config_id, c.effective_time AS config_effective_time, c.expiration_time AS config_expiration_time,
  d.ladder_min_amount, d.ladder_max_amount, d.rate_value
FROM v_profit p
JOIN source_config c
  ON c.partner_id = p.partner_id
 AND c.account_id = p.account_id
 AND c.product_line_type = p.product_line_type
 AND CAST(p.snapshot_date AS TIMESTAMP(6)) >= c.effective_time
 AND CAST(p.snapshot_date AS TIMESTAMP(6)) < c.expiration_time
JOIN source_config_detail d
  ON d.config_id = c.id
 AND CAST(p.snapshot_date AS TIMESTAMP(6)) >= d.effective_time
 AND CAST(p.snapshot_date AS TIMESTAMP(6)) < d.expiration_time;

CREATE TEMPORARY VIEW v_commission AS
SELECT
  CAST(ABS(HASH_CODE(CONCAT(
    '${snapshot_date}', ':', '${settlement_month}', ':', partner_id, ':', account_id, ':', product_line_type
  ))) AS BIGINT) AS id,
  CAST('${snapshot_date}' AS DATE) AS snapshot_date,
  settlement_month, partner_id, account_id, product_line_type,
  CAST(MAX(gross_profit) AS DECIMAL(20,4)) AS gross_profit,
  CAST(SUM(CASE
    WHEN gross_profit <= ladder_min_amount THEN CAST(0 AS DECIMAL(20,4))
    ELSE (CASE
      WHEN ladder_max_amount IS NULL THEN gross_profit - ladder_min_amount
      WHEN gross_profit < ladder_max_amount THEN gross_profit - ladder_min_amount
      ELSE ladder_max_amount - ladder_min_amount
    END) * rate_value
  END) AS DECIMAL(20,4)) AS commission_before_floor,
  CAST(GREATEST(SUM(CASE
    WHEN gross_profit <= ladder_min_amount THEN CAST(0 AS DECIMAL(20,4))
    ELSE (CASE
      WHEN ladder_max_amount IS NULL THEN gross_profit - ladder_min_amount
      WHEN gross_profit < ladder_max_amount THEN gross_profit - ladder_min_amount
      ELSE ladder_max_amount - ladder_min_amount
    END) * rate_value
  END), CAST(0 AS DECIMAL(20,4))) AS DECIMAL(20,4)) AS commission_amount,
  MAX(config_id) AS config_id,
  MAX(config_effective_time) AS config_effective_time,
  MAX(config_expiration_time) AS config_expiration_time,
  1 AS version, CAST('partner gross margin commission batch' AS STRING) AS remarks,
  CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
  CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
  CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_config_match
GROUP BY settlement_month, partner_id, account_id, product_line_type;

CREATE TEMPORARY TABLE sink_commission (
  id BIGINT, snapshot_date DATE, settlement_month DATE, partner_id STRING, account_id STRING,
  product_line_type STRING, gross_profit DECIMAL(20,4), commission_before_floor DECIMAL(20,4),
  commission_amount DECIMAL(20,4), config_id BIGINT, config_effective_time TIMESTAMP(6),
  config_expiration_time TIMESTAMP(6), version INT, remarks STRING, create_time TIMESTAMP(6),
  update_time TIMESTAMP(6), delete_time TIMESTAMP(6), PRIMARY KEY (id, snapshot_date) NOT ENFORCED
) WITH (
  'connector' = 'adbpg',
  'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
  'tableName' = 'partner_gross_margin_commission_p', 'targetSchema' = 'public',
  'userName' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}',
  'writeMode' = 'upsert', 'batchSize' = '1000'
);

INSERT INTO sink_commission SELECT * FROM v_commission;
