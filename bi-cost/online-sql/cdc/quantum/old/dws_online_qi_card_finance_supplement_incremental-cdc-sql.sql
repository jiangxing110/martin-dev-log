--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-24
-- Description:    QI DWS 账户维度和销售维度数据补充
-- 作业元信息：
--   作业类型：流处理 CDC
--   运行方式：全量初始化 + 增量实时同步
--   运行参数：无
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑或由上游 CDC ODS/DIM 提供最新数据。
-- 从 dim.dim_account / dim.dim_sale_account_relation_p 读取
-- 补充 dws_qi_card_finance_daily_p 中的
--   account_type, account_category, system_type, sale_id, am_id
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

-- ====================================================================
-- 1. Source 表
-- ====================================================================

CREATE TEMPORARY TABLE source_dws_qi_card_finance_daily_p (
    id                        BIGINT,
    report_date               DATE,
    account_id                STRING,
    version                   INT,
    remarks                   STRING,
    create_time               TIMESTAMP(6),
    update_time               TIMESTAMP(6),
    delete_time               TIMESTAMP(6),
    cost_reimbursement_vol    DECIMAL(20, 4),
    cost_service_vol          DECIMAL(20, 4),
    cost_acs_regular_count    INT,
    cost_acs_vip_count        INT,
    cost_vrm_count            INT,
    rebate_interchange_vol    DECIMAL(20, 4),
    rebate_incentive_vol      DECIMAL(20, 4)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADBPG_OLD_DW_POST}:${secret_values.ADBPG_OLD_DW_PORT}/${secret_values.ADBPG_OLD_DW_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT * FROM public.dws_qi_card_finance_daily_p) AS dws_qi_card_finance_daily_p_f',
    'username' = '${secret_values.ADBPG_OLD_DW_USERNAME}',
    'password' = '${secret_values.ADBPG_OLD_DW_PWD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_dim_account (
    id               VARCHAR,
    account_type     STRING,
    account_category STRING,
    system_type      STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id::text AS id, type AS account_type, type AS account_category, system_type FROM dim.dim_account) AS dim_account_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_dim_sale_account_relation_p (
    id                   STRING,
    relation_account_id  STRING,
    sale_id              STRING,
    am_id                STRING,
    relation_start_time  TIMESTAMP(6),
    relation_end_time    TIMESTAMP(6),
    delete_time          TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id::text AS id, relation_account_id::text AS relation_account_id, sale_id::text AS sale_id, am_id::text AS am_id, relation_start_time, relation_end_time, delete_time FROM dim.dim_sale_account_relation_p WHERE delete_time IS NULL) AS sale_relation_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
);

-- ====================================================================
-- 2. 销售关系（取最新一条活跃关系）
-- ====================================================================

CREATE TEMPORARY VIEW v_sale_relation AS
SELECT relation_account_id, sale_id, am_id
FROM (
    SELECT
        relation_account_id,
        sale_id,
        am_id,
        ROW_NUMBER() OVER (PARTITION BY relation_account_id ORDER BY relation_start_time DESC) AS rn
    FROM source_dim_sale_account_relation_p
    WHERE delete_time IS NULL
) ranked
WHERE rn = 1;

-- ====================================================================
-- 3. 补充维度数据
-- ====================================================================

CREATE TEMPORARY VIEW v_dws_qi_supplement AS
SELECT
    d.id,
    d.report_date,
    d.account_id,
    da.account_type,
    da.account_category,
    da.system_type,
    d.version,
    d.remarks,
    d.create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    d.delete_time,
    sr.sale_id,
    sr.am_id,
    d.cost_reimbursement_vol,
    d.cost_service_vol,
    d.cost_acs_regular_count,
    d.cost_acs_vip_count,
    d.cost_vrm_count,
    d.rebate_interchange_vol,
    d.rebate_incentive_vol,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee
FROM source_dws_qi_card_finance_daily_p d
LEFT JOIN source_dim_account da
    ON da.id = d.account_id
LEFT JOIN v_sale_relation sr
    ON sr.relation_account_id = d.account_id;

-- ====================================================================
-- 4. Sink
-- ====================================================================

CREATE TEMPORARY TABLE sink_dws_qi_card_finance_daily_p (
    id                        BIGINT,
    report_date               DATE,
    account_id                STRING,
    account_type              STRING,
    account_category          STRING,
    system_type               STRING,
    version                   INT,
    remarks                   STRING,
    create_time               TIMESTAMP(6),
    update_time               TIMESTAMP(6),
    delete_time               TIMESTAMP(6),
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
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_qi_card_finance_daily_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dws_qi_card_finance_daily_p
SELECT * FROM v_dws_qi_supplement;
