# Qbit Card Cost Cleaning Postgres Supplement

这套补充脚本用于在现有 PostgreSQL 过程版本上增加以下能力：

- `SL` 渠道 DWM / DWS
- 销售关系归属补充
- 金融渠道成本归因明细
- 总渠道成本日汇总
- `BB / QI` 的 DWS `v2` 版本，补齐 `sale_id` / `am_id` / `cost_fixed_fee`

## 1. 目标口径

最终总表：

```text
public.dws_total_channel_cost_daily_p
```

粒度：

```text
report_date + account_id + sale_id + am_id
```

字段：

```text
acquiring_cost
business_cost
quantum_cost
crypto_cost
total_channel_cost
```

其中：

```text
quantum_cost
= BB DWS 成本
+ QI DWS 成本
+ SL DWS 成本
+ 金融渠道成本中 product_line = 'QUANTUM_CARD'
```

## 2. 执行顺序

建议执行顺序：

1. 建表 / 变更表结构
2. 初始化销售关系快照
3. 初始化 `BB / QI v2 DWS`
4. 初始化 `SL DWM / DWS`
5. 按 `bi_month_tag` 成本项回刷 `dwm_finance_channel_cost_p`
6. 按月回刷 `dws_total_channel_cost_daily_p`

## 3. 文件说明

- `table-scripts/alter_bb_qi_sale_am_fixed_fee.sql`
- `table-scripts/dim_sale_account_relation_p.sql`
- `table-scripts/dwm_sl_card_transaction_detail_p.sql`
- `table-scripts/dws_sl_card_finance_daily_p.sql`
- `table-scripts/dwm_finance_channel_cost_p.sql`
- `table-scripts/dws_total_channel_cost_daily_p.sql`
- `account-relation/sp_init_dim_sale_account_relation_by_day.sql`
- `bb-channel/sp_init_bb_card_dws_fast_v2.sql`
- `qi-channel/sp_init_qi_card_dws_by_fast_v2.sql`
- `sl-channel/sp_init_sl_card_dwm_by_fast.sql`
- `sl-channel/sp_init_sl_card_dws_by_fast.sql`
- `total-cost/sp_init_finance_channel_cost_by_fast.sql`
- `total-cost/sp_init_total_channel_cost_by_fast.sql`

## 4. 设计取舍

这版补充以不破坏现有老过程为前提：

- 不直接覆盖现有 `BB / QI` 老过程
- 新增 `v2` 过程补齐销售关系口径
- 金融渠道成本采用月度批处理
- 总成本按月份整体回刷

## 5. 关键假设

- `bi_month_tag.amount` 为成本最终金额来源
- 销售关系优先取直接账户关系
- 直接关系不存在时，再通过 `api_account_relation.root_id` 回退到根账户销售关系
- `SL` 交易基于 `qbitCardSettlement` 中 `provider like '%Slash%'` 口径清洗
- 这版主要补齐批处理链路，不包含 `CDC` 调度过程

## 6. 当前金融渠道成本过程覆盖范围

当前 `total-cost/sp_init_finance_channel_cost_by_fast.sql` 已补以下首批分支：

- `BPC`
- `SUMSUB`
- `IDEMIA`
- `HZ_BANK`

也就是先覆盖：

```text
QUANTUM_CARD
```

下列产品线 / provider 还需要按同样模式继续补充分支：

- `GLOBAL_ACCOUNT`: `ZB/BZ`、`CL`
- `CRYPTO_ASSET`: `THUNES`、`CREGIS`、`TZ_WIRE`、`TZ_SELL`、`SAFEHERON`、`BITSTAMP`
- `ACQUIRING`: `ORENDA`、`WORLD_PAY`
