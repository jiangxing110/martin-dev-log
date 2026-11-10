# 销售返佣实体卡毛利扩展至全渠道方案

## 摘要

销售返佣物化视图当前只挂载 `provider = 'IQ'` 的实体卡毛利。本次取消 IQ 限制，按月份、客户和渠道将上游 `physical_card_gp` 匹配到对应量子卡返佣行；部门费率、毛利及佣金公式、字段和粒度均保持不变。

## 目标

让销售返佣视图纳入所有渠道的实体卡毛利，不再遗漏非 IQ 渠道。

## 当前情况

`sales-commission/table-scripts/mv_sales_commission_recent_estimate_v3.sql` 从 `dws.dws_metrics_sales_revenue_monthly` 读取 `qbit_card / physical_card_gp`，按月份、root account 和 provider 汇总。但来源 CTE、毛利挂载 JOIN，以及实体卡毛利和佣金输出都限定 `provider = 'IQ'`，导致非 IQ 渠道无法进入视图。

## 方案

### 采用：取消 IQ 限制，沿用现有 provider 粒度匹配

- 保留上游筛选 `product = 'qbit_card'`、`metric_code = 'physical_card_gp'` 和现有月份范围。
- 去掉来源 CTE、JOIN 和实体卡毛利/佣金计算中的 `provider = 'IQ'` 条件。
- 继续按 `settlement_month + root_account_id + provider` 汇总和匹配，实体卡毛利挂到对应 provider 的量子卡行，避免跨渠道串数。
- 国内部门 100%、海外及未识别部门 0% 的实体卡费率，以及其余毛利、佣金和输出字段都保持原样。

### 未采用：跨 provider 汇总后挂到任意单行

该方式会丢失渠道归属，并可能把毛利挂到错误渠道的返佣记录；不符合“其他不变”的要求。

## 范围与约束

- 只修改销售返佣物化视图 SQL 中实体卡毛利的 provider 限制。
- 不改上游 `physical_card_gp` 业务公式、部门费率名单、普通佣金公式、CDC 字段、快照流程或视图粒度。
- 本仓库仅保存方案和执行记录；目标 SQL 位于相邻的 `sale-repoet` 项目。

## 验收标准

- 来源 CTE 可以读取各 provider 的 `qbit_card / physical_card_gp`。
- 每个 provider 的实体卡毛利只挂到同月份、同 root account、同 provider 的量子卡返佣记录。
- 非 IQ 渠道遵循现有部门费率规则；IQ 渠道及所有其他佣金口径不变。
- 不新增或删除对外字段，不改变视图记录粒度和 CDC/快照接口。
