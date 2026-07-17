-- 作业元信息：
--   作业类型：DDL物化视图脚本
--   运行方式：非运行作业
--   运行参数：无
--   源库变更响应：上游收入/成本视图或表变更后，通过 pg_cron 每 5 分钟刷新物化结果。
--   v2 说明：渠道成本只读取 dws.dws_total_channel_cost_daily_v2_p，避免与 dwm_finance_channel_cost_p 重复计成本。

-- ==============================================
-- 1. 创建物化视图
-- ==============================================
CREATE MATERIALIZED VIEW "dws"."mv_gross_profit_daily" AS
WITH revenue_daily AS (
    SELECT
        stat_date AS report_date,
        account_id,
        category,
        SUM(
            CASE
                WHEN amount IS NULL OR amount::text = 'NaN' THEN 0
                ELSE amount
            END
        ) AS revenue_amount
    FROM "dws"."dws_revenue_summary_daily_mv"
    GROUP BY stat_date, account_id, category
),
total_channel_cost_daily AS (
    SELECT
        report_date,
        account_id,
        SUM(quantum_cost_amount) AS quantum_cost_amount,
        SUM(business_cost_amount) AS business_cost_amount,
        SUM(crypto_cost_amount) AS crypto_cost_amount,
        SUM(acquiring_cost_amount) AS acquiring_cost_amount
    FROM (
        SELECT
            report_date,
            account_id,
            CASE
                WHEN quantum_cost IS NULL OR quantum_cost::text = 'NaN' THEN 0
                ELSE quantum_cost
            END AS quantum_cost_amount,
            CASE
                WHEN business_cost IS NULL OR business_cost::text = 'NaN' THEN 0
                ELSE business_cost
            END AS business_cost_amount,
            CASE
                WHEN crypto_cost IS NULL OR crypto_cost::text = 'NaN' THEN 0
                ELSE crypto_cost
            END AS crypto_cost_amount,
            CASE
                WHEN acquiring_cost IS NULL OR acquiring_cost::text = 'NaN' THEN 0
                ELSE acquiring_cost
            END AS acquiring_cost_amount
        FROM "dws"."dws_total_channel_cost_daily_v2_p"
        WHERE delete_time IS NULL
    ) t
    GROUP BY report_date, account_id
),
channel_cost_source AS (
    SELECT report_date, account_id, 'qbit_card' AS category, quantum_cost_amount AS channel_cost_amount
    FROM total_channel_cost_daily
    WHERE quantum_cost_amount <> 0
    UNION ALL
    SELECT report_date, account_id, 'global_account' AS category, business_cost_amount AS channel_cost_amount
    FROM total_channel_cost_daily
    WHERE business_cost_amount <> 0
    UNION ALL
    SELECT report_date, account_id, 'crypto_assets' AS category, crypto_cost_amount AS channel_cost_amount
    FROM total_channel_cost_daily
    WHERE crypto_cost_amount <> 0
    UNION ALL
    SELECT report_date, account_id, 'particle_financing' AS category, acquiring_cost_amount AS channel_cost_amount
    FROM total_channel_cost_daily
    WHERE acquiring_cost_amount <> 0
),
channel_cost_daily AS (
    SELECT
        report_date,
        account_id,
        category,
        SUM(channel_cost_amount) AS channel_cost_amount
    FROM channel_cost_source
    GROUP BY report_date, account_id, category
),
gross_profit_daily AS (
    SELECT
        COALESCE(r.report_date, c.report_date) AS report_date,
        COALESCE(r.account_id, c.account_id) AS account_id,
        COALESCE(r.category, c.category) AS category,
        CAST(COALESCE(r.revenue_amount, 0) AS numeric(20,4)) AS revenue_amount,
        CAST(COALESCE(c.channel_cost_amount, 0) AS numeric(20,4)) AS channel_cost_amount
    FROM revenue_daily r
    FULL OUTER JOIN channel_cost_daily c
        ON c.report_date = r.report_date
       AND c.account_id = r.account_id
       AND c.category = r.category
)
SELECT
    CAST(ABS(('x' || substr(md5(CONCAT(report_date::text, ':', COALESCE(account_id, ''), ':', category)), 1, 15))::bit(60)::bigint) AS bigint) AS id,
    report_date,
    account_id,
    category,
    revenue_amount,
    channel_cost_amount,
    CAST(revenue_amount - channel_cost_amount AS numeric(20,4)) AS gross_profit_amount,
    CAST(
        CASE
            WHEN revenue_amount = 0 THEN 0
            ELSE (revenue_amount - channel_cost_amount) / revenue_amount
        END AS numeric(20,8)
    ) AS gross_margin,
    1 AS version,
    CAST(NULL AS varchar) AS remarks,
    CURRENT_TIMESTAMP AS create_time,
    CURRENT_TIMESTAMP AS update_time,
    CAST(NULL AS timestamp) AS delete_time,
    CAST(NULL AS timestamp) AS create_date
FROM gross_profit_daily
WITH DATA
DISTRIBUTED BY (id);

ALTER MATERIALIZED VIEW "dws"."mv_gross_profit_daily" OWNER TO "qbit_admin";

-- 唯一索引：用于 CONCURRENTLY 刷新
CREATE UNIQUE INDEX IF NOT EXISTS "idx_mv_gross_profit_daily_id"
    ON "dws"."mv_gross_profit_daily" ("id");

CREATE INDEX IF NOT EXISTS "idx_mv_gross_profit_daily_date_category"
    ON "dws"."mv_gross_profit_daily" ("report_date", "category");

CREATE INDEX IF NOT EXISTS "idx_mv_gross_profit_daily_account_dim"
    ON "dws"."mv_gross_profit_daily" ("account_id", "report_date");

COMMENT ON MATERIALIZED VIEW "dws"."mv_gross_profit_daily" IS
    'DWS物化视图：客户产品线毛利日汇总 v2，渠道成本来源 dws_total_channel_cost_daily_v2_p';

-- ==============================================
-- 2. 定时刷新（每 5 分钟）
-- ==============================================
-- 手动刷新：
-- REFRESH MATERIALIZED VIEW CONCURRENTLY dws.mv_gross_profit_daily;

-- pg_cron 定时任务（每 5 分钟刷新一次）：
SELECT cron.schedule(
    'refresh_mv_gross_profit_daily',
    '*/5 * * * *',
    $$REFRESH MATERIALIZED VIEW CONCURRENTLY dws.mv_gross_profit_daily$$
);

-- 查看已创建的定时任务：
-- SELECT * FROM cron.job;

-- 删除定时任务：
-- SELECT cron.unschedule('refresh_mv_gross_profit_daily');
