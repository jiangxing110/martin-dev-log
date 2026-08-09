# QI CDC dim_account 字段修复

## 摘要

QI DWM CDC 的 `source_dim_account` JDBC 查询错误读取了
`dim.dim_account.delete_time`，但实际表不存在该列，导致 Source `open()` 失败。

本次删除 Flink Source DDL 和 JDBC 子查询中的该字段。QI batch 已采用相同的
四字段口径，且下游仅使用 `id/account_type/type/system_type`，因此不改变业务结果。

