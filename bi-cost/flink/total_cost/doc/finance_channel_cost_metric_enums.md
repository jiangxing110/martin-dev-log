# 金融渠道成本指标枚举

Author: martinJiang

## 1. 目标

本文档定义金融渠道成本清洗涉及的枚举口径。

适用表：

```text
public.dwm_finance_channel_cost_p
```

当前设计语义是全产品线金融渠道成本归因明细表。

## 2. product_line 枚举

来源：`qbit-assets` 项目 `ProductLineEnum`。

| 枚举值 | 中文含义 | 进入总成本字段 |
| --- | --- | --- |
| `QUANTUM_CARD` | 量子账户/量子卡 | `quantum_cost` |
| `GLOBAL_ACCOUNT` | 全球账户 | `business_cost` |
| `CRYPTO_ASSET` | 加密账户 | `crypto_cost` |
| `ACQUIRING` | 收单账户 | `acquiring_cost` |
| `OTHER` | 其他 | 暂不接入 |

## 3. bi_month_tag.tag 枚举

来源：`qbit-assets` 项目 `MetricTypeEnum`。

这些值是 `bi_month_tag.tag` 的合法值。

| 枚举值 | 中文含义 | 本成本清洗建议用法 |
| --- | --- | --- |
| `INCENTIVE` | 渠道返现 Incentive 金额 | 返现类，不作为金融渠道成本 |
| `INTERCHANGE` | 渠道返现 Interchange 金额 | 返现类，不作为金融渠道成本 |
| `INCENTIVE_COEFFICIENT` | 渠道返现 Incentive 系数 | 系数类，不作为金融渠道成本 |
| `INTERCHANGE_COEFFICIENT` | 渠道返现 Interchange 系数 | 系数类，不作为金融渠道成本 |
| `CHANNEL_COST` | 渠道固定成本/渠道成本 | 金融渠道成本默认指标 |
| `CARD_CUSTOMIZATION_FEE` | 卡面定制费用 | IDEMIA 制卡成本可用 |
| `CRYPTO_EXCHANGE_GAIN` | 加密资产汇差收入 | 收入类，不作为成本 |
| `CRYPTO_OFFLINE_INCOME` | 加密资产线下收入 | 收入类，不作为成本 |
| `COMPANY_FINANCIAL` | 公司理财 | 暂不接入本成本表 |
| `OTHER` | 其他 | 特殊成本兜底，需在 `detail` 说明 |

推荐原则：

- 常规金融渠道成本统一使用 `CHANNEL_COST`。
- IDEMIA 如果后台已有明确卡面/制卡录入口径，可使用 `CARD_CUSTOMIZATION_FEE`。
- 不建议新增中文 tag，避免和 `MetricTypeEnum` 不一致。

## 4. provider 枚举

来源：`qbit-assets` 项目 `BiMonthTagProviderEnum`。

| product_line | provider | 中文/业务含义 | 当前成本项 |
| --- | --- | --- | --- |
| `QUANTUM_CARD` | `BPC` | BPC | QI 活跃卡成本 |
| `QUANTUM_CARD` | `Sumsub` | Sumsub | KYC 认证成本 |
| `QUANTUM_CARD` | `HZ_BANK` | HZ 银行 | QI 消费银行手续费 |
| `QUANTUM_CARD` | `IDEMIA` | IDEMIA | 实体卡制卡成本 |
| `GLOBAL_ACCOUNT` | `BZ` | BZ/ZB | Payout 成本 |
| `GLOBAL_ACCOUNT` | `CL` | Column | CL 活跃子账户固定成本 |
| `CRYPTO_ASSET` | `TZ-usdt` | TZ USDT | TZ sell USDT 换汇成本 |
| `CRYPTO_ASSET` | `TZ-usdc` | TZ USDC | TZ sell USDC 换汇成本 |
| `CRYPTO_ASSET` | `TZ-wire` | TZ wire | TZ wire 代付成本 |
| `CRYPTO_ASSET` | `TH` | Thunes | Thunes 银行手续费/固定成本 |
| `CRYPTO_ASSET` | `Cregis` | Cregis | Cregis 固定成本 |
| `CRYPTO_ASSET` | `Safeheron` | Safeheron | Safeheron 固定成本/额外成本 |
| `CRYPTO_ASSET` | `BS` | Bitstamp | Bitstamp 交易手续费 |
| `ACQUIRING` | `OD` | Orenda | Orenda 收单成本 |
| `ACQUIRING` | `WP` | World Pay | World Pay 收单成本 |

