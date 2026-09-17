# bi_month_tag 全量同步新增 account_id

## 变更内容

- 新增 `month-tag/bi_month_tag_full_sync.sql`。
- 更新 `month-tag/sync`，补齐相同的 `account_id` 全量同步逻辑。
- 全量同步 `public.bi_month_tag` 到 `ods.ods_bi_month_tag`。
- 源表、目标表及显式写入映射均包含 `account_id`。
- 全量脚本支持传入 `startTime`、`endTime`，按 `update_time` 左闭右开过滤；不传参数时保持全量范围。

## 验证

- 完成字段存在性和字段顺序静态检查。
- 未执行数据库同步；上线时运行该 Flink SQL 后，可用 `account_id` 条件分别核对源表与 ODS 表。
