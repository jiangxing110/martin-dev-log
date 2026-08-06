--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-06 01:20:00
-- Description:    注册 SL quantum-v2 monthly-cdc v2 删除函数
-- 作业元信息：
--   作业类型：ADBPG 函数注册
--   运行方式：在目标 ADBPG 数据库执行一次；VVR SQL v2 作业通过 JDBC 调用对应函数
--   运行参数：无
-- Notes:
--   1. 函数返回受影响行数。
--   2. p_dry_run = true 时只统计不删除。
--   3. monthly-cdc 删除范围固定为上月月初到本月月初。
--********************************************************************--

CREATE OR REPLACE FUNCTION dws.fn_delete_sl_card_finance_daily_v2_monthly_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE plpgsql
AS $function$
DECLARE
    affected_rows BIGINT;
    month_start DATE := DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')::date;
    month_end DATE := DATE_TRUNC('month', CURRENT_DATE)::date;
BEGIN
    IF p_dry_run THEN
        SELECT COUNT(*)
        INTO affected_rows
        FROM dws.dws_sl_card_finance_daily_p AS target
        WHERE (target.special_fee_type IS NULL OR target.special_fee_type <> 'CHANNEL_FIXED_FEE')
          AND target.report_date >= month_start
          AND target.report_date < month_end;

        RETURN affected_rows;
    END IF;

    DELETE FROM dws.dws_sl_card_finance_daily_p AS target
    WHERE (target.special_fee_type IS NULL OR target.special_fee_type <> 'CHANNEL_FIXED_FEE')
      AND target.report_date >= month_start
      AND target.report_date < month_end;

    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    RETURN affected_rows;
END;
$function$;

CREATE OR REPLACE FUNCTION dws.fn_delete_sl_channel_fixed_fee_v2_monthly_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE plpgsql
AS $function$
DECLARE
    affected_rows BIGINT;
    month_start DATE := DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')::date;
    month_end DATE := DATE_TRUNC('month', CURRENT_DATE)::date;
BEGIN
    IF p_dry_run THEN
        SELECT COUNT(*)
        INTO affected_rows
        FROM dws.dws_sl_card_finance_daily_p AS target
        WHERE target.special_fee_type = 'CHANNEL_FIXED_FEE'
          AND target.report_date >= month_start
          AND target.report_date < month_end;

        RETURN affected_rows;
    END IF;

    DELETE FROM dws.dws_sl_card_finance_daily_p AS target
    WHERE target.special_fee_type = 'CHANNEL_FIXED_FEE'
      AND target.report_date >= month_start
      AND target.report_date < month_end;

    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    RETURN affected_rows;
END;
$function$;

SELECT
    dws.fn_delete_sl_card_finance_daily_v2_monthly_cdc(true) AS sl_card_finance_daily_matched_rows,
    dws.fn_delete_sl_channel_fixed_fee_v2_monthly_cdc(true) AS sl_channel_fixed_fee_matched_rows;
