--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-18
-- Description:    销售绩效实际收入物化视图手动刷新与汇总检查
-- 作业元信息：
--   作业类型：ADBPG SQL
--   运行方式：ADBPG / PostgreSQL 客户端直连执行
--   运行参数：无
-- Notes:
--   1. 周期刷新由 sql/cdc 下的销售佣金/绩效收入/合伙人利润 Flink JDBC 刷新任务执行。
--   2. 本脚本用于手动刷新和查看收入项目、销售/AM的合计。
--********************************************************************--

REFRESH MATERIALIZED VIEW "dws"."mv_sales_commission_performance_income_recent";

SELECT
  activity_month,
  income_type,
  COUNT(*) AS row_count,
  SUM(income_amount)::numeric(20, 4) AS income_amount
FROM "dws"."mv_sales_commission_performance_income_recent"
GROUP BY activity_month, income_type
ORDER BY activity_month, income_type;

SELECT
  activity_month,
  sale_id,
  am_id,
  SUM(income_amount)::numeric(20, 4) AS real_time_processing
FROM "dws"."mv_sales_commission_performance_income_recent"
GROUP BY activity_month, sale_id, am_id
ORDER BY activity_month, sale_id, am_id;
