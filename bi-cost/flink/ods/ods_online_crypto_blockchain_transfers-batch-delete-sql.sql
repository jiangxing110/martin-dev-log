--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-05
-- Updated Time:   2026-08-05 23:17:34
-- Description:    ods_crypto_blockchain_transfers Flink 清理脚本
-- 作业元信息：
--   作业类型：批处理
--   运行方式：部署为 Flink/VVR SQL 作业后从运维中心启动，用于保留作业执行记录
--   运行参数：部署运行参数需开启 execution.application-management.enabled=true
--            和 execution.multi-jobs-in-application.enable=true
-- Notes:
--   1. 本脚本需要作为 Flink/VVR SQL 部署启动，不要在 SQL 编辑器中直接 Execute Draft。
--   2. Execute Draft 链路不会加载部署详情中的运行参数，会触发 multiple jobs 检查失败。
--   3. 删除成功后，再运行 ods_online_crypto_blockchain_transfers-batch-sql.sql。
--   4. 目标表当前已建分区范围为 2021-01-01 至 2027-01-01。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'sink.parallelism' = '1';
SET 'table.dml-sync' = 'true';
SET 'execution.application-management.enabled' = 'true';
SET 'execution.multi-jobs-in-application.enable' = 'true';
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
