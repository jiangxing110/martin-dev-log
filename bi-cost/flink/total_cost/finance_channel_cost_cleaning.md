# 金融渠道成本清洗设计

Author: martinJiang

## 1. 目标

本文档描述 `dwm_finance_channel_cost_p` 的清洗逻辑。

该表承载：

- 量子账户金融渠道成本
- 全球账户金融渠道成本
- 加密账户金融渠道成本
- 收单账户金融渠道成本

不承载：

- `dws_bb_card_finance_daily_p`
- `dws_qi_card_finance_daily_p`
- `dws_sl_card_finance_daily_p`

BB/QI/SL 卡渠道成本由各自 DWS 直接进入总成本表，避免重复计算。

## 2. 总体原则

金额来源统一来自 `bi_month_tag`。

业务明细表只负责提供：

- 分摊对象
- 分摊权重
- 成本归属日期

整体链路：

```text
bi_month_tag 月度金额
        +
业务明细表计算分摊对象/权重
        +
dim_sale_account_relation_p 挂 sale_id/am_id
        |
        v
dwm_finance_channel_cost_p
        |
        v
dws_total_channel_cost_daily_p
```

## 3. 产品线分桶

`dwm_finance_channel_cost_p.product_line` 决定成本进入总成本表哪个字段：

| product_line | 总成本字段 | 说明 |
| --- | --- | --- |
| `QUANTUM_CARD` | `quantum_cost` | 量子账户/量子卡金融渠道成本 |
| `GLOBAL_ACCOUNT` | `business_cost` | 全球账户金融渠道成本 |
| `CRYPTO_ASSET` | `crypto_cost` | 加密账户金融渠道成本 |
| `ACQUIRING` | `acquiring_cost` | 收单账户金融渠道成本 |

## 4. DWM 粒度

目标表：

```text
public.dwm_finance_channel_cost_p
```

粒度：

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

关键字段：

| 字段 | 说明 |
| --- | --- |
| `report_date` | 成本归属日期；月度成本按规则展开到当月每日，交易/KYC 类成本按业务发生日归属 |
| `account_id` | 客户账户 ID |
| `sale_id` | 销售 ID |
| `am_id` | AM ID |
| `product_line` | 产品线 |
| `provider` | 金融渠道 |
| `cost_type` | 成本类型 |
| `source_month` | 来源账单月份，取当月第一天 |
| `source_tag` | `bi_month_tag.tag` |
| `source_amount` | `bi_month_tag.amount` |
| `month_day_count` | 当月天数，月度成本按天均摊时参与分摊 |
| `basis_count` | 当前客户数量型分摊分子 |
| `month_basis_count` | 当月数量型分摊分母 |
| `basis_amount` | 当前客户金额型分摊分子 |
| `month_basis_amount` | 当月金额型分摊分母 |
| `allocation_rate` | 分摊比例 |
| `cost_amount` | 最终归因成本金额 |

## 5. 通用公式

数量型均摊：

```text
allocation_rate = basis_count / month_basis_count
cost_amount = source_amount * allocation_rate
```

月度金额按天均摊：

```text
allocation_rate = basis_count / month_basis_count / month_day_count
cost_amount = source_amount * allocation_rate
```

金额型加权分摊：

```text
allocation_rate = basis_amount / month_basis_amount
cost_amount = source_amount * allocation_rate
```

数据库可计算成本与账单金额修正：

```text
allocation_rate = raw_cost_amount / month_raw_cost_amount
cost_amount = source_amount * allocation_rate
```

## 6. bi_month_tag 取数口径

`bi_month_tag` 关键字段：

```text
product_line
provider
tag
statistics_time
amount
detail
```

统一过滤：

```text
product_line = 当前产品线
provider = 当前渠道
statistics_time >= source_month
statistics_time < next_month
delete_time is null
```

当前 provider 映射：

