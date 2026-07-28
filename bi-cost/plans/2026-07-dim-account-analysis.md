# Dim Account Analysis 执行计划

## 目标

新增 `dim.dim_account_analysis` 维表及 Flink batch/cdc 脚本，统一沉淀客户基础属性和五类业务激活时间。

## 文件

- [x] 新增设计方案：`design-docs/2026-07-dim-account-analysis.md`
- [x] 新增执行计划：`plans/2026-07-dim-account-analysis.md`
- [x] 新增 DDL：`flink/account_analysis/table-scripts/dim_account_analysis.sql`
- [x] 新增 batch 脚本：`flink/account_analysis/batch/dim_online_account_analysis-batch-sql.sql`
- [x] 新增 cdc 脚本：`flink/account_analysis/cdc/dim_online_account_analysis-cdc-sql.sql`
- [x] 校验新增 SQL 关键对象、sink 字段顺序和引用表名

## 实施步骤

- [x] 确认目标 schema 使用 `dim`。
- [x] 确认脚本结构参考 `flink/quantum-v2` 和 `flink/account_relation`。
- [x] 编写 `dim.dim_account_analysis` 建表、注释和索引。
- [x] 编写 batch 初始化脚本，读取 ADBPG ODS/DIM 表并全量 upsert。
- [x] 编写 CDC 增量脚本，使用 `account` 为主 CDC 源，业务事实表通过 postgres-cdc 聚合刷新。
- [x] 运行文本级校验，确认三份 SQL 文件存在并包含核心字段与 source/sink。

## 验收标准

- 三份 SQL 文件均存在。
- DDL 包含用户要求的所有字段。
- batch/cdc sink 字段顺序与目标表字段一致。
- 激活时间计算包含子母账户以及 Gateway、Distributor root account 合并。
