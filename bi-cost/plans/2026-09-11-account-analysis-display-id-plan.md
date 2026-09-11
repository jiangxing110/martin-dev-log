# 客户分析维表补充 display_id Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `public.account."displayId"` 接入 `dim.dim_account_analysis` 的 DDL、CDC 和 batch 回刷链路，并补偿 OpenAPI 属性晚到或 CDC 漏消费造成的维表缺失。

**Architecture:** 在现有账户基础字段之后增加 `display_id`，由 CDC 和 batch 的账户源统一提供，视图和 sink 按同一列顺序写入目标表。通过独立 ALTER 脚本支持已有目标表迁移，并用幂等 UPDATE 脚本周期性校正 OpenAPI 属性。

**Tech Stack:** PostgreSQL SQL、Flink Table SQL、shell 静态结构校验。

**Spec:** `design-docs/2026-09-11-account-analysis-display-id-design.md`

## Global Constraints

- 仅修改 `flink/account_analysis` 下的同步脚本和目标表脚本。
- 源字段使用 `account."displayId"`，目标字段使用 `display_id`。
- 保持已有字段顺序不变，仅在 `verified_name` 后插入 `display_id`。

---

### Task 1: 接入 display_id 字段

**Files:**
- Modify: `flink/account_analysis/table-scripts/dim_account_analysis.sql`
- Modify: `flink/account_analysis/cdc/dim_online_account_analysis-cdc-sql.sql`
- Modify: `flink/account_analysis/batch/dim_online_account_analysis-batch-sql.sql`
- Create: `flink/account_analysis/table-scripts/alter_dim_account_analysis_add_display_id.sql`

- [x] 在目标表、CDC source/view/sink、batch source/view/sink 中加入 `display_id`。
- [x] 增加幂等迁移脚本和字段注释。
- [x] 执行静态字段契约校验。
- [x] 增加 OpenAPI 属性幂等回填脚本，支持修复 838108 等存量客户。
