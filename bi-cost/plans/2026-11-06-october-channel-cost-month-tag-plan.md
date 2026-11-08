# 2026-10 BB / QI 月度 tag 配置 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增一个可重复执行的 SQL，为 BB 和 QI 写入 2026-10 `ods_bi_month_tag` 月度配置。

**Architecture:** 复用现有 BB / QI seed 的临时表、软删除、固定 ID 更新、缺失时插入和执行后核对模式。一个临时表覆盖 11 条配置；SQL 只生成不执行。

**Tech Stack:** Greenplum / PostgreSQL SQL、Markdown。

**Spec:** `design-docs/2026-11-06-october-channel-cost-month-tag-design.md`

## Global Constraints

- 月份为 `2026-10`，统计时间为 `2026-10-01 00:00:00+08`。
- BB `BB_CASH_RATE=0.022698`。
- QI 成本费率按 6 个参数映射；`QI_REBATE_INTERCHANGE_RATE=1.0000`，`QI_REBATE_INCENTIVE_RATE=1.0000`。
- QI 客户毛利侧 CROSS 参数在毛利查询中单独应用为 `1.0848`。
- 不连接数据库、不执行 SQL、不重算、不提交或推送。

## Review Focus

- `detail` 和统计时间是否全部为 2026-10；静态检查全部 values 行。
- 软删除是否仅触及对应 provider、product_line、account_type、tag 和月份；检查 UPDATE 条件。
- ID 是否覆盖全部 11 行且唯一；静态解析临时表 values。
- 销售返现 tag 是否为 1，未计算的 QI 毛利返现金额是否未被写成金额。

---

### Task 1: 新增 BB / QI 2026-10 seed SQL

**Files:**
- Create: `month-tag/bi_month_tag_seed_2026_10.sql`

- [x] 编写 11 行目标配置，使用独立固定 ID，并列明参数映射。
- [x] 加入限定 2026-10 scope 的软删除、固定 ID 更新、缺失时插入及执行后核对。
- [x] 确认 BB 与 QI provider / product_line / amount 值正确。

### Task 2: 静态验证

- [x] 核对配置行数、ID 唯一性、月份、统计时间、tag 和 amount。
- [x] 检查新增文件无尾随空格。
- [x] 标注固定 ID 尚需执行前数据库冲突检查；本次不执行数据库写入。
