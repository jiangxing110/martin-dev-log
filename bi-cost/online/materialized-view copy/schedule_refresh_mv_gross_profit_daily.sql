--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-31 16:30:00
-- Updated Time:   2026-08-05 19:08:43
-- Description:    注册毛利日汇总普通物化视图数据库定时刷新任务
-- Notes:
--   1. 本脚本依赖 pg_cron 或兼容 cron 扩展。
--   2. 先执行 mv_gross_profit_daily.sql 创建普通物化视图。
--   3. 再执行本脚本注册定时刷新任务。
--   4. 当前调度为每 30 分钟刷新一次。
--********************************************************************--

-- 1. 检查 pg_cron 是否已安装。
-- 如果结果为空，先联系 DBA 开启 pg_cron 或数据库任务调度能力。
SELECT
  extname,
  extversion
FROM pg_extension
WHERE extname = 'pg_cron';

-- 2. 如数据库允许当前用户创建扩展，可执行下面语句。
-- CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 3. 没有 pg_cron 时提前中断，避免后续 cron.job 报错不清楚。
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE EXCEPTION 'pg_cron extension is not installed. Please enable pg_cron before scheduling refresh job.';
  END IF;
END $$;

-- 4. 避免重复注册同名任务，并清理旧任务名。
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname IN (
  'refresh_gross_profit_daily_12h',
  'refresh_gross_profit_daily_30min',
  'refresh_gross_profit_daily_60min',
  'refresh_gross_profit_daily_1h'
);

-- 5. 注册每 30 分钟刷新一次。
SELECT cron.schedule(
  'refresh_gross_profit_daily_30min',
  '*/30 * * * *',
  $$REFRESH MATERIALIZED VIEW "dws"."mv_gross_profit_daily"$$
);

-- 6. 检查任务是否注册成功。
SELECT
  jobid,
  jobname,
  schedule,
  command,
  active
FROM cron.job
WHERE jobname = 'refresh_gross_profit_daily_30min';
