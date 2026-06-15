# 粒子理财体系 (Particle Finance)

## 概述

粒子理财是 Qbit 的资金增值服务模块，为商户提供固定收益理财和基金产品投资能力。系统分 V1 和 V2 两套版本：

- **V1（固定收益理财）**：用户存入 USD/USDC，按 APR 每日计息，支持转入/转出（T+0/T+1），由 admin 每日配置 APR 后自动发放收益
- **V2（基金产品）**：对接 Habit 外部基金平台和内部基金产品，支持申购/赎回，按净值计算份额和收益，T+1/T+2 确认

> V1 核心模块（APR 管理、收益自动发放、仪表板、本金快照、企业微信通知）由 martinjiang（江星）开发。

## V1 整体架构

```
┌───────────────────────────────────────────────────────────────┐
│                       管理端 (Admin)                           │
│  AdminFinancingController → 粒子理财管理                       │
│  AdminFinancingDashBoardController → 仪表板                    │
│  AdminFinancingProfitController → 收益管理                     │
│  AdminFinancingTransferController → 交易管理                   │
├───────────────────────────────────────────────────────────────┤
│                       商户端 (Merchant)                        │
│  FinancingController → 理财操作                                │
│  FinancingProfitController → 收益查询                          │
│  FinancingTransferController → 转入/转出                       │
├───────────────────────────────────────────────────────────────┤
│                       V1 核心服务层                              │
│  FinancingService → 开户/余额/统计                             │
│  FinancingTransferService → 转入/转出/完结                      │
│  FinancingProfitService → 收益记录/客户 APR                    │
│  FinancingAPRService → APR 计算/保存/自动发放                  │
│  FinancingBookkeepingService → 流水记账                        │
│  FinancingCapitalBalanceService → 在投本金管理                 │
│  FinancingProfitBalanceService → 收益余额管理                  │
├───────────────────────────────────────────────────────────────┤
│                      定时任务层                                  │
│  ProfitJob → 每日收益自动发放 (financing_job_handler)           │
│  LockUpPrincipalJob → 19点锁在投本金 (lock_up_principal_job)   │
└───────────────────────────────────────────────────────────────┘
```

## V1 核心实体

### FinancingCapitalBalance (`financing_capital_balances`)

扩展本金账户的 balance，id 与本金账户 balance id 同步：

| 字段 | 说明 |
|------|------|
| accountId | 账户ID |
| currency | 币种 (USDC/USD) |
| invest | 在投金额 |

### FinancingProfitBalance (`financing_profit_balances`)

扩展收益账户的 balance：

| 字段 | 说明 |
|------|------|
| id | 与余额 balance id 同步 |
| yesterdayProfit | 昨日收益 |
| totalProfit | 累计收益 |
| withdrawProfit | 已提取收益 |

### FinancingTransfer (`financing_transfers`)

理财转入/转出交易记录：

| 字段 | 说明 |
|------|------|
| accountId | 用户ID |
| tradeId | 三方交易id |
| transactionId | 总表交易id |
| action | 交易类型 (IN=转入 / OUT=转出) |
| currency | 币种 |
| originAmount | 原始交易金额 |
| settlementAmount | 结算金额 |
| fee | 手续费 |
| status | 状态 (Pending/Closed) |
| fromBalanceId | 转出方钱包id |
| toBalanceId | 转入方钱包id |
| senderType | 发送方类型 |
| recipientType | 接收方类型 |

### FinancingProfit (`financing_profits`)

每日收益记录：

| 字段 | 说明 |
|------|------|
| accountId | 账户ID |
| currency | 币种 |
| amount | 收益金额 |
| capital | 本金 |
| apr | APR 值 |
| date | 收益日期 (yyyy-MM-dd) |
| status | 状态 |

### FinancingBookkeeping (`financing_bookkeeping`)

流水记账表：

