# QI 渠道返现改按净消费计费方案

## 摘要

将 QI v2 财务汇总中的 Interchange、Incentive 两项渠道返现计费基数与 BI 净消费版本对齐，统一按非港 Closed/Pending 交易的净消费金额计算。

## 处理方案

- 同步修改 batch 与 CDC 两份 `dws_online_qi_card_finance_daily_v2` Flink SQL。
- 返现范围保留非港、`Closed/Pending` 条件，纳入 `Consumption`、`Reversal`、`Credit`。
- `Consumption` 金额正向计入，`Reversal/Credit` 金额负向计入，再分别乘以 0.02 和 0.0118。
- 更新 v2 目标表字段注释，明确“非港净消费金额”口径。
- 不调整其他成本基数、月度系数或固定渠道成本分摊逻辑。

## 验证

- batch 与 CDC 两份脚本均包含相同的净消费返现条件和正负方向。
- 两份脚本不再使用仅 `Consumption` 的返现基数表达式。
- `git diff --check` 通过。
