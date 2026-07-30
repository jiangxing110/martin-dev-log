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
--   2. 该视图包含复杂 CTE / JOIN / 窗口函数，不适用于 ADBPG 增量物化视图。
--   3. 本脚本用于手动刷新物化视图，并返回各月份、各来源类型汇总，方便检查。
--********************************************************************--

REFRESH MATERIALIZED VIEW "dws"."mv_sales_commission_recent_estimate";

SELECT
  settlement_month,
  source_type,
  COUNT(1) AS row_count,
  SUM(effective_revenue) AS effective_revenue,
  SUM(gp) AS gp,
  SUM(estimated_commission) AS estimated_commission
FROM "dws"."mv_sales_commission_recent_estimate"
GROUP BY settlement_month, source_type
ORDER BY settlement_month, source_type;