| 产品线 | 成本项 | provider | 建议 tag |
| --- | --- | --- | --- |
| `QUANTUM_CARD` | BPC QI 活跃卡成本 | `BPC` | `CHANNEL_COST` |
| `QUANTUM_CARD` | Sumsub KYC 成本 | `Sumsub` | `CHANNEL_COST` |
| `QUANTUM_CARD` | IDEMIA 制卡成本 | `IDEMIA` | `CARD_CUSTOMIZATION_FEE` 或 `CHANNEL_COST` |
| `QUANTUM_CARD` | HZ 银行手续费 | `HZ_BANK` | `CHANNEL_COST` |
| `GLOBAL_ACCOUNT` | ZB/BZ Payout 成本 | `BZ` | `CHANNEL_COST` |
| `GLOBAL_ACCOUNT` | CL 固定成本 | `CL` | `CHANNEL_COST` |
| `CRYPTO_ASSET` | Thunes | `TH` | `CHANNEL_COST` |
| `CRYPTO_ASSET` | Cregis | `Cregis` | `CHANNEL_COST` |
| `CRYPTO_ASSET` | TZ wire | `TZ-wire` | `CHANNEL_COST` |
| `CRYPTO_ASSET` | TZ sell USDT | `TZ-usdt` | `CHANNEL_COST` |
| `CRYPTO_ASSET` | TZ sell USDC | `TZ-usdc` | `CHANNEL_COST` |
| `CRYPTO_ASSET` | Safeheron | `Safeheron` | `CHANNEL_COST` |
| `CRYPTO_ASSET` | Bitstamp | `BS` | `CHANNEL_COST` |
| `ACQUIRING` | Orenda | `OD` | `CHANNEL_COST` |
| `ACQUIRING` | World Pay | `WP` | `CHANNEL_COST` |

注意：代码枚举里是 `BZ`，不是 `ZB`。如果业务仍叫 ZB，落库 provider 建议保持枚举 `BZ`。

## 7. 销售关系归属

本表不使用 `ods_sale_am_transaction_2026`。

清洗后的成本记录按 `account_id + report_date` 归属销售关系。

优先直接匹配：

```text
account_id = dim_sale_account_relation_p.relation_account_id
report_date >= relation_start_time
and (report_date < relation_end_time or relation_end_time is null)
```

如果直接客户找不到销售关系，再通过 `api_account_relation.root_id` 回退：

```text
account_id = api_account_relation.account_id
api_account_relation.root_id = dim_sale_account_relation_p.relation_account_id
report_date >= relation_start_time
and (report_date < relation_end_time or relation_end_time is null)
```

最终只写入：

```text
sale_id
am_id
```

## 8. 量子账户 quantum_account

### 8.1 BPC

QI 活跃卡成本。

分摊对象：

```sql
SELECT "accountId" AS account_id
FROM "qbitCard"
WHERE provider LIKE '%Qbit%'
  AND ("deleteCardTime" > '${source_month}' OR "deleteCardTime" IS NULL)
GROUP BY "accountId";
```

写入规则：

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

### 8.2 Sumsub

KYC 认证成本。

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

写入规则：

```text
product_line = 'QUANTUM_CARD'
provider = 'Sumsub'
cost_type = 'KYC_FEE'
report_date = KYC 发生日
basis_count = 当前客户当天 KYC 次数
month_basis_count = 当月全部 KYC 次数
allocation_rate = basis_count / month_basis_count
```

### 8.3 IDEMIA

实体卡制卡成本。

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

写入规则：

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

### 8.4 HZ_BANK

QI 消费银行手续费。

客户日级权重：

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

写入规则：

```text
product_line = 'QUANTUM_CARD'
provider = 'HZ_BANK'
cost_type = 'CONSUME_BANK_FEE'
report_date = 消费发生日
basis_amount = 当前客户当天净消费量
month_basis_amount = 当月全部净消费量
allocation_rate = basis_amount / month_basis_amount
```

## 9. 全球账户 business_account

### 9.1 BZ/ZB Payout

系统内部分可直接计算 `fee_cost`，系统外金额来自 `bi_month_tag`，按 ZB/BZ 付款金额均摊。

客户日级权重：

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

写入规则：

```text
product_line = 'GLOBAL_ACCOUNT'
provider = 'BZ'
cost_type = 'PAYOUT_FEE'
report_date = submitTime 日期
basis_amount = 当前客户当天 settle_amount
month_basis_amount = 当月全部 settle_amount
allocation_rate = basis_amount / month_basis_amount
```

### 9.2 CL

有 CL 活跃子账户的客户分摊。

