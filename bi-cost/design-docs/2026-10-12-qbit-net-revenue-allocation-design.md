# Qbit 渠道净收入计算修复方案

## 摘要

修复销售佣金预估视图中 Qbit 收入逐行截零的问题，避免负数 AM 收入被 `GREATEST(..., 0)` 丢弃，导致客户/渠道收入和毛利池虚增。保留当前渠道返现单行挂载方式，但补齐稳定排序字段，避免并列时返现落到不确定的 AM 行。此次不接入 `cash_back_amount`，也不改变成本总额和既有成本分摊口径。

## 1. 目标

在 `dws.mv_sales_commission_recent_estimate` 中保留 Qbit 各 AM 行的正负收入，使渠道毛利池按客户、结算月、provider 汇总后的净收入计算；同时让渠道返现接收行在重复刷新时稳定。

## 2. 当前问题

`revenue_cost_allocated.allocated_effective_revenue` 在每条收入明细上先应用 `GREATEST(..., 0)`。当同一客户、月份、provider 有正负 AM 收入时，负数行会在渠道池汇总前被抹掉。

以已提供的数据为例：

```text
正收入行  7,089.58 + 渠道返现 23,636.7201 = 30,726.3001
负收入行 -9,696.53 被逐行截为 0
当前 Qbit 汇总 = 30,726.3001

应保留正负行后汇总：
7,089.58 + 23,636.7201 - 9,696.53 = 21,029.7701
```

此外，`cost_allocation_rn` 的窗口排序未包含 `am_id`。当 `effective_revenue` 非零标记、`sale_id` 和 `department_id` 都相同时，窗口排序不唯一，单行承接的渠道返现可能落到不同 AM 行。

## 3. 修复口径

1. 对 `qbit_card`，`allocated_effective_revenue` 保留收入、渠道返现和专项收入扣减的有符号结果，不在 AM 明细级应用 `GREATEST(..., 0)`；其他产品维持原逐行截零行为。
2. 渠道返现仍只计入当前规则选中的一条明细，以避免重复；在 `cost_allocation_rn` 排序中补入 `am_id` 及必要的稳定键，确保接收行可重复确定。
3. 客户/渠道毛利池继续汇总明细收入和成本后计算 GP；现有池级非负毛利规则保持不变。负收入行因此会降低渠道池净收入和 GP。
4. 保持当前成本源、成本总额、成本分摊分母、物化视图名称、输出列和行粒度不变。
5. 不读取或扣减 `public.cash_back_bonuses.cash_back_amount`；本次按用户说明排除该字段。

## 4. 范围

- 修改：`/Users/martinjiang/VsCodeProjects/martin-dev-log/sale-repoet/sales-commission/table-scripts/mv_sales_commission_recent_estimate_v3.sql`
- 不修改：CDC、快照 SQL、上游收入/成本表、返佣规则表及数据库中的物化视图实例。
- 不执行：数据库刷新、部署、提交或推送。

## 5. 验收标准

- 示例中的 Qbit 明细汇总为 `21,029.7701`，而不是 `30,726.3001`。
- 渠道返现仍只计入一条 Qbit 明细，且并列 AM 行时接收行由完整排序键稳定决定。
- 同一客户、月份、provider 的渠道 GP 以有符号收入汇总后计算；池级 GP 规则不变。
- 成本总额、物化视图输出结构和 CDC 接口不变。
- 视图 SQL 不包含 `cash_back_amount` 接入逻辑。
