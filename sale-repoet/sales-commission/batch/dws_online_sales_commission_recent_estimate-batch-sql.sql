--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-29
-- Description:    销售佣金8号前预估物化视图手动刷新（ADBPG直连执行）
-- 作业元信息：
--   作业类型：ADBPG SQL
--   运行方式：在 ADBPG / PostgreSQL 客户端直连执行
--   运行参数：无
-- Notes:
--   1. 物化视图为 dws.mv_sales_commission_recent_estimate。
--   2. 本脚本不写 DWS 物理结果表。
--   3. 刷新范围由物化视图定义控制：近三个月 settlement_month。
--   4. 不要提交到 Flink SQL Gateway；Flink SQL 不支持 REFRESH MATERIALIZED VIEW。
--   5. 如果需要调度，使用数据库 SQL 调度/ADBPG 客户端任务执行本脚本。
--********************************************************************--

REFRESH MATERIALIZED VIEW "dws"."mv_sales_commission_recent_estimate";
