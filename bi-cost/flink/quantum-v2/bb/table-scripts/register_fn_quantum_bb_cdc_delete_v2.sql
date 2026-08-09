--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-06 01:03:20
-- Description:    注册 BB quantum-v2 CDC v2 删除函数
-- 作业元信息：
--   作业类型：ADBPG 函数注册
--   运行方式：在目标 ADBPG 数据库执行一次；VVR SQL v2 作业通过 JDBC 调用对应函数
--   运行参数：无
-- Notes:
--   1. 函数返回受影响行数。
--   2. p_dry_run = true 时只统计不删除。
--********************************************************************--

CREATE OR REPLACE FUNCTION dws.fn_delete_bb_card_finance_daily_v2_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE plpgsql
AS $function$
DECLARE
    affected_rows BIGINT;
BEGIN
    IF p_dry_run THEN
        WITH changed_months AS (
            SELECT DISTINCT DATE_TRUNC('month', event_time)::date AS report_month
            FROM (
                SELECT transaction_time AS event_time
                FROM dwm.dwm_bb_card_transaction_detail_v2_p
                WHERE (update_time >= CURRENT_DATE - INTERVAL '1 day' AND update_time < CURRENT_DATE)
                   OR (delete_time >= CURRENT_DATE - INTERVAL '1 day' AND delete_time < CURRENT_DATE)

                UNION ALL

                SELECT original_completion_time
                FROM dwm.dwm_bb_card_transaction_detail_v2_p
                WHERE (update_time >= CURRENT_DATE - INTERVAL '1 day' AND update_time < CURRENT_DATE)
                   OR (delete_time >= CURRENT_DATE - INTERVAL '1 day' AND delete_time < CURRENT_DATE)

                UNION ALL

                SELECT settlement_post_date
                FROM dwm.dwm_bb_card_transaction_detail_v2_p
                WHERE (update_time >= CURRENT_DATE - INTERVAL '1 day' AND update_time < CURRENT_DATE)
                   OR (delete_time >= CURRENT_DATE - INTERVAL '1 day' AND delete_time < CURRENT_DATE)

                UNION ALL

                SELECT auth_time
                FROM dwm.dwm_bb_card_auth_detail_v2_p
                WHERE (update_time >= CURRENT_DATE - INTERVAL '1 day' AND update_time < CURRENT_DATE)
                   OR (delete_time >= CURRENT_DATE - INTERVAL '1 day' AND delete_time < CURRENT_DATE)
            ) changed
            WHERE event_time IS NOT NULL
        )
        SELECT COUNT(*)
        INTO affected_rows
        FROM dws.dws_bb_card_finance_daily_v2_p AS target
        WHERE (target.special_fee_type IS NULL
               OR target.special_fee_type NOT IN ('ACTIVE_CARD_ACCOUNT_FEE', 'CHANNEL_FIXED_FEE'))
          AND EXISTS (
              SELECT 1
              FROM changed_months month_scope
              WHERE target.report_date >= month_scope.report_month
                AND target.report_date < month_scope.report_month + INTERVAL '1 month'
          );

        RETURN affected_rows;
    END IF;

    WITH changed_months AS (
        SELECT DISTINCT DATE_TRUNC('month', event_time)::date AS report_month
        FROM (
            SELECT transaction_time AS event_time
            FROM dwm.dwm_bb_card_transaction_detail_v2_p
            WHERE (update_time >= CURRENT_DATE - INTERVAL '1 day' AND update_time < CURRENT_DATE)
               OR (delete_time >= CURRENT_DATE - INTERVAL '1 day' AND delete_time < CURRENT_DATE)

            UNION ALL

            SELECT original_completion_time
            FROM dwm.dwm_bb_card_transaction_detail_v2_p
            WHERE (update_time >= CURRENT_DATE - INTERVAL '1 day' AND update_time < CURRENT_DATE)
               OR (delete_time >= CURRENT_DATE - INTERVAL '1 day' AND delete_time < CURRENT_DATE)

            UNION ALL

            SELECT settlement_post_date
            FROM dwm.dwm_bb_card_transaction_detail_v2_p
            WHERE (update_time >= CURRENT_DATE - INTERVAL '1 day' AND update_time < CURRENT_DATE)
               OR (delete_time >= CURRENT_DATE - INTERVAL '1 day' AND delete_time < CURRENT_DATE)

            UNION ALL

            SELECT auth_time
            FROM dwm.dwm_bb_card_auth_detail_v2_p
            WHERE (update_time >= CURRENT_DATE - INTERVAL '1 day' AND update_time < CURRENT_DATE)
               OR (delete_time >= CURRENT_DATE - INTERVAL '1 day' AND delete_time < CURRENT_DATE)
        ) changed
        WHERE event_time IS NOT NULL
    )
    DELETE FROM dws.dws_bb_card_finance_daily_v2_p AS target
    WHERE (target.special_fee_type IS NULL
           OR target.special_fee_type NOT IN ('ACTIVE_CARD_ACCOUNT_FEE', 'CHANNEL_FIXED_FEE'))
      AND EXISTS (
          SELECT 1
          FROM changed_months month_scope
          WHERE target.report_date >= month_scope.report_month
            AND target.report_date < month_scope.report_month + INTERVAL '1 month'
      );

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
    month_start DATE := DATE_TRUNC('month', CURRENT_DATE)::date;
    month_end DATE := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month')::date;
