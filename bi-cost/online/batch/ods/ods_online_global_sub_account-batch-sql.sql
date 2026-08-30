--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-22
-- 历史名称：sp_init_global_sub_account_ods.sql
-- 功能：PG业务表 globalSubAccount 实时同步到 ODS层 ods_global_sub_account
-- 作业元信息：
--   作业类型：批处理
--   运行方式：JDBC 批读 + ADBPG upsert
--   运行参数：start_time, end_time
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑。
--   ODS说明：用于初始化、补数和全量回刷 ODS 原始层。
-- 模式：JDBC 批读 + ADBPG upsert | 全量刷新
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
-- 1. 【临时表】PG CDC 源表 (camelCase 匹配 PG 源)
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
    'url' = 'jdbc:postgresql://${secret_values.PG_TEST_HOST}:${secret_values.PG_TEST_PORT1}/${secret_values.PG_TEST_DATABASE}',
    'table-name' = '(SELECT "id"::text AS "id", "createTime" AS createtime, "updateTime" AS updatetime, "deleteTime" AS deletetime, "version", "remarks"::text AS "remarks", "accountId"::text AS accountid, "holderId"::text AS holderid, "nickname"::text AS "nickname", "purpose"::text AS "purpose", "currency"::text AS "currency", "isEnabled" AS isenabled, "ccBalanceRelationId"::text AS ccbalancerelationid, "subAccountId"::text AS subaccountid, "balanceId"::text AS balanceid, "status"::text AS "status", "openTime" AS opentime, "isFree" AS isfree, "provider"::text AS "provider", "extraData"::text AS extradata, "originAccountId"::text AS originaccountid, "isMasterAccount" AS ismasteraccount, "vrnEnable" AS vrnenable FROM public."globalSubAccount" WHERE (("createTime" >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND "createTime" < CAST(''${end_time}'' AS TIMESTAMP(6))) OR ("updateTime" >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND "updateTime" < CAST(''${end_time}'' AS TIMESTAMP(6)))) ) AS ods_online_global_sub_account_f',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000',
    'scan.auto-commit' = 'false'
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
