# STAGING 销售关系与量子卡交易宽表全量同步方案

## 摘要

新增两份独立的 Flink JDBC 批处理脚本，全部从 STAGING PostgreSQL 读取业务源表，并将销售关系维表和量子卡交易宽表全量写回 STAGING 对应目标表，供每日调度执行。

## 处理方案

- 新增 `flink/quantum-v2/qbit-card-transaction-widetable/staging/dim_online_sale_account_relation-staging-full.sql`。
- 新增 `flink/quantum-v2/qbit-card-transaction-widetable/staging/dwm_online_qbit_card_transaction_widetable-staging-full.sql`。
- 两份脚本的 JDBC host、port、username、password 统一使用：
  `STAGING_PG_ASSETS_HOST`、`STAGING_PG_ASSETS_PORT`、`STAGING_PG_ASSETS_USERNAME`、`STAGING_PG_ASSETS_PASSWORD`。
- JDBC database 使用 `${secret_values.STAGING_PG_ASSETS_DATABASE}`；脚本不再依赖 ADB 连接变量。
- 销售关系脚本全量读取 `public."salesAccountRelation"`，写入 `dim.dim_sale_account_relation_p`。
- 交易宽表脚本全量读取 `public."qbit_card_transaction"` 及其卡、卡组、账户、账户扩展、账户关系维度，并读取 STAGING 的 `dim.dim_sale_account_relation_p`，写入 `dwm.dwm_quantum_card_transaction_p`。
- 交易宽表移除 `${start_time}`、`${end_time}` 时间窗口过滤；每日运行通过 JDBC sink 的 upsert 主键覆盖相同主键记录。
- 调度顺序固定为：先执行销售关系全量脚本，再执行交易宽表全量脚本，避免宽表读取到旧的销售关系维表。

## 边界与风险

- 本次“全量”定义为全量扫描源表并 upsert 目标表，不在 Flink 作业内自动 `TRUNCATE` 目标表。
- 若源表发生硬删除，目标表不会因本作业自动删除对应历史行；如需严格镜像，需在调度层增加经确认的目标表清理步骤。
- 两个目标表及其分区、字段定义默认已由对应建表 DDL 在 STAGING 数据库中准备完成。
- STAGING 目标表需先执行 `staging/dwm_qbit_card_transaction_widetable_p-staging-widen.sql`，将已确认超长的 255/30 长度字段扩为 `text`。

## 验证

- 静态检查两份脚本只使用 STAGING 连接变量，不残留 ADB 连接变量。
- 检查交易宽表脚本不包含 `${start_time}`、`${end_time}` 过滤条件。
- 检查源表、目标表和脚本依赖顺序，并运行 `git diff --check`。
