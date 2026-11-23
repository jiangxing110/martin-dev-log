# 销售毛利 Open API 月账单应收实收拆行实施计划

> 按已通过的拆行设计执行。金额保留正负号；不执行数据库 SQL、不编译、不运行测试、不提交或推送。

**目标：** 将 Open API 月账单应收与实收分别呈现在详情和详情导出中；应收保留渠道，实收使用不区分渠道的实际实收指标。

**方案：** V1 估算视图和明细快照增加内部 `api_bill_type` 字段；Batch 与 CDC 原样传递。详情 SQL 根据该字段将 `product` 映射为 `open_api_receivable` / `open_api_received` 后聚合。VO 和导出 BO 不新增类型字段，导出继续复用详情 VO 的 `product`。汇总查询与汇总快照结构保持不变。

**已通过设计：** `qbit-assets/sprint-19/销售毛利报表/OpenAPI月账单应收实收拆行设计.md`（方案已由用户确认）。

## 实施步骤

### 1. 修改 V1 估算视图来源与内部类型

**文件：**

- `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/sql/table-scripts/mv_sales_gross_profit_recent_estimate.sql`

- [x] Open API 应收继续取 `dws_metrics_sales_revenue_monthly` 的 `month_receivable`，保持结算月首日归属。
- [x] Open API 实收基数使用 `dws_sales_metric_daily` 的 `api_client_bill_actual_received_amount`，聚合时不区分 provider；`Cashflow_Rev` 使用该实收原值。
- [x] `Cashflow_Rev_sale` 在该实收基数上继续扣除月结 KYC、实体卡手续费和最低承诺三项，不改变其他收入行。
- [x] 输出 `api_bill_type`：`month_receivable` 标记 `RECEIVABLE`，`api_client_bill_actual_received_amount` 标记 `RECEIVED`，其他来源为 `NULL`。
- [x] 保持已有成本、返现、负数和三项毛利公式（含 `physical_card_gp`）不变，并核对 CTE 与 UNION 列顺序。
- [x] 视图 `sales_rows` 仅抑制没有 main 收入、返现、实体卡毛利或关联成本的 Open API 合成行；生产快照、生产估算和本地快照详情 Mapper 也过滤全零且未分类的 Open API 占位行，兼容历史快照。其它产品零值、真实 Open API 金额、负数及独立应收/实收行保留。

### 2. 扩展明细快照结构和固化任务

**文件：**

- `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/sql/table-scripts/dws_sales_gross_profit_snapshot_detail_p.sql`
- `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/sql/batch/dws_online_sales_gross_profit_snapshot-batch-sql.sql`
- `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/sql/cdc/dws_online_sales_gross_profit_snapshot-month-cdc-sql.sql`
- `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/sql/cdc/dws_online_sales_gross_profit_api-month-billing-cdc-sql.sql`

- [x] 在明细快照 DDL 增加可空 `api_bill_type` 列及注释，并将现有产品索引扩展此列；汇总快照 DDL 不变。
- [x] 在 Batch/两个 CDC 作业的 source 表、JDBC 投影、明细临时视图和 sink 表中按相同列顺序传递该列及 Cashflow 三项；API 月账单 CDC 同时过滤 NULL/空白 sale_id，避免写入快照表失败。
- [x] 汇总快照聚合不读取该字段，避免应收/实收拆行影响列表销售合计。
- [x] Ruling: 保留视图现有 ID 生成规则；应收和实收的 `metric_code` / `source_type` 已不同，ID 输入天然区分两行，因此无需把类型追加到哈希键，避免其他既有来源行 ID 全量变化。

### 3. 修改详情分页与导出共用查询

**文件：**

- `/Users/martinjiang/IdeaProjects/qbit-assets/qbit-core/src/main/resources/mapper/dws/DwsSalesGrossProfitMapper.xml`
- `/Users/martinjiang/IdeaProjects/qbit-assets/qbit-core/src/main/resources/mapper/dws/DwsLocalSalesGrossProfitMapper.xml`
- `/Users/martinjiang/IdeaProjects/qbit-assets/qbit-core/src/main/java/com/qbit/common_all/analysis/domain/vo/salesgrossprofit/SalesGrossProfitSummaryVO.java`
- `/Users/martinjiang/IdeaProjects/qbit-assets/qbit-core/src/main/java/com/qbit/common_all/analysis/domain/vo/salesgrossprofit/SalesGrossProfitDetailVO.java`

- [x] 生产快照、生产估算和本地快照详情查询均根据 `api_bill_type` 输出展示 product：应收为 `open_api_receivable`、实收为 `open_api_received`、其他沿用原 product。
- [x] 按转换后的 product 分组，确保应收行和实收行不会合并。
- [x] 详情 product 筛选支持 `open_api_receivable`、`open_api_received`；原有 `open_api` 筛选仍可查到全部 Open API 行。
- [x] VO 不增加 `apiBillType`；详情导出继续从同一 VO 的 product 取值，因此页面与导出行及表头一致。
- [x] 汇总及详情 VO 的 Schema 说明改用新的 Open API 实收指标名。
- [x] 汇总分页、汇总导出及其 SQL 不改变。

### 4. 对齐指标说明并做静态核查

**文件：**

- `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/销售毛利报表指标独立计算SQL.md`
- `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/销售毛利报表前后端对接文档.md`
- `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/开发方案.md`

- [x] 更新 Open API 实收来源说明为 `api_client_bill_actual_received_amount`，明确实收不分渠道、整体实收取原值、销售维度实收扣三项；指标文档补充两种口径各自的独立 SQL。
- [x] 说明详情 product 的两个展示值；内部 `api_bill_type` 不属于接口或导出字段。
- [x] 静态检查视图/Batch/CDC/DDL 列数和顺序、详情分组/筛选和导出映射；执行 `git diff --check`。不编译、不运行测试或数据库 SQL。

## 关键验收点

- 应收行按客户、日期、provider 保留渠道，实收行按客户、日期汇总且 provider 为 NULL；页面 product 分别显示 `open_api_receivable` 和 `open_api_received`。
- 实收行的 `Cashflow_Rev` 对应不区分渠道的 `api_client_bill_actual_received_amount` 原值；`Cashflow_Rev_sale` 对应该值减去三项月结费用。应收继续按 provider 展示。
- 列表聚合和汇总导出指标不因明细拆行发生变化。
- 详情 API 和详情导出均无独立 `api_bill_type` 字段，负金额不归零。


## 执行记录

- Final review: self-review；未派发审查代理，遵守当前会话的多代理限制。
- 用户补充：CSV 中这类全零 open_api 占位行可省略；仅在 sales_rows 的 Open API 行上加约束，真实金额和负数仍保留。
- 实现：视图和详情 Mapper 均已增加对应过滤。页面和详情导出共用 Mapper，因此两处都会隐藏全零未分类占位行；新生成的估算数据也不会再产出该行。
- 静态检查：视图/明细 DDL/Batch/CDC 字段传递与顺序一致；详情 SQL 类型映射、筛选、分组与导出 product 映射通过静态断言；两个仓库目标文件 git diff --check 无输出。
- 按用户既有要求不编译；未运行测试或数据库 SQL。
- 明细快照表 DDL 已更新但尚未在数据库执行；部署后须重建明细表并重跑目标月份快照，旧快照不会自动补 api_bill_type。
