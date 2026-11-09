# BB 2026-10 返现率单独调整方案

## 摘要

合并月度 seed 已执行后，单独将 `ods.ods_bi_month_tag` 中 BB 2026-10 的 `BB_CASH_RATE` 更新为 `2.2698% × 1.0377`，结果为 `0.0235537146`。本次只更新这条已存在的有效配置，不重跑 QI seed，也不改其他月份。

## 范围

- 新增 `month-tag/bb_bi_month_tag_rate_update_2026_10.sql`。
- 仅匹配 `id=202611060901`、BB provider/product_line、fullCustomer、`BB_CASH_RATE`、`detail='2026-10'` 且未软删除的记录。
- 不直接连接数据库，不运行 BB DWS 回刷。

## 更新值

- 原基础 rate：`0.022698`（2.2698%）
- 调整系数：`1.0377`
- 新 rate：`0.022698 × 1.0377 = 0.0235537146`（2.35537146%）

## 写入方式

执行前查询目标行；在事务中按固定 ID 和完整业务范围更新 `amount`、`update_time`、`remarks`；通过 `RETURNING` 和提交后的查询核对。条件不匹配时 UPDATE 不影响其他配置。

## 验证

- 仅命中目标 ID 和 2026-10 BB tag。
- SQL 表达式精确得到 `0.0235537146`。
- 静态检查 SQL scope、返回核对和空白格式。
