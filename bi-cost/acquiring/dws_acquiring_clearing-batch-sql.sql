--********************************************************************--
-- Author:         zhanghaoran
-- Created Time:   2026-06-09 13:46:55
-- Description:    Write your description here
-- Hints:          You can use SET statements to modify the configuration
--********************************************************************--
SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
-- SET 'pipeline.operator-chaining' = 'false'; 

-- 重启策略
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';


CREATE TEMPORARY TABLE source_dwm_acquiring_clearing_daily (
    account_id                   STRING,
    create_date                  DATE,
    amount_type                  STRING,
    clearing_count               BIGINT,
    acquiring_amount_total       DECIMAL(20, 3),
    acquiring_usd_amount_total   DECIMAL(20, 3),
    card_scheme_fee_total        DECIMAL(20, 3),
    issuing_bank_fee_total       DECIMAL(20, 3),
    tax_fee_total                DECIMAL(20, 3),
    miscellaneous_fee_total      DECIMAL(20, 3),
    fix_fee_total                DECIMAL(20, 3),
    percent_fee_total            DECIMAL(20, 3),
    back_fix_fee_total           DECIMAL(20, 3),
    back_percent_fee_total       DECIMAL(20, 3),
    total_fee_amount_total       DECIMAL(20, 3),
    margin_amount_total          DECIMAL(20, 3),
    create_time                  TIMESTAMP(6),
    update_time                  TIMESTAMP(6),
    delete_time                  TIMESTAMP(6),
    PRIMARY KEY (account_id, create_date, amount_type) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'table-name' = 'dwm.dwm_acquiring_clearing',
    'scan.fetch-size' = '5000'
);


CREATE TEMPORARY VIEW v_dws_acquiring_clearing_metrics AS
SELECT
    account_id,
    create_date,
    'Acquiring' AS product_line,
    'Clearing' AS business_domain,
    'acquiring_amount' AS metric_code,
    '收单金额' AS metric_name,
    'income' AS metric_type,
    CAST(SUM(COALESCE(acquiring_usd_amount_total, CAST(0 AS DECIMAL(20, 3)))) AS DECIMAL(20, 3)) AS metric_value_usd,
    SUM(COALESCE(clearing_count, CAST(0 AS BIGINT))) AS metric_count,
    'dwm_acquiring_clearing' AS source_system,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM source_dwm_acquiring_clearing_daily
WHERE delete_time IS NULL
  AND amount_type = 'income'
GROUP BY account_id, create_date

UNION ALL

SELECT
    account_id,
    create_date,
    'Acquiring' AS product_line,
    'Clearing' AS business_domain,
    'acquiring_fee' AS metric_code,
    '收单手续费' AS metric_name,
    'income' AS metric_type,
    CAST(SUM(COALESCE(total_fee_amount_total, CAST(0 AS DECIMAL(20, 3)))) AS DECIMAL(20, 3)) AS metric_value_usd,
    SUM(COALESCE(clearing_count, CAST(0 AS BIGINT))) AS metric_count,
    'dwm_acquiring_clearing' AS source_system,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM source_dwm_acquiring_clearing_daily
WHERE delete_time IS NULL
  AND amount_type = 'income'
GROUP BY account_id, create_date

UNION ALL

SELECT
    account_id,
    create_date,
    'Acquiring' AS product_line,
    'Clearing' AS business_domain,
    'acquiring_cost' AS metric_code,
    '收单成本' AS metric_name,
    'cost' AS metric_type,
    CAST(SUM(COALESCE(acquiring_usd_amount_total, CAST(0 AS DECIMAL(20, 3)))) AS DECIMAL(20, 3)) AS metric_value_usd,
    SUM(COALESCE(clearing_count, CAST(0 AS BIGINT))) AS metric_count,
    'dwm_acquiring_clearing' AS source_system,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM source_dwm_acquiring_clearing_daily
WHERE delete_time IS NULL
  AND amount_type = 'cost'
GROUP BY account_id, create_date;

CREATE TEMPORARY TABLE sink_dws_product_transfer_metrics (
    account_id       STRING,
    create_date      DATE,
    product_line     STRING,
    business_domain  STRING,
    metric_code      STRING,
    metric_name      STRING,
    metric_type      STRING,
    metric_value_usd DECIMAL(20, 3),
    metric_count     BIGINT,
    source_system    STRING,
    create_time      TIMESTAMP(6),
    update_time      TIMESTAMP(6),
    delete_time      TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'dws.dws_product_transfer_metrics',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'sink.buffer-flush.max-rows' = '1000',
    'sink.buffer-flush.interval' = '3000'
);

INSERT INTO sink_dws_product_transfer_metrics
SELECT * FROM v_dws_acquiring_clearing_metrics;
