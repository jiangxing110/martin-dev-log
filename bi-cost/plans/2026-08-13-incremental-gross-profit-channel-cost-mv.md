# Incremental Gross Profit Channel Cost MV Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增渠道成本与毛利日汇总的 ADBPG 增量物化视图脚本。

**Architecture:** 从现有普通物化视图脚本派生增量物化视图版本，保持对象名、字段、索引和分布键不变。新增脚本放入 `online/incremental-view/`，普通物化视图脚本和刷新调度脚本保持原样。

**Tech Stack:** AnalyticDB for PostgreSQL、PostgreSQL SQL、ADBPG incremental materialized view

## Global Constraints

- 不修改 `online/materialized-view/` 下现有普通物化视图脚本。
- 不修改现有 pg_cron 刷新脚本。
- 增量物化视图脚本不使用 CTE。
- 聚合层只使用 `SUM(column)`、`MIN(column)`、`MAX(column)` 形式。
- 增量物化视图脚本不创建唯一索引或主键。
- 毛利主版本和 AASA 版本都创建 `dws.mv_gross_profit_daily`，上线时只能选择一个版本执行。
- 不提交 Git。

---

### Task 1: 新增总渠道成本增量物化视图

**Files:**
- Create: `online/incremental-view/mv_channel_cost_daily.sql`

**Interfaces:**
- Consumes: `dws.dws_bb_card_finance_daily_v2_p`、`dws.dws_bz_card_finance_daily_v2_p`、`dws.dws_qi_card_finance_daily_v2_p`、`dws.dws_sl_card_finance_daily_p`、`dwm.dwm_finance_channel_cost_p`
- Produces: `dws.mv_channel_cost_daily`

- [x] 从 `online/materialized-view/mv_channel_cost_daily.sql` 复制查询口径。
- [x] 将创建语句改为 `CREATE INCREMENTAL MATERIALIZED VIEW`。
- [x] 将 CTE 改为派生表，规避 ADBPG 增量物化视图不支持 CTE 的限制。
- [x] 将成本分桶前移到明细层，外层只保留直接聚合。
- [x] 将 `id` 唯一索引改为普通索引。
- [x] 将注释改为增量物化视图维护说明。
- [x] 保留 owner、查询索引和 `DISTRIBUTED BY (id)`。

### Task 2: 新增毛利主版本增量物化视图

**Files:**
- Create: `online/incremental-view/mv_gross_profit_daily.sql`

**Interfaces:**
- Consumes: `dws.dws_effective_revenue_daily_mv`、`dws.mv_channel_cost_daily`
- Produces: `dws.mv_gross_profit_daily`

- [x] 从 `online/materialized-view/mv_gross_profit_daily.sql` 复制查询口径。
- [x] 将创建语句改为 `CREATE INCREMENTAL MATERIALIZED VIEW`。
- [x] 将收入和成本清洗前移到派生表，移除 `SUM(CASE ...)`。
- [x] 将零成本过滤从 `HAVING SUM(...)` 改为聚合结果外层 `WHERE`。
- [x] 将 `id` 唯一索引改为普通索引。
- [x] 将注释改为增量物化视图维护说明。
- [x] 保留 treasury 收入口径和成本缺省为 0 的逻辑。

### Task 3: 新增毛利 AASA 版本增量物化视图

**Files:**
- Create: `online/incremental-view/mv_gross_profit_daily_aasa.sql`

**Interfaces:**
- Consumes: `dws.dws_effective_revenue_daily_mv`、`dws.dws_total_channel_cost_daily_v2_p`
- Produces: `dws.mv_gross_profit_daily`

- [x] 从 `online/materialized-view/mv_gross_profit_daily_aasa.sql` 复制查询口径。
- [x] 将创建语句改为 `CREATE INCREMENTAL MATERIALIZED VIEW`。
- [x] 将收入和成本清洗前移到派生表，移除 `SUM(CASE ...)`。
- [x] 将零成本过滤从 `HAVING SUM(...)` 改为聚合结果外层 `WHERE`。
- [x] 将 `id` 唯一索引改为普通索引。
- [x] 将注释改为增量物化视图维护说明。
- [x] 保留 AASA 原成本来源和 category 范围。

### Task 4: 静态校验

**Files:**
- Test: `online/incremental-view/*.sql`

- [x] 检查新增脚本均包含 `CREATE INCREMENTAL MATERIALIZED VIEW`。
- [x] 检查新增脚本不包含 CTE。
- [x] 检查新增脚本不包含 `SUM(CASE ...)`、聚合后强转或 `HAVING SUM(...)`。
- [x] 检查新增脚本不包含 `CREATE UNIQUE INDEX` 或 `PRIMARY KEY`。
- [x] 检查新增脚本不包含 `REFRESH MATERIALIZED VIEW`。
- [x] 运行 `git diff --check`。
