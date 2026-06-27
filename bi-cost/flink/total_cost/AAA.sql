--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-16
-- 历史名称：sp_init_total_channel_cost_by_fast.sql
-- Description:    总渠道成本 DWS 批量初始化/回刷
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性初始化/回刷或调度执行
--   运行参数：start_date, end_date
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑或由上游 CDC ODS/DIM 提供最新数据。
-- Notes:
--   1. BB/QI/SL 作为量子卡卡渠道成本来源
--   2. dwm_finance_channel_cost_p 承载所有产品线金融渠道成本
--   3. 金融渠道成本按 product_line 分别进入 acquiring/business/quantum/crypto 成本桶
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

SET 'execution.checkpointing.interval' = '10s';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'pipeline.operator-chaining' = 'false';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'execution.checkpointing.timeout' = '30min';

SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';


CREATE TEMPORARY TABLE source_dws_bb_card_finance_daily_p (
    id                       BIGINT,
    report_date              DATE,
    account_id               STRING,
    account_type             STRING,
    account_category         STRING,
    system_type              STRING,
    m_dom_auth_count         INT,
    m_int_auth_count         INT,
    v_dom_auth_count         INT,
    v_int_auth_count         INT,
    m_int_decline_count      INT,
    v_int_decline_count      INT,
    dom_decline_count        INT,
    m_int_reversal_count     INT,
    v_int_reversal_count     INT,
    dom_reversal_count       INT,
    m_int_refund_count       INT,
    v_int_refund_count       INT,
    dom_refund_count         INT,
    av_m_dom_count           INT,
    av_m_int_count           INT,
    av_v_dom_count           INT,
    av_v_int_count           INT,
    m_dom_clearing_vol       DECIMAL(20, 4),
    m_int_clearing_vol       DECIMAL(20, 4),
    v_dom_clearing_vol       DECIMAL(20, 4),
    v_int_clearing_vol       DECIMAL(20, 4),
    bb_rebate_base_amt       DECIMAL(20, 4),
    bb_channel_cashback_comm DECIMAL(20, 4),
    active_card_count        INT,
    cost_fixed_fee           DECIMAL(20, 4),
    sale_id                  STRING,
    am_id                    STRING,
    delete_time              TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT * FROM dws.dws_bb_card_finance_daily_p) AS dws_bb_card_finance_daily_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_dws_qi_card_finance_daily_p (
    id                        BIGINT,
    report_date               DATE,
    account_id                STRING,
    account_type              STRING,
    account_category          STRING,
    system_type               STRING,
    sale_id                   STRING,
    am_id                     STRING,
    cost_reimbursement_vol    DECIMAL(20, 4),
    cost_service_vol          DECIMAL(20, 4),
    cost_acs_regular_count    INT,
    cost_acs_vip_count        INT,
    cost_vrm_count            INT,
    rebate_interchange_vol    DECIMAL(20, 4),
    rebate_incentive_vol      DECIMAL(20, 4),
    cost_fixed_fee            DECIMAL(20, 4),
    delete_time               TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT * FROM dws.dws_qi_card_finance_daily_p) AS dws_qi_card_finance_daily_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_dws_sl_card_finance_daily_p (
    id              BIGINT,
    report_date     DATE,
    account_id      STRING,
    account_type    STRING,
    account_category STRING,
    system_type     STRING,
    sale_id         STRING,
    am_id           STRING,
    rebate_base     DECIMAL(20, 4),
    rebate_amt      DECIMAL(20, 4),
    cost_fixed_fee  DECIMAL(20, 4),
    delete_time     TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT * FROM dws.dws_sl_card_finance_daily_p) AS dws_sl_card_finance_daily_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_dwm_finance_channel_cost_p (
    id               BIGINT,
    report_date      DATE,
    account_id       STRING,
    product_line      STRING,
    provider         STRING,
    cost_type        STRING,
    cost_amount      DECIMAL(20, 4),
    sale_id          STRING,
    am_id            STRING,
    delete_time      TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT * FROM dwm.dwm_finance_channel_cost_p) AS dwm_finance_channel_cost_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
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

CREATE TEMPORARY VIEW v_channel_cost_source AS
SELECT
    s.report_date,
    s.account_id,
    da.account_type,
    da.account_category,
    da.system_type,
    s.sale_id,
    s.am_id,
    'QUANTUM_CARD' AS product_line,
    'BB' AS cost_source,
    CAST(
        COALESCE(s.m_dom_auth_count, 0) * 0.1090
      + COALESCE(s.m_int_auth_count, 0) * 0.4845
      + COALESCE(s.v_dom_auth_count, 0) * 0.0725
      + COALESCE(s.v_int_auth_count, 0) * 0.4700
      + COALESCE(s.m_int_decline_count, 0) * 0.3595
      + COALESCE(s.v_int_decline_count, 0) * 0.3570
      + COALESCE(s.dom_decline_count, 0) * 0.0890
      + COALESCE(s.m_int_reversal_count, 0) * 0.7190
      + COALESCE(s.v_int_reversal_count, 0) * 0.7140
      + COALESCE(s.dom_reversal_count, 0) * 0.1780
      + COALESCE(s.m_int_refund_count, 0) * 0.4845
      + COALESCE(s.v_int_refund_count, 0) * 0.4770
      + COALESCE(s.dom_refund_count, 0) * 0.1090
      + COALESCE(s.av_m_dom_count, 0) * 0.1090
      + COALESCE(s.av_m_int_count, 0) * 0.4845
      + COALESCE(s.av_v_dom_count, 0) * 0.0725
      + COALESCE(s.av_v_int_count, 0) * 0.4770
      + COALESCE(s.m_dom_clearing_vol, 0) * -0.0021
      + COALESCE(s.m_int_clearing_vol, 0) * -0.0111
      + COALESCE(s.v_dom_clearing_vol, 0) * -0.0016
      + COALESCE(s.v_int_clearing_vol, 0) * -0.0116
      + COALESCE(s.bb_channel_cashback_comm, 0) * -1
      + COALESCE(s.active_card_count, 0) * 0.1000
      + COALESCE(s.cost_fixed_fee, CAST(0 AS DECIMAL(20, 4)))
        AS DECIMAL(20, 4)
    ) AS cost_amount
