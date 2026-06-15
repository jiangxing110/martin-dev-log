# Qbit 费用体系

> 涵盖 qbit-assets、pay-core、white-label-server 三套项目的费率/手续费体系。

## 目录

1. [系统架构概览](#1-系统架构概览)
2. [Fee Type 枚举体系](#2-fee-type-枚举体系)
3. [费率数据模型](#3-费率数据模型)
4. [费用计算引擎](#4-费用计算引擎)
5. [代收费体系 (AgencyFee)](#5-代收费体系-agencyfee)
6. [费率管理 API](#6-费率管理-api)
7. [费率校验与规则](#7-费率校验与规则)
8. [Partner 合作方费率](#8-partner-合作方费率)
9. [Fee Trade 类型](#9-fee-trade-类型)
10. [FeeInfoService 核心服务](#10-feeinfoservice-核心服务)
11. [跨项目对比](#11-跨项目对比)

---

## 1. 系统架构概览

Qbit 的费用体系分散在三个项目中，各有侧重：

| 项目 | 核心关注点 | 关键类 |
|------|-----------|--------|
| **qbit-assets** | 商户/管理端费率配置、开卡/交易代收费、费率校验 | `AccountFee`, `AgencyFee`, `FeeRateSections`, `AccountFeeType` |
| **pay-core** | 收单清结算费率引擎、阶梯/百分比/固定费用计算 | `FeeInfo`, `FeeCalculateUtils`, `FeeInfoService` |
| **white-label-server** | 白标商户费率枚举定义 | `AccountFeeType` (1210行巨型枚举) |

费用覆盖的业务域：
- **全球账户 (Global Account)**：入金、出金、转账、结汇
- **量子卡 (Quantum Card)**：开卡、交易 Markup、跨境、FX、ATM、Apple Pay
- **加密资产 (Crypto Asset)**：充提币、交易
- **国际转账**：SWIFT OUR/SHA、本地清算 (CHATS/FPS/SEPA/ACH 等)
- **收单 (Acquiring)**：百分比/固定/阶梯手续费、拒付费用
- **返现 (Cashback)**：量子卡消费返现、全球账户返现、加密资产返现

---

## 2. Fee Type 枚举体系

### 2.1 AccountFeeType（white-label-server）

**文件**: `white-label-server/app-core/.../enums/AccountFeeType.java`

- 1210 行巨型枚举，~300 个常量
- 每个常量对应一个业务费用类型，按业务域划分

#### 2.1.1 全球账户基础费率 (Global Account Base)

| 常量 | 说明 |
|------|------|
| `SettleRate` | 结汇汇率优惠 |
| `PaymentServiceOffers` | 付款服务费折扣 |
| `GlobalAccountInbound2` | 全球账户入金手续费(2) |
| `GlobalAccountExceedThresholdRate` | 大额阈值费率 |
| `GlobalAccountTransferFee` | 账户互转(原内部转账)手续费 |
| `GlobalAccountExceedThreshold` | 大额阈值 |
| `BaseCurrencyRateAdd` | 基础币种汇率加点 |
| `CNHMarkupFee` | CNH Markup 费 |

#### 2.1.2 全球账户入金/转账 (Global Account Inbound/Transfer)

按币种和供应商维度切分，后缀表示供应商：
- `_CC` / `_CL` / `_PY` / `_L2` / `_HF` / `_QB` / `_ZB` / `_RD` / `_RF` / `_EP`
- 入金分为主流币种 (`GlobalInboundCurrencyMain_*`) 和其他币种 (`GlobalInboundCurrencyOther_*`)
- 入金收费模式 2: `GlobalInbound2_CC` ~ `GlobalInbound2_HF`
- 账户转入手续费: `GlobalTransferIn_CC` ~ `GlobalTransferIn_EP`

#### 2.1.3 加密资产 (Crypto Asset)

| 常量 | 说明 |
|------|------|
| `CryptoAssetCollection` | 加密资产收款 |
| `CryptoAssetExchange` | 加密资产兑换 |
| `CryptoAssetPayoutMarkup` | 加密资产出金 Markup |
| `CryptoAssetExchangeSell` | 加密资产兑换(卖出) |
| `CryptoAssetExchangeTrade` | 加密资产兑换(交易) |
| `AssetsAccountTrading` | 资产账户交易 |
| `CryptoCrossChainFee` | 跨链费用 |
| `CryptoAssetAuditFeeOnChain` | 加密资产审核上链费 |
| `CryptoAssetFastTransaction` | 加密资产快速交易 |

#### 2.1.4 量子卡费率 (Quantum Card)

**开户/开卡费:**
- `QUANTUM_CREATE_CARD` / `QUANTUM_RP_CREATE_CARD` / `QUANTUM_RC_CREATE_CARD`
- `MakeCardFeeRP` / `MakeCardFeeNM`

**Markup 费 (按卡品牌/供应商):**
- `QUANTUM_CARD_MARKUP_FEE_NM` / `QUANTUM_CARD_MARKUP_FEE_RP` / `QUANTUM_CARD_MARKUP_FEE_RC`
- `QUANTUM_CARD_IPR_AND_RP_MARKUP_FEE` / `QUANTUM_CARD_IPR_AND_RC_MARKUP_FEE`
- `QUANTUM_MARKUP_FEE_V2_NM` / `QUANTUM_MARKUP_FEE_V2_RP` / `QUANTUM_MARKUP_FEE_V2_RC`

**跨境费:**
- `QUANTUM_CARD_CROSS_BORDER_FEE` / `CrossBorderMarkupFee`
- `QUANTUM_CROSS_BORDER_FEE_NM` / `RP` / `RC`

**FX/汇兑费:**
- `QUANTUM_CARD_FX_MARKUP_FEE` / `AuthorizationMarkUpFee` / `AuthorizationMarkupHN`
- `QUANTUM_FX_MARKUP_FEE_NM` / `RP` / `RC` / `IPR_AND_RP` / `IPR_AND_RC`

**ATM/Apple Pay:**
- `QUANTUM_CARD_ATM_WITHDRAWAL_FEE` / `QUANTUM_ATM_WITHDRAWAL_FEE_NM/RP/RC`

**其他:**
- `QUANTUM_CARD_NOT_ACTIVE_FEE` / 非活跃费
- `SettlementFee` / 结算费
- `QUANTUM_AUTHORIZATION_FEE_NM/RP/RC` / 预授权费

#### 2.1.5 API 月结量子卡费率 (Caas variants)

全量费率的 `_Caas` 后缀变体:
- `QUANTUM_CREATE_CARD_Caas` / `QUANTUM_RP_CREATE_CARD_Caas` / `QUANTUM_RC_CREATE_CARD_Caas`
- `QUANTUM_CARD_MARKUP_FEE_V2_NM_Caas` / `RP_Caas` / `RC_Caas`
- `QUANTUM_CROSS_BORDER_FEE_NM_Caas` / `RP_Caas` / `RC_Caas`
- `QUANTUM_FX_MARKUP_FEE_NM_Caas` / `RP_Caas` / `RC_Caas`
- `QUANTUM_ATM_WITHDRAWAL_FEE_NM_Caas` / `RP_Caas` / `RC_Caas`
- `QUANTUM_AUTHORIZATION_FEE_NM_Caas` / `RP_Caas` / `RC_Caas`

静态分组: `API_MONTH_QUANTUM_CARD_FEE_TYPE` 包含 25 个 Caas 类型。

#### 2.1.6 国际转账 (International Transfers)

**SWIFT 费率** (按币种+费率类型):
- `SwiftSHA_HKD` / `SwiftSHA_GBP` / `SwiftSHA_EUR` / `SwiftSHA_AUD` / `SwiftSHA_USD`
- `SwiftOUR_HKD` / `SwiftOUR_GBP` / `SwiftOUR_EUR` / `SwiftOUR_AUD` / `SwiftOUR_USD`
- `SwiftSHA_CAD` / `SwiftSHA_SGD` / `SwiftSHA_JPY` / `SwiftSHA_AED` / `SwiftSHA_ILS` / `SwiftSHA_CNH`
- `SwiftOUR_CAD` / `SwiftOUR_SGD` / `SwiftOUR_JPY` / `SwiftOUR_AED` / `SwiftOUR_ILS` / `SwiftOUR_CNH`

**本地清算费率**:
- `LocalCHATS_HKD` / `LocalFPS_HKD`
- `LocalSEPA_EUR`
- `LocalACH_USD` / `LocalWIRE_USD`
- `LocalFAST_SGD`
- `LocalIBG_MYR`
- `LocalPayNow_SGD`

**阶梯定价**:
- `SwiftACOTier1Tier2` / `SwiftACOTier3` / `SwiftACOTier4` / `SwiftACOTier5`
- `LocalPaymentFee1` ~ `LocalPaymentFee6`

#### 2.1.7 返现 (Cashback)

- `QUANTUM_CREATE_CARD_CASH_BACK` ~ 开卡返现
- `QUANTUM_ACCOUNT_CASH_BACK` ~ 量子账户返现
- `QUANTUM_CARD_NM_CONSUMPTION_CASH_BACK` ~ NM 卡消费返现
- `GLOBAL_ACCOUNT_SETTLE_CASH_BACK` ~ 全球账户结汇返现
- `GLOBAL_ACCOUNT_CC_INBOUND_CASH_BACK` / `CL_INBOUND` / `PY_INBOUND` ~ 入金返现
- `CRYPTO_ASSET_USD_TRADE_CASH_BACK` ~ 加密资产交易返现

#### 2.1.8 静态分组

```java
// 普通计次费用
COUNT_FEES
// 百分比费用 (~40 种)
PERCENT_FEES
// 加密资产收款 (~16 种)
CRYPTO_ASSET_COLLECTION
// 阶梯费用 (~20 种)
TIERED_FEES
// 量子卡查询用 (16 种)
CARD_FEES
// API 月结费率 (25 种)
API_MONTH_QUANTUM_CARD_FEE_TYPE
```

### 2.2 AccountFeeType（qbit-assets core）

**文件**: `qbit-assets/qbit-core/.../enums/AccountFeeType.java`

与 white-label 版本值相同，但位于 qbit-assets core 项目，`implements IEnum<String>`，额外包含 `L2` / `QB` / `ZB` 等供应商后缀变体。

### 2.3 FeeTypeEnum（pay-core）

**文件**: `pay-core/pay/common/.../enums/FeeTypeEnum.java`

用于收单支付的费率类型枚举：

| 值 | 说明 |
|----|------|
| `ACQUIRING_PERCENT(0)` | 收单百分比费率 |
| `ACQUIRING_COUNT(1)` | 收单笔数费率 |
| `ACQUIRING_MIN(2)` | 收单最低费率 |
| `REFUND(3)` | 退款费率 |
| `SETTLE_CONFIG(4)` | 结算配置 |
| `ACQUIRING_SINGLE_LIMIT(5)` | 收单单笔限额 |
| `ACQUIRING_DAY_COUNT_LIMIT(6)` | 收单日笔数限额 |
| `ACQUIRING_DAY_LIMIT(7)` | 收单日限额 |
| `CHANNEL_USE(8)` | 渠道使用费 |
| `CUSTOMER_DAY_AMOUNT_LIMIT(9)` | 客户日金额限额 |

### 2.4 FeeInfoTypeEnum（pay-core）

**文件**: `pay-core/pay/common/.../enums/v1/FeeInfoTypeEnum.java`

简单二元枚举，标记费率计算方式：

| 值 | 说明 |
|----|------|
| `FIXED(0)` | 固定值（按金额阶梯计费） |
| `PERCENT(1)` | 百分比（按比例计费，支持 min/max cap） |

### 2.5 AgencyFeeTypeEnum（qbit-assets core）

**文件**: `qbit-assets/qbit-core/.../dto/AgencyFeeTypeEnum.java`

| 值 | 说明 |
|----|------|
| `MARKUP_FEE` | Markup 费 |
| `SETTLE_FEE` | 结算费（百分比） |
| `SETTLE_FEE_PER_PIECE` | 结算费（笔数计费） |
| `REFUND_FEE` | 退款费 |
| `FAIL_FEE` | 失败费 |
| `FIX_FEE` | 固定费 |
| `REVERSAL_FEE` | 撤销费 |
| `ATM_FEE` | ATM 费 |
| `APPLE_PAY_FEE` | Apple Pay 费 |

---

## 3. 费率数据模型

### 3.1 AccountFee（qbit-assets core）

**文件**: `qbit-assets/qbit-core/.../entity/account/AccountFee.java`
**表名**: `accountFee`

| 字段 | 类型 | 说明 |
|------|------|------|
| `accountId` | String | 账户 ID |
| `feeType` | AccountFeeType | 费用类型枚举 |
| `rate` | BigDecimal | 费率值 |
| `collectionRate` | BigDecimal | 收单费率 |
| `low` | BigDecimal | 下限 |
| `high` | BigDecimal | 上限 |
| `mathType` | RateMathType | 计费方式枚举 (Count/Percent) |
| `childFeeType` | String | 子费用类型 |
| `startTime/endTime` | Date | 生效/失效时间 |
| `threshold` | BigDecimal | 阈值/门槛 |
| `type` | String | 费率类型（阶梯-Tiered / 单值-Single） |
| `raw` | String | 原始配置（阶梯值 JSON） |
| `provider` | String | 供应商 |
| `providerField` | String | 供应商自定义字段 |

继承自 `Base`，包含 `id`、`remarks`、`createTime`、`updateTime`、`deleteTime`、`version`。

#### 3.1.1 RateMathType

计费方式枚举，值包括：
- `Count` - 按笔数计费（固定费用）
- `Percent` - 按百分比计费

### 3.2 FeeInfo（pay-core）

**文件**: `pay-core/pay/common/.../entity/config/FeeInfo.java`
**表名**: `fee_info`

| 字段 | 类型 | 说明 |
|------|------|------|
| `configId` | Long | 配置 ID（关联 AccountPaymentConfig / ChannelPaymentConfig） |
| `channelId` | Long | 渠道 ID |
| `accountId` | Long | 商户/账户 ID |
| `methodId` | Long | 支付方式 ID |
| `transType` | PayTransactionTypeEnums | 交易类型 |
| `feeType` | FeeInfoTypeEnum | 费率类型 (FIXED/PERCENT) |
| `feeCurrency` | String | 费率币种 |
| `feeValue` | String | 费率值（阶梯映射 JSON 字符串） |
| `commissionValue` | String | 分佣阶梯值 |
| `feeMin` | BigDecimal | 最低费用（百分比模式 cap 用） |
| `feeMax` | BigDecimal | 最高费用（百分比模式 cap 用） |
| `feeReturnType` | String | 可退回交易类型 |
| `activeTime` | Long | 生效时间戳 |
| `invalidTime` | Long | 失效时间戳 |
| `configType` | TargetTypeEnums | 目标类型：CHANNEL/MERCHANT/AGENT/PARTNER |
| `tenantId` | Long | 租户 ID |

**feeValue 格式**: 阶梯映射 JSON，如 `{"100": "0.5", "1000": "0.3", "-1": "0.1"}`，表示：
- 金额 < 100: 费率 0.5%
- 100 <= 金额 < 1000: 费率 0.3%
- 金额 >= 1000: 费率 0.1%

使用 `FeeInfoConvert.INSTANCE.convertTypeStringToIntegerMap()` 转换为 `TreeMap<Integer, BigDecimal>` 用于阶梯查找。

### 3.3 Fee（pay-core）

**文件**: `pay-core/pay/common/.../entity/config/Fee.java`

| 字段 | 类型 | 说明 |
|------|------|------|
| `accountId` | String | 账户 ID |
| `feeSubjectType` | - | 费率主体类型 |
| `feeType` | FeeTypeEnum | 费率类型 |
| `feeRate` | BigDecimal | 费率 |
| `mathType` | FeeMathTypeEnum | 计费方式 |
| `startTime/endTime` | Long | 有效时间范围 |
| `low/high/threshold` | BigDecimal | 限价/阈值 |
| `raw` | Object | 原始配置 |
| `channelId` | - | 渠道 ID |

### 3.4 AgencyFee（qbit-assets core）

详见 [第 5 节：代收费体系](#5-代收费体系-agencyfee)。

### 3.5 费率 VO 体系

**FeeRateVO** - 费率展示层：
- `name` - 费率名称
- `description` - 费率描述
- `List<FeeRateDetailVO>` - 费率明细列表

**FeeRateDetailVO** - 费率明细：
- `name` - 名称
- `value` - 值
- `calculationType` (RateMathType: Count/Percent) - 计费方式
- `unit` - 单位
- `selected` - 阶梯是否被选中

**AdminAccountFeeListVO** - 管理端账户费率列表：
- `id`, `displayId`, `accountType`, `type`, `systemType`
- `verifiedName`, `verifiedNameEn`, `createTime`, `status`
- `List<AccountFee>` - 账户费率列表

**AccountFeeForMerchantVO** - 商户端费率展示：
- `id`, `accountId`, `feeType`, `rate`, `low`, `high`
- `mathType`, `childFeeType`, `startTime`, `endTime`, `threshold`
- `type`, `provider`, `providerField`

**AdminPaymentFeeResultVO** / **AdminPaymentFeeDetailVO** - 管理端出金手续费 VO。

---

## 4. 费用计算引擎

### 4.1 FeeCalculateUtils（pay-core）

**文件**: `pay-core/pay/common/.../utils/FeeCalculateUtils.java`

核心工具类，使用 `@UtilityClass`（Lombok 工具类），统一 `scale=12`、`RoundingMode.UP`。

#### 4.1.1 阶梯值计算 (Ladder)

```java
private static BigDecimal calculateLadderValue(BigDecimal amount, SortedMap<Integer, BigDecimal> ladderMap)
```

- 输入: 金额 + `TreeMap<Integer, BigDecimal>`（阈值→费率映射）
- 遍历有序的 TreeMap，找到金额所在的阈值段
- 金额 < 阈值 → 返回上一个阶梯值
- 金额 >= 所有阈值 → 返回最后一个阶梯值
- 用于: 百分比阶梯费率查找、固定费用阶梯查找

**阶梯匹配示例**:
```
TreeMap: {100 → 2.5%, 1000 → 2.0%, 5000 → 1.5%}
金额 800  → 费率 2.5% (800 < 1000)
金额 3000 → 费率 2.0% (3000 < 5000)
金额 10000 → 费率 1.5% (大于全部阈值，取最后一个)
```

#### 4.1.2 百分比费用计算

```java
public static BigDecimal calculatePercentFee(Acquiring acquiring, FeeInfo feeInfo, CurrencyRateBO amountCurrencyRate)
```

流程:
1. 解析 `feeInfo.feeValue` 为 `TreeMap<Integer, BigDecimal>`
2. 按 USD 金额查阶梯得到 `ladderRate`
3. 费率 = 阶梯费率 × 0.01（页面存储百分比值）
4. 无 min/max cap: `交易金额 × ladderRate × 0.01`
5. 有 min/max cap:
   - 以 USD 金额计算 `usdLadderFee`
   - 应用 `feeMin.max()` / `feeMax.min()` 约束
   - 交易币种 != USD 时: 乘以汇率转换
6. 返回 `scale=12, RoundingMode.UP`

#### 4.1.3 固定费用计算

```java
public static BigDecimal calculateFixFee(BigDecimal amount, FeeInfo feeInfo)
```

- 解析 feeValue 为阶梯映射
- 调用 `calculateLadderValue(amount, ladderMap)` 返回对应阶梯的固定费用
- 无阶梯配置返回 0

```java
// 含汇率转换的版本
public static BigDecimal calculateFixFee(Acquiring acquiring, FeeInfo fixFeeInfo,
                                          CurrencyRateBO feeCurrencyRate,
                                          CurrencyRateBO amountCurrencyRate)
```

流程：
1. 按 USD 金额查阶梯 → `fixFee`（fee 币种金额）
2. fixFee <= 0 → 返回 0
3. 交易币种 == fee 币种: 直接返回 fixFee
4. 否则: fee → USD (1 / feeCurrencyRate) → 交易币种 (× amountCurrencyRate)

#### 4.1.4 拒付相关费用

**拒付百分比**:
```java
public static BigDecimal calculateDisputePercentFee(BigDecimal tradeAmount, String tradeCurrency,
                                                     BigDecimal usdAmount, FeeInfo feeInfo,
                                                     CurrencyRateBO amountCurrencyRate)
```
- 逻辑与 `calculatePercentFee` 类似，但入参直接传交易金额/币种/USD 金额

**拒付固定费用**:
```java
public static BigDecimal calculateDisputeFixFee(String tradeCurrency, BigDecimal usdAmount,
                                                 FeeInfo fixFeeInfo, CurrencyRateBO feeCurrencyRate,
                                                 CurrencyRateBO amountCurrencyRate)
```
- 逻辑与 `calculateFixFee` 相同，入参格式不同

#### 4.1.5 提现费用计算

**提现百分比**:
```java
public static BigDecimal calculateWithdrawalPercentFee(BigDecimal usdAmount, BigDecimal amount,
                                                        WithdrawalFee feeInfo, CurrencyRateBO amountCurrencyRate)
```
- 标准百分比计算，但基于 WithdrawalFee 实体

**含逆向计算的提现百分比**:
```java
public static BigDecimal calculateWithdrawalPercentFee(BigDecimal usdAmount, BigDecimal amount,
                                                        WithdrawalFee feeInfo,
                                                        CurrencyRateBO amountCurrencyRate, BigDecimal fixedFee)
```
- 逆向计算：`fee = amount - (amount - fixedFee) / (rate × 0.01 + 1) - fixedFee`
- 公式推导：从"到账金额 = 总金额 - 固定费用 - 百分比费用"反推百分比费用
- 校验：`amount < fixedFee` → 抛 `CustomException`

**提现固定费用**:
```java
public static BigDecimal calculateWithdrawalFixFee(BigDecimal usdAmount, WithdrawalFee fixFeeInfo)
```
- 标准阶梯固定费用查找

#### 4.1.6 费率值校验

```java
public void checkFeeValue(TreeMap<Long, BigDecimal> feeValueMap, FeeInfoTypeEnum feeType)
```
- PERCENT 类型: 每个阶梯值 ≤ 100%
- Key 不能重复
- Key 和 Value 不能为负数

---

## 5. 代收费体系 (AgencyFee)

### 5.1 数据模型

**文件**: `qbit-assets/qbit-core/.../entity/AgencyFee.java`
**表名**: `agency_fee`
**继承**: `BaseV4`（含 id、remarks、createTime、updateTime、deleteTime、version）

| 字段 | 类型 | 说明 |
|------|------|------|
| `accountId` | String | 账户 ID（费用归属方） |
| `transactionId` | String | 交易 ID |
| `sourceId` | String | 业务 ID（开卡为 cardId，交易为交易业务 ID） |
| `feeType` | String | 费用类型（对应 AgencyFeeTypeEnum 的 value） |
| `fee` | BigDecimal | 代收费用金额 |
| `needSettle` | Boolean | 是否需要结算 |
| `hasSettled` | Boolean | 是否已结算 |
| `transactionTime` | Date | 交易时间 |
| `currency` | String | 币种 |

### 5.2 AgencyFeeTypeEnum

详见 [2.5 节](#25-agencyfeetypeenumqbit-assets-core)。

### 5.3 使用场景

- **开卡代收费**: 开卡时收取 Markup 费、制卡费
- **交易代收费**: 每笔交易按费率计算 Markup、结算费
- **退款代收费**: 退款时按比例扣除已收费用
- **失败的代收费**: 交易失败时收取失败费
- **ATM/Apple Pay 代收费**: 特殊场景的费用代收

---

## 6. 费率管理 API

### 6.1 qbit-assets 管理端

#### AccountFeeAdminController

| 路径 | 方法 | 说明 |
|------|------|------|
| `POST /api/admin/account/fee/detail` | `getAccountFee()` | 费率详情查询 |

- 接收 `CardAccountFeeAdminSearchDTO`
- 返回 `List<AccountFee>`

#### AdminPaymentFeeController

| 路径 | 方法 | 说明 |
|------|------|------|
| `POST /api/admin/payment/account/fee/list` | `accountPaymentFeeList()` | 各账户出金手续费列表 |
| `POST /api/admin/payment/account/fee/detail` | `accountPaymentFeeDetail()` | 账户出金手续费详情 |
| `POST /api/admin/payment/account/fee/type/list` | `accountPaymentFeeList()` | 手续费类型列表 |

### 6.2 qbit-assets 商户端

#### AccountFeeController

| 路径 | 方法 | 说明 |
|------|------|------|
| `POST /api/account/fee/detail` | `getAccountFee()` | 当前账户费率详情 |
| `POST /api/account/fee/list` | `accountFeeList()` | 全量用户费率（限定量子卡） |

#### InternalAccountFeeController

| 路径 | 方法 | 说明 |
|------|------|------|
| `POST /qbit-assets/account/fee/detail` | `getAccountFee()` | 内部接口：费率详情 |
| `POST /qbit-assets/account/fee/list` | `accountFeeList()` | 内部接口：费率列表 |
| `POST /qbit-assets/account/fee/list-by-account-id` | `listByAccountId()` | 内部接口：按账户+费率类型查询 |
| `POST /qbit-assets/account/fee/card-bin-create-card-fee` | `getCardBinCreateCardFee()` | 内部接口：按账户+卡 BIN 查询开卡费率 |

- 标注 `@NoAuth(NoAuth.INTERNAL)` 表示内部接口
- 请求头需要传递 `account-id`

---

## 7. 费率校验与规则

### 7.1 FeeRateSections

**文件**: `qbit-assets/qbit-core/.../enums/FeeRateSections.java`

静态映射 `Map<AccountFeeType, FeeRateSection>`，定义了各费率类型的允许范围：

```
FeeRateSection { max, min, isPercent }
```

| AccountFeeType | max | min | isPercent |
|---------------|-----|-----|-----------|
| `QUANTUM_CREATE_CARD_CASH_BACK` | 1.0 | 0.0 | true |
| `DECLINE_FEE_API_ACCOUNT` | 100.0 | 0.0 | true |
| `DECLINE_FEE_MERCHANT_ACCOUNT` | 100.0 | 0.0 | true |
| `QUANTUM_CARD_NM_CONSUMPTION_CASH_BACK` | 0.02 | 0.0 | true |
| `GLOBAL_ACCOUNT_SETTLE_CASH_BACK` | 0.007 | 0.0 | true |
| `CRYPTO_ASSET_USD_TRADE_CASH_BACK` | 100000000.0 | 0.0 | false |
| `SwiftSHA` | null | 6.5 | false |
| `SwiftACOTier1Tier2` | null | 17.5 | false |
| `LocalPaymentFee1` | null | 0.5 | false |
| `OpenReapCard` | null | 5.0 | false |

约 30 个 fee type 配置了校验规则，覆盖开卡返现、decline 费、消费返现、SWIFT/本地支付固定费率。

### 7.2 FeeValue 校验 (pay-core)

`FeeCalculateUtils.checkFeeValue()` 在新增/更新费率时执行：

1. **百分比限制**: PERCENT 类型的每个阶梯值不能超过 100%
2. **Key 去重**: 阶梯映射中不能有重复阈值
3. **非负性**: 所有 key 和 value ≥ 0

---

## 8. Partner 合作方费率

### 8.1 PartnerFeeType

**文件**: `qbit-assets/qbit-core/.../enums/PartnerFeeType.java`

当前实现值：
- `AccountDeposit` - 量子账户充值

注释中列出的规划费率类型：
- **Web3**: Crypto_Assets, Global_Account_Charging, Partner_Settlement, Partner_QbitCard_Recharge, Partner_Inbound_fee_Settlement
- **量子账户**: Partner_QbitCard_Kyb_Passed, Partner_QbitCard_Action, Partner_QbitCard_Recharge
- **全球账户**: Partner_Register, Partner_Action, Partner_GlobalAccount_Kyb_Passed, Partner_Settlement, Partner_Inbound_fee_Settlement

### 8.2 Agent/Partner 费率 (pay-core)

`FeeInfoService` 提供了独立的 Agent/Partner 费率管理接口：

| 方法 | 说明 |
|------|------|
| `upsertAgentPartner()` | 创建/更新代理商或直清机构费率 |
| `listAgentPartnerFee()` | 查询代理商/直清机构费率 |

Agent/Partner 使用 `configType = AGENT(3)` 或 `PARTNER_DIRECT_CLEAR(4)`。

---

## 9. Fee Trade 类型

### 9.1 AccountFeeTradeEnum

**文件**: `qbit-assets/qbit-core/.../enums/AccountFeeTradeEnum.java`

| 值 | 说明 |
|----|------|
| `Default` | 默认手续费交易类型 |
| `ApiMonthlyCurrent` | API 月结实时交易 |
| `ApiMonthlyAsync` | API 月结异步 T+1 交易 |

`implements IEnum<String>`，MyBatis-Plus 枚举映射。

### 9.2 PayTransactionTypeEnums（pay-core）

`FeeInfo.transType` 使用的交易类型枚举，用于在 fee_info 表中区分不同交易场景的费用配置：
- 正常的收单交易
- 拒付 (CHARGEBACK_FEE)
- RDR 费用 (RDR_FEE)
- ETHOCA 费用 (ETHOCA_FEE)

### 9.3 TargetTypeEnums（pay-core）

`FeeInfo.configType` 使用的目标类型枚举：

| 值 | 说明 |
|----|------|
| CHANNEL(1) | 渠道费率 |
| MERCHANT(2) | 商户费率 |
| AGENT(3) | 代理商费率 |
| PARTNER_DIRECT_CLEAR(4) | 直清机构费率 |
| PARTNER_INDIRECT_CLEAR(5) | 间清机构费率 |

---

## 10. FeeInfoService 核心服务

### 10.1 接口定义

**文件**: `pay-core/pay/common/.../service/config/FeeInfoService.java`

| 方法 | 说明 |
|------|------|
| `upsert(FeeInfoCreateDTO)` | 创建/更新费率（商户/渠道） |
| `removeFeeInfo(FeeInfoRemoveDTO)` | 删除费率（仅可删除未生效的） |
| `listByQuery(FeeInfoQueryDTO)` | 查询费率列表 |
| `removeByAccountPaymentConfig(AccountPaymentConfig)` | 按支付配置删除关联费率 |
| `upsertAgentPartner(FeeInfoForAgentPartnerCreateDTO)` | 代理商/直清机构费率增改 |
| `listAgentPartnerFee(FeeInfoAgentPartnerQueryDTO)` | 代理商/直清机构费率查询 |
| `chargebackFeeUpsert(ChargebackFeeUpsertDTO)` | 拒付费率增改 |
| `chargebackPageByQuery(ChargebackFeePageQueryDTO)` | 拒付费率分页查询 |
| `getDisputeFeeWithFeeType(Long, FeeInfoTypeEnum)` | 获取拒付费用费率 (CHARGEBACK_FEE) |
| `fetchRdrFeeWithFeeType(Long, FeeInfoTypeEnum)` | 获取 RDR 费用费率 |
| `fetchEthocaFeeWithFeeType(Long, FeeInfoTypeEnum)` | 获取 ETHOCA 费用费率 |
| `getClearingFeeInfoMap(Long, PayTransactionTypeEnums, TargetTypeEnums)` | 获取清算费率 Map (PERCENT + FIXED) |

### 10.2 核心逻辑

#### 10.2.1 upsert 流程

1. `checkCreateDto()` — 校验生效时间(≥当前时间-60s)、feeMin ≤ feeMax
2. `FeeCalculateUtils.checkFeeValue()` — 校验阶梯值合法性
3. `checkAndFillQuery()` — 按 configType 补齐 channelId / methodId / accountId
4. `validateNoDuplicates()` — 检查相同生效时间的重复配置
5. FIXED 类型清空 feeMin/feeMax
6. 新记录 → 写入 DB → `removeInvalidFee()` 清理过期历史
7. 更新记录 → 逻辑删除旧记录 → 写入新记录 → 清理过期历史

#### 10.2.2 removeInvalidFee 清理策略

按 configType + configId + channelId + accountId + methodId + transType + feeType + feeCurrency 分组：
- 保留生效时间最新的一条记录
- 其余历史记录设置 `invalidTime = now - 1`（逻辑失效）

#### 10.2.3 拒付费用专用

`getDisputeFeeWithFeeType` / `fetchRdrFeeWithFeeType` / `fetchEthocaFeeWithFeeType`:
- 按 accountId + transType + feeType 查询
- `activeTime ≤ now` 且 `ORDER BY activeTime DESC LIMIT 1`
- 多于 1 条抛出 `SystemException`
- 找不到返回 null（代表无手续费）

#### 10.2.4 清算费率获取

`getClearingFeeInfoMap`:
- 根据 configId + transType 分别查询 PERCENT 和 FIXED 类型的活跃费率
- 返回 `Map<FeeInfoTypeEnum, FeeInfo>`（最多 2 条）

---

## 11. 跨项目对比

| 维度 | qbit-assets | pay-core | white-label-server |
|------|-------------|----------|-------------------|
| **核心实体** | `AccountFee` (accountFee表), `AgencyFee` (agency_fee表) | `FeeInfo` (fee_info表), `Fee`, `WithdrawalFee` | `AccountFeeType` 枚举定义 |
| **Fee Type 枚举** | `AccountFeeType` (core), `AgencyFeeTypeEnum`, `PartnerFeeType`, `FeeRateSections` | `FeeTypeEnum`, `FeeInfoTypeEnum`, `PayTransactionTypeEnums`, `TargetTypeEnums` | `AccountFeeType` (1210行, 最完整) |
| **计费模式** | Count / Percent / Tiered (通过 `RateMathType` + `threshold` + `raw`) | Ladder(阶梯) / Percent / Fix / Withdrawal (通过 `FeeCalculateUtils`) | - |
| **阶梯计费** | 字段: `type=Tiered`, `raw=JSON` | 字段: `feeValue=JSON` → `TreeMap` 解析 | - |
| **费用归属** | 按 `accountId` 区分 | 按 `configType` (CHANNEL/MERCHANT/AGENT/PARTNER) + `accountId` | - |
| **时间管理** | `startTime/endTime` | `activeTime/invalidTime` + 历史清理逻辑 | - |
| **缓存** | 通过 AccountFeeService 管理 | - | - |
| **管理 API** | 3 个 Controller（admin/merchant/internal） | FeeInfoService 内部服务 | - |
| **收单清算** | - | 核心: `FeeCalculateUtils` + `FeeInfoService` + `AcquiringClearingHandler` | - |
| **代收费** | `AgencyFee` + `AgencyFeeTypeEnum` | - | - |
| **合作方费率** | `PartnerFeeType` | Agent/Partner 费率管理 | - |
