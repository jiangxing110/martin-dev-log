--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-12 20:17:49
-- Description:    销售佣金与合伙人毛利预估物化视图串行刷新函数
-- 作业元信息：
--   作业类型：ADBPG/PostgreSQL 函数
--   运行方式：由 Flink JDBC 刷新触发任务调用
--   运行参数：无
-- Notes:
--   1. 执行前需先创建销售刷新和合伙人刷新函数。
--   2. 函数按销售视图、合伙人视图的顺序调用两个既有刷新函数。
--   3. 本脚本只创建包装函数，不注册数据库内置定时任务。
--********************************************************************--

CREATE OR REPLACE FUNCTION "dws"."sp_refresh_mv_sales_and_partner_recent_estimate"()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM "dws"."sp_refresh_mv_sales_commission_recent_estimate"();
  PERFORM "dws"."sp_refresh_mv_partner_account_profit_recent_estimate"();
END;
$$;

ALTER FUNCTION "dws"."sp_refresh_mv_sales_and_partner_recent_estimate"()
  OWNER TO "flink_cdc_user";

COMMENT ON FUNCTION "dws"."sp_refresh_mv_sales_and_partner_recent_estimate"() IS
  '依次刷新销售佣金和合伙人毛利预估物化视图，供 Flink 单个 JDBC DML 调用';

-- 手动执行：
-- SELECT "dws"."sp_refresh_mv_sales_and_partner_recent_estimate"();
