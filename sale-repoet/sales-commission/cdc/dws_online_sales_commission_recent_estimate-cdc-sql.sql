--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-29
-- Description:    销售佣金8号前预估物化视图刷新说明
-- 作业元信息：
--   作业类型：说明脚本
--   运行方式：通过 ADBPG / PostgreSQL 客户端调度执行
--   运行参数：无
-- Notes:
--   1. dws.mv_sales_commission_recent_estimate 包含复杂 CTE / JOIN / 窗口函数。
--   2. ADBPG 增量物化视图不支持该类查询，当前使用普通物化视图。
--   3. 本任务不提交 Flink SQL Gateway。
--   4. 调度时执行 batch/dws_online_sales_commission_recent_estimate-batch-sql.sql。
--********************************************************************--

CREATE TEMPORARY VIEW sales_commission_recent_estimate_refresh_notice AS
SELECT
    CAST('dws.mv_sales_commission_recent_estimate is a normal materialized view because the query is not incrementally maintainable. Refresh it through an ADBPG client, not Flink SQL Gateway.' AS STRING) AS message;
