# bi_month_tag 全量同步新增 account_id 方案

## 摘要

新增一个 Flink JDBC 全量同步脚本，将业务 PostgreSQL 的 `public.bi_month_tag` 全量写入 ADB PG 的 `ods.ods_bi_month_tag`，并补齐新增的 `account_id` 字段。

## 处理方案

- 新增独立脚本 `month-tag/bi_month_tag_full_sync.sql`，并同步更新现有 `month-tag/sync`。
- 源表和目标表均声明 `account_id STRING`，目标表继续以 `id` 作为 upsert 主键。
- 使用显式字段清单进行 `INSERT ... SELECT`，确保 `account_id` 按列名位置同步，并保留 `delete_time` 以传播软删除状态。
- 采用现有 JDBC/ADB PG 连接配置和批处理参数，执行全量读取，不增加增量过滤条件。
- 支持 `${startTime}`、`${endTime}` 参数按 `update_time` 左闭右开过滤；参数为空时分别回退到 `1970-01-01 00:00:00` 和 `9999-12-31 23:59:59`，保持全量同步行为。

## 验证

- 静态检查源表、目标表、INSERT 列表和 SELECT 列表均包含 `account_id`。
- 检查字段顺序一致，并运行 `git diff --check`。
