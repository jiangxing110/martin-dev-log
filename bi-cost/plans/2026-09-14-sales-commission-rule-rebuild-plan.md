# 销售佣金部门产品规则重建 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (recommended) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按当前部门产品白名单重建销售佣金规则，补齐当前部门的非加密规则和 13～20 行部门的加密规则。

**Architecture:** 用显式部门产品映射替代普通部门与产品的笛卡尔积。规则表按当前 `department_id` 精确匹配；海外销售部 - 2 使用独立特殊规则；加密成本特殊口径继续由销售返佣物化视图负责。

**Tech Stack:** PostgreSQL/ADBPG SQL、销售佣金规则维表、Markdown。

**Spec:** `design-docs/2026-09-14-sales-commission-rule-rebuild-design.md`

## Global Constraints

- 13～20 行部门有 `crypto` 业务。
- 国内新增销售小组不配置 `crypto`，但配置需要的非加密产品。
- 海外销售部 - 2 使用直邀 20%、非直邀 10% 的特殊规则。
- 普通 `crypto` 规则使用 GP 和 12%/6%/3.6% 活跃天数阶梯。
- 加密成本的是否忽略 0 由现有物化视图成本逻辑控制。
- 默认只保留工作区代码和文档修改，不执行 git commit 或 git push。

### Task 1: 重写规则初始化脚本

**Files:**
- Modify: `/Users/martinjiang/VsCodeProjects/martin-dev-log/sale-repoet/sales-commission/table-scripts/dim_sales_commission_rule.sql`

- [ ] 使用显式部门产品映射生成普通规则。
- [ ] 为国内新增小组补齐非加密产品规则。
- [ ] 为 13～20 行部门生成普通 `crypto` 规则，并保留海外销售部 - 2 特殊规则。
- [ ] 删除旧的批量 `crypto` 误配逻辑，保证国内部门及小组不再生成 `crypto`。

### Task 2: 静态规则核对

**Files:**
- Check: `/Users/martinjiang/VsCodeProjects/martin-dev-log/sale-repoet/sales-commission/table-scripts/dim_sales_commission_rule.sql`

- [ ] 核对 13～20 行部门名单和部门 ID。
- [ ] 核对 7 个新增国内小组不存在 `crypto` 产品规则。
- [ ] 核对普通加密规则、海外销售部 - 2 特殊规则和 OpenAPI 规则。
- [ ] 运行 `git diff --check`。

### Task 3: 数据库执行后验证 SQL

**Files:**
- Modify: `/Users/martinjiang/VsCodeProjects/martin-dev-log/bi-cost/task_2026/analysis_report.md`

- [ ] 提供规则数量按部门/产品汇总 SQL。
- [ ] 提供当前加密业务部门收入与 MV 结果核对 SQL。
- [ ] 说明刷新 `dws.mv_sales_commission_recent_estimate` 后的验证顺序。
