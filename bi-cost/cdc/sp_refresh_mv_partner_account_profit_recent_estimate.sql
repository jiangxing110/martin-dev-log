--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-09-02
-- Description:    合伙人客户毛利物化视图刷新函数
-- Notes:
--   1. 调用前应先刷新 dws.mv_sales_commission_recent_estimate。
--   2. 使用 advisory lock 避免并发刷新。
--   3. 本函数不注册数据库定时任务，由外部调度调用。
--********************************************************************--

CREATE OR REPLACE FUNCTION "dws"."sp_refresh_mv_partner_account_profit_recent_estimate"()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_lock_key bigint := hashtext('dws.mv_partner_account_profit_recent_estimate.refresh')::bigint;
BEGIN
  IF NOT pg_try_advisory_lock(v_lock_key) THEN
    RAISE NOTICE 'partner account profit refresh is already running, skip this call.';
    RETURN;
  END IF;

  BEGIN
    REFRESH MATERIALIZED VIEW "dws"."mv_partner_account_profit_recent_estimate";
  EXCEPTION WHEN OTHERS THEN
    PERFORM pg_advisory_unlock(v_lock_key);
    RAISE;
  END;

  PERFORM pg_advisory_unlock(v_lock_key);
END;
$$;

ALTER FUNCTION "dws"."sp_refresh_mv_partner_account_profit_recent_estimate"()
  OWNER TO "flink_cdc_user";

COMMENT ON FUNCTION "dws"."sp_refresh_mv_partner_account_profit_recent_estimate"() IS
  '刷新合伙人客户毛利近6个月物化视图，调用前先刷新销售返佣基础物化视图';
