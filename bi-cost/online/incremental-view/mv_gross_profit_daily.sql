-- 作业元信息：
--   作业类型：DDL增量物化视图脚本
--   运行方式：非运行作业
--   运行参数：无
--   源库变更响应：ADBPG 增量物化视图随底表变更自动维护。
--   v2 说明：渠道成本读取 dws.mv_channel_cost_daily；treasury 无渠道成本时按 0 计算。

-- ==============================================
-- 1. 创建增量物化视图
-- ==============================================
DROP MATERIALIZED VIEW IF EXISTS "dws"."mv_gross_profit_daily";

CREATE INCREMENTAL MATERIALIZED VIEW "dws"."mv_gross_profit_daily" AS
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
FROM (
    SELECT
        COALESCE(r.report_date, c.report_date) AS report_date,
        COALESCE(r.account_id, c.account_id) AS account_id,
        COALESCE(r.category, c.category) AS category,
        CAST(COALESCE(r.revenue_amount, 0) AS numeric(20,4)) AS revenue_amount,
        CAST(COALESCE(c.channel_cost_amount, 0) AS numeric(20,4)) AS channel_cost_amount
    FROM (
        SELECT
            report_date,
            account_id,
            category,
            SUM(effective_revenue_amount) AS revenue_amount
        FROM (
            SELECT
                stat_date AS report_date,
                account_id,
                CASE
                    WHEN category = 'card' THEN 'qbit_card'
                    ELSE category
                END AS category,
                CASE
                    WHEN effective_revenue IS NULL OR effective_revenue::text = 'NaN' THEN 0
                    ELSE effective_revenue
                END AS effective_revenue_amount
            FROM "dws"."dws_effective_revenue_daily_mv"
            WHERE category IN ('global_account', 'acquiring', 'card', 'crypto_assets', 'treasury')
        ) revenue_source
        GROUP BY report_date, account_id, category
    ) r
    FULL OUTER JOIN (
        SELECT
            report_date,
            account_id,
            category,
            SUM(channel_cost_amount) AS channel_cost_amount
        FROM (
            SELECT report_date, account_id, category, channel_cost_amount
            FROM (
                SELECT
                    report_date,
                    account_id,
                    'qbit_card' AS category,
                    SUM(quantum_cost_amount) AS channel_cost_amount
                FROM (
                    SELECT
                        report_date,
                        account_id,
                        CASE
                            WHEN quantum_cost IS NULL OR quantum_cost::text = 'NaN' THEN 0
                            ELSE quantum_cost
                        END AS quantum_cost_amount
                    FROM "dws"."mv_channel_cost_daily"
                    WHERE delete_time IS NULL
                ) quantum_cost_source
                GROUP BY report_date, account_id
            ) quantum_cost_grouped
            WHERE channel_cost_amount <> 0

            UNION ALL

            SELECT report_date, account_id, category, channel_cost_amount
            FROM (
                SELECT
                    report_date,
                    account_id,
                    'global_account' AS category,
                    SUM(business_cost_amount) AS channel_cost_amount
                FROM (
                    SELECT
                        report_date,
                        account_id,
                        CASE
                            WHEN business_cost IS NULL OR business_cost::text = 'NaN' THEN 0
                            ELSE business_cost
                        END AS business_cost_amount
                    FROM "dws"."mv_channel_cost_daily"
                    WHERE delete_time IS NULL
                ) business_cost_source
                GROUP BY report_date, account_id
            ) business_cost_grouped
            WHERE channel_cost_amount <> 0

            UNION ALL

            SELECT report_date, account_id, category, channel_cost_amount
            FROM (
                SELECT
                    report_date,
                    account_id,
                    'crypto_assets' AS category,
                    SUM(crypto_cost_amount) AS channel_cost_amount
                FROM (
                    SELECT
                        report_date,
                        account_id,
                        CASE
                            WHEN crypto_cost IS NULL OR crypto_cost::text = 'NaN' THEN 0
                            ELSE crypto_cost
                        END AS crypto_cost_amount
                    FROM "dws"."mv_channel_cost_daily"
                    WHERE delete_time IS NULL
                ) crypto_cost_source
                GROUP BY report_date, account_id
            ) crypto_cost_grouped
            WHERE channel_cost_amount <> 0

            UNION ALL

            SELECT report_date, account_id, category, channel_cost_amount
            FROM (
                SELECT
                    report_date,
                    account_id,
                    'acquiring' AS category,
                    SUM(acquiring_cost_amount) AS channel_cost_amount
                FROM (
                    SELECT
                        report_date,
                        account_id,
                        CASE
                            WHEN acquiring_cost IS NULL OR acquiring_cost::text = 'NaN' THEN 0
                            ELSE acquiring_cost
                        END AS acquiring_cost_amount
                    FROM "dws"."mv_channel_cost_daily"
                    WHERE delete_time IS NULL
                ) acquiring_cost_source
                GROUP BY report_date, account_id
            ) acquiring_cost_grouped
            WHERE channel_cost_amount <> 0
        ) channel_cost_source
        GROUP BY report_date, account_id, category
    ) c
        ON c.report_date = r.report_date
       AND c.account_id = r.account_id
       AND c.category = r.category
) gross_profit_daily
DISTRIBUTED BY (id);

ALTER MATERIALIZED VIEW "dws"."mv_gross_profit_daily"
    OWNER TO "flink_cdc_user";

-- 普通索引：用于按 id 查询；ADBPG IMV 不支持唯一索引或主键。
CREATE INDEX IF NOT EXISTS "idx_mv_gross_profit_daily_id"
    ON "dws"."mv_gross_profit_daily" ("id");

CREATE INDEX IF NOT EXISTS "idx_mv_gross_profit_daily_date_category"
    ON "dws"."mv_gross_profit_daily" ("report_date", "category");

CREATE INDEX IF NOT EXISTS "idx_mv_gross_profit_daily_account_dim"
    ON "dws"."mv_gross_profit_daily" ("account_id", "report_date");

COMMENT ON MATERIALIZED VIEW "dws"."mv_gross_profit_daily" IS
    'DWS增量物化视图：客户产品线毛利日汇总 v2，收入来源有效收入 MV，成本来源 mv_channel_cost_daily，treasury 无成本时按 0 计算';

-- ==============================================
-- 2. 维护说明
-- ==============================================
-- 本视图为 ADBPG 增量物化视图，不再通过手动刷新命令或 pg_cron 定时维护。
