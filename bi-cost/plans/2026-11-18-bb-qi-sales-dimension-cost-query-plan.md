# BB / QI 销售维度成本查询实施计划

> **执行方式：** 当前会话由 Codex 逐项实施；不提交 Git。

**目标：** 在 `online/check/v2/` 新增 BB 与 QI 当月成本的销售维度查询脚本。

**方案：** 复制两份现有客户维度查询的公式和成本项，将归集键切换为 DWS 的 `sale_id`。支持可选 `sale_id` 参数过滤指定销售；NULL 查询全部，空字符串查询未分配销售。空 ID 统一规范化为 NULL，并显示为“未分配销售”；按销售 ID 生成逐项成本、返现和总成本。

**参考方案：** `design-docs/2026-11-18-bb-qi-sales-dimension-cost-query-design.md`

## 约束

- 使用 PostgreSQL / ADBPG 语法，日期区间左闭右开。
- BB、QI 原查询的费用公式和返现收入处理口径保持一致。
- 不关联销售关系维表；未分配销售数据保留。
- 不修改现有客户维度查询，不执行 Git commit / push。

## 文件

- 新增 `online/check/v2/查询_BB当月成本_销售维度.sql`：BB 成本及 Cashback 按销售汇总。
- 新增 `online/check/v2/查询_QI当月成本明细_销售维度.sql`：QI 成本及 Interchange / Incentive 按销售汇总。

## 实施步骤

- [x] 核对输入查询字段、费用公式、日期口径及 DWS 中的 `sale_id`。
- [x] 新增 BB 销售维度 SQL，并保留各项基数、费率、金额、成本总计和返现。
- [x] 新增 QI 销售维度 SQL，并保留各项基数、加权费率、金额、成本总计和返现。
- [x] 对照输入 SQL 静态核对成本项编号与数量、聚合键和输出列；未连接数据库执行。
- [x] 增加可选 `sale_id` 过滤参数，支持指定销售、全部销售和未分配销售查询。
