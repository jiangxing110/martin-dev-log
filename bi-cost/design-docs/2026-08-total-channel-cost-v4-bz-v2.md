# Total Channel Cost V4 BZ V2 口径调整方案

Created Time: 2026-08-05 15:15:07
Updated Time: 2026-08-05 15:15:07

## 摘要

本次调整在总渠道成本 V4 批处理脚本中加入 BZ 量子卡渠道成本。V4 从 `dws.dws_bz_card_finance_daily_v2_p` 读取 BZ v2 成本基础数据，按基础金额/笔数乘对应 rate 后汇总进入 `dws.dws_total_channel_cost_daily_v2_p` 的 `quantum_cost` 成本桶。

## 调整范围

- 修改 `flink/total_cost/dws_online_total_channel_cost_daily_v4-batch-sql.sql`。
- 新增 BZ source：`source_dws_bz_card_finance_daily_v2_p`。
- 新增 BZ 成本分支，`product_line = 'QUANTUM_CARD'`，`cost_source = 'BZ'`。
- QI、BB、SL、金融渠道成本逻辑保持 V4 原有行为。
- 输出仍写入 `dws.dws_total_channel_cost_daily_v2_p`。

## BZ 成本公式

BZ V4 成本包括：

- `clearing_base_amt * reimbursement_rate`
- `refund_base_amt * reimbursement_rate`
- `visa_charges_base_amt * visa_charges_rate`
- `card_create_count * card_setup_rate`
- `card_create_count * account_activation_rate`
- `card_active_count * account_on_file_rate`
- `settlement_volume * service_fee_rate`
- `verify_count * verify_fee_rate`
- `auth_count * auth_fee_rate`
- `clearing_count * clearing_fee_rate`
- `refund_count * refund_fee_rate`
- `reversal_count * reversal_fee_rate`
- `cost_fixed_fee`

## 验证方式

- 检查 V4 SQL 引用了 `dws_bz_card_finance_daily_v2_p`。
- 检查 BZ source 字段覆盖上述公式需要的 base/count/rate/fixed fee 字段。
- 检查 BZ 分支进入 `QUANTUM_CARD`。
- 检查 SQL 文本括号和空白。
