--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-06 01:03:20
-- Updated Time:   2026-08-23 21:31:00
-- Description:    注册 BB quantum-v2 CDC v2 删除函数
-- 作业元信息：
--   作业类型：ADBPG 函数注册
--   运行方式：在目标 ADBPG 数据库执行一次；VVR SQL v2 作业通过 JDBC 调用对应函数
--   运行参数：无
-- Notes:
--   1. 函数返回受影响行数。
--   2. 当前 CDC 重建范围为 2026-01-01 至 CURRENT_DATE（不包含当天）：
--      p_dry_run=true 只计数；false 删除该范围内的普通行（保留 active/fixed 特殊行）。
--      由 DWS CDC 作业在全量重算前调用，保证"先删后算"幂等。
--********************************************************************--

CREATE OR REPLACE FUNCTION dws.fn_delete_bb_card_finance_daily_v2_cdc(p_dry_run BOOLEAN DEFAULT true)
RETURNS BIGINT
LANGUAGE plpgsql
AS $function$
DECLARE
    affected_rows BIGINT;
    rebuild_start DATE := DATE '2026-01-01';
    rebuild_end DATE := CURRENT_DATE;
BEGIN
    IF p_dry_run THEN
        SELECT COUNT(*)
        INTO affected_rows
        FROM dws.dws_bb_card_finance_daily_v2_p AS target
        WHERE (target.special_fee_type IS NULL
               OR target.special_fee_type NOT IN ('ACTIVE_CARD_ACCOUNT_FEE', 'CHANNEL_FIXED_FEE'))
          AND target.report_date >= rebuild_start
          AND target.report_date < rebuild_end;

        RETURN affected_rows;
    END IF;

    DELETE FROM dws.dws_bb_card_finance_daily_v2_p AS target
    WHERE (target.special_fee_type IS NULL
           OR target.special_fee_type NOT IN ('ACTIVE_CARD_ACCOUNT_FEE', 'CHANNEL_FIXED_FEE'))
      AND target.report_date >= rebuild_start
      AND target.report_date < rebuild_end;

    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    RETURN affected_rows;
END;
$function$;

