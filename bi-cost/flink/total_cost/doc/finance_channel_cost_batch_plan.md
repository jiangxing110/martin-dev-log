# 金融渠道成本 Batch 清洗方案

Author: martinJiang

## 1. 目标

金融渠道成本统一清洗到：

```text
public.dwm_finance_channel_cost_p
```

该表承载全产品线金融渠道成本：

- 量子账户 `QUANTUM_CARD`
- 全球账户 `GLOBAL_ACCOUNT`
- 加密账户 `CRYPTO_ASSET`
- 收单账户 `ACQUIRING`

金额来源统一来自：

```text
bi_month_tag.amount
```

业务明细表只负责提供分摊对象、分摊权重和成本归属日期。

## 2. 不做 CDC 清洗

金融渠道成本不做 CDC 实时清洗。

原因：

- `bi_month_tag` 是月度账单/人工录入，金额通常后置确认。
- 多数成本依赖整月分母，例如当月客户数、当月净消费、当月代付金额。
- 任意一条明细变化都可能影响整月分摊比例，需要整月回刷。
- 固定成本需要展开到当月每日，实时维护复杂度高。

最终落地方式：

```text
bi_month_tag 新增/更新
        |
        v
运维或后台接口触发 batch
        |
        v
按 source_month + product_line + provider + source_tag 回刷
```

## 3. Batch 作业

推荐作业名：

```text
sp_init_finance_channel_cost_by_fast.sql
```

作业参数：

```text
source_month = '2026-04-01'
next_month = '2026-05-01'
product_line = 'QUANTUM_CARD'
provider = 'BPC'
source_tag = 'CHANNEL_COST'
```

作业只回刷一个：

```text
source_month + product_line + provider + source_tag
```

这样每次 `bi_month_tag` 加一条或改一条，只重算对应成本项，不影响其他渠道。

## 4. 幂等逻辑

每次回刷先逻辑删除旧数据：

```sql
UPDATE "public"."dwm_finance_channel_cost_p"
SET
  "delete_time" = NOW(),
  "update_time" = NOW()
WHERE "source_month" = '${source_month}'
  AND "product_line" = '${product_line}'
  AND "provider" = '${provider}'
  AND "source_tag" = '${source_tag}'
  AND "delete_time" IS NULL;
```

然后重新插入当月结果。

## 5. DWM 粒度

目标表粒度：

```text
report_date
+ account_id
+ product_line
+ provider
+ cost_type
+ source_month
+ source_tag
+ sale_id
+ am_id
```

核心字段：

| 字段 | 说明 |
| --- | --- |
| `report_date` | 成本归属日期 |
| `account_id` | 客户账户 ID |
| `sale_id` | 销售 ID |
| `am_id` | AM ID |
| `product_line` | 产品线 |
| `provider` | 渠道 |
| `cost_type` | 成本指标 |
| `source_month` | 来源账单月份 |
| `source_tag` | `bi_month_tag.tag` |
| `source_amount` | `bi_month_tag.amount` |
| `month_day_count` | 当月天数 |
| `basis_count` | 当前客户数量型分摊分子 |
| `month_basis_count` | 当月数量型分摊分母 |
| `basis_amount` | 当前客户金额型分摊分子 |
| `month_basis_amount` | 当月金额型分摊分母 |
| `allocation_rate` | 最终分摊比例 |
| `cost_amount` | 最终分摊成本 |

## 6. 通用公式

数量型均摊：

```text
allocation_rate = basis_count / month_basis_count
cost_amount = source_amount * allocation_rate
```

数量型按天均摊：

```text
allocation_rate = basis_count / month_basis_count / month_day_count
cost_amount = source_amount * allocation_rate
```

金额型加权：

```text
allocation_rate = basis_amount / month_basis_amount
cost_amount = source_amount * allocation_rate
```

数据库计算值按账单金额缩放：

```text
allocation_rate = basis_amount / month_basis_amount
cost_amount = source_amount * allocation_rate
```

这里 `basis_amount` 存 raw cost 或业务金额，取决于具体成本项。

## 7. 销售关系

不使用：

```text
ods_sale_am_transaction_2026
```

