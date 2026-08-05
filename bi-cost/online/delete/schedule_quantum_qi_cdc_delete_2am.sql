--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-05 14:47:12
-- Description:    注册 QI 量子卡 CDC 每日 PostgreSQL 删除任务
-- Schedule:       每天北京时间 02:00
-- Notes:
--   1. 在目标 ADBPG 数据库执行一次本脚本完成注册。
--   2. 删除逻辑对应 quantum-v2/qi/cdc 下的两个 delete-sql 作业。
--   3. 删除成功后再运行对应 QI CDC INSERT 作业。
--********************************************************************--

CREATE OR REPLACE FUNCTION dws.fn_quantum_qi_cdc_delete()
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN
    -- 普通汇总：合并前一天事实数据和 QI 配置发生变化的月份。
    WITH changed_months AS (
        SELECT DISTINCT DATE_TRUNC('month', transaction_time)::date AS report_month
        FROM dwm.dwm_qi_card_transaction_detail_v2_p
        WHERE (
                (source_update_time >= CURRENT_DATE - INTERVAL '1 day' AND source_update_time < CURRENT_DATE)
             OR (source_delete_time >= CURRENT_DATE - INTERVAL '1 day' AND source_delete_time < CURRENT_DATE)
             OR (update_time >= CURRENT_DATE - INTERVAL '1 day' AND update_time < CURRENT_DATE)
             OR (delete_time >= CURRENT_DATE - INTERVAL '1 day' AND delete_time < CURRENT_DATE)
        )
          AND transaction_time IS NOT NULL

        UNION

        SELECT DISTINCT DATE_TRUNC('month', statistics_time)::date
        FROM ods.ods_bi_month_tag
        WHERE delete_time IS NULL
          AND provider = 'IQ'
          AND update_time >= CURRENT_DATE - INTERVAL '1 day'
          AND update_time < CURRENT_DATE
          AND statistics_time IS NOT NULL
    )
    DELETE FROM dws.dws_qi_card_finance_daily_v2_p AS target
    WHERE (target.special_fee_type IS NULL OR target.special_fee_type <> 'CHANNEL_FIXED_FEE')
      AND EXISTS (
          SELECT 1
          FROM changed_months month_scope
          WHERE target.report_date >= month_scope.report_month
            AND target.report_date < month_scope.report_month + INTERVAL '1 month'
      );

    -- 渠道固定成本：按前一天更新的 QI CHANNEL_COST 配置月份清理。
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
        SELECT jobid FROM cron.job WHERE jobname = 'quantum_qi_cdc_delete_2am'
    LOOP
        PERFORM cron.unschedule(existing_job_id);
    END LOOP;

    PERFORM cron.schedule(
        'quantum_qi_cdc_delete_2am',
        cron_expression,
        'SELECT dws.fn_quantum_qi_cdc_delete()'
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
WHERE jobname = 'quantum_qi_cdc_delete_2am';
