# 合伙人毛利刷新接入销售刷新作业实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将合伙人毛利视图刷新接到现有销售毛利刷新作业之后，使链路按销售刷新、合伙人刷新、快照的顺序执行。

**Architecture:** 在销售刷新 Flink JDBC 作业中保留销售刷新 INSERT，并在其后通过第二个 JDBC source 调用合伙人刷新函数，由 `blackhole` sink 消费调用结果。使用 `table.dml-sync = true` 串行完成两次刷新；调度平台在刷新作业成功后再启动快照。

**Tech Stack:** Flink SQL、JDBC connector、PostgreSQL/ADBPG、blackhole sink。

**Spec:** `/Users/martinjiang/VsCodeProjects/martin-dev-log/bi-cost/design-docs/2026-11-12-partner-profit-snapshot-refresh-design.md`

## Global Constraints

- 销售刷新 INSERT 必须先于合伙人刷新 INSERT。
- 刷新函数失败时，调度平台不得继续运行快照作业。
- 使用现有 `secret_values.ADB_PG_*` 连接配置和 `org.postgresql.Driver`。
- 销售刷新作业附加 PostgreSQL JDBC driver JAR 依赖。
- 保留独立合伙人刷新脚本作为手动补刷入口。
- 保持 partner batch 和月度 CDC 快照脚本不变，不执行 git commit 或 push。

## Review Focus

- JDBC source 调用 PostgreSQL `void` 函数时，使用返回固定 `affected_rows` 的子查询，确保调用被执行。
- 两个 JDBC DML 在 `table.dml-sync = true` 下顺序执行，不并发触发。
- 合伙人刷新步骤失败后，Flink 作业必须失败，外部调度不得启动快照。
- 合伙人独立刷新脚本仍可用于手动补刷，不改变快照表写入。
- 销售和合伙人刷新共用正确的 PostgreSQL JDBC 依赖。

---

### Task 1: 在销售刷新 Flink 作业中追加合伙人刷新

**Files:**
- Modify: `/Users/martinjiang/VsCodeProjects/martin-dev-log/sale-repoet/sales-commission/cdc/dws_online_sales_commission_recent_estimate-refresh-cdc-sql.sql`
- Keep: `/Users/martinjiang/VsCodeProjects/martin-dev-log/parter-account-profit/cdc/dws_online_partner_account_profit_recent_estimate-refresh-cdc-sql.sql` as manual partner-only refresh.
- Keep unchanged: `/Users/martinjiang/VsCodeProjects/martin-dev-log/parter-account-profit/batch/dws_partner_account_profit_snapshot-batch-sql.sql`
- Keep unchanged: `/Users/martinjiang/VsCodeProjects/martin-dev-log/parter-account-profit/cdc/dws_partner_account_profit_snapshot-month-cdc-sql.sql`

**Interfaces:**
- Consumes: Existing PostgreSQL functions `dws.sp_refresh_mv_sales_commission_recent_estimate()` and `dws.sp_refresh_mv_partner_account_profit_recent_estimate()`.
- Produces: One Flink trigger job that refreshes sales first, partner second; the snapshot jobs continue to read the refreshed partner materialized view.

- [x] Add a JDBC source and `blackhole` sink for the partner refresh function, matching the existing sales refresh connector configuration.
- [x] Place partner refresh INSERT after sales refresh INSERT; preserve `table.dml-sync = true`.
- [x] Add/update header notes explaining the two-step order and PostgreSQL JDBC dependency.
- [x] Keep both snapshot SQL files unchanged and retain the independent partner refresh script as a manual-only entry.

