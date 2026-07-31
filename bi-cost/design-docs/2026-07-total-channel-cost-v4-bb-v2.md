# Total Channel Cost V4 BB V2 口径调整方案

Created Time: 2026-07-31 16:11:06
Updated Time: 2026-07-31 16:11:06

## 摘要

本次调整新增总渠道成本批处理 V4 脚本，仅更新 BB 量子卡成本来源和公式。V4 从 `dws.dws_bb_card_finance_daily_v2_p` 读取 BB 成本基础数据，并参考 `flink/total_cost/check/v2/query_bb_card_cost_detail_v2.sql` 计算 BB 成本；QI、SL、金融渠道成本逻辑保持 V3 不变。

## 调整范围

- 新增 `flink/total_cost/dws_online_total_channel_cost_daily_v4-batch-sql.sql`。
- BB 来源表从 `dws.dws_bb_card_finance_daily_p` 切换为 `dws.dws_bb_card_finance_daily_v2_p`。
- BB 成本补齐 AC Decline、Volume Fee Cost、Fixed Fee、Active Card Account Fee。
- Dollar Volume Fee 使用参考查询中的正向费率，不再沿用 V3 中负向金额公式。
- 保留总成本 sink：`dws.dws_total_channel_cost_daily_v2_p`。

## BB 成本公式

BB V4 成本包括：

- 普通授权笔数费用。
- Account Verification 授权笔数费用。
- Dollar Volume Fee。
- Reversal / Refund / Decline 费用。
- AC Decline 费用。
- Active Card Account Fee：`active_card_count * 0.1`。
- Volume Fee Cost：按月 `total_net_amount` 阶梯计算后按行净额占比分摊。
- Fixed Fee：`cost_fixed_fee`。

## Volume Fee 分摊

`query_bb_card_cost_detail_v2.sql` 用查询范围内 BB 总 `total_net_amount` 计算阶梯 Volume Fee。总成本 DWS 需要按 `report_date + account_id + sale_id + am_id` 落表，因此 V4 先按 `yyyyMM` 聚合月度 `total_net_amount`，再将月度 Volume Fee 按每行 `total_net_amount / month_total_net_amount` 分摊。

## 验证方式

- 检查 V4 SQL 不再引用旧 BB 来源表。
- 检查 V4 SQL 引用了 `dws_bb_card_finance_daily_v2_p`、`ac_m_int_decline_count`、`total_net_amount`。
- 检查 SQL 文本括号和关键语句结构。