按 `account_id + report_date` 匹配销售关系。

优先直接匹配：

```text
account_id = dim_sale_account_relation_p.relation_account_id
report_date >= relation_start_time
and (report_date < relation_end_time or relation_end_time is null)
```

如果直接客户找不到，再通过 `api_account_relation.root_id` 回退：

```text
account_id = api_account_relation.account_id
root_id = dim_sale_account_relation_p.relation_account_id
report_date >= relation_start_time
and (report_date < relation_end_time or relation_end_time is null)
```

最终只写：

```text
sale_id
am_id
```

## 8. 产品线分桶

`product_line` 决定后续进入总成本表哪个字段：

| product_line | 总成本字段 |
| --- | --- |
| `QUANTUM_CARD` | `quantum_cost` |
| `GLOBAL_ACCOUNT` | `business_cost` |
| `CRYPTO_ASSET` | `crypto_cost` |
| `ACQUIRING` | `acquiring_cost` |

## 9. 清洗规则

### 9.1 量子账户 QUANTUM_CARD

#### BPC

成本含义：

```text
QI 活跃卡成本
```

分摊对象：

```sql
SELECT "accountId" AS account_id
FROM "qbitCard"
WHERE provider LIKE '%Qbit%'
  AND ("deleteCardTime" > '${source_month}' OR "deleteCardTime" IS NULL)
GROUP BY "accountId";
```

落库口径：

```text
product_line = 'QUANTUM_CARD'
provider = 'BPC'
cost_type = 'ACTIVE_CARD_COST'
report_date = 当月每一天
basis_count = 1
month_basis_count = 当月有 QI 活跃卡客户数
month_day_count = 当月天数
allocation_rate = basis_count / month_basis_count / month_day_count
```

#### Sumsub

成本含义：

```text
KYC 认证成本
```

分摊对象：

```sql
SELECT
  account_id,
  CAST(create_time AS date) AS report_date,
  COUNT(1) AS kyc_count
FROM idv_channel_request_record
WHERE request_channel = 'sumsub'
  AND request_type = 'POST'
  AND create_time >= '${source_month}'
  AND create_time < '${next_month}'
GROUP BY account_id, CAST(create_time AS date);
```

落库口径：

```text
product_line = 'QUANTUM_CARD'
provider = 'Sumsub'
cost_type = 'KYC_FEE'
report_date = KYC 发生日
basis_count = 当前客户当天 KYC 次数
month_basis_count = 当月全部 KYC 次数
allocation_rate = basis_count / month_basis_count
```

#### IDEMIA

成本含义：

```text
实体卡制卡成本
```

分摊对象：

```sql
SELECT
  "accountId" AS account_id,
  COUNT(1) AS physical_card_count
FROM "qbitPhysicalCard"
WHERE "createTime" >= '${source_month}'
  AND "createTime" < '${next_month}'
GROUP BY "accountId";
```

落库口径：

```text
product_line = 'QUANTUM_CARD'
provider = 'IDEMIA'
cost_type = 'CARD_PRODUCTION_FEE'
report_date = 当月每一天
basis_count = 当前客户当月实体卡数
month_basis_count = 当月全部实体卡数
month_day_count = 当月天数
allocation_rate = basis_count / month_basis_count / month_day_count
```

#### HZ_BANK

成本含义：

```text
QI 消费银行手续费
```

分摊权重：

```text
QI 卡净消费量
```

```sql
SELECT
  tr."accountId" AS account_id,
  CAST(tr."transactionTime" AS date) AS report_date,
  (
    SUM(CASE WHEN tr."businessType" = 'Consumption' AND tr.status IN ('Closed', 'Pending') THEN tr."settleAmount" ELSE 0 END)
    - SUM(CASE WHEN tr."businessType" = 'Reversal' AND tr.status IN ('Closed', 'Pending') THEN tr."settleAmount" ELSE 0 END)
    - SUM(CASE WHEN tr."businessType" = 'Credit' AND tr.status = 'Closed' THEN tr."settleAmount" ELSE 0 END)
  ) AS net_consume_amount
FROM "qbit_card_transaction" tr
WHERE tr."deleteTime" IS NULL
  AND tr.provider LIKE '%Qbit%'
  AND tr."businessType" IN ('Credit', 'Consumption', 'Reversal')
  AND tr."transactionTime" >= '${source_month}'
  AND tr."transactionTime" < '${next_month}'
GROUP BY tr."accountId", CAST(tr."transactionTime" AS date);
```

