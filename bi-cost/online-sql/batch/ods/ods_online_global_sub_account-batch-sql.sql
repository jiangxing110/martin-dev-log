--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-22
-- 历史名称：sp_init_global_sub_account_ods.sql
-- 功能：PG业务表 JDBC 批处理同步到 ODS层 ods_global_sub_account
-- 作业元信息：
--   作业类型：批处理
--   运行方式：调度执行，按 start_date / end_date 窗口回刷
--   运行参数：start_date, end_date
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑。
--   ODS说明：ODS 原始层保存源表原始数据，用于下游 DWD/DWM/DWS 加工。
----------------------------------------------------------------------

SET 'parallelism.default' = '1';
SET 'execution.checkpointing.interval' = '10s';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'execution.checkpointing.timeout' = '30min';

SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';

-- ==============================================
-- 1. 【临时表】PG 源表 (JDBC 批处理)
-- ==============================================
CREATE TEMPORARY TABLE flink_source_global_sub_account (
    id                       STRING,
    createTime               TIMESTAMP(6),
    updateTime               TIMESTAMP(6),
    deleteTime               TIMESTAMP(6),
    version                  INT,
    remarks                  STRING,
    accountId                STRING,
    holderId                 STRING,
    nickname                 STRING,
    purpose                  STRING,
    currency                 STRING,
    isEnabled                BOOLEAN,
    ccBalanceRelationId      STRING,
    subAccountId             STRING,
    balanceId                STRING,
    status                   STRING,
    openTime                 TIMESTAMP(6),
    isFree                   BOOLEAN,
    provider                 STRING,
    extraData                STRING,
    originAccountId          STRING,
    isMasterAccount          BOOLEAN,
    vrnEnable                BOOLEAN,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.PG_TEST_HOST}:${secret_values.PG_TEST_PORT1}/${secret_values.PG_TEST_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT * FROM globalSubAccount) AS globalSubAccount_f',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

-- ==============================================
-- 2. 【临时表】ADBPG 目标表 ods.ods_global_sub_account
-- ==============================================
CREATE TEMPORARY TABLE flink_sink_ods_global_sub_account (
    id                       STRING,
    dt                       DATE,
    create_time              TIMESTAMP(6),
    update_time              TIMESTAMP(6),
    delete_time              TIMESTAMP(6),
    version                  INT,
    remarks                  STRING,
    account_id               STRING,
    holder_id                STRING,
    nickname                 STRING,
    purpose                  STRING,
    currency                 STRING,
    is_enabled               BOOLEAN,
    cc_balance_relation_id   STRING,
    sub_account_id           STRING,
    balance_id               STRING,
    status                   STRING,
    open_time                TIMESTAMP(6),
    is_free                  BOOLEAN,
    provider                 STRING,
    extra_data               STRING,
    origin_account_id        STRING,
    is_master_account        BOOLEAN,
    vrn_enable               BOOLEAN,
    submit_time              TIMESTAMP(6),
    PRIMARY KEY (id, dt) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'ods_global_sub_account',
    'targetSchema' = 'ods',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '200'
);

-- ==============================================
-- 3. 数据同步: submit_time = create_time, dt = create_time::DATE
-- ==============================================
INSERT INTO flink_sink_ods_global_sub_account
SELECT
    id,
    CAST(createTime AS DATE) AS dt,
    createTime AS create_time,
    updateTime AS update_time,
    deleteTime AS delete_time,
    version,
    remarks,
    accountId AS account_id,
    holderId AS holder_id,
    nickname,
    purpose,
    currency,
    isEnabled AS is_enabled,
    ccBalanceRelationId AS cc_balance_relation_id,
    subAccountId AS sub_account_id,
    balanceId AS balance_id,
    status,
    openTime AS open_time,
    isFree AS is_free,
    provider,
    extraData AS extra_data,
    originAccountId AS origin_account_id,
    isMasterAccount AS is_master_account,
    vrnEnable AS vrn_enable,
    createTime AS submit_time
FROM flink_source_global_sub_account;
