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

当前先落量子卡成本链路：

```text
quantum_cost
= bb_dws_cost
+ qi_dws_cost
+ sl_dws_cost
+ finance_quantum_channel_cost
```

## 2. 表定位

### dwm_finance_quantum_channel_cost_p

这是量子卡金融补充成本归因表。

只承载 BB/QI/SL DWS 之外的量子卡金融渠道成本，例如：

- Thunes 银行手续费和固定成本
- BPC 月度账单成本
- Sumsb KYC 成本
- IDEMIA 制卡成本
- HZ 银行手续费
- 其他需要从账单、标签或后置分摊得到的量子卡金融成本

不承载：

- `dws_bb_card_finance_daily_p`
- `dws_qi_card_finance_daily_p`
- `dws_sl_card_finance_daily_p`

这些卡渠道 DWS 直接作为总成本 DWS 的来源，避免重复计算。

粒度：

```text
report_date + account_id + provider + cost_type + sale_id + am_id
```

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

BB/QI/SL/finance quantum 的拆分只保留在来源表和计算口径中，总表不再单独存拆分字段。

## 3. 数据流

```text
dws_bb_card_finance_daily_p
dws_qi_card_finance_daily_p
dws_sl_card_finance_daily_p
dwm_finance_quantum_channel_cost_p
        |
        v
dws_total_channel_cost_daily_p
```

## 4. 成本边界

BB/QI/SL 不进入 `dwm_finance_quantum_channel_cost_p`。

`dwm_finance_quantum_channel_cost_p` 只补充量子卡相关金融渠道成本。

最终：

```text
客户某天总量子卡渠道成本
= BB 卡渠道成本
+ QI 卡渠道成本
+ SL 卡渠道成本
+ 量子卡金融补充成本
```

## 5. 文件

- `table-scripts/dwm_finance_quantum_channel_cost_p.sql`: 量子卡金融补充成本归因表
- `table-scripts/dws_total_channel_cost_daily_p.sql`: 总渠道成本 DWS 表
- `sp_init_total_channel_cost_by_fast.sql`: 总渠道成本批量初始化/回刷
