# BB Auth 2026-02 月表字段兼容执行计划

**Goal:** 修复 BB Auth DWM 批处理在 2026-02 月表上读取不存在字段导致启动失败的问题。

**Scope:** `dwm_online_bb_card_auth_detail_v2-batch-sql.sql`、`dwm_online_bb_card_auth_detail_v2-cdc-sql.sql`、`fn_bb_card_auth_detail_by_window` 和配套文档记录。

## Steps

- [x] 确认报错字段来自 JDBC source 子查询。
- [x] 对比 2026-02 月表字段，确认成本计算必需字段齐全。
- [x] 移除对子查询中 `"Merchant Name"`、`"MCC"` 等 2026-02 缺失字段的直接引用。
- [x] 使用 `NULL` 占位保持 DWM sink schema 不变。
- [x] 修复 CDC 使用的 `fn_bb_card_auth_detail_by_window`，避免函数读取缺失扩展字段。
- [x] 修复 CDC DWM 视图，`merchant_name`、`mcc` 使用 `NULL` 占位。
- [x] 搜索确认 batch SQL 不再直接引用 2026-02 缺失字段。
- [x] 记录设计方案和变更日志。

## Verification

- 检查 batch SQL 不再包含 PostgreSQL 源列引用 `"Merchant Name"` 或 `"MCC"`。
- 检查 CDC 函数中扩展字段返回 `NULL`，不再读取月表缺失列。
- 检查 Flink source 字段数和 JDBC 子查询输出字段数保持一致。
