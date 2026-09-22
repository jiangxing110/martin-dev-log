# BB 渠道返现视图费率对齐方案

## 摘要

BB 批处理已经根据月度 `BB_CASH_RATE` 计算 `cashback_income`。销售佣金和合伙人毛利视图仍使用固定 `0.021195`，会与 DWS 当前结果不一致。本次改为直接汇总 DWS 的 `cashback_income`。

## 规则

```text
BB 渠道返现 = SUM(dws_bb_card_finance_daily_v2_p.cashback_income)
```

`cashback_income` 已经包含净消费基数和当月实际返现率，视图不再重复计算费率。

## 不变项

- BB 净消费基数仍由 BB batch/CDC 产出。
- BB 成本计算不变。
- 渠道返现仍只挂到同一客户/渠道的一条 qbit_card 明细。
- 合伙人视图与销售视图使用相同的 BB 渠道返现事实。
