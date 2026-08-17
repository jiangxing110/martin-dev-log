--********************************************************************--
-- Author:         zhanghaoran
-- Created Time:   2026-08-11
-- Updated Time:   2026-08-17 00:00:00
-- Description:    Full DWD -> DWM/DWS card transaction metric batch job
-- Notes:
--   1. Statistical date uses DWD field dt directly.
--   2. Run adbpg_card_transaction_dwm_dws_ddl.sql before this job.
--   3. Before a complete rebuild, truncate only the card DWM table.
--      In the shared DWS table, delete only rows matching:
--      product_line = 'Card', business_domain = 'Card Transaction',
--      metric_code = 'card_consumption_amount'. Never truncate shared DWS.
--********************************************************************--

SET 'parallelism.default' = '2';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.optimizer.reuse-source-enabled' = 'true';
SET 'table.optimizer.reuse-sub-plan-enabled' = 'true';

SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

-- Build QI/BB/BZ interchange revenue detail metrics into dws.dws_tpv_metrics.
-- Required parameters:
--   ${start_date}: inclusive, YYYY-MM-DD
--   ${end_date}:   exclusive, YYYY-MM-DD
--
-- Revenue sources:
--   QI = rebate_interchange_base_amt * rebate_interchange_rate
--      + rebate_incentive_base_amt * rebate_incentive_rate
--   BB = cashback_income
--   BZ             = clearing_base_amt * reimbursement_rate