-- 月度 CDC 使用此重载函数，只删除本次月份范围内的普通行。
CREATE OR REPLACE FUNCTION dws.fn_delete_bb_card_finance_daily_v2_cdc(
    p_start_date DATE,
    p_end_date DATE,
    p_dry_run BOOLEAN DEFAULT false
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $function$
DECLARE
    affected_rows BIGINT;
BEGIN
    IF p_dry_run THEN
        SELECT COUNT(*) INTO affected_rows
        FROM dws.dws_bb_card_finance_daily_v2_p AS target
        WHERE (target.special_fee_type IS NULL
               OR target.special_fee_type NOT IN ('ACTIVE_CARD_ACCOUNT_FEE', 'CHANNEL_FIXED_FEE'))
          AND target.report_date >= p_start_date
          AND target.report_date < p_end_date;
        RETURN affected_rows;
    END IF;

    DELETE FROM dws.dws_bb_card_finance_daily_v2_p AS target
    WHERE (target.special_fee_type IS NULL
           OR target.special_fee_type NOT IN ('ACTIVE_CARD_ACCOUNT_FEE', 'CHANNEL_FIXED_FEE'))
      AND target.report_date >= p_start_date
      AND target.report_date < p_end_date;

    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    RETURN affected_rows;
END;
$function$;

CREATE OR REPLACE FUNCTION dws.fn_delete_bb_active_card_count_v2_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE plpgsql
AS $function$
DECLARE
    affected_rows BIGINT;
    rebuild_start DATE := DATE '2026-01-01';
    rebuild_end DATE := CURRENT_DATE;
BEGIN
    IF p_dry_run THEN
        SELECT COUNT(*)
        INTO affected_rows
        FROM dws.dws_bb_card_finance_daily_v2_p AS target
        WHERE target.special_fee_type = 'ACTIVE_CARD_ACCOUNT_FEE'
          AND target.report_date >= rebuild_start
          AND target.report_date < rebuild_end;

        RETURN affected_rows;
    END IF;

    DELETE FROM dws.dws_bb_card_finance_daily_v2_p AS target
    WHERE target.special_fee_type = 'ACTIVE_CARD_ACCOUNT_FEE'
      AND target.report_date >= rebuild_start
      AND target.report_date < rebuild_end;

    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    RETURN affected_rows;
END;
$function$;

CREATE OR REPLACE FUNCTION dws.fn_delete_bb_active_card_count_v2_cdc(
    p_start_date DATE,
    p_end_date DATE,
    p_dry_run BOOLEAN DEFAULT false
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $function$
DECLARE
    affected_rows BIGINT;
BEGIN
    IF p_dry_run THEN
        SELECT COUNT(*) INTO affected_rows
        FROM dws.dws_bb_card_finance_daily_v2_p AS target
        WHERE target.special_fee_type = 'ACTIVE_CARD_ACCOUNT_FEE'
          AND target.report_date >= p_start_date
          AND target.report_date < p_end_date;
        RETURN affected_rows;
    END IF;

    DELETE FROM dws.dws_bb_card_finance_daily_v2_p AS target
    WHERE target.special_fee_type = 'ACTIVE_CARD_ACCOUNT_FEE'
      AND target.report_date >= p_start_date
      AND target.report_date < p_end_date;

    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    RETURN affected_rows;
END;
$function$;

CREATE OR REPLACE FUNCTION dws.fn_delete_bb_channel_fixed_fee_v2_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE plpgsql
AS $function$
DECLARE
    affected_rows BIGINT;
    rebuild_start DATE := DATE '2026-01-01';
    rebuild_end DATE := CURRENT_DATE;
BEGIN
    IF p_dry_run THEN
        SELECT COUNT(*)
        INTO affected_rows
        FROM dws.dws_bb_card_finance_daily_v2_p AS target
        WHERE target.special_fee_type = 'CHANNEL_FIXED_FEE'
          AND target.report_date >= rebuild_start
          AND target.report_date < rebuild_end;

        RETURN affected_rows;
    END IF;

    DELETE FROM dws.dws_bb_card_finance_daily_v2_p AS target
    WHERE target.special_fee_type = 'CHANNEL_FIXED_FEE'
      AND target.report_date >= rebuild_start
      AND target.report_date < rebuild_end;

    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    RETURN affected_rows;
END;
$function$;

CREATE OR REPLACE FUNCTION dws.fn_delete_bb_channel_fixed_fee_v2_cdc(
    p_start_date DATE,
    p_end_date DATE,
    p_dry_run BOOLEAN DEFAULT false
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $function$
DECLARE
    affected_rows BIGINT;
BEGIN
    IF p_dry_run THEN
        SELECT COUNT(*) INTO affected_rows
        FROM dws.dws_bb_card_finance_daily_v2_p AS target
        WHERE target.special_fee_type = 'CHANNEL_FIXED_FEE'
          AND target.report_date >= p_start_date
          AND target.report_date < p_end_date;
        RETURN affected_rows;
    END IF;

    DELETE FROM dws.dws_bb_card_finance_daily_v2_p AS target
    WHERE target.special_fee_type = 'CHANNEL_FIXED_FEE'
      AND target.report_date >= p_start_date
      AND target.report_date < p_end_date;

    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    RETURN affected_rows;
END;
$function$;

SELECT
    dws.fn_delete_bb_card_finance_daily_v2_cdc(true) AS bb_card_finance_daily_matched_rows,
    dws.fn_delete_bb_active_card_count_v2_cdc(true) AS bb_active_card_count_matched_rows,
    dws.fn_delete_bb_channel_fixed_fee_v2_cdc(true) AS bb_channel_fixed_fee_matched_rows;
