# 销售返佣实体卡毛利全渠道支持实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 取消销售返佣 v3 物化视图对 IQ 的实体卡毛利限制，并保留所有现有业务口径。

**Architecture:** 在 v3 中继续按结算月、root account 和 provider 汇总/匹配 `physical_card_gp`。移除来源、挂载和佣金输出中的 IQ 条件；不改部门费率、输出列、返佣公式、行粒度或 v2。

**Tech Stack:** PostgreSQL 物化视图 SQL。

**Spec:** [2026-11-10-sales-commission-physical-card-all-channels-design.md](../design-docs/2026-11-10-sales-commission-physical-card-all-channels-design.md)

## Global Constraints

- 仅修改 `mv_sales_commission_recent_estimate_v3.sql` 中实体卡毛利的 provider 限制。
- 保持上游筛选 `product = 'qbit_card'`、`metric_code = 'physical_card_gp'` 和月份范围。
- 保持按 `settlement_month + root_account_id + provider` 汇总及匹配。
- 保持国内 100%、海外及未知部门 0% 的实体卡佣金率和其余佣金逻辑。
- 不修改 v2、上游毛利公式、CDC、快照任务、视图字段或记录粒度。

## Review Focus

- 相同客户同月的不同 provider 不得串用实体卡毛利；保留 provider 匹配条件。
- 没有对应 provider 返佣行时不得重复挂载；保留原有目标行选择逻辑。
- 国内、海外及未知部门费率应保持原名单和默认值。
- 非实体卡收入、普通量子卡佣金和 v2 文件均不应变化。
- 输出列顺序、名称和视图记录粒度不应变化。

---

### Task 1: 扩展 v3 实体卡毛利到所有 provider

**Files:**
- Modify: `/Users/martinjiang/VsCodeProjects/martin-dev-log/sale-repoet/sales-commission/table-scripts/mv_sales_commission_recent_estimate_v3.sql`
- Reference: `design-docs/2026-11-10-sales-commission-physical-card-all-channels-design.md`

- [x] 移除实体卡毛利来源 CTE 中的 `r.provider = 'IQ'` 限制。
- [x] 移除实体卡毛利 JOIN 和实体卡毛利/费率输出逻辑中的 `o.provider = 'IQ'` 限制；保留产品、月份、客户、provider 匹配和目标行选择条件。
- [x] 保持实体卡佣金费率名单、佣金计算公式、其他字段和分摊逻辑不变。
- [x] 静态检查 SQL 内容，确认 v2、上游来源公式、CDC/快照接口均未修改，且 provider 粒度匹配仍然存在。Git diff/status 检查受本机 Xcode 许可提示阻断。

### 交付记录

- [x] 修改完成后将实施步骤标记完成。
- [ ] SQL 上线后在 `changelogs/` 记录变更；本计划不执行数据库部署或刷新。
