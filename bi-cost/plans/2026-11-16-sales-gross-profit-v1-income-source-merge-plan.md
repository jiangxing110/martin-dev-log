# 销售毛利 V1 收入及调账来源合并实施计划

> **For agentic workers:** 按步骤修改与核对 SQL；使用 checkbox 跟踪进度。遵守用户要求，不执行数据库 SQL、不编译、不提交或推送。

**Goal:** 将毛利 V2 中新增的 Open API 月账单收入、量子卡渠道返现、BI 月度收入及返现调整并入现有 V1 物化视图。

**Architecture:** 新增三个与 V1 输出列兼容的 source CTE，并 `UNION ALL` 加入 `all_rows`，继续由 V1 现有聚合和派生指标逻辑计算结果。保留 V1 成本来源、日粒度、视图名及负数处理。

**Tech Stack:** PostgreSQL / ADBPG SQL，物化视图。

**Spec:** `design-docs/2026-11-16-sales-gross-profit-v1-income-source-merge-design.md`

## Global Constraints

- 修改 `mv_sales_gross_profit_recent_estimate`，不创建或切换到 V2 视图。
- 只合并 Open API 月账单收入、BB/QI/BZ 渠道返现、`ods_bi_month_tag` 月度调账来源。
- 保留 V1 日成本逻辑；BB 的 `volume_fee_cost` 直接取已按日分摊的来源列，IQ 成本保留 `report_date + sale_id` 归属，不做二次收入权重分摊。
- 月度来源按业务月份 1 号记录；日来源保留来源日；金额符号原样保留。
- 不执行建视图、刷新、数据库 SQL 或编译；不提交或推送。

## Review Focus

- 新 CTE 列顺序、类型和 `all_rows` 的 V1 行结构一致。
- 新增收入/返现指标不会与 `dws_sales_metric_daily` 已有指标重复计入。
- BI 月度 tag 正负号、产品映射、有效销售归属时间边界符合 V2 当前逻辑。
- 视图名、成本 CTE 和负数毛利公式保持 V1 现状。

### Task 1: 将 V2 新来源并入 V1

**Files:**
- Modify: `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/销售毛利报表/sql/table-scripts/mv_sales_gross_profit_recent_estimate.sql`

**Interfaces:**
- Consumes: V1 的 `account_root_relation`、`recent_sales_metric` 及现有账户/销售映射；V2 的三类新增来源查询。
- Produces: 维持 V1 列结构的月度 API 收入、渠道返现收入、月度调账行，供 `all_rows` 继续聚合。

- [x] 加入 `monthly_api_income_rows`，读取 `dws_metrics_sales_revenue_monthly.offline_api_income_amount` 并按 `settlement_month` 首日落日。
- [x] 加入 `qbit_card_channel_rebate_rows`，按来源 `report_date + sale_id` 读取 BB/QI/BZ 渠道返现。
- [x] 加入 `bi_month_adjustment_rows`，复制已定义 tag 的收入/返现符号映射、月初日期和调账时点销售归属。
- [x] 在 `all_rows` 中并入三类新来源，保持 V1 视图名、最终公式和输出索引不变。
- [x] BB 成本改为直接汇总 `volume_fee_cost`，移除视图内按月重算的阶梯费部分。
- [x] 静态检查 CTE 字段顺序和聚合路径；不执行 SQL 或编译。
