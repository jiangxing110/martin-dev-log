# 合伙人毛利刷新接入销售刷新作业设计

## 目的

让销售毛利物化视图和合伙人毛利物化视图按固定顺序刷新：先刷新 `dws.mv_sales_commission_recent_estimate`，再刷新 `dws.mv_partner_account_profit_recent_estimate`；快照作业安排在该刷新作业成功之后。

## 当前情况

- 销售刷新 Flink 作业调用 `dws.sp_refresh_mv_sales_commission_recent_estimate()`。
- 合伙人刷新函数 `dws.sp_refresh_mv_partner_account_profit_recent_estimate()` 已存在，也有独立 Flink JDBC 触发脚本可供手动补刷。
- 合伙人视图 SQL 当前读取底层收入、成本等事实表，没有直接读取销售佣金物化视图；刷新函数注释仍保留“先刷新销售视图”的先后约定。
- 两个快照 SQL 只读取合伙人毛利视图并写快照表。用户已回退其中的内嵌刷新修改，保持只做快照。

## 设计

在现有销售刷新 Flink SQL 作业末尾增加第二个 JDBC 刷新调用：

1. 先执行现有销售刷新 INSERT。
2. 销售刷新完成后，再执行 `dws.sp_refresh_mv_partner_account_profit_recent_estimate()`。
3. 为合伙人刷新定义 JDBC source 和 `blackhole` sink，保持 `table.dml-sync = true`，确保按 SQL 顺序同步执行；任一步骤失败则刷新作业失败。
4. 调度平台配置快照作业依赖该刷新作业成功。

独立的合伙人刷新 Flink SQL 保留为手动单独补刷入口。batch 和月度 CDC 快照脚本保持不变，不包含刷新逻辑。

## 考虑的方式

1. **把合伙人刷新追加到现有销售刷新 Flink 作业（采用）**：一次调度内按销售→合伙人顺序刷新，减少维护两条定时刷新链路的风险。
2. **保留两个刷新作业，由调度器串联**：顺序清晰，但需要额外维护作业依赖；独立合伙人刷新脚本仍用于手动补刷。
3. **把刷新逻辑内嵌到快照 SQL**：会耦合刷新和快照职责，且快照脚本已被用户恢复，不采用。

## 范围与验收

- 修改 `sale-repoet/sales-commission/cdc/dws_online_sales_commission_recent_estimate-refresh-cdc-sql.sql`，在销售刷新之后增加合伙人刷新。
- 保留 `parter-account-profit/cdc/dws_online_partner_account_profit_recent_estimate-refresh-cdc-sql.sql` 作为合伙人单独补刷入口。
- 不修改 batch 和月度快照 SQL，不改物化视图计算口径、快照字段和返佣公式。
- 销售刷新成功后才执行合伙人刷新；合伙人刷新成功后，调度器才能启动快照作业。
- Flink 作业需添加 PostgreSQL JDBC driver 附加依赖。
