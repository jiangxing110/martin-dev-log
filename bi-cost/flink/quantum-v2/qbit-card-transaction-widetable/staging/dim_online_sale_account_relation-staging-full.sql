--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-16
-- Updated Time:   2026-08-04 16:58:00
-- 历史名称：sp_init_dim_sale_account_relation_by_fast.sql
-- Description:    STAGING 销售关系 DIM 每日全量同步
-- 作业元信息：
--   作业类型：批处理
--   运行方式：每日调度全量执行
--   运行参数：无
--   源库变更响应：每日调度重跑，读取 STAGING 源表最新全量数据。
--   DIM说明：销售关系 DIM 的持续变更由 CDC 增量脚本承担。
-- Notes:
--   1. 主源: salesAccountRelation
--   2. 只同步销售关系时间线，不展开 api_account_relation 子户
--   3. DWM 通过 account_id/root_id + 交易时间匹配本 DIM
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'execution.checkpointing.interval' = '10s';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'pipeline.operator-chaining' = 'false';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'execution.checkpointing.timeout' = '30min';

SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';


CREATE TEMPORARY TABLE source_sales_account_relation (
    id                   STRING,
    account_id           STRING,
    sales_id             STRING,
    am_id                STRING,
    operation_manager_id STRING,
    create_time          TIMESTAMP(6),
    update_time          TIMESTAMP(6),
    delete_time          TIMESTAMP(6),
    remarks              STRING,
    version              INT,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.STAGING_PG_ASSETS_HOST}:${secret_values.STAGING_PG_ASSETS_PORT}/${secret_values.STAGING_PG_ASSETS_DATABASE}',
    'table-name' = '(SELECT id::text AS id, "accountId"::text AS account_id, "salesId"::text AS sales_id, "amId"::text AS am_id, "operationManagerId"::text AS operation_manager_id, "createTime" AS create_time, "updateTime" AS update_time, "deleteTime" AS delete_time, remarks, version FROM public."salesAccountRelation" WHERE "accountId" IS NOT NULL AND "createTime" IS NOT NULL) AS sales_account_relation_f',
    'username' = '${secret_values.STAGING_PG_ASSETS_USERNAME}',
    'password' = '${secret_values.STAGING_PG_ASSETS_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY VIEW v_dim_sale_account_relation AS
SELECT
    id,
    account_id AS relation_account_id,
    sales_id AS sale_id,
    am_id AS am_id,
    operation_manager_id AS operation_manager_id,
    create_time AS relation_start_time,
    delete_time AS relation_end_time,
    COALESCE(version, 1) AS version,
    remarks,
    create_time AS create_time,
    COALESCE(update_time, create_time) AS update_time,
    delete_time AS delete_time
FROM source_sales_account_relation
WHERE account_id IS NOT NULL
  AND create_time IS NOT NULL;

CREATE TEMPORARY TABLE sink_dim_sale_account_relation_p (
    id                    STRING,
    relation_account_id   STRING,
    sale_id               STRING,
    am_id                 STRING,
    operation_manager_id  STRING,
    relation_start_time   TIMESTAMP(6),
    relation_end_time     TIMESTAMP(6),
    version               INT,
    remarks               STRING,
    create_time           TIMESTAMP(6),
    update_time           TIMESTAMP(6),
    delete_time           TIMESTAMP(6),
    PRIMARY KEY (id, relation_start_time) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.STAGING_PG_ASSETS_HOST}:${secret_values.STAGING_PG_ASSETS_PORT}/${secret_values.STAGING_PG_ASSETS_DATABASE}',
    'tableName' = 'dim_sale_account_relation_p',
    'targetSchema' = 'dim',
    'userName' = '${secret_values.STAGING_PG_ASSETS_USERNAME}',
    'password' = '${secret_values.STAGING_PG_ASSETS_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dim_sale_account_relation_p
SELECT * FROM v_dim_sale_account_relation;


