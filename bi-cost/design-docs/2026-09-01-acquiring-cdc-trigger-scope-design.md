# ACQUIRING CDC 触发范围修复方案

## 摘要

修复 ACQUIRING 成本 CDC 作业的月份触发范围与删除函数范围不一致问题，避免无关标签更新时重复写入 OD/WP 日明细并触发主键冲突。

## 方案

在 `v_param` 的昨日更新标签条件中增加 `product_line = 'ACQUIRING'`，并限制 `provider` 为 `OD` 或 `WP`。保留按月重算、按天输出的现有逻辑及 `writeMode = 'insert'`。

## 验证

- 检查过滤条件位于 `v_param` 的月份触发查询中。
- 确认未修改 `report_date` 计算和 sink 写入模式。
- 使用 `git diff --check` 检查格式。
