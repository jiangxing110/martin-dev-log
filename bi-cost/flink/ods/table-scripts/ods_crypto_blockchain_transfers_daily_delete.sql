--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-05
-- Updated Time:   2026-08-05 12:05:00
-- Description:    ods_crypto_blockchain_transfers 每日全量同步前 ADBPG 原生清理脚本
-- 作业元信息：
--   作业类型：ADBPG SQL
--   运行方式：在 ADBPG 查询窗口/ADBPG 调度中执行，先于 Flink insert 全量同步脚本执行
--   运行参数：无
-- Notes:
--   1. 不要在 VVR/Flink Draft 中执行本脚本。
--   2. Flink DELETE 在当前 VVR batch Draft 中会触发 multi-jobs-in-application 限制。
--   3. 清理动作使用 ADBPG 原生 SQL 执行，随后再运行 ods_online_crypto_blockchain_transfers-batch-sql.sql 回灌。
--   4. 目标表当前已建分区范围为 2021-01-01 至 2027-01-01。
--********************************************************************--

DELETE FROM ods.ods_crypto_blockchain_transfers
WHERE dt >= DATE '2021-01-01'
  AND dt < DATE '2027-01-01';
