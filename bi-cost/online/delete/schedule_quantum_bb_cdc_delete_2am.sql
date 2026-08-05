--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-05 14:47:12
-- Updated Time:   2026-08-05 23:57:15
-- Description:    注册 BB 量子卡 CDC 每日 PostgreSQL 删除任务
-- Schedule:       每天北京时间 02:00
-- Notes:
--   1. 在目标 ADBPG 数据库执行一次本脚本完成注册。
--   2. 删除逻辑对应 quantum-v2/bb/cdc 下的三个 delete-sql 作业。
--   3. 删除成功后再运行对应 BB CDC INSERT 作业。
--   4. 如果需要在 VVR 保留 Flink 作业执行记录，使用 flink/jobs/delete-table-data JAR，
--      并为渠道固定成本清理传入 --delete-type bb-channel-fixed-fee-cdc。
--********************************************************************--

CREATE OR REPLACE FUNCTION dws.fn_quantum_bb_cdc_delete()
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN
    -- 普通汇总：按前一天发生变化的交易、结算和授权月份清理。
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

    -- 渠道固定成本：按前一天更新的 BB CHANNEL_COST 配置月份清理。
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

    -- Active Card：始终清理本月，并补充前一天发生变化的授权月份。
    WITH changed_months AS (
        SELECT DATE_TRUNC('month', CURRENT_DATE)::date AS report_month

        UNION

        SELECT DISTINCT DATE_TRUNC('month', COALESCE(auth_time, update_time))::date
        FROM dwm.dwm_bb_card_auth_detail_v2_p
        WHERE ((update_time >= CURRENT_DATE - INTERVAL '1 day' AND update_time < CURRENT_DATE)
            OR (delete_time >= CURRENT_DATE - INTERVAL '1 day' AND delete_time < CURRENT_DATE))
          AND COALESCE(auth_time, update_time) IS NOT NULL
    )
    DELETE FROM dws.dws_bb_card_finance_daily_v2_p AS target
    WHERE target.special_fee_type = 'ACTIVE_CARD_ACCOUNT_FEE'
      AND EXISTS (
          SELECT 1
          FROM changed_months month_scope
          WHERE target.report_date >= month_scope.report_month
            AND target.report_date < month_scope.report_month + INTERVAL '1 month'
      );
END;
$function$;

DO $register$
DECLARE
    cron_timezone text := COALESCE(current_setting('cron.timezone', true), 'GMT');
    cron_expression text;
    existing_job_id bigint;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        RAISE EXCEPTION 'pg_cron extension is not installed';
    END IF;

    IF LOWER(cron_timezone) IN ('asia/shanghai', 'prc') THEN
        cron_expression := '0 2 * * *';
    ELSIF LOWER(cron_timezone) IN ('gmt', 'utc', 'etc/utc') THEN
        cron_expression := '0 18 * * *';
    ELSE
        RAISE EXCEPTION 'Unsupported cron.timezone: %. Expected Asia/Shanghai, PRC, GMT or UTC', cron_timezone;
    END IF;

    FOR existing_job_id IN
        SELECT jobid FROM cron.job WHERE jobname = 'quantum_bb_cdc_delete_2am'
    LOOP
        PERFORM cron.unschedule(existing_job_id);
    END LOOP;

    PERFORM cron.schedule(
        'quantum_bb_cdc_delete_2am',
        cron_expression,
        'SELECT dws.fn_quantum_bb_cdc_delete()'
    );
END;
$register$;

SELECT
    jobid,
    jobname,
    schedule,
    command,
    database,
    username,
    active,
    COALESCE(current_setting('cron.timezone', true), 'GMT') AS cron_timezone
FROM cron.job
WHERE jobname = 'quantum_bb_cdc_delete_2am';
