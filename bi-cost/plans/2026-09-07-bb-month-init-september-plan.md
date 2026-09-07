# BB 2026 年 8/9 月初始化脚本 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修正 2026 年 8 月 BB 月初始化脚本，并生成完整月份范围的 2026 年 9 月脚本。

**Architecture:** 以现有 8 月脚本为唯一模板，仅调整文件名、日期边界和更新时间；不改变 SQL 业务逻辑。

**Tech Stack:** Flink SQL、PostgreSQL JDBC、Markdown、Git。

**Spec:** `design-docs/2026-09-07-bb-month-init-september-design.md`

## Global Constraints

- 8 月时间范围必须是 `[2026-08-01, 2026-09-01)`。
- 9 月时间范围必须是 `[2026-09-01, 2026-10-01)`。
- 保留现有 SQL 逻辑和字段定义不变。

### Task 1: 修正 8 月脚本

**Files:**
- Modify: `flink/quantum-v2/bb/month-init/active-card-count/dws_bb_active_card_2026-08.sql`
- Modify: `flink/quantum-v2/bb/month-init/card-finance/dws_bb_card_finance_2026-08.sql`
- Modify: `flink/quantum-v2/bb/month-init/channel-fixed-fee/dws_bb_channel_fixed_fee_2026-08.sql`

- [x] 将 `2026-08-23` 替换为 `2026-09-01`。
- [x] 保留创建时间并更新文件头更新时间。

### Task 2: 生成 9 月脚本

**Files:**
- Create: `flink/quantum-v2/bb/month-init/active-card-count/dws_bb_active_card_2026-09.sql`
- Create: `flink/quantum-v2/bb/month-init/card-finance/dws_bb_card_finance_2026-09.sql`
- Create: `flink/quantum-v2/bb/month-init/channel-fixed-fee/dws_bb_channel_fixed_fee_2026-09.sql`

- [x] 基于修正后的 8 月脚本复制生成。
- [x] 将所有 8 月日期顺延为 9 月，将 9 月结束边界顺延为 10 月。
- [x] 更新文件名、月份标题和更新时间。

### Task 3: 静态验证

- [x] 检查 8 月脚本不存在 `2026-08-23`。
- [x] 检查 9 月脚本使用 `[2026-09-01, 2026-10-01)`。
- [x] 运行 `git diff --check`。
