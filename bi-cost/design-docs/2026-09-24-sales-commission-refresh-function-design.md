# 销售佣金刷新函数返回类型修复方案

## 摘要

销售佣金刷新 CDC 任务需要通过 JDBC source 调用刷新函数，但函数返回值没有业务意义。本次保留函数的 `void` 接口，由 PostgreSQL 子查询在函数执行后返回固定的数值列给 Flink。

## 方案

- 刷新函数保留 `RETURNS void`。
- JDBC 子查询调用函数后返回固定 `affected_rows = 1`。
- 刷新异常继续抛出，并在异常前释放 advisory lock。
- Flink CDC 脚本使用 `affected_rows BIGINT` 读取结果，保持与 BB 月初始化任务一致。

## 范围

- `sales-commission/cdc/sp_refresh_mv_sales_commission_recent_estimate.sql`

## 验证

先在 ADB 执行函数脚本，再执行：

```sql
SELECT "dws"."sp_refresh_mv_sales_commission_recent_estimate"();
```

函数调用成功后应正常返回一行 `affected_rows = 1`，随后再部署或重启 Flink 刷新任务。
