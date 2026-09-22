# BB 渠道返现视图费率对齐实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement the plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让销售佣金和合伙人毛利视图直接使用 BB DWS 已计算的渠道返现，避免继续使用过期固定费率。

**Architecture:** 保留 BB DWS 的净消费基数和月度返现率计算逻辑；下游两个物化视图在 `qbit_card_channel_rebate` 中汇总 `cashback_income`，再按现有规则挂到 qbit_card/provider 明细。同步更新说明文档。

**Tech Stack:** PostgreSQL materialized-view SQL、Markdown。

**Spec:** `design-docs/2026-09-22-bb-channel-rebate-view-rate-design.md`

## Global Constraints

- BB 渠道返现必须与 `dws.dws_bb_card_finance_daily_v2_p.cashback_income` 一致。
- 不再在销售或合伙人视图中写死 `0.021195`。
- 不修改 BB 成本、净消费、佣金阶梯和分配规则。
- 不执行 git commit 或 git push。

## Review Focus

- 同一客户 191 个子户的返现必须汇总为 `7963.8358`。
- DWS 返现率变化后，下游视图不能继续使用旧费率。
- 销售视图和合伙人视图的 BB 返现表达式必须一致。

### Task 1: 修改下游视图

- [x] 将销售和合伙人视图的 BB 返现来源改为 `SUM(COALESCE(b.cashback_income, 0))`。
- [x] 更新相关 SQL 注释和开发文档。

### Task 2: 静态验证

- [ ] 检查两个视图不再出现 `0.021195`。
- [ ] 检查两个视图均引用 `cashback_income`。
- [ ] 运行 `git diff --check`。