CREATE TEMPORARY TABLE source_qi_card_finance_daily (
    account_id                  STRING,
    report_date                 DATE,
    rebate_interchange_base_amt DECIMAL(20, 4),
    rebate_incentive_base_amt   DECIMAL(20, 4),
    rebate_interchange_rate     DECIMAL(20, 8),
    rebate_incentive_rate       DECIMAL(20, 8)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    -- 标准日期区间：${start_date} 到 ${end_date}，左闭右开，适合指定范围回刷。
    -- 'table-name' = '(SELECT account_id, report_date, rebate_interchange_base_amt, rebate_incentive_base_amt, rebate_interchange_rate, rebate_incentive_rate FROM dws.dws_qi_card_finance_daily_v2_p WHERE delete_time IS NULL AND account_id IS NOT NULL AND TRIM(account_id) <> '''' AND report_date >= CAST(''${start_date}'' AS DATE) AND report_date < CAST(''${end_date}'' AS DATE)) AS qi_card_finance_range',
    -- 从 ${start_date} 到昨天为止，适合固定起点自动补跑到调度日前一天。
    'table-name' = '(SELECT account_id, report_date, rebate_interchange_base_amt, rebate_incentive_base_amt, rebate_interchange_rate, rebate_incentive_rate FROM dws.dws_qi_card_finance_daily_v2_p WHERE delete_time IS NULL AND account_id IS NOT NULL AND TRIM(account_id) <> '''' AND report_date >= CAST(''${start_date}'' AS DATE) AND report_date < CURRENT_DATE) AS qi_card_finance_range',
    -- 只获取昨天增量数据，适合每日稳定调度。
    -- 'table-name' = '(SELECT account_id, report_date, rebate_interchange_base_amt, rebate_incentive_base_amt, rebate_interchange_rate, rebate_incentive_rate FROM dws.dws_qi_card_finance_daily_v2_p WHERE delete_time IS NULL AND account_id IS NOT NULL AND TRIM(account_id) <> '''' AND report_date >= CURRENT_DATE - INTERVAL ''1 day'' AND report_date < CURRENT_DATE) AS qi_card_finance_range',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '30000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_bb_card_finance_daily (
    account_id      STRING,
    report_date     DATE,
    cashback_income DECIMAL(20, 4)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    -- 标准日期区间：${start_date} 到 ${end_date}，左闭右开，适合指定范围回刷。
    -- 'table-name' = '(SELECT account_id, report_date, cashback_income FROM dws.dws_bb_card_finance_daily_v2_p WHERE delete_time IS NULL AND account_id IS NOT NULL AND TRIM(account_id) <> '''' AND report_date >= CAST(''${start_date}'' AS DATE) AND report_date < CAST(''${end_date}'' AS DATE)) AS bb_card_finance_range',
    -- 从 ${start_date} 到昨天为止，适合固定起点自动补跑到调度日前一天。
    'table-name' = '(SELECT account_id, report_date, cashback_income FROM dws.dws_bb_card_finance_daily_v2_p WHERE delete_time IS NULL AND account_id IS NOT NULL AND TRIM(account_id) <> '''' AND report_date >= CAST(''${start_date}'' AS DATE) AND report_date < CURRENT_DATE) AS bb_card_finance_range',
    -- 只获取昨天增量数据，适合每日稳定调度。
    -- 'table-name' = '(SELECT account_id, report_date, cashback_income FROM dws.dws_bb_card_finance_daily_v2_p WHERE delete_time IS NULL AND account_id IS NOT NULL AND TRIM(account_id) <> '''' AND report_date >= CURRENT_DATE - INTERVAL ''1 day'' AND report_date < CURRENT_DATE) AS bb_card_finance_range',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '30000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_bz_card_finance_daily (
    account_id          STRING,
    report_date         DATE,
    clearing_base_amt   DECIMAL(20, 4),
    reimbursement_rate DECIMAL(20, 10)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    -- 标准日期区间：${start_date} 到 ${end_date}，左闭右开，适合指定范围回刷。
    -- 'table-name' = '(SELECT account_id, report_date, clearing_base_amt, reimbursement_rate FROM dws.dws_bz_card_finance_daily_v2_p WHERE delete_time IS NULL AND account_id IS NOT NULL AND BTRIM(account_id) <> '''' AND report_date >= CAST(''${start_date}'' AS DATE) AND report_date < CAST(''${end_date}'' AS DATE)) AS bz_card_finance_range',
    -- 从 ${start_date} 到昨天为止，与线上 QI/BB 作业保持一致。
    'table-name' = '(SELECT account_id, report_date, clearing_base_amt, reimbursement_rate FROM dws.dws_bz_card_finance_daily_v2_p WHERE delete_time IS NULL AND account_id IS NOT NULL AND BTRIM(account_id) <> '''' AND report_date >= CAST(''${start_date}'' AS DATE) AND report_date < CURRENT_DATE) AS bz_card_finance_range',
    -- 只获取昨天增量数据，适合每日稳定调度。
    -- 'table-name' = '(SELECT account_id, report_date, clearing_base_amt, reimbursement_rate FROM dws.dws_bz_card_finance_daily_v2_p WHERE delete_time IS NULL AND account_id IS NOT NULL AND BTRIM(account_id) <> '''' AND report_date >= CURRENT_DATE - INTERVAL ''1 day'' AND report_date < CURRENT_DATE) AS bz_card_finance_range',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '30000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_dim_account (
    id   STRING,
    type STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'table-name' = 'dim.dim_account',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE sink_dws_tpv_metrics (
    entity          STRING,
    state_date      DATE,
    product         STRING,
    business_domain STRING,
    metric_code     STRING,
    metric_name     STRING,
    metric_label    STRING,
    metric_type     STRING,
    metric_value    DECIMAL(20, 3),
    source_system   STRING,
    create_time     TIMESTAMP(6),
    PRIMARY KEY (entity, state_date, product, business_domain, metric_code, metric_name, metric_label, metric_type) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'tableName' = 'dws_tpv_metrics',
    'writeMode' = 'upsert',
    'batchSize' = '5000'
);

CREATE TEMPORARY VIEW dim_account_classified AS
SELECT
    id,
    CASE
        WHEN type IN ('ApiClientCustomer', 'ApiClient') THEN 'api_customer'
        WHEN type IS NULL OR TRIM(type) = '' THEN 'other'
        ELSE 'merchant_customer'
    END AS account_type_desc
FROM source_dim_account;

-- Keep the fixed coefficients visible here. Later this view can be replaced by a lookup table.
CREATE TEMPORARY VIEW source_interchange_income AS
SELECT
    account_id,
    report_date,
    'QI' AS product_line,
    SUM(
        CAST(COALESCE(rebate_interchange_base_amt, CAST(0 AS DECIMAL(20, 4))) AS DECIMAL(38, 6))
            * CAST(COALESCE(rebate_interchange_rate, CAST(1 AS DECIMAL(20, 8))) AS DECIMAL(20, 8))
        + CAST(COALESCE(rebate_incentive_base_amt, CAST(0 AS DECIMAL(20, 4))) AS DECIMAL(38, 6))
            * CAST(COALESCE(rebate_incentive_rate, CAST(1 AS DECIMAL(20, 8))) AS DECIMAL(20, 8))
    ) AS interchange_income
FROM source_qi_card_finance_daily
GROUP BY
    account_id,
    report_date

UNION ALL

SELECT
    account_id,
    report_date,
    'BB' AS product_line,
    SUM(
        CAST(COALESCE(cashback_income, CAST(0 AS DECIMAL(20, 4))) AS DECIMAL(38, 6))
    ) AS interchange_income
FROM source_bb_card_finance_daily
GROUP BY
    account_id,
    report_date

UNION ALL

SELECT
    account_id,
    report_date,
    'BZ' AS product_line,
    SUM(
        CAST(
            COALESCE(clearing_base_amt, CAST(0 AS DECIMAL(20, 4)))
                * COALESCE(reimbursement_rate, CAST(0 AS DECIMAL(20, 10)))
            AS DECIMAL(38, 10)
        )
    ) AS interchange_income
FROM source_bz_card_finance_daily
GROUP BY
    account_id,
    report_date;

CREATE TEMPORARY VIEW dws_interchange_revenue_base AS
SELECT
    COALESCE(acc.account_type_desc, 'other') AS entity,
    income.report_date AS state_date,
    income.product_line,
    SUM(income.interchange_income) AS interchange_income
FROM source_interchange_income AS income
LEFT JOIN dim_account_classified AS acc
    ON income.account_id = acc.id
GROUP BY
    COALESCE(acc.account_type_desc, 'other'),
    income.report_date,
    income.product_line;

CREATE TEMPORARY VIEW dws_interchange_revenue_metrics AS
SELECT
    entity,
    state_date,
    product_line AS product,
    'revenue' AS business_domain,
    CASE product_line
        WHEN 'QI' THEN 'qi_interchange_income_amount'
        WHEN 'BB' THEN 'bb_interchange_income_amount'
        WHEN 'BZ' THEN 'bz_interchange_income_amount'
    END AS metric_code,
    CASE product_line
        WHEN 'QI' THEN 'QI渠道返现'
        WHEN 'BB' THEN 'BB渠道返现'
        WHEN 'BZ' THEN 'BZ渠道返现'
    END AS metric_name,
    CASE product_line
        WHEN 'QI' THEN 'QI Interchange Revenue'
        WHEN 'BB' THEN 'BB Interchange Revenue'
        WHEN 'BZ' THEN 'BZ Interchange Revenue'
    END AS metric_label,
    'amount' AS metric_type,
    CAST(ROUND(interchange_income, 3) AS DECIMAL(20, 3)) AS metric_value,
    'dws.dws_qi_card_finance_daily_v2_p,dws.dws_bb_card_finance_daily_v2_p,dws.dws_bz_card_finance_daily_v2_p,dim.dim_account' AS source_system,
    CURRENT_TIMESTAMP AS create_time
FROM dws_interchange_revenue_base
WHERE product_line IN ('QI', 'BB', 'BZ');

CREATE TEMPORARY VIEW dws_interchange_revenue_total_metrics AS
SELECT
    entity,
    state_date,
    'card' AS product,
    'cms' AS business_domain,
    'interchange_revenue_amount' AS metric_code,
    '渠道返现' AS metric_name,
    'Interchange Revenue' AS metric_label,
    'amount' AS metric_type,
    CAST(ROUND(SUM(interchange_income), 3) AS DECIMAL(20, 3)) AS metric_value,
    'dws.dws_qi_card_finance_daily_v2_p,dws.dws_bb_card_finance_daily_v2_p,dws.dws_bz_card_finance_daily_v2_p,dim.dim_account' AS source_system,
    CURRENT_TIMESTAMP AS create_time
FROM dws_interchange_revenue_base
GROUP BY
    entity,
    state_date;

CREATE TEMPORARY VIEW dws_interchange_revenue_all_metrics AS
SELECT
    entity,
    state_date,
    product,
    business_domain,
    metric_code,
    metric_name,
    metric_label,
    metric_type,
    metric_value,
    source_system,
    create_time
FROM dws_interchange_revenue_metrics

UNION ALL

SELECT
    entity,
    state_date,
    product,
    business_domain,
    metric_code,
    metric_name,
    metric_label,
    metric_type,
    metric_value,
    source_system,
    create_time
FROM dws_interchange_revenue_total_metrics;

INSERT INTO sink_dws_tpv_metrics
SELECT
    entity,
    state_date,
    product,
    business_domain,
    metric_code,
    metric_name,
    metric_label,
    metric_type,
    metric_value,
    source_system,
    create_time
FROM dws_interchange_revenue_all_metrics;


-- SET 'parallelism.default' = '4';
-- SET 'pipeline.operator-chaining' = 'true';
-- SET 'table.optimizer.reuse-source-enabled' = 'true';
-- SET 'table.optimizer.reuse-sub-plan-enabled' = 'true';

-- SET 'restart-strategy.type' = 'fixed-delay';
-- SET 'restart-strategy.fixed-delay.attempts' = '3';
-- SET 'restart-strategy.fixed-delay.delay' = '60s';

-- Build QI/BB interchange revenue detail metrics with fixed coefficients into dws.dws_tpv_metrics.
-- Required parameters:
--   ${start_date}: inclusive, YYYY-MM-DD
--   ${end_date}:   exclusive, YYYY-MM-DD
--
-- Coefficients:
--   QI Interchange = 2%
--   QI Incentive   = 1.08%
--   BB             = -2.16%

-- CREATE TEMPORARY TABLE source_qi_card_finance_daily (
--     account_id             STRING,
--     report_date            DATE,
--     rebate_interchange_vol DECIMAL(20, 4),
--     rebate_incentive_vol   DECIMAL(20, 4)
-- ) WITH (
--     'connector' = 'jdbc',
--     'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
--     'username' = '${secret_values.ADB_PG_USERNAME}',
--     'password' = '${secret_values.ADB_PG_PASSWORD}',
--     -- 标准日期区间：${start_date} 到 ${end_date}，左闭右开，适合指定范围回刷。
--     -- 'table-name' = '(SELECT account_id, report_date, rebate_interchange_vol, rebate_incentive_vol FROM public.dws_qi_card_finance_daily_p WHERE delete_time IS NULL AND account_id IS NOT NULL AND TRIM(account_id) <> '''' AND report_date >= CAST(''${start_date}'' AS DATE) AND report_date < CAST(''${end_date}'' AS DATE)) AS qi_card_finance_range',
--     -- 从 ${start_date} 到昨天为止，适合固定起点自动补跑到调度日前一天。
--     'table-name' = '(SELECT account_id, report_date, rebate_interchange_vol, rebate_incentive_vol FROM public.dws_qi_card_finance_daily_p WHERE delete_time IS NULL AND account_id IS NOT NULL AND TRIM(account_id) <> '''' AND report_date >= CAST(''${start_date}'' AS DATE) AND report_date < CURRENT_DATE) AS qi_card_finance_range',
--     -- 只获取昨天增量数据，适合每日稳定调度。
--     -- 'table-name' = '(SELECT account_id, report_date, rebate_interchange_vol, rebate_incentive_vol FROM public.dws_qi_card_finance_daily_p WHERE delete_time IS NULL AND account_id IS NOT NULL AND TRIM(account_id) <> '''' AND report_date >= CURRENT_DATE - INTERVAL ''1 day'' AND report_date < CURRENT_DATE) AS qi_card_finance_range',
--     'driver' = 'org.postgresql.Driver',
--     'scan.fetch-size' = '30000',
--     'scan.auto-commit' = 'false'
-- );

