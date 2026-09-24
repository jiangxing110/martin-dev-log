# GLOBAL_ACCOUNT BZ 按客户数分摊实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement the plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 GLOBAL_ACCOUNT / BZ 成本按当月 Active ZB 客户数平均分摊，避免按支付流水或子账户数量重复分摊。

**Architecture:** 从 ODS 读取 `bi_month_tag` 的 BZ 月度成本金额，并从 `ods_global_sub_account` 筛选 Active ZB 子账户。按父客户 `account_id` 去重生成客户基础明细，每个客户的 `basis_count` 固定为 1，再由已有月度分摊逻辑计算 `amount / customer_count`。

**Tech Stack:** Flink SQL、PostgreSQL JDBC source、DWM 成本表。

**Spec:** `design-docs/2026-09-24-global-account-bz-customer-allocation-design.md`

## Global Constraints

- BZ 金额来源必须是 `bi_month_tag.amount`。
- 客户数必须按父客户 `account_id` 去重。
- 一个客户有多个 Active ZB 子账户时只能分配一份客户配额。
- 不修改 CL、OFFLINE 的统计逻辑。
- 不执行 git commit 或 git push。

## Review Focus

- 同一客户有多个 Active ZB 子账户时，`basis_count` 仍为 1。
- 未达到目标月月末前创建的客户不应进入该月分摊。
- 非 Active、已删除或非 ZB 子账户不应进入分母。
- 全部客户成本之和应回到 `bi_month_tag` BZ 金额总和。

### Task 1: 更新 BZ 分摊基础

- [x] 在批处理、CDC v2、CDC 脚本中读取 `ods_global_sub_account`。
- [x] 按 `provider = 'ZB'`、`status = 'Active'`、未删除和创建时间过滤客户。
- [x] 每个父客户输出一行，使用 `CAST(1 AS DECIMAL(20, 4)) AS basis_count`。
- [x] 保留现有月度金额除以基础总量的下游分摊逻辑。

### Task 2: 静态验证与回刷

- [ ] 检查三个脚本不再使用 `COUNT(DISTINCT g.id)` 作为分摊权重。
- [ ] 运行 `git diff --check`。
- [ ] 回刷目标月份 BZ DWM 成本，再刷新下游销售毛利视图。
