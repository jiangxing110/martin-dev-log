--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-18 09:56:35
-- Description:    销售绩效实际收入近6个月物化视图刷新函数
-- 作业元信息：
--   作业类型：ADBPG刷新函数脚本
--   运行方式：由销售佣金/合伙人毛利 Flink JDBC 刷新包装函数调用
--   运行参数：无
-- Notes:
--   1. 本脚本只创建数据库函数，不注册数据库内置定时任务。
--   2. 使用 advisory lock 避免重复调度并发刷新同一个物化视图。
--   3. 本文件是 ADBPG/PostgreSQL 脚本，不能提交到 Flink SQL Gateway。
--********************************************************************--

CREATE OR REPLACE FUNCTION "dws"."sp_refresh_mv_sales_commission_performance_income_recent"()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_lock_key bigint := hashtext('dws.mv_sales_commission_performance_income_recent.refresh')::bigint;
    v_locked boolean;
BEGIN
    v_locked := pg_try_advisory_lock(v_lock_key);

    IF NOT v_locked THEN
        RAISE NOTICE 'dws.mv_sales_commission_performance_income_recent refresh is already running, skip this call.';
        RETURN;
    END IF;

    BEGIN
        REFRESH MATERIALIZED VIEW "dws"."mv_sales_commission_performance_income_recent";
    EXCEPTION WHEN OTHERS THEN
        PERFORM pg_advisory_unlock(v_lock_key);
        RAISE;
    END;

    PERFORM pg_advisory_unlock(v_lock_key);
END;
$$;

ALTER FUNCTION "dws"."sp_refresh_mv_sales_commission_performance_income_recent"()
  OWNER TO "flink_cdc_user";

COMMENT ON FUNCTION "dws"."sp_refresh_mv_sales_commission_performance_income_recent"() IS
  '刷新销售绩效实际收入近6个月普通物化视图，由销售佣金/合伙人毛利 Flink JDBC 刷新链路调用';

-- 手动执行：
-- SELECT "dws"."sp_refresh_mv_sales_commission_performance_income_recent"();
