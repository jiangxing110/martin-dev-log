--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-05 16:30:00
-- Description:    注册总渠道成本普通物化视图每小时刷新任务
-- Notes:
--   1. 依赖 pg_cron 或兼容 cron 扩展。
--   2. 先执行 mv_total_channel_cost_daily.sql。
--   3. 每小时第 5 分钟并发刷新一次。
--********************************************************************--

-- 1. 检查 pg_cron 是否已安装。
SELECT
    extname,
    extversion
FROM pg_extension
WHERE extname = 'pg_cron';

-- 2. 没有 pg_cron 时提前中断。
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_extension
        WHERE extname = 'pg_cron'
    ) THEN
        RAISE EXCEPTION
            'pg_cron extension is not installed. Please enable pg_cron before scheduling refresh job.';
    END IF;
END $$;

-- 3. 重复执行时先清理同名任务。
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname IN (
    'refresh_total_channel_cost_daily_60min',
    'refresh_total_channel_cost_daily_v3_60min',
    'refresh_total_channel_cost_daily_v3_1h'
);

-- 4. 每小时第 5 分钟并发刷新。
SELECT cron.schedule(
    'refresh_total_channel_cost_daily_60min',
    '5 * * * *',
    $$REFRESH MATERIALIZED VIEW CONCURRENTLY "dws"."dws_total_channel_cost_daily_mv"$$
);

-- 5. 检查任务是否注册成功。
SELECT
    jobid,
    jobname,
    schedule,
    command,
    active
FROM cron.job
WHERE jobname = 'refresh_total_channel_cost_daily_60min';