落库口径：

```text
product_line = 'QUANTUM_CARD'
provider = 'HZ_BANK'
cost_type = 'CONSUME_BANK_FEE'
report_date = 消费发生日
basis_amount = 当前客户当天净消费量
month_basis_amount = 当月全部净消费量
allocation_rate = basis_amount / month_basis_amount
```

### 9.2 全球账户 GLOBAL_ACCOUNT

#### BZ/ZB Payout

成本含义：

```text
Payout 成本，系统内 fee_cost 可算，系统外金额从 bi_month_tag 获取后按 payout 金额分摊
```

分摊权重：

```sql
SELECT
  account_id,
  SUM((extra ->> 'fee_cost')::numeric) AS raw_fee_cost,
  SUM(settle_amount) AS payout_amount,
  CAST("submitTime" AS date) AS report_date
FROM payment_transaction_record
WHERE channel = 'ZB'
  AND payout_direction_type = 'SubToPayee'
  AND status = 'Closed'
  AND extra ->> 'third_party_created_time' >= '${source_month}'
  AND extra ->> 'third_party_created_time' < '${next_month}'
GROUP BY CAST("submitTime" AS date), account_id;
```

落库口径：

```text
product_line = 'GLOBAL_ACCOUNT'
provider = 'BZ'
cost_type = 'PAYOUT_FEE'
report_date = submitTime 日期
basis_amount = 当前客户当天 settle_amount
month_basis_amount = 当月全部 settle_amount
allocation_rate = basis_amount / month_basis_amount
```

#### CL

成本含义：

```text
CL 活跃子账户固定成本
```

分摊对象：

```sql
SELECT "accountId" AS account_id
FROM "globalSubAccount"
WHERE provider = 'Column'
  AND status = 'Active'
GROUP BY "accountId";
```

落库口径：

```text
product_line = 'GLOBAL_ACCOUNT'
provider = 'CL'
cost_type = 'ACTIVE_SUB_ACCOUNT_COST'
report_date = 当月每一天
basis_count = 1
month_basis_count = 当月有 CL 活跃子账户客户数
month_day_count = 当月天数
allocation_rate = basis_count / month_basis_count / month_day_count
```

### 9.3 加密账户 CRYPTO_ASSET

#### Thunes

成本含义：

```text
银行手续费 + 固定成本
```

分摊权重：

```sql
SELECT account_id, SUM(origin_amount * usd_rate) AS transfer_amount
FROM crypto_assets_transfers
WHERE recipient_type = 'wire'
  AND status = 'Closed'
  AND delete_time IS NULL
  AND extend_field ->> 'platform' = 'THUNES'
  AND create_time >= '${source_month}'
  AND create_time < '${next_month}'
GROUP BY account_id;
```

落库口径：

```text
product_line = 'CRYPTO_ASSET'
provider = 'TH'
cost_type = 'WIRE_BANK_FEE' 或 'FIXED_FEE'
```

#### Cregis

```sql
SELECT account_id
FROM crypto_assets_addresses
WHERE platform = 'CREGIS'
  AND "enable" = true
GROUP BY account_id;
```

落库口径：

```text
product_line = 'CRYPTO_ASSET'
provider = 'Cregis'
cost_type = 'FIXED_FEE'
```

#### TZ-wire

```sql
SELECT account_id, SUM(origin_amount * usd_rate) AS wire_amount
FROM crypto_assets_transfers
WHERE recipient_type = 'wire'
  AND status = 'Closed'
  AND extend_field ->> 'platform' = 'TZ'
  AND create_time >= '${source_month}'
  AND create_time < '${next_month}'
GROUP BY account_id;
```

落库口径：

```text
product_line = 'CRYPTO_ASSET'
provider = 'TZ-wire'
cost_type = 'WIRE_FEE' 或 'FIXED_FEE'
```

#### TZ-sell

