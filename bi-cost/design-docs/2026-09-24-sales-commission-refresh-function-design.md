# 销售佣金刷新函数返回类型修复方案

## 摘要

销售佣金刷新 CDC 任务通过 JDBC source 读取刷新函数结果，但数据库函数返回 `void`，Flink SQL 又将其强制转换为 `text`，导致任务初始化失败。本次将函数改为返回状态文本。

## 方案

- 刷新函数返回类型改为 `text`。
- 刷新成功返回 `OK`。
- 检测到已有刷新任务运行时返回 `SKIPPED_ALREADY_RUNNING`。
- 刷新异常继续抛出，并在异常前释放 advisory lock。
- Flink CDC 脚本继续使用 `CAST(function() AS text)` 读取结果。

## 范围

- `sales-commission/cdc/sp_refresh_mv_sales_commission_recent_estimate.sql`

## 验证

先在 ADB 执行函数脚本，再执行：

```sql
SELECT "dws"."sp_refresh_mv_sales_commission_recent_estimate"();
```

正常结果应为 `OK`，随后再部署或重启 Flink 刷新任务。
