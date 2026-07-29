--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-29
-- Description:    销售佣金8号前预估物化视图手动刷新
-- 作业元信息：
--   作业类型：物化视图手动刷新
--   运行方式：一次性初始化/手动刷新
--   运行参数：无
-- Notes:
--   1. 物化视图为 dws.mv_sales_commission_recent_estimate。
--   2. 本脚本不写 DWS 物理结果表。
--   3. 刷新范围由物化视图定义控制：近三个月 settlement_month。
--********************************************************************--

REFRESH MATERIALIZED VIEW "dws"."mv_sales_commission_recent_estimate";
