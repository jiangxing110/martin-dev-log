# QI CDC JDBC 驼峰字段修复方案

## 摘要

QI DWM CDC 的 JDBC 派生表输出带引号的驼峰字段，Flink JDBC 外层查询未引用标识符，导致 PostgreSQL 将 `transactionId` 折叠为 `transactionid` 后找不到列。

## 方案

- 参考对应 batch，将主交易 Source 的输出统一为小写下划线字段。
- 同步调整 Flink Source DDL 和下游字段引用。
- 保持昨天的 `updateTime/createTime/deleteTime` 查询窗口及业务计算逻辑不变。

## 验证

- Source 派生表不再输出带引号的驼峰别名。
- CDC 主交易 Source 字段与 batch 命名一致。
- SQL diff 不包含筛选窗口和分摊逻辑变更。
