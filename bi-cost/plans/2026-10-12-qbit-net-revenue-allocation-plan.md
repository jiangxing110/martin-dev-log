# Qbit 渠道净收入计算修复执行计划

**目标：** 修复 Qbit AM 明细逐行截零造成的渠道净收入和毛利池虚高，并使渠道返现接收行稳定可重复。

**方案：** [2026-10-12-qbit-net-revenue-allocation-design.md](../design-docs/2026-10-12-qbit-net-revenue-allocation-design.md)

**修改文件：**

- `/Users/martinjiang/VsCodeProjects/martin-dev-log/sale-repoet/sales-commission/table-scripts/mv_sales_commission_recent_estimate_v3.sql`

## 约束

- 仅 Qbit 保留逐行有符号有效收入；其他产品沿用现有截零逻辑。
- `cash_back_amount` 不纳入此次修改。
- 成本来源、总额和现有成本分摊方法不变。
- 保留物化视图名称、输出列、行粒度、CDC 和快照接口。
- 不刷新数据库物化视图，不部署，不执行 git commit 或 git push。

## 步骤

- [x] 对 Qbit 明细移除逐行 `GREATEST(..., 0)`，让负收入参与客户/渠道净额；其他产品维持原行为。
- [x] 为返现接收行增加 AM 和完整稳定排序键，继续只将渠道返现计入一条明细。
- [x] 静态核对样例净额为 `21,029.7701`，并确认渠道 GP 池以有符号收入合计计算。
- [x] 检查视图输出列、行粒度、CDC 接口未变，且没有接入 `cash_back_amount`。
- [x] 检查差异和空白错误；不运行测试或数据库刷新。
- [ ] 实际上线后再在 `changelogs/` 补充发布记录。

## 进度

- [x] 读取并评审方案，确认收入逐行截零及排序不唯一的问题。
- [x] 修改销售佣金物化视图 SQL。
- [x] 完成静态核对。
- [ ] 上线后补充发布日志。