```sql
SELECT account_id, SUM(origin_amount * usd_rate) AS sell_amount
FROM crypto_assets_transfers
WHERE action = 'sell'
  AND status = 'Closed'
  AND delete_time IS NULL
  AND currency = '${currency}'
  AND create_time >= '${source_month}'
  AND create_time < '${next_month}'
GROUP BY account_id;
```

落库口径：

```text
product_line = 'CRYPTO_ASSET'
provider = 'TZ-usdt' 或 'TZ-usdc'
cost_type = 'FX_FEE'
```

#### Safeheron

```sql
SELECT account_id
FROM view_crypto_assets_blockchain_transfers
WHERE "action" = 'out'
  AND create_time >= '${source_month}'
  AND create_time < '${next_month}'
  AND status = 'Closed'
  AND platform = 'SAFEHERON'
GROUP BY account_id;
```

落库口径：

```text
product_line = 'CRYPTO_ASSET'
provider = 'Safeheron'
cost_type = 'FIXED_FEE' 或 'EXTRA_FEE'
```

#### Bitstamp

```sql
SELECT account_id, SUM(origin_amount * usd_rate) AS sell_amount
FROM crypto_assets_transfers
WHERE action = 'sell'
  AND status = 'Closed'
  AND delete_time IS NULL
  AND currency = 'USDT'
  AND create_time >= '${source_month}'
  AND create_time < '${next_month}'
GROUP BY account_id;
```

落库口径：

```text
product_line = 'CRYPTO_ASSET'
provider = 'BS'
cost_type = 'TRADING_FEE'
```

### 9.4 收单账户 ACQUIRING

#### Orenda

计算方式：

```text
raw_cost = sum(acquiring_usd_amount) * 0.0025
allocation_rate = raw_cost / month_raw_cost_total
cost_amount = bi_month_tag.amount * allocation_rate
```

落库口径：

```text
product_line = 'ACQUIRING'
provider = 'OD'
cost_type = 'ACQUIRING_FEE'
report_date = 收单发生日
basis_amount = 当前客户当天 raw_cost
month_basis_amount = 当月全部 raw_cost
```

#### World Pay

计算方式：

```text
按客户收单金额比例分摊
```

落库口径：

```text
product_line = 'ACQUIRING'
provider = 'WP'
cost_type = 'ACQUIRING_FEE'
report_date = 收单发生日
basis_amount = 当前客户当天 acquiring_usd_amount
month_basis_amount = 当月全部 acquiring_usd_amount
```

## 10. 作业拆分建议

不要一次写完全部渠道。

建议分四版：

```text
V1 QUANTUM_CARD:
BPC, Sumsub, IDEMIA, HZ_BANK

V2 GLOBAL_ACCOUNT:
BZ, CL

V3 CRYPTO_ASSET:
TH, Cregis, TZ-wire, TZ-sell, Safeheron, BS

V4 ACQUIRING:
OD, WP
```

每版单独核对：

```text
sum(cost_amount) = bi_month_tag.amount
```

## 11. 对 dws_total_channel_cost_daily_p 的影响

`dwm_finance_channel_cost_p` 写入后，由：

```text
sp_init_total_channel_cost_by_fast.sql
```

汇总到：

```text
public.dws_total_channel_cost_daily_p
```

总表粒度：

```text
report_date + account_id + sale_id + am_id
```

金融渠道成本在总表里不保留 `provider` / `cost_type` / `source_tag` 明细，也不增加单独的 `channel` 行维度，只按产品线进入四个成本桶字段。

### 11.1 成本分桶

`dwm_finance_channel_cost_p.product_line` 决定金融渠道成本进入哪个字段：

```text
ACQUIRING      -> acquiring_cost
GLOBAL_ACCOUNT -> business_cost
QUANTUM_CARD   -> quantum_cost
CRYPTO_ASSET   -> crypto_cost
```

### 11.2 和 BB/QI/SL 的关系

```text
quantum_cost
= BB DWS 成本
+ QI DWS 成本
+ SL DWS 成本
+ 金融渠道成本中 product_line = 'QUANTUM_CARD' 的部分
```

BB/QI/SL 不写入 `dwm_finance_channel_cost_p`。

