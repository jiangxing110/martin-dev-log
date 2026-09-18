# STAGING 销售关系与量子卡交易宽表全量同步

## 变更内容

- 新增 STAGING 销售关系全量脚本：
  `flink/quantum-v2/qbit-card-transaction-widetable/staging/dim_online_sale_account_relation-staging-full.sql`。
- 新增 STAGING 量子卡交易宽表全量脚本：
  `flink/quantum-v2/qbit-card-transaction-widetable/staging/dwm_online_qbit_card_transaction_widetable-staging-full.sql`。
- 两份脚本均从 STAGING PostgreSQL 读取并写入 STAGING，对应连接变量为 `STAGING_PG_ASSETS_*`。
- JDBC database 使用 `STAGING_PG_ASSETS_DATABASE`，不再固定写死数据库名。
- 交易宽表取消时间窗口过滤，改为每日全量扫描并按主键 upsert。
- 调度顺序为销售关系维表先执行、交易宽表后执行。
- 新增 STAGING 宽表超长字段迁移脚本，将已确认超长的 255/30 长度字段扩为 `text`，避免全量同步因历史长值失败。

## 验证

- 已完成连接变量、数据库名、源表、目标表和全量条件静态检查。
- 未执行真实数据库同步；上线调度时需确认 `STAGING_PG_ASSETS_DATABASE` 对应数据库及目标表分区已准备完成。
- 需先在 STAGING 数据库执行宽表字段迁移，再重跑交易宽表全量脚本。
