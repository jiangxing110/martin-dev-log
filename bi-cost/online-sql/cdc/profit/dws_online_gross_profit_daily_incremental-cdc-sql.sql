--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-22
-- Description:    Gross Profit CDC初始化/回刷
-- 作业元信息：
--   作业类型：流处理 CDC
--   运行方式：全量初始化 + 增量实时同步
--   运行参数：无
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑或由上游 CDC ODS/DIM 提供最新数据。
-- Notes:
--   1. 收入输入来自独立视图 dws.vw_profit_revenue_daily
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
    account_category  STRING,
    system_type       STRING,
    category          STRING,
    revenue_amount    STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
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
    acquiring_cost    STRING,
    business_cost     STRING,
    quantum_cost      STRING,
    crypto_cost       STRING,
    total_channel_cost STRING,
    delete_time       TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY VIEW v_gross_profit_daily_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(CAST(r.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', r.account_id, ':', r.category))) AS BIGINT) AS id,
    r.report_date,
    r.account_id,
    COALESCE(r.account_type, c.account_type) AS account_type,
    COALESCE(r.account_category, c.account_category) AS account_category,
    COALESCE(r.system_type, c.system_type) AS system_type,
    r.category,
    CAST(COALESCE(CAST(r.revenue_amount AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4))) AS DECIMAL(20, 4)) AS revenue_amount,
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
    ) AS channel_cost_amount,
    CAST(
        COALESCE(CAST(r.revenue_amount AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4))) -
        CASE r.category
            WHEN 'qbit_card' THEN COALESCE(CAST(c.quantum_cost AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4)))
            WHEN 'global_account' THEN COALESCE(CAST(c.business_cost AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4)))
            WHEN 'crypto_assets' THEN COALESCE(CAST(c.crypto_cost AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4)))
            WHEN 'particle_financing' THEN CAST(0 AS DECIMAL(20, 4))
            WHEN 'company_registration' THEN CAST(0 AS DECIMAL(20, 4))
            WHEN 'offline_order' THEN CAST(0 AS DECIMAL(20, 4))
            ELSE CAST(0 AS DECIMAL(20, 4))
        END AS DECIMAL(20, 4)
    ) AS gross_profit_amount,
    CAST(
        CASE
            WHEN COALESCE(CAST(r.revenue_amount AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4))) = CAST(0 AS DECIMAL(20, 4)) THEN CAST(0 AS DECIMAL(20, 8))
            ELSE (
                (
                    COALESCE(CAST(r.revenue_amount AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4))) -
                    CASE r.category
                        WHEN 'qbit_card' THEN COALESCE(CAST(c.quantum_cost AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4)))
                        WHEN 'global_account' THEN COALESCE(CAST(c.business_cost AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4)))
                        WHEN 'crypto_assets' THEN COALESCE(CAST(c.crypto_cost AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4)))
                        WHEN 'particle_financing' THEN CAST(0 AS DECIMAL(20, 4))
                        WHEN 'company_registration' THEN CAST(0 AS DECIMAL(20, 4))
                        WHEN 'offline_order' THEN CAST(0 AS DECIMAL(20, 4))
                        ELSE CAST(0 AS DECIMAL(20, 4))
                    END
                ) / COALESCE(CAST(r.revenue_amount AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4)))
            )
        END AS DECIMAL(20, 8)
    ) AS gross_margin,
    1 AS version,
    CAST(NULL AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM source_profit_revenue_daily r
LEFT JOIN source_total_channel_cost_daily c
    ON c.report_date = r.report_date
   AND c.account_id = r.account_id
   AND c.delete_time IS NULL;

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
