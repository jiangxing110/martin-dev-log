-- ==============================================================
-- 增量物化视图：dws.dws_effective_revenue_daily_mv
-- 说明    : 有效收入 = 收入 - 客户返现
-- 来源    : dws_revenue_summary_daily_mv（收入，已去 currency）
--           dws_cashback_daily（客户返现）
-- 粒度    : (stat_date, category, account_id, account_type, system_type)
-- 刷新    : 自动增量刷新，基表写入后实时同步
-- ==============================================================

DROP MATERIALIZED VIEW IF EXISTS dws.dws_effective_revenue_daily_mv;

CREATE INCREMENTAL MATERIALIZED VIEW dws.dws_effective_revenue_daily_mv AS
SELECT
    COALESCE(r.stat_date, c.stat_date)            AS stat_date,
    COALESCE(r.category, c.category)              AS category,
    COALESCE(r.account_id, c.account_id)          AS account_id,
    COALESCE(r.account_type, c.account_type)      AS account_type,
    COALESCE(r.system_type, c.system_type)        AS system_type,
    COALESCE(r.total_revenue, 0)                  AS total_revenue,
    COALESCE(c.total_cashback, 0)                 AS total_cashback,
    COALESCE(r.total_revenue, 0) - COALESCE(c.total_cashback, 0) AS effective_revenue
FROM (
    SELECT stat_date                              AS stat_date,
           category                               AS category,
           COALESCE(account_id, '')               AS account_id,
           COALESCE(account_type, '')             AS account_type,
           COALESCE(system_type, '')              AS system_type,
           SUM(amount)                            AS total_revenue
    FROM dws.dws_revenue_summary_daily_mv
    GROUP BY stat_date, category, account_id, account_type, system_type
) r
FULL OUTER JOIN (
    SELECT stat_date                              AS stat_date,
           category                               AS category,
           account_id                             AS account_id,
           account_type                           AS account_type,
           system_type                            AS system_type,
           SUM(cashback_amount)                   AS total_cashback
    FROM dws.dws_cashback_daily
    GROUP BY stat_date, category, account_id, account_type, system_type
) c
    ON  r.stat_date    = c.stat_date
    AND r.category     = c.category
    AND r.account_id   = c.account_id
    AND r.account_type = c.account_type
    AND r.system_type  = c.system_type
DISTRIBUTED BY (stat_date);

COMMENT ON MATERIALIZED VIEW dws.dws_effective_revenue_daily_mv IS '有效收入日维度汇总（收入-返现）';

COMMENT ON COLUMN dws.dws_effective_revenue_daily_mv.stat_date IS '统计日期';
COMMENT ON COLUMN dws.dws_effective_revenue_daily_mv.category IS '业务大类';
COMMENT ON COLUMN dws.dws_effective_revenue_daily_mv.account_id IS '账户ID';
COMMENT ON COLUMN dws.dws_effective_revenue_daily_mv.account_type IS '账户类型';
COMMENT ON COLUMN dws.dws_effective_revenue_daily_mv.system_type IS '系统类型';
COMMENT ON COLUMN dws.dws_effective_revenue_daily_mv.total_revenue IS '总收入';
COMMENT ON COLUMN dws.dws_effective_revenue_daily_mv.total_cashback IS '总客户返现';
COMMENT ON COLUMN dws.dws_effective_revenue_daily_mv.effective_revenue IS '有效收入（收入-返现）';