```sql
SELECT "accountId" AS account_id
FROM "globalSubAccount"
WHERE provider = 'Column'
  AND status = 'Active'
GROUP BY "accountId";
```

写入规则：

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

## 10. 加密账户 crypto_account

### 10.1 Thunes

固定成本按客户数均摊，交易手续费按代付金额均摊。

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

写入规则：

```text
product_line = 'CRYPTO_ASSET'
provider = 'TH'
cost_type = 'WIRE_BANK_FEE' 或 'FIXED_FEE'
```

### 10.2 Cregis

有 Cregis 地址的账户均摊。

```sql
SELECT account_id
FROM crypto_assets_addresses
WHERE platform = 'CREGIS'
  AND "enable" = true
GROUP BY account_id;
```

写入规则：

```text
product_line = 'CRYPTO_ASSET'
provider = 'Cregis'
cost_type = 'FIXED_FEE'
report_date = 当月每一天
```

### 10.3 TZ-wire

固定成本按客户数均摊，交易手续费按代付金额均摊。

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

写入规则：

```text
product_line = 'CRYPTO_ASSET'
provider = 'TZ-wire'
cost_type = 'WIRE_FEE' 或 'FIXED_FEE'
```

### 10.4 TZ-sell

换汇费用按 TZ 付款客户承兑量分摊，USDT 和 USDC 分开。

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

写入规则：

```text
product_line = 'CRYPTO_ASSET'
provider = 'TZ-usdt' 或 'TZ-usdc'
cost_type = 'FX_FEE'
```

### 10.5 Safeheron

固定成本按使用 Safeheron 的客户均摊，额外成本后置计算。

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

写入规则：

```text
product_line = 'CRYPTO_ASSET'
provider = 'Safeheron'
cost_type = 'FIXED_FEE'
```

### 10.6 Bitstamp

交易手续费按加密承兑量分摊。

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

写入规则：

```text
product_line = 'CRYPTO_ASSET'
provider = 'BS'
cost_type = 'TRADING_FEE'
```

## 11. 收单账户 acquiring_account

### 11.1 Orenda

先按数据库规则算 raw cost，再按 `bi_month_tag.amount / raw_cost_total` 修正到实际账单金额。

```text
raw_cost = sum(acquiring_usd_amount) * 0.0025
allocation_rate = raw_cost / month_raw_cost_total
cost_amount = bi_month_tag.amount * allocation_rate
```

写入规则：

```text
product_line = 'ACQUIRING'
provider = 'OD'
cost_type = 'ACQUIRING_FEE'
report_date = 收单发生日
basis_amount = 当前客户当天 raw_cost
month_basis_amount = 当月全部 raw_cost
```

### 11.2 World Pay

按客户收单金额比例分摊。

```text
product_line = 'ACQUIRING'
provider = 'WP'
cost_type = 'ACQUIRING_FEE'
report_date = 收单发生日
basis_amount = 当前客户当天 acquiring_usd_amount
month_basis_amount = 当月全部 acquiring_usd_amount
```

## 12. 幂等与回刷

建议按月后置 batch 执行。

作业参数：

```text
source_month = '2026-04-01'
next_month = '2026-05-01'
```

回刷前先逻辑删除当月旧数据：

```sql
UPDATE "public"."dwm_finance_channel_cost_p"
SET
  "delete_time" = NOW(),
  "update_time" = NOW()
WHERE "source_month" = '${source_month}'
  AND "delete_time" IS NULL;
```

然后重新插入当月结果。

## 13. 推荐作业顺序

```text
1. 确认 bi_month_tag 当月金额已录入
2. 回刷 dim_sale_account_relation_p
3. 执行 finance channel cost batch
4. 执行 total channel cost batch
5. 下游毛利作业读取 total channel cost
```

## 14. 待确认事项

1. IDEMIA 在 `bi_month_tag` 中最终使用 `CARD_CUSTOMIZATION_FEE` 还是 `CHANNEL_COST`。
2. Sumsub 是否只统计 `request_type = 'POST'`，是否需要排除失败记录。
3. BPC 是按“有活跃 QI 卡的客户数”均摊，还是按“活跃 QI 卡数量”均摊。
4. 固定成本是否都要按当月每日展开。目前文档按每日展开处理。
5. ZB/BZ provider 落库值是否统一为枚举 `BZ`。
