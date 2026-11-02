--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-02
-- Description:    注册销售毛利预估物化视图定时刷新任务
-- Notes: 刷新节奏参考 sale-repoet/sales-commission/table-scripts/schedule_refresh_mv_sales_commission_recent_estimate.sql。
--********************************************************************--

SELECT extname, extversion FROM pg_extension WHERE extname = 'pg_cron';

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE EXCEPTION 'pg_cron extension is not installed. Please enable pg_cron before scheduling refresh job.';
  END IF;
END $$;

SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname = 'refresh_sales_gross_profit_recent_estimate_12h';

-- 沿用销售返佣视图的每12小时刷新触发时间。
SELECT cron.schedule(
  'refresh_sales_gross_profit_recent_estimate_12h',
  '0 */12 * * *',
  $$REFRESH MATERIALIZED VIEW "dws"."mv_sales_gross_profit_recent_estimate"$$
);

SELECT jobid, jobname, schedule, command, active
FROM cron.job
WHERE jobname = 'refresh_sales_gross_profit_recent_estimate_12h';