| 字段 | 说明 |
|------|------|
| accountId | 用户ID |
| transferId | 交易ID |
| balanceId | 钱包id |
| transferInAmount | 转入金额 |
| transferOutAmount | 转出金额 |
| available | 余额 |
| profitTime | 开始产生收益时间 |
| last | 是否为最新记录 |

### FinancingAPR (`financing_apr`)

APR 配置表（martinjiang 开发）：

| 字段 | 说明 |
|------|------|
| remarks | 备注 |
| userId | 操作人 |
| date | 日期 |
| system | 系统 APR（平台收益） |
| customer | 客户 APR（用户收益） |
| startCapital | 期初本金 |
| endCapital | 期末本金 |
| startProfit | 期初收益 |
| endProfit | 期末收益 |
| isSend | 是否已发放 |

## V2 整体架构

```
┌───────────────────────────────────────────────────────────────┐
│                       管理端 (Admin)                           │
│  AdminFundOrderController → 订单管理/审核                      │
│  AdminFundProfitController → 收益管理                          │
│  AdminParticleBankingAccountOpenController → 开户管理          │
├───────────────────────────────────────────────────────────────┤
│                       商户端 (Merchant)                        │
│  FundController → 理财资产列表                                 │
│  FundOrderController → 申购/赎回                               │
│  FundHoldingController → 持仓查询                              │
│  FundProductController → 产品列表/详情                         │
│  FundProfitController → 收益查询                               │
│  FundQuotationCurveController → 净值曲线                       │
├───────────────────────────────────────────────────────────────┤
│                       V2 核心服务层                              │
│  FundService → 申购/赎回资产列表                               │
│  FundProductService → 产品管理                                 │
│  FundOrderService → 申购/赎回/审核/持仓                        │
│  FundHoldingService → 持仓管理                                 │
│  FundProfitService → 收益管理                                  │
│  FundQuotationCurveService → 净值曲线                          │
│  FundReconciliationService → 理财对账                          │
│  ExpenseAccountService → 费用账户管理                          │
├───────────────────────────────────────────────────────────────┤
│                      资金划转层                                  │
│  FundTransferFactory → 申购/赎回资金工厂                       │
│  FundTransferProvider (接口)                                    │
│    ├─ FundTransferCryptoAssetProviderImpl → 加密资产渠道       │
│    └─ FundTransferGlobalAccountProviderImpl → 全球账户渠道     │
├───────────────────────────────────────────────────────────────┤
│                      Habit 对接层                                │
│  habit/dto/ → 开户/申购/状态查询 DTO                          │
│  habit/entity/FundExpenseAccount → 费用账户                    │
│  habit/utils/BusinessUtils → 业务工具                          │
└───────────────────────────────────────────────────────────────┘
```

## V2 核心实体

### FundProduct (`fund_products`)

基金产品：

| 字段 | 说明 |
|------|------|
| code | 基金产品 code |
| nameEn | 产品名称(英文) |
| nameZh | 产品名称(中文) |
| currency | 币种 (USD) |
| date | 净值对应日期 |
| netValue | 净值 |
| minPurchaseAmount | 最小申购金额 |
| maxPurchaseAmount | 最大申购金额 |
| minRedeemShare | 最小赎回份额 |
| profitSevenDays | 七日年化收益率 |
| annualPercentageRate | 年化收益率 |
| platform | 平台 (HABIT / INTERNAL) |
| defaulted | 是否为默认产品 |
| purchaseAssets | 支持申购的资产类型 |
| redeemAssets | 接收赎回资金的资产类型 |

### FundOrder (`fund_orders`)

申购/赎回订单：

| 字段 | 说明 |
|------|------|
| accountId | 账户ID |
| productId | 产品ID |
| tradeId | 三方交易ID |
| type | 订单类型 (PURCHASE / REDEEM) |
| currency | 币种 |
| amount | 本币金额 |
| fees | 技术服务费 |
| netValue | 确认净值 |
| share | 份额 |
| status | 状态 (PENDING / COMPLETE / CANCELLED / FAILED) |
| platform | 平台 |
| source | 转出方（资金类型+ID） |
| destination | 转入方（资金类型+ID） |
| hidden | 是否对商户端隐藏 |