BEGIN
    IF p_dry_run THEN
        SELECT COUNT(*)
        INTO affected_rows
        FROM dws.dws_bb_card_finance_daily_v2_p AS target
        WHERE target.special_fee_type = 'ACTIVE_CARD_ACCOUNT_FEE'
          AND target.report_date >= month_start
          AND target.report_date < month_end;

        RETURN affected_rows;
    END IF;

    DELETE FROM dws.dws_bb_card_finance_daily_v2_p AS target
    WHERE target.special_fee_type = 'ACTIVE_CARD_ACCOUNT_FEE'
      AND target.report_date >= month_start
      AND target.report_date < month_end;

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
BEGIN
    IF p_dry_run THEN
        WITH changed_months AS (
            SELECT DISTINCT DATE_TRUNC('month', statistics_time)::date AS report_month
            FROM ods.ods_bi_month_tag
            WHERE delete_time IS NULL
              AND tag = 'CHANNEL_COST'
              AND provider = 'BB'
              AND update_time >= CURRENT_DATE - INTERVAL '1 day'
              AND update_time < CURRENT_DATE
              AND statistics_time IS NOT NULL
        )
        SELECT COUNT(*)
        INTO affected_rows
        FROM dws.dws_bb_card_finance_daily_v2_p AS target
        WHERE target.special_fee_type = 'CHANNEL_FIXED_FEE'
          AND EXISTS (
              SELECT 1
              FROM changed_months month_scope
              WHERE target.report_date >= month_scope.report_month
                AND target.report_date < month_scope.report_month + INTERVAL '1 month'
          );

        RETURN affected_rows;
    END IF;

    WITH changed_months AS (
        SELECT DISTINCT DATE_TRUNC('month', statistics_time)::date AS report_month
        FROM ods.ods_bi_month_tag
        WHERE delete_time IS NULL
          AND tag = 'CHANNEL_COST'
          AND provider = 'BB'
          AND update_time >= CURRENT_DATE - INTERVAL '1 day'
          AND update_time < CURRENT_DATE
          AND statistics_time IS NOT NULL
    )
    DELETE FROM dws.dws_bb_card_finance_daily_v2_p AS target
    WHERE target.special_fee_type = 'CHANNEL_FIXED_FEE'
      AND EXISTS (
          SELECT 1
          FROM changed_months month_scope
          WHERE target.report_date >= month_scope.report_month
            AND target.report_date < month_scope.report_month + INTERVAL '1 month'
      );

    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    RETURN affected_rows;
END;
$function$;

SELECT
    dws.fn_delete_bb_card_finance_daily_v2_cdc(true) AS bb_card_finance_daily_matched_rows,
    dws.fn_delete_bb_active_card_count_v2_cdc(true) AS bb_active_card_count_matched_rows,
    dws.fn_delete_bb_channel_fixed_fee_v2_cdc(true) AS bb_channel_fixed_fee_matched_rows;
