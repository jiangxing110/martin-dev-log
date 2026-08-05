--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-05 14:47:12
-- Description:    注册 QI 量子卡 monthly-cdc PostgreSQL 删除任务
-- Schedule:       每月 8 日北京时间 02:00
-- Notes:
--   1. 在目标 ADBPG 数据库执行一次本脚本完成注册。
--   2. 删除范围为上月月初（含）至本月月初（不含）。
--   3. 删除成功后再运行对应 QI monthly-cdc INSERT 作业。
--********************************************************************--

CREATE OR REPLACE FUNCTION dws.fn_quantum_qi_monthly_delete()
RETURNS void
LANGUAGE plpgsql
AS $function$
BEGIN
    DELETE FROM dws.dws_qi_card_finance_daily_v2_p
    WHERE report_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')::date
      AND report_date < DATE_TRUNC('month', CURRENT_DATE)::date
      AND (special_fee_type IS NULL OR special_fee_type <> 'CHANNEL_FIXED_FEE');

    DELETE FROM dws.dws_qi_card_finance_daily_v2_p
    WHERE report_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')::date
      AND report_date < DATE_TRUNC('month', CURRENT_DATE)::date
      AND special_fee_type = 'CHANNEL_FIXED_FEE';
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
        cron_expression := '0 2 8 * *';
    ELSIF LOWER(cron_timezone) IN ('gmt', 'utc', 'etc/utc') THEN
        cron_expression := '0 18 7 * *';
    ELSE
        RAISE EXCEPTION 'Unsupported cron.timezone: %. Expected Asia/Shanghai, PRC, GMT or UTC', cron_timezone;
    END IF;

    FOR existing_job_id IN
        SELECT jobid FROM cron.job WHERE jobname = 'quantum_qi_monthly_delete_2am'
    LOOP
        PERFORM cron.unschedule(existing_job_id);
    END LOOP;

    PERFORM cron.schedule(
        'quantum_qi_monthly_delete_2am',
        cron_expression,
        'SELECT dws.fn_quantum_qi_monthly_delete()'
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
WHERE jobname = 'quantum_qi_monthly_delete_2am';
