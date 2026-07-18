--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-22
-- 历史名称：sp_init_gross_profit_daily_by_fast.sql
-- Description:    Gross Profit 批量初始化/回刷
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性初始化/回刷或调度执行
--   运行参数：start_date, end_date
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑或由上游 CDC ODS/DIM 提供最新数据。
-- Notes:
--   1. 收入输入来自收入汇总物化视图 dws.dws_revenue_summary_daily_mv
--   2. 成本输入来自 dws.dws_total_channel_cost_daily_p
--   3. 粒度: report_date + account_id + category
--   4. 当前版本不按 sale_id / am_id 拆分毛利
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'sink.parallelism' = '1';
SET 'table.dml-sync' = 'true';
SET 'pipeline.operator-chaining' = 'true';
SET 'execution.checkpointing.interval' = '5min';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'execution.checkpointing.timeout' = '30min';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'table.optimizer.reuse-source-enabled' = 'true';
SET 'table.optimizer.reuse-sub-plan-enabled' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '1';
SET 'restart-strategy.fixed-delay.delay' = '60s';
SET 'sql-client.execution.result-mode' = 'tableau';

CREATE TEMPORARY TABLE source_profit_revenue_daily (
    report_date       DATE,
    account_id        STRING,
    account_type      STRING,
    system_type       STRING,
    category          STRING,
    revenue_amount    DOUBLE
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT stat_date AS report_date, account_id, account_type, system_type, category, CAST(CASE WHEN (amount IS NULL OR CAST(amount AS TEXT) = ''NaN'') THEN 0 ELSE amount END AS DOUBLE PRECISION) AS revenue_amount FROM dws.dws_revenue_summary_daily_mv WHERE stat_date >= CAST(''${start_date}'' AS DATE) AND stat_date < CAST(''${end_date}'' AS DATE)) AS dws_revenue_summary_daily_mv_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_total_channel_cost_daily (
    report_date       DATE,
    account_id        STRING,
    account_type      STRING,
    account_category  STRING,
    system_type       STRING,
    acquiring_cost    DOUBLE,
    business_cost     DOUBLE,
    quantum_cost      DOUBLE,
    crypto_cost       DOUBLE,
    total_channel_cost DOUBLE
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT report_date, account_id, account_type, account_category, system_type, CAST(CASE WHEN (acquiring_cost IS NULL OR CAST(acquiring_cost AS TEXT) = ''NaN'') THEN 0 ELSE acquiring_cost END AS DOUBLE PRECISION) AS acquiring_cost, CAST(CASE WHEN (business_cost IS NULL OR CAST(business_cost AS TEXT) = ''NaN'') THEN 0 ELSE business_cost END AS DOUBLE PRECISION) AS business_cost, CAST(CASE WHEN (quantum_cost IS NULL OR CAST(quantum_cost AS TEXT) = ''NaN'') THEN 0 ELSE quantum_cost END AS DOUBLE PRECISION) AS quantum_cost, CAST(CASE WHEN (crypto_cost IS NULL OR CAST(crypto_cost AS TEXT) = ''NaN'') THEN 0 ELSE crypto_cost END AS DOUBLE PRECISION) AS crypto_cost, CAST(CASE WHEN (total_channel_cost IS NULL OR CAST(total_channel_cost AS TEXT) = ''NaN'') THEN 0 ELSE total_channel_cost END AS DOUBLE PRECISION) AS total_channel_cost FROM dws.dws_total_channel_cost_daily_p WHERE delete_time IS NULL AND report_date >= CAST(''${start_date}'' AS DATE) AND report_date < CAST(''${end_date}'' AS DATE)) AS dws_total_channel_cost_daily_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY VIEW v_gross_profit_daily_joined AS
WITH revenue_daily AS (
    SELECT
        report_date,
        account_id,
        MAX(account_type) AS account_type,
        MAX(system_type) AS system_type,
        category,
        CAST(SUM(COALESCE(CAST(revenue_amount AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 4)) AS revenue_amount
    FROM source_profit_revenue_daily
    GROUP BY report_date, account_id, category
),
channel_cost_daily AS (
    SELECT
        report_date,
        account_id,
        MAX(account_type) AS account_type,
        MAX(account_category) AS account_category,
        MAX(system_type) AS system_type,
        CAST(SUM(COALESCE(CAST(acquiring_cost AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 4)) AS acquiring_cost,
        CAST(SUM(COALESCE(CAST(business_cost AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 4)) AS business_cost,
        CAST(SUM(COALESCE(CAST(quantum_cost AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 4)) AS quantum_cost,
        CAST(SUM(COALESCE(CAST(crypto_cost AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 4)) AS crypto_cost,
        CAST(SUM(COALESCE(CAST(total_channel_cost AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 4)) AS total_channel_cost
    FROM source_total_channel_cost_daily
    GROUP BY report_date, account_id
)
SELECT
    r.report_date,
    r.account_id,
    COALESCE(r.account_type, c.account_type) AS account_type,
    c.account_category AS account_category,
    COALESCE(r.system_type, c.system_type) AS system_type,
    r.category,
    r.revenue_amount,
    CAST(
        CASE r.category
            WHEN 'qbit_card' THEN COALESCE(CAST(c.quantum_cost AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4)))
            WHEN 'global_account' THEN COALESCE(CAST(c.business_cost AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4)))
            WHEN 'crypto_assets' THEN COALESCE(CAST(c.crypto_cost AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4)))
            WHEN 'particle_financing' THEN CAST(0 AS DECIMAL(20, 4))
            WHEN 'company_registration' THEN CAST(0 AS DECIMAL(20, 4))
            WHEN 'offline_order' THEN CAST(0 AS DECIMAL(20, 4))
            ELSE CAST(0 AS DECIMAL(20, 4))
        END AS DECIMAL(20, 4)
    ) AS channel_cost_amount
FROM revenue_daily r
LEFT JOIN channel_cost_daily c
    ON c.report_date = r.report_date
   AND c.account_id = r.account_id;

CREATE TEMPORARY VIEW v_gross_profit_daily_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', account_id, ':', category))) AS BIGINT) AS id,
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    category,
    revenue_amount,
    channel_cost_amount,
    CAST(revenue_amount - channel_cost_amount AS DECIMAL(20, 4)) AS gross_profit_amount,
    CAST(
        CASE
            WHEN revenue_amount = CAST(0 AS DECIMAL(20, 4)) THEN CAST(0 AS DECIMAL(20, 8))
            ELSE (revenue_amount - channel_cost_amount) / revenue_amount
        END AS DECIMAL(20, 8)
    ) AS gross_margin,
    1 AS version,
    CAST(NULL AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_gross_profit_daily_joined;

CREATE TEMPORARY TABLE sink_dws_gross_profit_daily_p (
    id                   BIGINT,
    report_date          DATE,
    account_id           STRING,
    account_type         STRING,
    account_category     STRING,
    system_type          STRING,
    category             STRING,
    revenue_amount       DECIMAL(20, 4),
    channel_cost_amount  DECIMAL(20, 4),
    gross_profit_amount  DECIMAL(20, 4),
    gross_margin         DECIMAL(20, 8),
    version              INT,
    remarks              STRING,
    create_time          TIMESTAMP(6),
    update_time          TIMESTAMP(6),
    delete_time          TIMESTAMP(6),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'targetSchema' = 'dws',
    'tableName' = 'dws_gross_profit_daily_p',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dws_gross_profit_daily_p
SELECT
    id,
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    category,
    revenue_amount,
    channel_cost_amount,
    gross_profit_amount,
    gross_margin,
    version,
    remarks,
    create_time,
    update_time,
    delete_time
FROM v_gross_profit_daily_base;
