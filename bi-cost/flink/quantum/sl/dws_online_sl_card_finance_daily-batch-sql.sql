--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-15
-- 历史名称：sp_init_sl_card_dws_by_fast.sql
-- Description:    Quantum SL DWS 批量初始化/回刷
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性初始化/回刷或调度执行
--   运行参数：start_date, end_date
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑或由上游 CDC ODS/DIM 提供最新数据。
-- Notes:
--   1. 主链路: qbitCardSettlement -> DWM -> DWS
--   2. 粒度: account_id + report_date + sale_id + am_id
--   3. cost_fixed_fee 后续通过 bi_month_tag 单独更新
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

CREATE TEMPORARY TABLE source_dwm_sl_card_transaction_detail_p (
    id                         STRING,
    account_id                 STRING,
    version                    INT,
    remarks                    STRING,
    create_time                TIMESTAMP(6),
    update_time                TIMESTAMP(6),
    delete_time                TIMESTAMP(6),
    settlement_date            DATE,
    settlement_transaction_id  STRING,
    qbit_card_transaction_id   STRING,
    qbit_transaction_id        STRING,
    provider                   STRING,
    billing_amount             DECIMAL(20, 4),
    billing_currency_code      STRING,
    transaction_amount         DECIMAL(20, 4),
    transaction_currency_code  STRING,
    country                    STRING,
    sale_id                    STRING,
    am_id                      STRING,
    raw_data                   STRING,
    etl_time                   TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = 'dwm.dwm_sl_card_transaction_detail_p',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_dim_account (
    id                STRING,
    account_type      STRING,
    account_category  STRING,
    system_type       STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, account_type, type AS account_category, system_type FROM dim.dim_account) AS dim_account_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY VIEW v_dws_sl_daily_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(CAST(s.settlement_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', s.account_id, ':', COALESCE(s.sale_id, ''), ':', COALESCE(s.am_id, '')))) AS BIGINT) AS id,
    s.settlement_date AS report_date,
    s.account_id,
    da.account_type,
    da.account_category,
    da.system_type,
    1 AS version,
    CAST(NULL AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time,
    s.sale_id,
    s.am_id,
    CAST(SUM(COALESCE(s.billing_amount, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 4)) AS rebate_base,
    CAST(SUM(
        CASE
            WHEN s.country = 'US' THEN COALESCE(s.billing_amount, CAST(0 AS DECIMAL(20, 4))) * CAST(0.02 AS DECIMAL(20, 4))
            ELSE COALESCE(s.billing_amount, CAST(0 AS DECIMAL(20, 4))) * CAST(0.005 AS DECIMAL(20, 4))
        END
    ) AS DECIMAL(20, 4)) AS rebate_amt,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee
FROM source_dwm_sl_card_transaction_detail_p s
LEFT JOIN source_dim_account da ON da.id = s.account_id
WHERE s.delete_time IS NULL
GROUP BY s.settlement_date, s.account_id, da.account_type, da.account_category, da.system_type, s.sale_id, s.am_id;

CREATE TEMPORARY TABLE sink_dws_sl_card_finance_daily_p (
    id              BIGINT,
    report_date     DATE,
    account_id      STRING,
    account_type    STRING,
    account_category STRING,
    system_type     STRING,
    version         INT,
    remarks         STRING,
    create_time     TIMESTAMP(6),
    update_time     TIMESTAMP(6),
    delete_time     TIMESTAMP(6),
    sale_id         STRING,
    am_id           STRING,
    rebate_base     DECIMAL(20, 4),
    rebate_amt      DECIMAL(20, 4),
    cost_fixed_fee  DECIMAL(20, 4),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_sl_card_finance_daily_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dws_sl_card_finance_daily_p
SELECT
    id,
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    version,
    remarks,
    create_time,
    update_time,
    delete_time,
    sale_id,
    am_id,
    rebate_base,
    rebate_amt,
    cost_fixed_fee
FROM v_dws_sl_daily_base;

