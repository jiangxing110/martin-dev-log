# 销售毛利看板 SQL Implementation Plan

> **For agentic workers:** Use this plan to track SQL deliverables. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 参考 `sale-repoet/sales-commission` 的 SQL 包结构、物化视图与快照机制，新增销售毛利数据层 SQL。

**Architecture:** 使用 `dws_sales_metric_daily` 按 report_date 汇总收入和返现，沿用销售返佣视图的成本归集结果，并单独读取 QI/BZ RS 毛利返现；建立月度估算视图、快照表、12 小时视图刷新、每月 8 号快照和 20 号完整重算补入任务。

**Tech Stack:** PostgreSQL/ADBPG、pg_cron、Flink SQL JDBC/ADBPG connector。

**Spec:** `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/开发方案.md`

## Global Constraints

- `dws_sales_metric_daily` 是日粒度，先按 report_date 汇总到月，再按 sale_id 聚合。
- 客户返现、代收返现和毛利返现均参与 Rebate；金额正负号保留，不归零。
- Pref_GP = Pref_Rev - Cost；Cashflow_GP_sale = Cashflow_Rev_sale - Cost。
- 8 号快照固化上月；20 号补数复用当月 8 号 snapshot_date，并完整重算后 upsert 汇总及明细。
- 不连接数据库，不执行部署，不执行 git commit/push。

### Task 1: DDL and estimate view

**Files:** `qbit-assets/sprint-19/销售毛利报表/sql/table-scripts/`

- [x] 创建汇总快照表和明细快照表，按 snapshot_date 年分区。
- [x] 创建近期估算物化视图及 12 小时刷新调度。
- [x] 保留负数，不引入佣金计算字段或佣金毛利截断。

### Task 2: Snapshot jobs

**Files:** `qbit-assets/sprint-19/销售毛利报表/sql/cdc/`

- [x] 创建每月 8 号快照任务，同一 Statement Set 写入汇总与明细。
- [x] 创建每月 20 号 API 月账单补数任务，使用原 snapshot_date 重算并 upsert 两张表。

### Task 3: Static review

**Files:** `qbit-assets/sprint-19/销售毛利报表/sql/check/`

- [x] 添加估算视图与快照按销售对账 SQL。
- [x] 检查金额列没有 GREATEST/ABS 截断及脚本无行尾空格。
- [ ] 在目标 ADBPG/Flink 环境执行 DDL 与 CDC 作业验证。
