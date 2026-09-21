# QI 渠道返现净消费口径 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 QI v2 Interchange、Incentive 渠道返现计费基数改为非港净消费口径。

**Architecture:** 在 batch 与 CDC 的日/月聚合层统一使用同一套净消费 CASE 表达式，保留现有费率和下游 `base * rate` 结构；同步更新目标表注释。

**Tech Stack:** Flink SQL、PostgreSQL DDL、Markdown、Git。

**Spec:** `design-docs/2026-09-21-qi-channel-cashback-net-consumption-design.md`

## Global Constraints

- 仅修改 QI v2 渠道返现两个基数及其字段注释。
- 返现交易范围为非港、`Closed/Pending`、`Consumption/Reversal/Credit`。
- `Consumption` 正向，`Reversal/Credit` 负向；Interchange 乘 0.02，Incentive 乘 0.0118。
- 不执行 git commit 或 git push。

## Review Focus

- Reversal/Credit 必须抵减返现基数，而不是继续产生正向返现。
- 非港条件必须保留，避免将香港交易纳入返现。
- batch 与 CDC 的口径必须一致，避免回刷与增量结果不同。

### Task 1: 更新返现基数表达式

**Files:**
- Modify: `flink/quantum-v2/qi/batch/dws_online_qi_card_finance_daily_v2-batch-sql.sql`
- Modify: `flink/quantum-v2/qi/cdc/dws_online_qi_card_finance_daily_v2-cdc-v2-sql.sql`
- Modify: `flink/quantum-v2/qi/table-scripts/dws_qi_card_finance_daily_v2_p.sql`

- [x] 将 batch/CDC 两个返现基数改为净消费 CASE。
- [x] 更新两个字段注释为非港净消费口径。

### Task 2: 静态验证

- [x] 检查 batch/CDC 均包含三个业务类型、正负方向和两个费率。
- [x] 检查旧的仅 Consumption 返现表达式已移除。
- [x] 运行 `git diff --check`。
