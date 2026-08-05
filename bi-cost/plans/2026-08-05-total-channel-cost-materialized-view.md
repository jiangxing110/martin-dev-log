# Total Channel Cost Materialized View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 使用每 5 小时刷新的 ADBPG 普通物化视图替代总渠道成本 Flink batch/CDC。

**Architecture:** 将现有 batch 的五路成本来源和计算公式迁移到一个普通物化视图。使用唯一索引支持并发刷新，通过 pg_cron 每 5 小时整点刷新。

**Tech Stack:** AnalyticDB for PostgreSQL、PostgreSQL SQL、pg_cron

## Global Constraints

- 不修改或删除 `dws.dws_total_channel_cost_daily_v2_p`。
- 不修改现有毛利物化视图。
- 不提交 Git。

---

### Task 1: 创建总渠道成本物化视图

**Files:**
- Create: `flink/total_cost/mv_channel_cost_daily.sql`

- [x] 迁移 BB、BZ、QI、SL 和金融渠道成本计算逻辑。
- [x] 按日期、账户、销售和 AM 汇总四个成本桶。
- [x] 创建唯一索引和查询索引。

### Task 2: 创建小时刷新任务

**Files:**
- Create: `flink/total_cost/schedule_refresh_mv_channel_cost_daily.sql`

- [x] 检查 pg_cron 扩展。
- [x] 幂等清理同名旧任务。
- [x] 注册每 5 小时整点并发刷新。
- [x] 输出任务注册结果。
- [x] 将毛利刷新调整为每 30 分钟一次。

### Task 3: 静态校验

**Files:**
- Test: `flink/total_cost/*.sql`

- [x] 对照 batch 核对来源、公式和分桶。
- [x] 运行 `git diff --check`。
