--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-05
-- Updated Time:   2026-08-05 14:54:40
-- Description:    ods_crypto_blockchain_transfers Flink 清理脚本（已停用）
-- 作业元信息：
--   作业类型：批处理
--   运行方式：已由 delete-table-data JAR 作业替代，不再部署或调度
--   运行参数：无
-- Notes:
--   1. 正式删除流程使用 delete-table-data JAR 作业。
--   2. 本文件仅保留历史实现，不要继续部署。
--   3. 手动兜底使用 table-scripts/ods_crypto_blockchain_transfers_daily_delete.sql。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'sink.parallelism' = '1';
SET 'table.dml-sync' = 'true';
SET 'pipeline.operator-chaining' = 'true';
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
