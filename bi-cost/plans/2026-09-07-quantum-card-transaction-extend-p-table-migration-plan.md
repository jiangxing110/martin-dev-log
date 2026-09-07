# quantum_card_transaction_extend_p 表迁移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将仓库内交易扩展表脚本从旧表切换到 `public.quantum_card_transaction_extend_p`。

**Architecture:** 只做表名映射更新，保留现有 SQL 的字段、过滤、窗口和关联逻辑；同步维护 BB/QI DWM 表结构注释。

**Tech Stack:** Flink SQL、PostgreSQL SQL、Markdown、Git。

**Spec:** `design-docs/2026-09-07-quantum-card-transaction-extend-p-table-migration-design.md`

## Global Constraints

- 新物理表名必须是 `public.quantum_card_transaction_extend_p`。
- 不修改查询逻辑、字段逻辑、临时表名或无关文件。
- 不修改明确声明不依赖交易扩展表的 Qbit 交易宽表脚本。
- 保留工作区中已有的无关改动。

### Task 1: 更新实际 SQL 表引用

**Files:**
- Modify: `bb_cost_check/BB客户成本*.sql`
- Modify: `flink/quantum-v2/bb/batch/dwm_online_bb_card_transaction_detail_v2-batch-sql.sql`
- Modify: `flink/quantum-v2/bb/cdc/dwm_online_bb_card_transaction_detail_v2-cdc-sql.sql`
- Modify: `flink/quantum-v2/bb/check.sql`
- Modify: `flink/quantum-v2/qi/batch/dwm_online_qi_card_transaction_detail_v2-batch-sql.sql`
- Modify: `flink/quantum-v2/qi/cdc/dwm_online_qi_card_transaction_detail_v2-cdc-sql.sql`

- [x] 将上述文件中的实际旧物理表引用替换为 `public.quantum_card_transaction_extend_p`。
- [x] 保留 BB Flink 临时 source 名称及其下游引用不变。

### Task 2: 更新表结构说明

**Files:**
- Modify: `flink/quantum-v2/bb/table-scripts/dwm_bb_card_transaction_detail_v2_p.sql`
- Modify: `flink/quantum-v2/qi/table-scripts/dwm_qi_card_transaction_detail_v2_p.sql`

- [x] 将注释和字段说明中的旧交易主源名称更新为新表名。
- [x] 保留 Qbit 交易宽表脚本中的“不依赖交易扩展表”说明。

### Task 3: 静态验证

- [x] 搜索旧物理表名，确认无实际 SQL 引用。
- [x] 搜索新表名，确认所有受影响脚本均已覆盖。
- [x] 运行 `git diff --check`。
- [x] 检查 diff 仅包含本次表名迁移及方案/计划文档。