### FundHolding (`fund_holdings`)

用户持仓：

| 字段 | 说明 |
|------|------|
| accountId | 账户ID |
| productId | 产品ID |
| share | 持仓份额 |
| yesterdayProfit | 昨日收益 |
| holdingProfit | 累计持有收益 |
| yesterdayDate | 昨日收益日期 |
| lastNetValue | 最后一次发放收益的净值 |

### FundProfit (`fund_profits`)

收益记录：

| 字段 | 说明 |
|------|------|
| accountId | 账户ID |
| productId | 产品ID |
| date | 收益日期 |
| currency | 币种 |
| netValue | 净值 |
| share | 持仓份额 |
| apr | 7日年化收益率 |
| profit | 收益金额 |
| fees | 技术服务费 |
| status | 结算状态 (UNSETTLED / PENDING / SETTLED) |

### FundQuotationCurve (`fund_quotation_curves`)

净值曲线：

| 字段 | 说明 |
|------|------|
| productId | 产品ID |
| date | 日期 |
| netValue | 净值 |
| rate | 7日年化收益率 |

## V1 核心业务流程

### 开户流程

```
商户开户申请
    ↓
FinancingService.create(accountId)
    ├── 创建本金账户 Balance (FinancingWallet, USDC/USD)
    ├── 创建收益账户 Balance (FinancingProfitWallet, USD)
    ├── 创建 FinancingCapitalBalance 扩展表
    └── 创建 FinancingProfitBalance 扩展表
```

### 转入流程（入金）

```
用户发起转入（从量子卡/全球账户/加密钱包 → 理财）
    ↓
FinancingTransferService.transferIn()
    ├── 校验账户/余额
    ├── 判断转入类型 (QbitCard/Global/VirtualUSD/CircleWallet)
    ├── 创建 FinancingTransfer (PENDING)
    ├── balanceService.singleBalanceAddAmountToPending (动钱)
    └── 发送企业微信通知

转出方确认完结
    ↓
FinancingTransferService.closedTransferIn()
    ├── 校验状态 (必须是 PENDING)
    ├── closeFinancingTransfer() → 更新状态为 Closed
    └── financingBookkeepingIn() → 更新记账表 + profitTime
```

### 转出流程（出金）

```
用户发起转出（从理财 → 量子卡/全球账户/加密钱包）
    ↓
FinancingTransferService.transferOut()
    ├── 校验余额
    ├── financingBookkeepingOut() → 计算手续费
    ├── 创建 FinancingTransfer (PENDING)
    ├── balanceService.singleBalanceSubAmountToPending (动钱)
    └── 发送企业微信通知

资金方确认完结
    ↓
FinancingTransferService.closedTransferOut()
    ├── 校验状态 (必须是 PENDING)
    └── closeFinancingTransfer() → 更新状态为 Closed
```

### 收益发放流程（每日）

```
ProfitJob (financing_job_handler, XXL-Job)
    ↓
1. 清除所有用户的昨日收益 (yesterdayProfit = 0)
    ↓
2. FinancingAPRService.getApr() → 获取当天 APR
    ↓
3. FinancingAPRService.isAllowSend() → 检查是否允许发放
    ↓
4. FinancingAPRService.autoSendProfit()
    ├── 遍历所有有理财余额的用户
    ├── 计算每日收益 = 本金 × APR / 365
    ├── 创建 FinancingProfit 记录
    ├── 更新 FinancingProfitBalance (收益余额 + 昨日收益)
    └── 更新 FinancingAPR.isSend = true

LockUpPrincipalJob (lock_up_principal_job_handler)
    ↓
每天 19:00 执行
    ↓
1. saveAllFinancingWalletSnapshot() → 存储本金快照
2. 锁住两天内有交易的在投本金 → 用于第二天计算可收益本金
```

