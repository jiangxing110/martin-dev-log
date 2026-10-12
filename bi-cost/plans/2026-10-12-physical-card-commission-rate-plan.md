# 实体卡毛利返佣率调整执行计划

**目标：** 调整销售佣金物化视图，使国内实体卡毛利按 100% 计佣、海外按 0% 计佣，同时保持普通量子卡佣金和 CDC 接口不变。

**方案：** [2026-10-12-physical-card-commission-rate-design.md](../design-docs/2026-10-12-physical-card-commission-rate-design.md)

**修改文件：**

- `/Users/martinjiang/VsCodeProjects/martin-dev-log/sale-repoet/sales-commission/table-scripts/mv_sales_commission_recent_estimate_v3.sql`

## 步骤

- [x] 按方案将 `commission_base` 定义为不含实体卡毛利的常规返佣基数。
- [x] 将 `estimated_commission` 改为“常规返佣基数 × 现有返佣率 + 实体卡毛利 × 部门实体卡费率”。
- [x] 在视图中输出 `physical_card_gp`、`physical_card_commission_rate`、`physical_card_commission`，并将实体卡佣金计入总额。
- [x] 国内 department_id 使用方案中的显式名单，海外及未知部门实体卡费率为 0。
- [x] 静态核对 `gp`、`commission_base`、`commission_rate` 和 `estimated_commission` 的关系，确认普通量子卡公式未变。
- [x] 确认物化视图名称、原有字段和记录粒度保留；CDC 仍读取原有显式字段清单。
- [ ] 上线后在 `changelogs/` 记录变更；本计划不执行数据库刷新或部署。

## 进度

- [x] 读取现有物化视图和部门组织表，确认问题位置及部门范围。
- [x] 编写并评审设计方案和执行计划。
- [x] 实施视图 SQL 并完成静态核对。
- [ ] 上线后补充发布日志。

> 物化视图 SQL 修改已完成；尚未在数据库执行刷新或部署。发布日志待实际上线后补充。
