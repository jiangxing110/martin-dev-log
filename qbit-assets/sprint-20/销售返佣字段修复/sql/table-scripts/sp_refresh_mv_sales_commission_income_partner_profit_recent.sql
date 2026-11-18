--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-18
-- Description:    销售佣金、绩效收入及合伙人利润物化视图串行刷新包装函数
-- 作业元信息：
--   作业类型：ADBPG/PostgreSQL 函数
--   运行方式：由现有 Flink JDBC 刷新触发任务调用
--   运行参数：无
-- Notes:
--   1. 执行前需先创建销售佣金、绩效收入和合伙人利润各自的刷新函数。
--   2. 函数名不超过 PostgreSQL 63-byte identifier limit。
--   3. 本脚本不注册数据库内置定时任务。
--********************************************************************--

CREATE OR REPLACE FUNCTION "dws"."sp_refresh_mv_sales_commission_income_partner_profit_recent"()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM "dws"."sp_refresh_mv_sales_commission_recent_estimate"();
  PERFORM "dws"."sp_refresh_mv_sales_commission_performance_income_recent"();
  PERFORM "dws"."sp_refresh_mv_partner_account_profit_recent_estimate"();
END;
$$;

ALTER FUNCTION "dws"."sp_refresh_mv_sales_commission_income_partner_profit_recent"()
  OWNER TO "flink_cdc_user";

COMMENT ON FUNCTION "dws"."sp_refresh_mv_sales_commission_income_partner_profit_recent"() IS
  '依次刷新销售佣金、销售绩效实际收入及合伙人利润预估物化视图，供 Flink 单个 JDBC DML 调用';

-- 手动执行：
-- SELECT "dws"."sp_refresh_mv_sales_commission_income_partner_profit_recent"();
