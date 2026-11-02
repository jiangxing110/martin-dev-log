--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-02
-- Description:    销售毛利近期估算物化视图手动刷新（ADBPG直连执行）
-- 作业元信息：
--   作业类型：ADBPG SQL
--   运行方式：在 ADBPG / PostgreSQL 客户端直连执行
--   运行参数：无
-- Notes:
--   1. 物化视图为 dws.mv_sales_gross_profit_recent_estimate。
--   2. 视图按 sale-repoet/sales-commission 的普通物化视图模式每12小时刷新；本脚本用于手动刷新/核对。
--   3. 汇总字段保留来源正负数；本脚本不包含归零或符号转换逻辑。
--********************************************************************--

REFRESH MATERIALIZED VIEW "dws"."mv_sales_gross_profit_recent_estimate";

SELECT
  settlement_month,
  source_type,
  COUNT(1) AS row_count,
  SUM(pref_rev) AS pref_rev,
  SUM(client_rebate) AS client_rebate,
  SUM(client_collection_rebate) AS client_collection_rebate,
  SUM(gross_profit_rebate) AS gross_profit_rebate,
  SUM(rebate) AS rebate,
  SUM(pref_rev_effective) AS pref_rev_effective,
  SUM(cost) AS cost,
  SUM(pref_gp) AS pref_gp,
  SUM(cashflow_rev_sale) AS cashflow_rev_sale,
  SUM(cashflow_rev_sale_effective) AS cashflow_rev_sale_effective,
  SUM(cashflow_gp_sale) AS cashflow_gp_sale
FROM "dws"."mv_sales_gross_profit_recent_estimate"
GROUP BY settlement_month, source_type
ORDER BY settlement_month, source_type;
