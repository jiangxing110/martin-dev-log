--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-16
-- Description:    销售关系 DIM 批量初始化/回刷
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性初始化/回刷或调度执行
--   运行参数：无
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑或由上游 CDC ODS/DIM 提供最新数据。
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
    `accountId`          STRING,
    `salesId`            STRING,
    `amId`               STRING,
    `operationManagerId` STRING,
    `createTime`         TIMESTAMP(6),
    `updateTime`         TIMESTAMP(6),
    `deleteTime`         TIMESTAMP(6),
    remarks              STRING,
    version              INT,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'salesAccountRelation',
    'targetSchema' = 'public',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY VIEW v_dim_sale_account_relation AS
SELECT
    id,
    `accountId` AS relation_account_id,
    `salesId` AS sale_id,
    `amId` AS am_id,
    `operationManagerId` AS operation_manager_id,
    `createTime` AS relation_start_time,
    `deleteTime` AS relation_end_time,
    COALESCE(version, 1) AS version,
    remarks,
    `createTime` AS create_time,
    COALESCE(`updateTime`, `createTime`) AS update_time,
    `deleteTime` AS delete_time
FROM source_sales_account_relation
WHERE `accountId` IS NOT NULL
  AND `createTime` IS NOT NULL;

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
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dim_sale_account_relation_p',
    'targetSchema' = 'dim',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
),
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dim_sale_account_relation_p
SELECT * FROM v_dim_sale_account_relation;
