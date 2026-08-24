--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-06 01:03:20
-- Updated Time:   2026-08-23 21:50:00
-- Description:    注册 QI quantum-v2 CDC v2 删除函数
-- 作业元信息：
--   作业类型：ADBPG 函数注册
--   运行方式：在目标 ADBPG 数据库执行一次；VVR SQL v2 作业通过 JDBC 调用对应函数
--   运行范围：2026-01-01 <= report_date < CURRENT_DATE
-- Notes:
--   1. 函数返回受影响行数。
--   2. p_dry_run = true 时只统计不删除。
--   3. 主财务删除函数保留 CHANNEL_FIXED_FEE，固定成本函数单独清理该特殊行。
--********************************************************************--

CREATE OR REPLACE FUNCTION dws.fn_delete_qi_card_finance_daily_v2_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE plpgsql
AS $function$
DECLARE
    affected_rows BIGINT;
    rebuild_start DATE := DATE '2026-01-01';
    rebuild_end DATE := CURRENT_DATE;
BEGIN
    IF p_dry_run THEN
        SELECT COUNT(*) INTO affected_rows
        FROM dws.dws_qi_card_finance_daily_v2_p AS target
        WHERE (target.special_fee_type IS NULL OR target.special_fee_type <> 'CHANNEL_FIXED_FEE')
          AND target.report_date >= rebuild_start
          AND target.report_date < rebuild_end;
        RETURN affected_rows;
    END IF;

    DELETE FROM dws.dws_qi_card_finance_daily_v2_p AS target
    WHERE (target.special_fee_type IS NULL OR target.special_fee_type <> 'CHANNEL_FIXED_FEE')
      AND target.report_date >= rebuild_start
      AND target.report_date < rebuild_end;

    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    RETURN affected_rows;
END;
$function$;

CREATE OR REPLACE FUNCTION dws.fn_delete_qi_channel_fixed_fee_v2_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE plpgsql
AS $function$
DECLARE
    affected_rows BIGINT;
    rebuild_start DATE := DATE '2026-01-01';
    rebuild_end DATE := CURRENT_DATE;
BEGIN
    IF p_dry_run THEN
        SELECT COUNT(*) INTO affected_rows
        FROM dws.dws_qi_card_finance_daily_v2_p AS target
        WHERE target.special_fee_type = 'CHANNEL_FIXED_FEE'
          AND target.report_date >= rebuild_start
          AND target.report_date < rebuild_end;
        RETURN affected_rows;
    END IF;

    DELETE FROM dws.dws_qi_card_finance_daily_v2_p AS target
    WHERE target.special_fee_type = 'CHANNEL_FIXED_FEE'
      AND target.report_date >= rebuild_start
      AND target.report_date < rebuild_end;

    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    RETURN affected_rows;
END;
$function$;

SELECT
    dws.fn_delete_qi_card_finance_daily_v2_cdc(true) AS qi_card_finance_daily_matched_rows,
    dws.fn_delete_qi_channel_fixed_fee_v2_cdc(true) AS qi_channel_fixed_fee_matched_rows;
