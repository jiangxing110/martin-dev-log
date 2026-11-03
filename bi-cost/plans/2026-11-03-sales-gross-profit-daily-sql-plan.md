# 销售毛利日区间 SQL 改造实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将销售毛利数据层从月汇总改为保留业务日 `report_date`，以支持任意闭区间日期查询，同时维持现有每月 8 日快照与 20 日幂等回刷节奏。

**Architecture:** 估算物化视图按业务日和销售明细维度产数；汇总快照按 `report_date + sale_id`、明细快照按 `report_date + sale_id + 客户/产品/渠道/来源` 保存；`snapshot_date` 继续标识快照版本并沿用原分区和回刷调度。批处理、CDC 投影和对账 SQL 使用相同列顺序与业务键。

**Tech Stack:** PostgreSQL/ADBPG、增量物化视图、Flink SQL JDBC/ADBPG connector。

**Spec:** `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/日维度重构设计稿.md`

## Global Constraints

- 闭区间日期条件按真实业务 `report_date` 筛选，不能先截断到月份后再查询。
- `snapshot_date` 是快照版本日期；保留每月 8 日固化和 20 日复用同版本日期回刷，不改成每日调度。
- 月份仍作为追溯字段保留，但不再作为区间过滤的唯一日期字段。
- 客户返现、代收返现和毛利返现进入 `Rebate`；所有金额保留正负，不归零、不取绝对值。
- `Pref_GP = Pref_Rev - Cost`，`Cashflow_GP_sale = Cashflow_Rev_sale - Cost`；不得重复扣减已计入 `Cost` 的返现。
- 成本从佣金估算视图使用的成本源表按源 `report_date` 直接归集，不读取佣金视图的 `cogs`，不再按收入权重二次均摊；已按客户/日期分摊的 `dwm_finance_channel_cost_p` 直接使用其 `cost_amount`。
- `ods_bi_month_tag` 的月度调账按所属月份 1 号作为 `report_date`；其他日成本按源业务日期记录，按有效日期映射销售归属，不复制或均摊成本金额。
- 不编译 Java、不连接数据库、不部署、不执行快照任务、不执行 git commit/push。

## Files and Responsibilities

- `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/sql/table-scripts/mv_sales_gross_profit_recent_estimate.sql`：统一日来源并保留 `report_date`，按日生成可汇总明细；成本直接取佣金视图的原始成本表并按源日期、销售归属记录，不使用佣金结果中的 `cogs`。
- `.../sql/table-scripts/dws_sales_gross_profit_snapshot_p.sql`：销售日汇总快照 DDL。
- `.../sql/table-scripts/dws_sales_gross_profit_snapshot_detail_p.sql`：客户/产品/渠道/来源日明细快照 DDL。
- `.../sql/table-scripts/schedule_refresh_mv_sales_gross_profit_recent_estimate.sql`：保留既有刷新周期；若对象名或依赖改变则同步调整。
- `.../sql/batch/dws_online_sales_gross_profit_snapshot-batch-sql.sql`：参数化指定快照版本和日期范围的手动/初始化回刷。
- `.../sql/cdc/dws_online_sales_gross_profit_snapshot-month-cdc-sql.sql`：每月 8 日固化上个业务月的日行。
- `.../sql/cdc/dws_online_sales_gross_profit_api-month-billing-cdc-sql.sql`：20 日完整重算并回写同一快照版本。
- `.../sql/batch/dws_online_sales_gross_profit_recent_estimate-batch-sql.sql`：日粒度来源和结果汇总检查。
- `.../sql/check/sales_gross_profit_month_reconciliation.sql`：调整为按日期范围及销售对账。

## Review Focus

- 同一销售同一天包含多个来源行时，汇总金额不得在视图或快照中重复累加。
- 返现、成本或毛利为负数时，视图、快照和对账结果保留原符号。
- `provider IS NULL` 与具名 provider 必须保持独立明细。
- 20 日回刷同一 `snapshot_date` 时须完整重算并 upsert，不可在 8 日值上累加。
- 区间跨月时必须按每条 `report_date` 筛选；快照版本选择不能把较新月份版本误用于旧月份。

---

### Task 1: 改造日粒度估算物化视图

**Files:**
- Modify: `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/sql/table-scripts/mv_sales_gross_profit_recent_estimate.sql`

