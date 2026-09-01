# GLOBAL_ACCOUNT Settlement transfer 字段映射修复方案

## 摘要

修复 settlement CDC 作业启动时读取 `public.transfer` 失败的问题。源表使用驼峰字段名，SQL 当前错误地直接引用了不存在的蛇形字段。

## 方案

在 JDBC `table-name` 查询中使用实际字段名并通过别名映射到 Flink 表结构：`accountId`、`usdAmount`、`settlementCurrency`、`transferType`、`transactionTime`、`deleteTime`；其中 `usdAmount` 显式转换为 `NUMERIC(20,4)`，匹配 Flink 的 `DECIMAL(20,4)`。settlement 的月度成本通过 `bi_month_tag.tag = 'SETTLEMENT_COST'` 触发和读取；由于产出 provider 为 NULL，相关连接使用 NULL-safe 比较。

## 验证

- 确认 source 查询不再直接引用 `account_id` 等不存在的物理列名。
- 确认别名仍与 `source_transfer` 的 Flink 字段一致。
- 使用 `git diff --check` 检查格式。
