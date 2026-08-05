--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-05
-- Updated Time:   2026-08-05 23:37:06
-- Description:    ods_crypto_blockchain_transfers 手动清理兜底脚本
-- 作业元信息：
--   作业类型：ADBPG 手动 SQL
--   运行方式：仅在 JAR 删除作业不可用时，通过 ADBPG SQL Console 手动执行
--   运行参数：无
-- Notes:
--   1. 正式流程使用 flink/jobs/delete-table-data JAR 作业删除，本脚本不参与日常调度。
--   2. 本脚本不要部署到 VVR/Flink Draft。
--   3. JAR 删除成功后，再运行 ods_online_crypto_blockchain_transfers-batch-sql.sql。
--   4. JAR 业务参数：
--        --pg-url jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}
--        --pg-user ${secret_values.ADB_PG_USERNAME}
--        --pg-password ${secret_values.ADB_PG_PASSWORD}
--        --schema ods
--        --table-name ods_crypto_blockchain_transfers
--        --date-column dt
--        --start-date 2021-01-01
--        --end-date 2027-01-01
--        --dry-run false
--   5. 数据库连接和密码必须通过部署密钥配置，不要以明文写入脚本或作业参数。
--   6. 目标表当前已建分区范围为 2021-01-01 至 2027-01-01。
--********************************************************************--

DELETE FROM ods.ods_crypto_blockchain_transfers
WHERE dt >= DATE '2021-01-01'
  AND dt < DATE '2027-01-01';