FROM source_dws_bb_card_finance_daily_p s
LEFT JOIN source_dim_account da ON da.id = s.account_id
WHERE s.delete_time IS NULL

    
UNION ALL

SELECT
    s.report_date,
    s.account_id,
    da.account_type,
    da.account_category,
    da.system_type,
    s.sale_id,
    s.am_id,
    'QUANTUM_CARD' AS product_line,
    'QI' AS cost_source,
    CAST(
        COALESCE(s.cost_reimbursement_vol * 0.9946, CAST(0 AS DECIMAL(20, 4)))
      + COALESCE(s.cost_service_vol * 1.0084, CAST(0 AS DECIMAL(20, 4)))
      + COALESCE(s.cost_acs_regular_count * 0.9852, CAST(0 AS DECIMAL(20, 4)))
      + COALESCE(s.cost_acs_vip_count * 1.1146, CAST(0 AS DECIMAL(20, 4)))
      + COALESCE(s.cost_vrm_count * 1.2239, CAST(0 AS DECIMAL(20, 4)))
      + COALESCE(s.cost_fixed_fee, CAST(0 AS DECIMAL(20, 4)))
        AS DECIMAL(20, 4)
    ) AS cost_amount
FROM source_dws_qi_card_finance_daily_p s
LEFT JOIN source_dim_account da ON da.id = s.account_id
WHERE s.delete_time IS NULL

UNION ALL

SELECT
    s.report_date,
    s.account_id,
    da.account_type,
    da.account_category,
    da.system_type,
    s.sale_id,
    s.am_id,
    'QUANTUM_CARD' AS product_line,
    'SL' AS cost_source,
    CAST(COALESCE(s.cost_fixed_fee, CAST(0 AS DECIMAL(20, 4))) AS DECIMAL(20, 4)) AS cost_amount
FROM source_dws_sl_card_finance_daily_p s
LEFT JOIN source_dim_account da ON da.id = s.account_id
WHERE s.delete_time IS NULL

UNION ALL

SELECT
    s.report_date,
    s.account_id,
    da.account_type,
    da.account_category,
    da.system_type,
    s.sale_id,
    s.am_id,
    s.product_line,
    CONCAT('FINANCE:', COALESCE(s.provider, ''), ':', COALESCE(s.cost_type, '')) AS cost_source,
    CAST(COALESCE(s.cost_amount, CAST(0 AS DECIMAL(20, 4))) AS DECIMAL(20, 4)) AS cost_amount
FROM source_dwm_finance_channel_cost_p s
LEFT JOIN source_dim_account da ON da.id = s.account_id
WHERE s.delete_time IS NULL;

CREATE TEMPORARY VIEW v_total_channel_cost_daily AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', account_id, ':', COALESCE(sale_id, ''), ':', COALESCE(am_id, '')))) AS BIGINT) AS id,
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    sale_id,
    am_id,
    CAST(SUM(CASE WHEN product_line = 'ACQUIRING' THEN cost_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS acquiring_cost,
    CAST(SUM(CASE WHEN product_line = 'GLOBAL_ACCOUNT' THEN cost_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS business_cost,
    CAST(SUM(CASE WHEN product_line = 'QUANTUM_CARD' THEN cost_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS quantum_cost,
    CAST(SUM(CASE WHEN product_line = 'CRYPTO_ASSET' THEN cost_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS crypto_cost,
    CAST(SUM(cost_amount) AS DECIMAL(20, 4)) AS total_channel_cost,
    1 AS version,
    CAST(NULL AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_channel_cost_source
GROUP BY report_date, account_id, account_type, account_category, system_type, sale_id, am_id;

CREATE TEMPORARY TABLE sink_dws_total_channel_cost_daily_p (
    id                            BIGINT,
    report_date                   DATE,
    account_id                    STRING,
    account_type                  STRING,
    account_category              STRING,
    system_type                   STRING,
    sale_id                       STRING,
    am_id                         STRING,
    acquiring_cost                DECIMAL(20, 4),
    business_cost                 DECIMAL(20, 4),
    quantum_cost                  DECIMAL(20, 4),
    crypto_cost                   DECIMAL(20, 4),
    total_channel_cost            DECIMAL(20, 4),
    version                       INT,
    remarks                       STRING,
    create_time                   TIMESTAMP(6),
    update_time                   TIMESTAMP(6),
    delete_time                   TIMESTAMP(6),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_total_channel_cost_daily_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'insert',
    'batchSize' = '2000'
);

INSERT INTO sink_dws_total_channel_cost_daily_p
SELECT * FROM v_total_channel_cost_daily;
