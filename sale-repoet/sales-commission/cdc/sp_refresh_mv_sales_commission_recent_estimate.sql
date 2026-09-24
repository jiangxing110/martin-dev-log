--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-13 00:00:00
-- Description:    销售佣金8号前预估物化视图刷新函数
-- 作业元信息：
--   作业类型：ADBPG刷新函数脚本
--   运行方式：由外部调度周期调用
--   运行参数：无
-- Notes:
--   1. 保留 dws.mv_sales_commission_recent_estimate 普通物化视图。
--   2. 本脚本不注册数据库内置定时任务。
--   3. 外部调度执行 SELECT "dws"."sp_refresh_mv_sales_commission_recent_estimate"(); 即可刷新。
--   4. 使用 advisory lock 避免重复调度并发刷新同一个物化视图。
--   5. 本脚本是 ADBPG/PostgreSQL 脚本，不能提交到 Flink SQL Gateway。
--********************************************************************--

CREATE OR REPLACE FUNCTION "dws"."sp_refresh_mv_sales_commission_recent_estimate"()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_lock_key bigint := hashtext('dws.mv_sales_commission_recent_estimate.refresh')::bigint;
    v_locked boolean;
BEGIN
    v_locked := pg_try_advisory_lock(v_lock_key);

    IF NOT v_locked THEN
        RAISE NOTICE 'dws.mv_sales_commission_recent_estimate refresh is already running, skip this call.';
        RETURN;
    END IF;

    BEGIN
        REFRESH MATERIALIZED VIEW "dws"."mv_sales_commission_recent_estimate";
    EXCEPTION WHEN OTHERS THEN
        PERFORM pg_advisory_unlock(v_lock_key);
        RAISE;
    END;

    PERFORM pg_advisory_unlock(v_lock_key);
END;
$$;

ALTER FUNCTION "dws"."sp_refresh_mv_sales_commission_recent_estimate"()
  OWNER TO "flink_cdc_user";

COMMENT ON FUNCTION "dws"."sp_refresh_mv_sales_commission_recent_estimate"() IS
  '刷新销售佣金8号前预估普通物化视图，由外部调度周期调用，不注册数据库内置定时任务';

-- 手动执行：
-- SELECT "dws"."sp_refresh_mv_sales_commission_recent_estimate"();
