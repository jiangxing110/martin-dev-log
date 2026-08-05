--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-05
-- Updated Time:   2026-08-05 11:55:00
-- Description:    ods_crypto_blockchain_transfers 每日全量同步前清理脚本
-- 作业元信息：
--   作业类型：批处理
--   运行方式：定期调度执行，先于 ods_online_crypto_blockchain_transfers-batch-sql.sql 执行
--   运行参数：无
-- Notes:
--   1. 目标表当前已建分区范围为 2021-01-01 至 2027-01-01。
--   2. 后续新增年份分区时，需要同步扩展清理上限。
--   3. 本脚本必须作为独立 VVR Draft/作业运行，不要与 insert 脚本合并到同一个 Draft。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'sink.parallelism' = '1';
SET 'table.dml-sync' = 'true';
SET 'execution.application-management.enabled' = 'true';
SET 'execution.multi-jobs-in-application.enable' = 'true';
SET 'pipeline.operator-chaining' = 'true';
SET 'execution.checkpointing.interval' = '5min';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'execution.checkpointing.timeout' = '30min';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '1';
SET 'restart-strategy.fixed-delay.delay' = '60s';

CREATE TEMPORARY TABLE sink_ods_crypto_blockchain_transfers (
    id STRING,
    dt DATE,
    PRIMARY KEY (id, dt) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'ods_crypto_blockchain_transfers',
    'targetSchema' = 'ods',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

DELETE FROM sink_ods_crypto_blockchain_transfers
WHERE dt >= DATE '2021-01-01'
  AND dt < DATE '2027-01-01';
