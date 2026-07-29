--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-29
-- Description:    销售佣金8号前预估物化视图半天刷新任务
-- 作业元信息：
--   作业类型：调度型物化视图刷新
--   运行方式：半天调度一次
--   运行参数：无
-- Notes:
--   1. 物化视图为 dws.mv_sales_commission_recent_estimate。
--   2. 本任务不覆盖8号后快照。
--   3. 每月8号快照固化前必须先刷新成功。
--********************************************************************--

REFRESH MATERIALIZED VIEW "dws"."mv_sales_commission_recent_estimate";
