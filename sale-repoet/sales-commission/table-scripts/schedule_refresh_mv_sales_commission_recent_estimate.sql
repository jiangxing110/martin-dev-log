--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-30 18:05:00
-- Description:    注册销售佣金预估物化视图数据库定时刷新任务
-- Notes:
--   1. 本脚本依赖 pg_cron 或兼容 cron 扩展。
--   2. 先执行 mv_sales_commission_recent_estimate.sql 创建物化视图。
--   3. 再执行本脚本注册定时刷新任务。
--   4. 当前调度为每 12 小时刷新一次。
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

-- 4. 避免重复注册同名任务。
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname = 'refresh_sales_commission_recent_estimate_12h';

-- 5. 注册每 12 小时刷新一次。
SELECT cron.schedule(
  'refresh_sales_commission_recent_estimate_12h',
  '0 */12 * * *',
  $$REFRESH MATERIALIZED VIEW "dws"."mv_sales_commission_recent_estimate"$$
);

-- 6. 检查任务是否注册成功。
SELECT
  jobid,
  jobname,
  schedule,
  command,
  active
FROM cron.job
WHERE jobname = 'refresh_sales_commission_recent_estimate_12h';
