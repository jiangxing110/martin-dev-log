# BPC Active Card Cost Monthly Pool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修正 BPC QI 活跃卡成本在多月份回刷时跨月混合客户池的问题。

**Architecture:** BPC 拆分作业保持现有 DWM 写入结构不变，只在分摊基数链路中补齐 `source_month`。月度客户池、日期展开、月分母和月度金额都按 `source_month` 关联。

**Tech Stack:** Alibaba Cloud Flink SQL, ADB PostgreSQL connector, Markdown design docs.

## Global Constraints

- 不修改 sink 表结构。
- 不修改合并作业，合并作业当前已有按 `source_month` 关联的口径。
- BPC 客户池判断口径为 QI 卡 `provider LIKE '%Qbit%'` 且 `delete_card_time > source_month 00:00:00 OR delete_card_time IS NULL`。

---

### Task 1: Document BPC Monthly Pool Rule

**Files:**
- Create: `design-docs/2026-07-bpc-active-card-cost-monthly-pool.md`
- Create: `plans/2026-07-bpc-active-card-cost-monthly-pool.md`

**Interfaces:**
- Consumes: 用户提供的 BPC 活跃卡客户池 SQL。
- Produces: 可评审的业务口径、根因和验收口径。

- [x] 写明 BPC 是 QI 活跃卡客户均摊成本。
- [x] 写明按费用月份第一天判断活跃客户池。
- [x] 写明拆分作业跨月混池根因。
- [x] 写明验收口径。

### Task 2: Fix Split BPC Batch SQL

**Files:**
- Modify: `flink/total_cost/finance/quantum_card/dwm_online_quantum_card_bpc_cost-batch-sql.sql`

**Interfaces:**
- Consumes: `v_param.source_month`, `source_qbit_card.delete_card_time`, `source_bi_month_tag.statistics_time`。
- Produces: 按 `source_month` 隔离的 `v_allocated_cost_base` 和最终 DWM 成本行。

- [x] 在 `v_month_days` 输出 `source_month`。
- [x] 在 `v_bpc_accounts` 输出并按 `source_month, account_id` 聚合。
- [x] 在 `v_bpc_basis` 输出 `source_month` 并按月份关联 `v_month_days`。
- [x] 在 `v_cost_basis_month_total` 按 `source_month` 聚合。
- [x] 在 `v_cost_basis` 按 `source_month` 关联月分母。
- [x] 在 `v_allocated_cost_base` 按 `source_month` 关联 `v_bi_month_tag_cost`。

### Task 3: Verification

**Files:**
- Read-only verification across modified SQL and docs.

**Interfaces:**
- Consumes: SQL text.
- Produces: 静态校验结果。

- [x] 检查 BPC 拆分作业中 `v_bpc_accounts` 是否保留 `source_month`。
- [x] 检查 `v_bpc_basis` 是否不再 `CROSS JOIN v_month_days`。
- [x] 检查月汇总是否按 `source_month` 分组。
- [x] 检查金额分摊是否按 `source_month` 关联。
