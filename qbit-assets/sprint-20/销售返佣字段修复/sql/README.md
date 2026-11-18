# 销售返佣字段修复 SQL

本目录按 Sprint 19 销售毛利报表的 `table-scripts`、`batch`、`cdc`、`check` 结构组织。收入统计单独建模，不把实际收入混入佣金有效收入、GP 或佣金明细。

## 执行顺序

1. 在 ADBPG 执行 `table-scripts/dws_sales_commission_income_snapshot_detail_p.sql`，创建收入快照明细表及年度分区。
2. 执行 `table-scripts/mv_sales_commission_performance_income_recent.sql`，创建近六个自然月的收入物化视图。
3. 执行 `table-scripts/sp_refresh_mv_sales_commission_performance_income_recent.sql`，创建收入视图刷新函数。
4. 确认销售佣金和合伙人利润的既有刷新函数已创建，再执行 `table-scripts/sp_refresh_mv_sales_commission_income_partner_profit_recent.sql`。
5. 部署 `cdc/dws_online_sales_commission_and_partner_account_profit_recent_estimate-refresh-cdc-sql.sql`，替换现有 Flink JDBC 刷新作业，使单次触发依次刷新销售佣金、绩效收入、合伙人利润三个物化视图。数据库不使用 `pg_cron`，沿用当前 Flink 外部调度。
6. 8 号快照运行前，确认上述刷新任务完成；再执行 `batch/dws_online_sales_commission_snapshot-batch-sql.sql`，传入 `snapshot_date` 和 `settlement_month`，在一个 Statement Set 中写佣金主表、佣金明细表和收入明细表。
7. 单独排查/手动刷新时，可执行 `batch/dws_online_sales_commission_income_recent_estimate-batch-sql.sql`；执行完后用 `check/sales_commission_income_month_reconciliation.sql` 按月、销售/AM 和收入项目核对。

## 关键口径

- 收入视图直接使用各来源记录中的 `sale_id`、`am_id`，不连接当前销售关系。
- 所有收入按月粒度保存，`activity_month` 固定记为该月 1 号（如 `2026-09-01`），表示整个 9 月，不代表只统计 9 月 1 日。
- BB/QI 渠道返现源表虽然按日记录，仍按 `report_date` 汇总整月后写入月初；销售和 AM 继续按源记录归属分组。
- BB/QI 来源的 `account_id` 是底层账户；物化视图先通过 `public.api_account_relation.account_id` 映射 `root_id`，再按 `root_account_id` 聚合并写入快照。未找到有效映射时保留来源 `account_id`。
- OpenAPI 的 `activity_month` 按实际收款日期所在月归月，另保留账单月份 `bill_month`。
- QI Interchange / Incentive 按来源 SQL 的 `base * rate` 汇总，且仅取 `special_fee_type IS NULL`。
- BB/QI 渠道返现作为收入单独计入；不混入佣金的 `effective_revenue`、成本或 GP。
- 快照 batch 的 `${settlement_month}` 是目标活动月（`yyyy-MM`），`${snapshot_date}` 是快照日期。

## 部署说明

包装函数名为 `dws.sp_refresh_mv_sales_commission_income_partner_profit_recent`。旧包装函数不会由这些脚本自动删除；确认 Flink 作业切换到新函数后，可另行评估清理旧函数。
