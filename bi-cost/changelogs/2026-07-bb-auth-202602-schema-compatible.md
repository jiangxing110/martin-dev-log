# BB Auth 2026-02 月表字段兼容

## 变更时间

2026-07-30 20:27:55

## 变更内容

- 修复 BB Auth DWM 批处理读取 2026-02 月表时报 `"Merchant Name"` 不存在的问题。
- 批处理 JDBC 子查询不再直接读取 2026-02 缺失的 `"Merchant Name"`、`"MCC"`、`pos_service_code`、`authorization_id_code`。
- 修复 CDC Auth DWM 使用的 `fn_bb_card_auth_detail_by_window`，函数返回结构保持不变，扩展字段统一返回 `NULL`。
- CDC Auth DWM 视图中 `merchant_name`、`mcc` 使用 `NULL` 占位。
- `merchant_name` 和 `mcc` 在 DWM 中使用 `NULL` 占位，保持目标表结构不变。

## 影响范围

- 文件：`flink/quantum-v2/bb/batch/dwm_online_bb_card_auth_detail_v2-batch-sql.sql`
- 文件：`flink/quantum-v2/bb/cdc/dwm_online_bb_card_auth_detail_v2-cdc-sql.sql`
- 文件：`flink/quantum-v2/bb/ddl-migrations/20260731_update_fn_bb_card_auth_detail_by_window_optional_fields.sql`
- 指标：Decline、AC Decline、Active Card 计算口径不变。