**Interfaces:**
- Produces: `report_date`, source trace fields, seller/detail dimensions and signed gross-profit metrics.
- Consumers: both snapshot writers, estimate query, batch/reconciliation SQL.

- [x] 保留销售日指标表、API 日收入来源及销售佣金预估视图中的原始 `report_date`，将日字段纳入各自分组键和稳定 ID。
- [x] 将成本来源改为佣金预估视图所依赖的原始成本表；按源 `report_date` 记录，使用成本表已有的客户/销售归属，不读取佣金视图 `cogs`，不按收入权重二次分摊。
- [x] 将毛利返现映射到已清洗的 `dws_sales_metric_daily.client_rebate` 日来源；不再读取独立 `gross_profit_rebate` 指标，避免重复计算。
- [x] 物化视图最终明细按设计稿的日粒度输出，派生指标保留负数并遵守公式。
- [x] 静态检查最终 SELECT、GROUP BY、hash 键及索引均包含 `report_date`。

**Dependency resolved:** 用户确认毛利返现与客户返现一起存入 `dws_sales_metric_daily.client_rebate`，代收返现单独存入 `client_collection_rebate`，二者均按 `metric_type = 'cost'` 取数。快照既有 `gross_profit_rebate` 列为兼容保留并写0；总 Rebate 只由上述两类返现合计，避免重复。

### Task 2: 改造汇总和明细快照 DDL

**Files:**
- Modify: `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/sql/table-scripts/dws_sales_gross_profit_snapshot_p.sql`
- Modify: `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/sql/table-scripts/dws_sales_gross_profit_snapshot_detail_p.sql`

**Interfaces:**
- Consumes: Task 1 daily estimate rows.
- Produces: partitioned daily snapshot tables used by API and batch/CDC writers.

- [x] 汇总表新增 `report_date` 并将日销售作为业务粒度；明细表新增 `report_date` 作为日粒度，保留报表月份追溯字段。
- [x] 保留 `(id, snapshot_date)` 主键、`snapshot_date` 分区和 2026–2028 分区；确定性 ID 额外包含 `report_date`。
- [x] 增加 `report_date + sale_id` 汇总索引和日明细筛选索引，更新表/字段注释。
- [x] 静态核对主表、分区、索引字段及金额约束。

### Task 3: 对齐批处理和 CDC 快照写入

**Files:**
- Modify: `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/sql/batch/dws_online_sales_gross_profit_snapshot-batch-sql.sql`
- Modify: `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/sql/cdc/dws_online_sales_gross_profit_snapshot-month-cdc-sql.sql`
- Modify: `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/sql/cdc/dws_online_sales_gross_profit_api-month-billing-cdc-sql.sql`

**Interfaces:**
- Consumes: Task 1 daily estimate and Task 2 table schemas.
- Produces: daily detail and summary rows for one snapshot version.

- [x] JDBC 投影和 Flink source schema 增加 `report_date` 并与物化视图列对齐。
- [x] 明细快照 ID 按快照版本和日明细源 ID 确定；汇总快照按 `snapshot_date + report_date + sale_id` 聚合。
- [x] 8 日任务仅改变写入粒度，保留上月固化和现有分区日期逻辑。
- [x] 20 日任务按完整日估算结果重算目标月份，沿用 8 日 `snapshot_date` 并幂等 upsert 两张快照表。
- [x] 参数化批处理按业务月边界选取目标日期行。
- [x] 静态核对 Statement Set 两路 sink 的列顺序、主键字段、筛选边界和 snapshot_date。

### Task 4: 更新检查 SQL 并完成静态核对

**Files:**
- Modify: `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/sql/batch/dws_online_sales_gross_profit_recent_estimate-batch-sql.sql`
- Modify: `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/sql/check/sales_gross_profit_month_reconciliation.sql`

- [x] 来源检查输出日粒度的行数、收入、返现、成本和毛利。
- [x] 对账 SQL 接受闭区间起止日期，按 `report_date + sale_id` 对比视图及每月最新快照。
- [x] 完成 SQL 静态字段/粒度一致性检查；未执行编译或数据库作业。

## Execution Notes

- 用户已明确要求直接修改 SQL，因此计划执行方式为当前会话内逐项实施。
- 当前数据库表数据不能从现有本地 SQL 静态证明；实施时依赖用户确认的真实日来源字段，不根据月字段造日日期。
