# Total Channel Cost Flink Design

## 1. 目标

总渠道成本按客户、日期、销售关系归集四类成本：

```text
total_channel_cost
= acquiring_cost
+ business_cost
+ quantum_cost
+ crypto_cost
```

当前成本来源分两类：

```text
1. BB/QI/SL 卡渠道 DWS 成本
2. 金融渠道成本 DWM
```

## 2. 表定位

### dwm_finance_channel_cost_p

这是全产品线金融渠道成本归因明细表。

承载从 `bi_month_tag` 后置分摊得到的金融渠道成本，例如：

- 量子账户: BPC、Sumsub、IDEMIA、HZ_BANK
- 全球账户: BZ/ZB、CL
- 加密账户: Thunes、Cregis、TZ-wire、TZ-sell、Safeheron、Bitstamp
- 收单账户: Orenda、World Pay

不承载：

- `dws_bb_card_finance_daily_p`
- `dws_qi_card_finance_daily_p`
- `dws_sl_card_finance_daily_p`

这些卡渠道 DWS 直接作为总成本 DWS 的来源，避免和金融渠道成本重复计算。

粒度：

```text
report_date + account_id + product_line + provider + cost_type + source_month + source_tag + sale_id + am_id
```

`cost_amount` 是最终归因金额，金额来源统一来自 `bi_month_tag.amount`。

明细表同时保留分摊审计字段：

- `source_month`: 来源账单月份，取当月第一天
- `source_tag`: `bi_month_tag.tag`
- `source_amount`: `bi_month_tag.amount`
- `product_line`: 产品线，决定进入总成本表哪个成本桶
- `month_day_count`: 当月天数，月度成本按天均摊时参与分摊
- `basis_count` / `month_basis_count`: 数量型分摊分子和分母
- `basis_amount` / `month_basis_amount`: 金额型分摊分子和分母
- `allocation_rate`: 分摊比例

分区按 `report_date` 月分区。月度成本按规则展开到当月每日，交易/KYC类成本按业务发生日期归属。

### dws_total_channel_cost_daily_p

这是最终总渠道成本日汇总表。

粒度：

```text
report_date + account_id + sale_id + am_id
```

字段拆分：

- `acquiring_cost`: 收单渠道成本
- `business_cost`: 业务渠道成本
- `quantum_cost`: 量子卡渠道成本
- `crypto_cost`: 加密渠道成本
- `total_channel_cost`: 四类成本合计

BB/QI/SL/金融渠道明细的拆分只保留在来源表和计算口径中。

总表不保留以下维度：

- `provider`
- `cost_type`
- `source_tag`
- 单独的 `channel` 行维度

也就是说，总表是按客户+日期+销售关系聚合后的宽表，渠道差异体现在四个成本桶字段里，而不是额外再拆一列渠道类型。

## 3. 数据流

```text
dws_bb_card_finance_daily_p
dws_qi_card_finance_daily_p
dws_sl_card_finance_daily_p
dwm_finance_channel_cost_p
        |
        v
dws_total_channel_cost_daily_p
```

## 4. 成本边界

BB/QI/SL 卡渠道 DWS 不进入 `dwm_finance_channel_cost_p`。

`dwm_finance_channel_cost_p` 只承载金融渠道成本，不承载 BB/QI/SL 已经独立产出的卡渠道 DWS 成本。

金融渠道成本按 `product_line` 分桶：

```text
product_line = 'QUANTUM_CARD'    -> quantum_cost
product_line = 'GLOBAL_ACCOUNT'  -> business_cost
product_line = 'CRYPTO_ASSET'    -> crypto_cost
product_line = 'ACQUIRING'       -> acquiring_cost
```

## 5. 文件

- `table-scripts/dwm_finance_channel_cost_p.sql`: 金融渠道成本归因明细表
- `table-scripts/dws_total_channel_cost_daily_p.sql`: 总渠道成本 DWS 表
- `sp_init_total_channel_cost_by_fast.sql`: 总渠道成本批量初始化/回刷