## V2 核心业务流程

### 申购流程

```
用户选择产品 + 输入金额
    ↓
1. FundOrderService.checkPurchaseParams()
    ├── 检查产品有效性
    ├── 检查单笔限额 (min/max)
    ├── 检查当日限额 (300万 USD)
    ├── 检查累计限额 (1000万 USD)
    └── 检查是否开户
    ↓
2. FundOrderService.purchase()
    ├── 校验账户业务状态 (非清退中)
    ├── Redisson 分布式锁 (accountId + productId)
    ├── FundTransferFactory.purchase()
    │   ├── 从用户资产扣款 (source asset → fund account)
    │   └── 异步 fund account 加钱
    ├── 创建 FundOrder (PENDING)
    └── 发布 FundOrderEvent
    ↓
3. Admin 审核 → FundOrderService.review()
    ├── COMPLETE → 确认份额, 更新持仓
    └── CANCELLED/FAILED → 拒绝
```

### 赎回流程

```
用户发起赎回
    ↓
1. FundOrderService.redeem()
    ├── 校验业务状态
    ├── Redisson 分布式锁
    ├── 检查持仓份额充足
    ├── 计算未结算收益 + 手续费
    ├── 创建 FundOrder (PENDING)
    ├── handleProfitSettles() → 更新收益结算状态
    └── updateHolding() → 更新持仓
    ↓
2. Admin 审核 → FundOrderService.review()
    ├── COMPLETE → FundTransferFactory.redeem()
    │   ├── fund account 减钱
    │   └── 异步用户资产加钱
    └── CANCELLED/FAILED → 拒绝
```

### 交易确认规则

```
申购确认：
  09:50 前提交 → T+1 确认
  09:50 后提交 → T+2 确认

净值使用：
  申购 → 按确认日的净值计算份额
  收益 → 每日按持仓份额 × 净值计算
```

## 核心枚举

| 枚举 | 说明 |
|------|------|
| `FundPlatformEnum` | 基金平台：HABIT / INTERNAL |
| `FundOrderTypeEnum` | 订单类型：PURCHASE(申购) / REDEEM(赎回) |
| `FundOrderStatusEnum` | 订单状态：PENDING / COMPLETE / CANCELLED / FAILED |
| `FundProfitStatusEnum` | 结算状态：UNSETTLED / PENDING / SETTLED |
| `FundDateIntervalEnum` | 日期范围类型 |
| `WalletTypeEnum` | V1 钱包类型：FinancingWallet / FinancingProfitWallet |

## 资金划转架构 (V2 FundTransferFactory)

采用工厂 + 策略模式，支持多种资金来源/去向：

```
FundTransferFactory (静态工厂)
    │
    ├── purchase() → 从用户资产扣款 → fund account 加钱
    └── redeem()  → fund account 减钱 → 用户资产加钱
    │
    └── FundTransferProvider (策略接口)
        ├── supports(type) → 判断是否支持该渠道
        ├── getAccountIdAndBalanceId()
        ├── transferOut() → 扣款（申购）
        └── transferIn()  → 入账（赎回）
        │
        ├── FundTransferCryptoAssetProviderImpl → 加密资产渠道
        └── FundTransferGlobalAccountProviderImpl → 全球账户渠道
```

## V1 与 V2 对比

| 维度 | V1 | V2 |
|------|----|----|
| 定位 | 固定收益理财 | 基金产品投资 |
| 开发者 | martinjiang + litao + klover | litao |
| 收益方式 | APR 每日计息，admin 配置利率 | 净值浮动，按份额计算 |
| 产品 | 单一产品（USD/USDC 存款） | 多种基金产品，可配置 |
| 资金来源 | 量子卡/全球账户/加密钱包 | 全球账户/加密资产/闪付钱包 |
| 确认时间 | T+0 (USDC) / T+1 (USD) | T+1/T+2 |
| 外部对接 | 无 | Habit 基金平台 |
| 核心模式 | 转入→锁本金→计息→转出 | 申购→确认份额→持有→赎回 |
| 手续费 | 可配置 fee | 技术服务费 (AmountDTO) |
| 对账 | 无独立对账 | FundReconciliationService |
| 订单审核 | 无（自动完成） | Admin 审核申购/赎回 |

