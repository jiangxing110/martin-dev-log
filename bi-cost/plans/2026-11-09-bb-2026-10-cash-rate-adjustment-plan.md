# BB 2026-10 返现率单独调整 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 提供独立 SQL，仅更新已写入 `ods_bi_month_tag` 的 BB 2026-10 返现率。

**Architecture:** 按固定 ID 和完整 BB 2026-10 tag 范围更新单条记录，不重跑合并 seed。事务内使用 `UPDATE ... RETURNING`，事务后查询核对。

**Tech Stack:** Greenplum / PostgreSQL SQL、Markdown。

**Spec:** `design-docs/2026-11-09-bb-2026-10-cash-rate-adjustment-design.md`

## Global Constraints

- 目标行 ID 为 `202611060901`，provider/product_line 为 `BB`，account_type 为 `fullCustomer`，tag 为 `BB_CASH_RATE`，detail 为 `2026-10`。
- 新 amount 为 `0.022698::numeric * 1.0377::numeric = 0.0235537146`。
- 不修改 QI 配置，不重跑合并 seed，不连接数据库或重算 DWS。

## Review Focus

- UPDATE 是否严格限定唯一 BB 10 月行；检查完整 WHERE 条件。
- 金额是否为十进制精确值；静态校验表达式和注释。

---

### Task 1: 新增独立 BB 10 月 rate update SQL

**Files:**
- Create: `month-tag/bb_bi_month_tag_rate_update_2026_10.sql`

- [x] 写入更新前查询、事务 UPDATE/RETURNING 和执行后核对查询。
- [x] 确认仅目标 BB 10 月 ID 与 tag 被修改。
- [x] 静态核对 rate、scope 和空白格式；不执行数据库写入。
