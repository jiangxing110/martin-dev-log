# 合伙人毛利刷新接入销售刷新作业设计

> Updated Time: 2026-11-12 20:17:49

## 目的

让销售毛利物化视图和合伙人毛利物化视图按固定顺序刷新：先刷新 `dws.mv_sales_commission_recent_estimate`，再刷新 `dws.mv_partner_account_profit_recent_estimate`；快照作业安排在该刷新作业成功之后。

## 当前情况

- 销售刷新 Flink 作业调用 `dws.sp_refresh_mv_sales_commission_recent_estimate()`。
- 合伙人刷新函数 `dws.sp_refresh_mv_partner_account_profit_recent_estimate()` 已存在，也有独立 Flink JDBC 触发脚本可供手动补刷。
- 合伙人视图 SQL 当前读取底层收入、成本等事实表，没有直接读取销售佣金物化视图；刷新函数注释仍保留“先刷新销售视图”的先后约定。
- 两个快照 SQL 只读取合伙人毛利视图并写快照表。用户已回退其中的内嵌刷新修改，保持只做快照。

## 设计

通过一个 PostgreSQL 包装函数串行调用两个现有刷新函数，Flink 作业只保留一个 JDBC DML：

1. 新增独立的 Flink 作业文件 `dws_online_sales_commission_and_partner_account_profit_recent_estimate-refresh-cdc-sql.sql`，不覆盖原销售刷新脚本。
2. 新增 ADBPG 包装函数 `dws.sp_refresh_mv_sales_and_partner_recent_estimate()`。
3. 包装函数先调用 `dws.sp_refresh_mv_sales_commission_recent_estimate()`，完成后再调用 `dws.sp_refresh_mv_partner_account_profit_recent_estimate()`。
4. 合并刷新 Flink SQL 只调用包装函数一次，并由 `blackhole` sink 承接固定 affected_rows；避免 Batch 应用多 DML 需要额外启用多作业配置。
5. 任一步骤抛错都会使包装函数调用失败，调度平台不应继续启动快照作业。
6. 调度平台配置快照作业依赖该刷新作业成功。

独立的合伙人刷新 Flink SQL 保留为手动单独补刷入口。batch 和月度 CDC 快照脚本保持不变，不包含刷新逻辑。

## 考虑的方式

1. **数据库包装函数 + Flink 单个 DML（采用）**：避免 Batch 应用多作业限制，并在数据库函数内明确保证销售→合伙人的顺序。
2. **Flink 两个 DML 并配置多作业参数**：需要在部署运行参数中启用应用管理和多作业执行；当前目标是让脚本不依赖该额外配置，因此不采用。
3. **保留两个刷新作业，由调度器串联**：顺序清晰，但需要额外维护作业依赖；独立合伙人刷新脚本仍用于手动补刷。
4. **把刷新逻辑内嵌到快照 SQL**：会耦合刷新和快照职责，且快照脚本已被用户恢复，不采用。

## 范围与验收

- 新增 `sale-repoet/sales-commission/cdc/sp_refresh_mv_sales_and_partner_recent_estimate.sql`，串行调用两个现有刷新函数。
- 保留 `sale-repoet/sales-commission/cdc/dws_online_sales_commission_recent_estimate-refresh-cdc-sql.sql` 为仅刷新销售视图的旧作业。
- 新建 `sale-repoet/sales-commission/cdc/dws_online_sales_commission_and_partner_account_profit_recent_estimate-refresh-cdc-sql.sql`，只执行一个 JDBC INSERT 调用包装函数。
- 保留 `parter-account-profit/cdc/dws_online_partner_account_profit_recent_estimate-refresh-cdc-sql.sql` 作为合伙人单独补刷入口。
- 不修改 batch 和月度快照 SQL，不改物化视图计算口径、快照字段和返佣公式。
- 销售刷新成功后才执行合伙人刷新；合伙人刷新成功后，调度器才能启动快照作业。
- Flink 作业需添加 PostgreSQL JDBC driver 附加依赖。
