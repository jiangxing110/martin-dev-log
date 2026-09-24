# 全球账户成本按客户级分摊 Implementation Plan

**Goal:** 将全球账户 BZ、CL、OFFLINE 成本作为未分渠道成本分摊到 `group_account` 收入，避免最终 `cogs` 为 0。

**Architecture:** 仅修改销售佣金物化视图 SQL 中全球账户成本 CTE 的 provider 输出和聚合粒度。其他产品成本逻辑不变，继续通过现有 `provider_cogs` 匹配。

**Tech Stack:** PostgreSQL materialized view SQL；本地静态 SQL 校验。

**Spec:** `design-docs/2026-09-24-global-account-cost-allocation-design.md`

## Global Constraints

- 不修改量子卡、加密和 OpenAPI 的 provider 级成本匹配。
- 不执行 git commit 或 git push。
- 保留原文件 Created Time，并更新 Updated Time。

## Review Focus

- 全球账户收入 provider 为空时，BZ、CL、OFFLINE 成本仍能被分摊。
- 全球账户多条收入明细时，未分渠道成本只分摊一次，不重复计算。
- 其他产品的渠道成本仍按 provider 匹配。

### Task 1: 修改全球账户成本归属

**Files:**
- Modify: `/Users/martinjiang/VsCodeProjects/martin-dev-log/sale-repoet/sales-commission/table-scripts/mv_sales_commission_recent_estimate_v2.sql`

- [ ] 将全球账户渠道成本、结汇成本和线下 fee_cost 的 provider 统一改为 `NULL::varchar`。
- [ ] 删除这些 CTE 中按 provider 的分组，仅按结算月和 root_account_id 汇总。
- [ ] 保留其他产品成本 CTE 不变。

### Task 2: 静态验证

**Files:**
- Verify: `/Users/martinjiang/VsCodeProjects/martin-dev-log/sale-repoet/sales-commission/table-scripts/mv_sales_commission_recent_estimate_v2.sql`

- [ ] 检查 SQL 关键字、括号和 UNION 列类型。
- [ ] 检查成本 CTE 已进入 `v_cost_by_account_product`。
- [ ] 检查 `git diff --check` 无空白错误。