-- CREATE TEMPORARY TABLE source_bb_card_finance_daily (
--     account_id         STRING,
--     report_date        DATE,
--     bb_rebate_base_amt DECIMAL(20, 4)
-- ) WITH (
--     'connector' = 'jdbc',
--     'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
--     'username' = '${secret_values.ADB_PG_USERNAME}',
--     'password' = '${secret_values.ADB_PG_PASSWORD}',
--     -- 标准日期区间：${start_date} 到 ${end_date}，左闭右开，适合指定范围回刷。
--     -- 'table-name' = '(SELECT account_id, report_date, bb_rebate_base_amt FROM public.dws_bb_card_finance_daily_p WHERE delete_time IS NULL AND account_id IS NOT NULL AND TRIM(account_id) <> '''' AND report_date >= CAST(''${start_date}'' AS DATE) AND report_date < CAST(''${end_date}'' AS DATE)) AS bb_card_finance_range',
--     -- 从 ${start_date} 到昨天为止，适合固定起点自动补跑到调度日前一天。
--     'table-name' = '(SELECT account_id, report_date, bb_rebate_base_amt FROM public.dws_bb_card_finance_daily_p WHERE delete_time IS NULL AND account_id IS NOT NULL AND TRIM(account_id) <> '''' AND report_date >= CAST(''${start_date}'' AS DATE) AND report_date < CURRENT_DATE) AS bb_card_finance_range',
--     -- 只获取昨天增量数据，适合每日稳定调度。
--     -- 'table-name' = '(SELECT account_id, report_date, bb_rebate_base_amt FROM public.dws_bb_card_finance_daily_p WHERE delete_time IS NULL AND account_id IS NOT NULL AND TRIM(account_id) <> '''' AND report_date >= CURRENT_DATE - INTERVAL ''1 day'' AND report_date < CURRENT_DATE) AS bb_card_finance_range',
--     'driver' = 'org.postgresql.Driver',
--     'scan.fetch-size' = '30000',
--     'scan.auto-commit' = 'false'
-- );

-- CREATE TEMPORARY TABLE source_dim_account (
--     id   STRING,
--     type STRING,
--     PRIMARY KEY (id) NOT ENFORCED
-- ) WITH (
--     'connector' = 'jdbc',
--     'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
--     'username' = '${secret_values.ADB_PG_USERNAME}',
--     'password' = '${secret_values.ADB_PG_PASSWORD}',
--     'table-name' = 'dim.dim_account',
--     'driver' = 'org.postgresql.Driver',
--     'scan.fetch-size' = '20000',
--     'scan.auto-commit' = 'false'
-- );

-- CREATE TEMPORARY TABLE sink_dws_tpv_metrics (
--     entity          STRING,
--     state_date      DATE,
--     product         STRING,
--     business_domain STRING,
--     metric_code     STRING,
--     metric_name     STRING,
--     metric_label    STRING,
--     metric_type     STRING,
--     metric_value    DECIMAL(20, 3),
--     source_system   STRING,
--     create_time     TIMESTAMP(6),
--     PRIMARY KEY (entity, state_date, product, business_domain, metric_code, metric_name, metric_label, metric_type) NOT ENFORCED
-- ) WITH (
--     'connector' = 'adbpg',
--     'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
--     'targetSchema' = 'dws',
--     'userName' = '${secret_values.ADB_PG_USERNAME}',
--     'password' = '${secret_values.ADB_PG_PASSWORD}',
--     'tableName' = 'dws_tpv_metrics',
--     'writeMode' = 'upsert',
--     'batchSize' = '5000'
-- );

-- CREATE TEMPORARY VIEW dim_account_classified AS
-- SELECT
--     id,
--     CASE
--         WHEN type IN ('ApiClientCustomer', 'ApiClient') THEN 'api_customer'
--         WHEN type IS NULL OR TRIM(type) = '' THEN 'other'
--         ELSE 'merchant_customer'
--     END AS account_type_desc
-- FROM source_dim_account;

-- -- Keep the fixed coefficients visible here. Later this view can be replaced by a lookup table.
-- CREATE TEMPORARY VIEW source_interchange_income AS
-- SELECT
--     account_id,
--     report_date,
--     'QI' AS product_line,
--     SUM(
--         CAST(COALESCE(rebate_interchange_vol, CAST(0 AS DECIMAL(20, 4))) AS DECIMAL(38, 6))
--             * CAST(0.02 AS DECIMAL(10, 6))
--         + CAST(COALESCE(rebate_incentive_vol, CAST(0 AS DECIMAL(20, 4))) AS DECIMAL(38, 6))
--             * CAST(0.0108 AS DECIMAL(10, 6))
--     ) AS interchange_income
-- FROM source_qi_card_finance_daily
-- GROUP BY
--     account_id,
--     report_date

-- UNION ALL

-- SELECT
--     account_id,
--     report_date,
--     'BB' AS product_line,
--     SUM(
--         CAST(COALESCE(bb_rebate_base_amt, CAST(0 AS DECIMAL(20, 4))) AS DECIMAL(38, 6))
--             * CAST(-0.0216 AS DECIMAL(10, 6))
--     ) AS interchange_income
-- FROM source_bb_card_finance_daily
-- GROUP BY
--     account_id,
--     report_date;

-- CREATE TEMPORARY VIEW dws_interchange_revenue_base AS
-- SELECT
--     COALESCE(acc.account_type_desc, 'other') AS entity,
--     income.report_date AS state_date,
--     income.product_line,
--     SUM(income.interchange_income) AS interchange_income
-- FROM source_interchange_income AS income
-- LEFT JOIN dim_account_classified AS acc
--     ON income.account_id = acc.id
-- GROUP BY
--     COALESCE(acc.account_type_desc, 'other'),
--     income.report_date,
--     income.product_line;

-- CREATE TEMPORARY VIEW dws_interchange_revenue_metrics AS
-- SELECT
--     entity,
--     state_date,
--     product_line AS product,
--     'revenue' AS business_domain,
--     CASE product_line
--         WHEN 'QI' THEN 'qi_interchange_income_amount'
--         WHEN 'BB' THEN 'bb_interchange_income_amount'
--     END AS metric_code,
--     CASE product_line
--         WHEN 'QI' THEN 'QI渠道返现'
--         WHEN 'BB' THEN 'BB渠道返现'
--     END AS metric_name,
--     'Interchange Revenue' AS metric_label,
--     'amount' AS metric_type,
--     CAST(ROUND(interchange_income, 3) AS DECIMAL(20, 3)) AS metric_value,
--     'public.dws_qi_card_finance_daily_p,public.dws_bb_card_finance_daily_p,dim.dim_account' AS source_system,
--     CURRENT_TIMESTAMP AS create_time
-- FROM dws_interchange_revenue_base
-- WHERE product_line IN ('QI', 'BB');

-- INSERT INTO sink_dws_tpv_metrics
-- SELECT
--     entity,
--     state_date,
--     product,
--     business_domain,
--     metric_code,
--     metric_name,
--     metric_label,
--     metric_type,
--     metric_value,
--     source_system,
--     create_time
-- FROM dws_interchange_revenue_metrics;