## 关键路径速查

### V1

| 路径 | 说明 |
|------|------|
| `common_all/financing/v1/service/FinancingService.java` | 开户/余额/统计 |
| `common_all/financing/v1/service/FinancingTransferService.java` | 转入/转出/完结/锁本金 |
| `common_all/financing/v1/service/FinancingProfitService.java` | 收益记录/客户 APR |
| `common_all/financing/v1/service/FinancingAPRService.java` | APR 计算/保存/自动发放 **(martinjiang)** |
| `common_all/financing/v1/service/FinancingBookkeepingService.java` | 流水记账 |
| `common_all/financing/v1/service/FinancingCapitalBalanceService.java` | 在投本金 |
| `common_all/financing/v1/service/FinancingProfitBalanceService.java` | 收益余额 |
| `common_all/financing/v1/service/impl/FinancingTransferServiceImpl.java` | 转入/转出实现 (含仪表板+导出+通知 = **martinjiang**) |
| `common_all/financing/v1/service/impl/FinancingAPRServiceImpl.java` | APR 计算实现 **(martinjiang)** |
| `common_all/financing/v1/domain/entity/FinancingAPR.java` | APR 实体 **(martinjiang)** |
| `admin/financing/v1/controller/AdminFinancingController.java` | 管理端理财管理 |
| `admin/financing/v1/controller/AdminFinancingDashBoardController.java` | 仪表板 |
| `merchant/financing/v1/controller/FinancingController.java` | 商户端理财操作 |
| `job/financing/ProfitJob.java` | 每日收益自动发放 |
| `job/financing/LockUpPrincipalJob.java` | 19点锁在投本金 |

### V2

| 路径 | 说明 |
|------|------|
| `common_all/financing/v2/service/FundService.java` | 申购/赎回资产列表 |
| `common_all/financing/v2/service/FundProductService.java` | 产品管理 |
| `common_all/financing/v2/service/FundOrderService.java` | 申购/赎回/审核/持仓 |
| `common_all/financing/v2/service/FundHoldingService.java` | 持仓管理 |
| `common_all/financing/v2/service/FundProfitService.java` | 收益管理 |
| `common_all/financing/v2/service/FundReconciliationService.java` | 理财对账 |
| `common_all/financing/v2/service/FundTransferFactory.java` | 申购/赎回资金工厂 |
| `common_all/financing/v2/service/FundTransferProvider.java` | 资金划转策略接口 |
| `common_all/financing/v2/service/impl/FundTransferCryptoAssetProviderImpl.java` | 加密资产渠道 |
| `common_all/financing/v2/service/impl/FundTransferGlobalAccountProviderImpl.java` | 全球账户渠道 |
| `common_all/financing/v2/domain/entity/FundProduct.java` | 基金产品 |
| `common_all/financing/v2/domain/entity/FundOrder.java` | 申购/赎回订单 |
| `common_all/financing/v2/domain/entity/FundHolding.java` | 持仓 |
| `common_all/financing/v2/domain/entity/FundProfit.java` | 收益 |
| `common_all/financing/v2/domain/entity/FundQuotationCurve.java` | 净值曲线 |
| `common_all/financing/v2/habit/` | Habit 基金平台对接 |
| `admin/financing/v2/controller/AdminFundOrderController.java` | 订单审核 |
| `merchant/financing/v2/controller/FundOrderController.java` | 申购/赎回 |
| `merchant/financing/v2/controller/FundHoldingController.java` | 持仓查询 |
| `merchant/financing/v2/controller/FundProductController.java` | 产品列表 |