注意：

- 业务口径里常写 `ZB`，但代码枚举是 `BZ`。落库建议统一使用 `BZ`。
- 业务口径里常写 `thunes`，但代码枚举是 `TH`。落库建议统一使用 `TH`。
- 业务口径里常写 `Bitstamp`，但代码枚举是 `BS`。落库建议统一使用 `BS`。

## 5. cost_type 枚举

`cost_type` 是 `dwm_finance_channel_cost_p` 内部成本类型，不来自 `bi_month_tag`。

| product_line | provider | cost_type | 含义 |
| --- | --- | --- | --- |
| `QUANTUM_CARD` | `BPC` | `ACTIVE_CARD_COST` | QI 活跃卡成本 |
| `QUANTUM_CARD` | `Sumsub` | `KYC_FEE` | KYC 认证成本 |
| `QUANTUM_CARD` | `IDEMIA` | `CARD_PRODUCTION_FEE` | 实体卡制卡成本 |
| `QUANTUM_CARD` | `HZ_BANK` | `CONSUME_BANK_FEE` | QI 消费银行手续费 |
| `GLOBAL_ACCOUNT` | `BZ` | `PAYOUT_FEE` | BZ/ZB payout 成本 |
| `GLOBAL_ACCOUNT` | `CL` | `ACTIVE_SUB_ACCOUNT_COST` | CL 活跃子账户固定成本 |
| `CRYPTO_ASSET` | `TH` | `WIRE_BANK_FEE` | Thunes 代付银行手续费 |
| `CRYPTO_ASSET` | `TH` | `FIXED_FEE` | Thunes 固定成本 |
| `CRYPTO_ASSET` | `Cregis` | `FIXED_FEE` | Cregis 固定成本 |
| `CRYPTO_ASSET` | `TZ-wire` | `WIRE_FEE` | TZ wire 代付手续费 |
| `CRYPTO_ASSET` | `TZ-wire` | `FIXED_FEE` | TZ wire 固定成本 |
| `CRYPTO_ASSET` | `TZ-usdt` | `FX_FEE` | TZ USDT -> USD 换汇费用 |
| `CRYPTO_ASSET` | `TZ-usdc` | `FX_FEE` | TZ USDC -> USD 换汇费用 |
| `CRYPTO_ASSET` | `Safeheron` | `FIXED_FEE` | Safeheron 固定成本 |
| `CRYPTO_ASSET` | `Safeheron` | `EXTRA_FEE` | Safeheron 额外成本 |
| `CRYPTO_ASSET` | `BS` | `TRADING_FEE` | Bitstamp 交易手续费 |
| `ACQUIRING` | `OD` | `ACQUIRING_FEE` | Orenda 收单成本 |
| `ACQUIRING` | `WP` | `ACQUIRING_FEE` | World Pay 收单成本 |

## 6. 推荐落库示例

### BPC

```text
product_line = 'QUANTUM_CARD'
provider = 'BPC'
source_tag = 'CHANNEL_COST'
cost_type = 'ACTIVE_CARD_COST'
```

### ZB/BZ Payout

```text
product_line = 'GLOBAL_ACCOUNT'
provider = 'BZ'
source_tag = 'CHANNEL_COST'
cost_type = 'PAYOUT_FEE'
```

### TZ-sell USDT

```text
product_line = 'CRYPTO_ASSET'
provider = 'TZ-usdt'
source_tag = 'CHANNEL_COST'
cost_type = 'FX_FEE'
```

### Orenda

```text
product_line = 'ACQUIRING'
provider = 'OD'
source_tag = 'CHANNEL_COST'
cost_type = 'ACQUIRING_FEE'
```
