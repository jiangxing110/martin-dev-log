--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-06 01:03:20
-- Description:    注册 QI quantum-v2 CDC v2 删除函数
-- 作业元信息：
--   作业类型：ADBPG 函数注册
--   运行方式：在目标 ADBPG 数据库执行一次；VVR SQL v2 作业通过 JDBC 调用对应函数
--   运行参数：无
-- Notes:
--   1. 函数返回受影响行数。
--   2. p_dry_run = true 时只统计不删除。
--********************************************************************--

CREATE OR REPLACE FUNCTION dws.fn_delete_qi_card_finance_daily_v2_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE plpgsql
AS $function$
DECLARE
    affected_rows BIGINT;
BEGIN
    IF p_dry_run THEN
        WITH fact_changed_keys AS (
            SELECT DISTINCT transaction_time::date AS report_date, account_id
            FROM dwm.dwm_qi_card_transaction_detail_v2_p
            WHERE transaction_time IS NOT NULL
              AND account_id IS NOT NULL
              AND ((source_update_time >= CURRENT_DATE - INTERVAL '1 day' AND source_update_time < CURRENT_DATE)
                OR (source_delete_time >= CURRENT_DATE - INTERVAL '1 day' AND source_delete_time < CURRENT_DATE)
                OR (update_time >= CURRENT_DATE - INTERVAL '1 day' AND update_time < CURRENT_DATE)
                OR (delete_time >= CURRENT_DATE - INTERVAL '1 day' AND delete_time < CURRENT_DATE))
        ),
        config_changed_months AS (
            SELECT DISTINCT DATE_TRUNC('month', statistics_time)::date AS report_month
            FROM ods.ods_bi_month_tag
            WHERE delete_time IS NULL
              AND provider = 'IQ'
              AND tag IN (
                  'QI_COST_REIMBURSEMENT_RATE',
                  'QI_COST_SERVICE_RATE',
                  'QI_COST_ACS_REGULAR_RATE',
                  'QI_COST_ACS_VIP_RATE',
                  'QI_COST_VRM_RATE',
                  'QI_COST_HK_REGULAR_RATE',
                  'QI_COST_HK_VIP_RATE',
                  'QI_COST_DCSF_RATE',
                  'QI_REBATE_INTERCHANGE_RATE',
                  'QI_REBATE_INCENTIVE_RATE'
              )
              AND update_time >= CURRENT_DATE - INTERVAL '1 day'
              AND update_time < CURRENT_DATE
              AND statistics_time IS NOT NULL
        ),
        config_changed_keys AS (
            SELECT DISTINCT s.transaction_time::date AS report_date, s.account_id
            FROM dwm.dwm_qi_card_transaction_detail_v2_p s
            JOIN config_changed_months m
              ON s.transaction_time >= m.report_month
             AND s.transaction_time < m.report_month + INTERVAL '1 month'
            WHERE s.delete_time IS NULL
              AND s.transaction_time IS NOT NULL
              AND s.account_id IS NOT NULL
        ),
        changed_keys AS (
            SELECT report_date, account_id FROM fact_changed_keys
            UNION
            SELECT report_date, account_id FROM config_changed_keys
        )
        SELECT COUNT(*)
        INTO affected_rows
        FROM dws.dws_qi_card_finance_daily_v2_p AS target
        WHERE (target.special_fee_type IS NULL OR target.special_fee_type <> 'CHANNEL_FIXED_FEE')
          AND EXISTS (
              SELECT 1
              FROM changed_keys scope
              WHERE target.report_date = scope.report_date
                AND target.account_id = scope.account_id
          );

        RETURN affected_rows;
    END IF;

    WITH fact_changed_keys AS (
        SELECT DISTINCT transaction_time::date AS report_date, account_id
        FROM dwm.dwm_qi_card_transaction_detail_v2_p
        WHERE transaction_time IS NOT NULL
          AND account_id IS NOT NULL
          AND ((source_update_time >= CURRENT_DATE - INTERVAL '1 day' AND source_update_time < CURRENT_DATE)
            OR (source_delete_time >= CURRENT_DATE - INTERVAL '1 day' AND source_delete_time < CURRENT_DATE)
            OR (update_time >= CURRENT_DATE - INTERVAL '1 day' AND update_time < CURRENT_DATE)
            OR (delete_time >= CURRENT_DATE - INTERVAL '1 day' AND delete_time < CURRENT_DATE))
    ),
    config_changed_months AS (
        SELECT DISTINCT DATE_TRUNC('month', statistics_time)::date AS report_month
        FROM ods.ods_bi_month_tag
        WHERE delete_time IS NULL
          AND provider = 'IQ'
          AND tag IN (
              'QI_COST_REIMBURSEMENT_RATE',
              'QI_COST_SERVICE_RATE',
              'QI_COST_ACS_REGULAR_RATE',
              'QI_COST_ACS_VIP_RATE',
              'QI_COST_VRM_RATE',
              'QI_COST_HK_REGULAR_RATE',
              'QI_COST_HK_VIP_RATE',
              'QI_COST_DCSF_RATE',
              'QI_REBATE_INTERCHANGE_RATE',
              'QI_REBATE_INCENTIVE_RATE'
          )
          AND update_time >= CURRENT_DATE - INTERVAL '1 day'
          AND update_time < CURRENT_DATE
          AND statistics_time IS NOT NULL
    ),
    config_changed_keys AS (
        SELECT DISTINCT s.transaction_time::date AS report_date, s.account_id
        FROM dwm.dwm_qi_card_transaction_detail_v2_p s
        JOIN config_changed_months m
          ON s.transaction_time >= m.report_month
         AND s.transaction_time < m.report_month + INTERVAL '1 month'
        WHERE s.delete_time IS NULL
          AND s.transaction_time IS NOT NULL
          AND s.account_id IS NOT NULL
    ),
    changed_keys AS (
        SELECT report_date, account_id FROM fact_changed_keys
        UNION
        SELECT report_date, account_id FROM config_changed_keys
    )
    DELETE FROM dws.dws_qi_card_finance_daily_v2_p AS target
    WHERE (target.special_fee_type IS NULL OR target.special_fee_type <> 'CHANNEL_FIXED_FEE')
      AND EXISTS (
          SELECT 1
          FROM changed_keys scope
          WHERE target.report_date = scope.report_date
            AND target.account_id = scope.account_id
      );

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
BEGIN
    IF p_dry_run THEN
        WITH changed_months AS (
            SELECT DISTINCT DATE_TRUNC('month', statistics_time)::date AS report_month
            FROM ods.ods_bi_month_tag
            WHERE delete_time IS NULL
              AND tag = 'CHANNEL_COST'
              AND provider = 'IQ'
              AND update_time >= CURRENT_DATE - INTERVAL '1 day'
              AND update_time < CURRENT_DATE
              AND statistics_time IS NOT NULL
        )
        SELECT COUNT(*)
        INTO affected_rows
        FROM dws.dws_qi_card_finance_daily_v2_p AS target
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
          AND provider = 'IQ'
          AND update_time >= CURRENT_DATE - INTERVAL '1 day'
          AND update_time < CURRENT_DATE
          AND statistics_time IS NOT NULL
    )
    DELETE FROM dws.dws_qi_card_finance_daily_v2_p AS target
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
    dws.fn_delete_qi_card_finance_daily_v2_cdc(true) AS qi_card_finance_daily_matched_rows,
    dws.fn_delete_qi_channel_fixed_fee_v2_cdc(true) AS qi_channel_fixed_fee_matched_rows;
