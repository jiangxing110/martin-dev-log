--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-29
-- Description:    销售佣金每月8号快照固化任务
-- 作业元信息：
--   作业类型：月度批式CDC固化任务
--   运行方式：每月8号调度执行
--   运行参数：无
-- Notes:
--   1. 固定每月8号执行，结算月份为上个月月初。
--   2. 本任务不是实时CDC，不监听源表持续覆盖历史快照。
--   3. 推荐调度前先成功执行 recent_estimate 半天刷新任务。
--********************************************************************--

SET 'parallelism.default' = '2';
SET 'pipeline.operator-chaining' = 'false';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';
SET 'table.dml-sync' = 'true';

-- 月度固化任务复用 batch 快照脚本。
-- 调度平台传参建议：
--   snapshot_date    = CURRENT_DATE
--   settlement_month = 当前日期所在月份往前推1个月，格式 yyyy-MM
-- 示例：
--   2026-06-08 执行时 snapshot_date=2026-06-08, settlement_month=2026-05
-- 可直接提交 batch/dws_online_sales_commission_snapshot-batch-sql.sql。
