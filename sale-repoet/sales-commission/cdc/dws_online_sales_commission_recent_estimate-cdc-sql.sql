--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-29
-- Description:    销售佣金8号前预估物化视图半天刷新任务说明
-- 作业元信息：
--   作业类型：ADBPG SQL 调度说明
--   运行方式：半天调度一次，必须通过 ADBPG / PostgreSQL 客户端执行
--   运行参数：无
-- Notes:
--   1. 物化视图为 dws.mv_sales_commission_recent_estimate。
--   2. 本任务不覆盖8号后快照。
--   3. 每月8号快照固化前必须先刷新成功。
--   4. 不要提交到 Flink SQL Gateway；Flink SQL 不支持 REFRESH MATERIALIZED VIEW。
--   5. 真正需要执行的数据库 SQL：
--      REFRESH MATERIALIZED VIEW "dws"."mv_sales_commission_recent_estimate";
--********************************************************************--

CREATE TEMPORARY VIEW sales_commission_recent_estimate_refresh_notice AS
SELECT
    CAST('REFRESH MATERIALIZED VIEW is ADBPG/PostgreSQL SQL, not Flink SQL. Run batch/dws_online_sales_commission_recent_estimate-batch-sql.sql through an ADBPG client.' AS STRING) AS message;
