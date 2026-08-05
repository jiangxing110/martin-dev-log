--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-06 00:20:56
-- Description:    ods_crypto_blockchain_transfers v2 Flink SQL 清理作业
-- 作业元信息：
--   作业类型：批处理
--   运行方式：VVR SQL 作业调用 ADBPG 删除函数，用于保留 Flink 作业执行记录
--   前置依赖：先在 ADBPG 执行 online/table/ods/register_fn_delete_crypto_blockchain_transfers_v2.sql
-- Notes:
--   1. 本作业不直接使用 Flink SQL DELETE，而是通过 JDBC source 调用 ADBPG 函数。
--   2. 这样 VVR 侧只有一个 INSERT 作业，避免 CREATE TEMPORARY TABLE/VIEW + DELETE 的 batch 多作业限制。
--   3. 部署时需要在“附加依赖文件”添加 PostgreSQL JDBC driver，例如 postgresql-42.7.4.jar。
--   4. 首次执行建议把函数第三个参数改为 true 做 dry-run；确认行数后再改为 false。
--   5. 删除成功后，再运行 ods_online_crypto_blockchain_transfers-batch-sql.sql。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'sink.parallelism' = '1';
SET 'table.dml-sync' = 'true';
SET 'pipeline.operator-chaining' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '1';
SET 'restart-strategy.fixed-delay.delay' = '60s';

CREATE TEMPORARY TABLE source_delete_ods_crypto_blockchain_transfers_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT ods.fn_delete_crypto_blockchain_transfers_v2(DATE ''2021-01-01'', DATE ''2027-01-01'', false) AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

CREATE TEMPORARY TABLE print_delete_ods_crypto_blockchain_transfers_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'print'
);

INSERT INTO print_delete_ods_crypto_blockchain_transfers_result
SELECT affected_rows
FROM source_delete_ods_crypto_blockchain_transfers_result;
