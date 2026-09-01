# GLOBAL_ACCOUNT BZ CDC 触发范围修复方案

## 摘要

修复 GLOBAL_ACCOUNT/BZ 成本 CDC 作业的月份触发范围与删除范围不一致问题，避免其他产品线或 provider 的月度标签更新时重复生成 BZ 日明细并触发主键冲突。

## 背景

作业按 `source_month` 触发、按 `report_date` 产出日明细。当前 `v_param` 从所有昨日更新的月度标签推导月份，但删除函数仅处理 `GLOBAL_ACCOUNT + BZ`。因此非 BZ 标签更新也会触发 BZ 月度重算，旧数据未被删除时使用 `INSERT` 会产生 `(id, report_date)` 重复键。

## 方案

在目标 CDC SQL 的 `v_param` 查询中增加：

```sql
t.product_line = 'GLOBAL_ACCOUNT'
AND t.provider = 'BZ'
```

这样仍保持“按月触发、按天产出”，但触发来源与删除函数的作用域一致。保留 sink 的 `writeMode = 'insert'`，不通过 upsert 掩盖数据范围问题。

## 验证

- 静态确认过滤条件位于 `v_param` 的昨日更新条件中。
- 确认未修改 `report_date` 计算、日明细聚合和 sink 写入模式。
- 使用 `git diff --check` 检查格式。
