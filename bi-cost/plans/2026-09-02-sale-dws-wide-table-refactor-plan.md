# 销售 DWS 13/14/18 宽表化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 13、14、18 的 CDC/Batch 改为窗口化明细 source、Flink 关系匹配和 Flink 聚合。

> 2026-09-02 补充：CDC 目录 01–22 按当前运行策略统一只保留 2026 年 Sink；2024/2025 历史数据通过 Batch 回刷。

**Architecture:** 交易 source 按窗口读取，关系 source 仅读取相关账户；直接关系和 root 关系分别匹配后以 `ROW_NUMBER()` 选优，再按原有 DWS 业务键聚合并写入年度分表。

**Tech Stack:** Flink SQL、PostgreSQL JDBC/ADBPG connector、Markdown。

**Spec:** `design-docs/2026-09-02-sale-dws-wide-table-refactor-design.md`

## Global Constraints

- 保留删除函数、原有 DWS 字段、年度分表 sink、确定性主键和 upsert 行为。
- Batch 使用 `start_date/end_date`，CDC 使用最近一天变更窗口。
- 不修改线上数据库，不 commit，不 push。

### Task 1: 重构 13/14/18 Batch source 与 Flink 聚合

**Files:**
- Modify: `task_2026/flink_reference/batch/13_dws_sale_card_transaction_v2-batch-sql.sql`
- Modify: `task_2026/flink_reference/batch/14_dws_sale_card_transaction_extend_v2-batch-sql.sql`
- Modify: `task_2026/flink_reference/batch/18_dws_sale_crypto_assets_transfers_v2-batch-sql.sql`

- [ ] 删除旧 PostgreSQL `source_dws_*` 聚合。
- [ ] 增加窗口化交易 source 和裁剪后的关系 source。
- [ ] 增加直接/root 关系匹配、`ROW_NUMBER()` 去重、sale/am 展开和 Flink 聚合。
- [ ] 保留原删除函数和年度 sink 写入。

> 2026-09-02：18 Batch 已完成切换；旧 source 定义暂保留但已不再被最终 sink 引用，便于回滚核对。

### Task 2: 重构 13/14/18 CDC source 与 Flink 聚合

**Files:**
- Modify: `task_2026/flink_reference/cdc/13_dws_sale_card_transaction_v2-cdc-sql.sql`
- Modify: `task_2026/flink_reference/cdc/14_dws_sale_card_transaction_extend_v2-cdc-sql.sql`
- Modify: `task_2026/flink_reference/cdc/18_dws_sale_crypto_assets_transfers_v2-cdc-sql.sql`

- [ ] 用最近一天变更 scope 裁剪当前有效交易。
- [ ] 增加独立关系 source、直接/root 匹配和去重展开。
- [ ] 保持 CDC 删除函数和年度 sink 行为。

> 2026-09-02：18 CDC 已完成切换；旧 source 定义暂保留但已不再被最终 sink 引用，便于回滚核对。

### Task 3: 静态验证

- [ ] 检查六个文件无旧 `source_dws_*` source。
- [ ] 检查时间窗口、关系匹配和 `ROW_NUMBER()` 结构。
- [x] 对 18 Batch/CDC 运行 `git diff --check`，并核对最终 sink 已引用 Flink 聚合视图。
