--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-30
-- 功能：PG Test public.qbitCardGroup CDC 同步到 ADBPG ODS ods.ods_qbit_card_group
-- 模式：全量初始化 + 增量实时同步 | 支持 Upsert/Delete
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'execution.checkpointing.interval' = '10s';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'execution.checkpointing.timeout' = '30min';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';

CREATE TEMPORARY TABLE flink_source_qbit_card_group (
    id          STRING,
    `createTime` TIMESTAMP(6),
    `updateTime` TIMESTAMP(6),
    `deleteTime` TIMESTAMP(6),
    version     INT,
    `groupName` STRING,
    status      STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = '${secret_values.PG_TEST_HOST}',
    'port' = '${secret_values.PG_TEST_PORT1}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'database-name' = '${secret_values.PG_TEST_DATABASE}',
    'schema-name' = 'public',
    'table-name' = 'qbitCardGroup',
    'slot.name' = 'flink_slot_qbit_card_group_ods_pgtest_v1',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.connector.pgout.publication.autocreate' = 'false',
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'true',
    'scan.incremental.snapshot.chunk.size' = '50000',
    'heartbeat.interval.ms' = '30000',
    'debezium.field.name.adjustment.mode' = 'none'
);

CREATE TEMPORARY TABLE flink_sink_ods_qbit_card_group (
    id          STRING,
    dt          DATE,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    version     INT,
    group_name  STRING,
    status      STRING,
    submit_time TIMESTAMP(6),
    PRIMARY KEY (id, dt) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'ods_qbit_card_group',
    'targetSchema' = 'ods',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '200'
);

INSERT INTO flink_sink_ods_qbit_card_group
SELECT
    id,
    CAST(`createTime` AS DATE) AS dt,
    `createTime` AS create_time,
    `updateTime` AS update_time,
    `deleteTime` AS delete_time,
    version,
    `groupName` AS group_name,
    status,
    `createTime` AS submit_time
FROM flink_source_qbit_card_group;

