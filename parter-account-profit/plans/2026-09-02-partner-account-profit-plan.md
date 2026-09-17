# 合伙人客户毛利 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 基于销售 v2 的底层收入、成本、返现和调整事实逻辑，独立计算账户级合伙人客户毛利，并每月 21 号固化上个月数据。

**Architecture:** 不读取 `dws.mv_sales_commission_recent_estimate`。合伙人视图直接复用销售 v2 的底层收入、成本、返现及 `bi_month_tag` 调整逻辑，以 root account 的 `referralCode` 关联新版合伙人。有渠道的 real_time 与 API 月结实收按共享毛利池分配；API 月费/一次性费用保留明细但不进入毛利返佣 gp；快照任务读取目标月份物化视图，在同一 statement set 中写入详情和主表。

**Tech Stack:** PostgreSQL/ADBPG materialized view、Flink SQL、JDBC/ADBPG connector、Markdown。

**Spec:** `/Users/martinjiang/VsCodeProjects/martin-dev-log/parter-account-profit/合伙人客户毛利设计文档.md`

## Global Constraints

- 本期落地客户经营毛利、量子账户/加密资产返佣配置及返佣结果表。
- `open_api` 与 `qbit_card` 对外统一为 `qbit_card`，使用 `source_product` 区分原始产品。
- 仅纳入 API 实收 `month_revenue`，不纳入 API 应收 `month_receivable`。
- 有渠道的 real_time 与 API 月结手续费共享 COGS、返现后的渠道毛利池；池毛利非正时两类 gp 均为 0。
- API 月费/一次性手续费保留实收明细，但不进入毛利阶梯返佣 gp。
- 负毛利在明细和汇总中原样保留，不在中间层归零。
- 返佣采用超额累进，负毛利不产生返佣，最终返佣金额不低于 0。
- 返佣结果表建立在 `public` schema，不使用 `dws` schema。
- 快照日期固定为每月 21 号，目标结算月为上个月月初。

### Task 1: Create DDL and materialized view

**Files:**
- Create: `table-scripts/mv_partner_account_profit_recent_estimate.sql`
- Create: `table-scripts/dws_partner_account_profit_snapshot_p.sql`
- Create: `table-scripts/dws_partner_account_profit_snapshot_detail_p.sql`
- Create: `cdc/sp_refresh_mv_partner_account_profit_recent_estimate.sql`

- [x] 建立物化视图，直接读取收入、成本、返现和调整事实表，以邀请码关联新版合伙人，并按客户/产品/渠道/费用项聚合。
- [ ] 建立主表和详情表，按 `snapshot_date` 分区并加入查询索引。
- [x] 静态检查字段、API 应收过滤、产品标准化和有渠道 API 月结共享毛利池公式。

### Task 2: Create snapshot jobs

**Files:**
- Create: `batch/dws_partner_account_profit_snapshot-batch-sql.sql`
- Create: `cdc/dws_partner_account_profit_snapshot-month-cdc-sql.sql`

- [ ] 批任务支持 `snapshot_date`、`settlement_month` 参数。
- [ ] 月任务自动使用当月 21 号和上个月月初。
- [ ] 同一 statement set 写详情和主表，保证幂等 upsert。

### Task 3: Create commission configuration and result job

**Files:**
- Create: `table-scripts/partner_gross_margin_config_quantum_crypto.sql`
- Create: `table-scripts/partner_gross_margin_commission_p.sql`
- Create: `batch/partner_gross_margin_commission-batch-sql.sql`

- [ ] 写入 `QUANTUM_ACCOUNT` 与 `CRYPTO_ASSETS` 的 10%/20% 默认阶梯。
- [ ] 按合伙人、客户、业务线、结算月计算并 upsert 返佣结果。
- [ ] 保留毛利、原始阶梯计算值、最终返佣金额和命中的配置 ID。

### Task 4: Verify

- [ ] 检查 SQL 中不存在费率、佣金计算逻辑。
- [ ] 检查 `month_revenue` 过滤、`source_product`、`root_account_referral_id` 和负数保留逻辑。
- [ ] 检查所有目标脚本 `git diff --check` 通过。