原因：

```text
BB/QI/SL 已经有独立 DWS：
dws_bb_card_finance_daily_p
dws_qi_card_finance_daily_p
dws_sl_card_finance_daily_p
```

如果再写入金融渠道成本 DWM，会重复计入 `quantum_cost`。

### 11.3 总表汇总公式

总表每日客户成本：

```text
acquiring_cost =
  sum(dwm_finance_channel_cost_p.cost_amount where product_line = 'ACQUIRING')

business_cost =
  sum(dwm_finance_channel_cost_p.cost_amount where product_line = 'GLOBAL_ACCOUNT')

quantum_cost =
  sum(bb_dws_cost)
  + sum(qi_dws_cost)
  + sum(sl_dws_cost)
  + sum(dwm_finance_channel_cost_p.cost_amount where product_line = 'QUANTUM_CARD')

crypto_cost =
  sum(dwm_finance_channel_cost_p.cost_amount where product_line = 'CRYPTO_ASSET')

total_channel_cost =
  acquiring_cost
  + business_cost
  + quantum_cost
  + crypto_cost
```

### 11.4 总表结构含义

总表是宽表，不是按渠道展开的窄表。

也就是说：

```text
同一个 account_id + report_date + sale_id + am_id
只保留一行
```

这一行中：

```text
acquiring_cost
business_cost
quantum_cost
crypto_cost
```

分别承载不同产品线/渠道归并后的金额。

### 11.5 回刷顺序

单个 `bi_month_tag` 成本项变更后，推荐顺序：

```text
1. 回刷 dwm_finance_channel_cost_p
   仅回刷 source_month + product_line + provider + source_tag

2. 回刷 dws_total_channel_cost_daily_p
   回刷该 source_month 对应月份的总表
```

总表不能只更新某个 provider，因为总表没有 provider 字段。

建议总表按月份回刷：

```text
report_date >= source_month
report_date < next_month
```

### 11.6 幂等影响

金融渠道 DWM 回刷时是局部逻辑删除：

```text
source_month + product_line + provider + source_tag
```

总表回刷时建议按月逻辑删除：

```sql
UPDATE "public"."dws_total_channel_cost_daily_p"
SET
  "delete_time" = NOW(),
  "update_time" = NOW()
WHERE "report_date" >= '${source_month}'
  AND "report_date" < '${next_month}'
  AND "delete_time" IS NULL;
```

然后按月重新汇总 BB/QI/SL 和 `dwm_finance_channel_cost_p`。

### 11.7 校验口径

金融渠道 DWM 校验：

```text
sum(dwm_finance_channel_cost_p.cost_amount)
= bi_month_tag.amount
```

按单个成本项校验：

```text
source_month + product_line + provider + source_tag
```

总表校验：

```text
sum(dws_total_channel_cost_daily_p.total_channel_cost)
= sum(acquiring_cost)
 + sum(business_cost)
 + sum(quantum_cost)
 + sum(crypto_cost)
```

量子卡总成本校验：

```text
sum(quantum_cost)
= sum(BB DWS 成本)
 + sum(QI DWS 成本)
 + sum(SL DWS 成本)
 + sum(QUANTUM_CARD 金融渠道成本)
```

### 11.7 毛利链路影响

后续毛利计算只读总表：

```text
dws_total_channel_cost_daily_p
```

产品线毛利可按四个字段取成本：

```text
QUANTUM_CARD   -> quantum_cost
GLOBAL_ACCOUNT -> business_cost
CRYPTO_ASSET   -> crypto_cost
ACQUIRING      -> acquiring_cost
```

## 12. 待确认事项

1. IDEMIA 在 `bi_month_tag` 中最终使用 `CARD_CUSTOMIZATION_FEE` 还是 `CHANNEL_COST`。
2. Sumsub 是否只统计 `request_type = 'POST'`，是否需要排除失败记录。
3. BPC 是按“有活跃 QI 卡的客户数”均摊，还是按“活跃 QI 卡数量”均摊。
4. 固定成本是否都要按当月每日展开。目前方案按每日展开处理。
5. ZB/BZ provider 落库值是否统一为枚举 `BZ`。
