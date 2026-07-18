# 资产体系

## 概述

资产体系是 Qbit 的核心资产管理模块，提供加密资产托管、转账、兑换、汇率、钱包地址管理、支付出金、报表分析等能力。系统对接多个交易所和托管钱包（OKX、Gate、HashKey、Cobo、Cregis、Safeheron），通过工厂策略模式实现多源汇率获取和多渠道出金路由。

## 整体架构

```
┌──────────────────────────────────────────────────────────────────┐
│                       商户端 (Merchant)                            │
│  AssetsController → 充提币/资产查询                                │
│  CryptoAssetV2Controller → 加密资产 V2                             │
│  PayoutController → 出金                                          │
├──────────────────────────────────────────────────────────────────┤
│                       管理端 (Admin)                               │
│  AdminCryptoAssetV2Controller → 加密资产概览                       │
│  AdminAssetsController → 资产管理                                  │
│  AdminPayoutController → 出金管理                                  │
├──────────────────────────────────────────────────────────────────┤
│                     核心业务服务层                                  │
│  CryptoAssetsTransferService → 转账                                │
│  CryptoAssetsTransactionService → 交易查询                         │
│  CryptoAssetsWalletService → 钱包管理                              │
│  CryptoAssetsRateService → 汇率                                   │
│  CryptoAssetsRefundService → 退款                                 │
├──────────────────────────────────────────────────────────────────┤
│                     支付出金层 (Payout)                             │
│  PayoutFactory + PayoutService                                     │
│  ├─ GeoPayoutServiceImpl → Geo 渠道                               │
│  ├─ RdWalletPayoutServiceImpl → RdWallet 渠道                     │
│  └─ ThunesPayoutServiceImpl → Thunes 渠道                         │
├──────────────────────────────────────────────────────────────────┤
│                     钱包 & 地址管理层                                │
│  SubAccountPool → 子账户资金池                                     │
│  CryptoWalletAddressFactory → 地址生成工厂                         │
│  AddressScanQuotaService → 地址扫描配额                            │
├──────────────────────────────────────────────────────────────────┤
│                     汇率 & 报价层                                   │
│  CryptoRateService → 汇率服务                                      │
│  CryptoQuoteService → 报价服务                                     │
├──────────────────────────────────────────────────────────────────┤
│                     报表导出层 (Report)                              │
│  ReportFactory + AbstractReportHandler                              │
│  ├─ CryptoAssetsReportHandler → 加密资产报表                       │
│  ├─ PayoutReportHandler → 出金报表                                 │
│  └─ ... (7+ 报表类别)                                              │
├──────────────────────────────────────────────────────────────────┤
│                     三方托管/交易所层                                │
│  Cobo / Cregis / Safeheron / OKX / Gate / HashKey / Circle        │
└──────────────────────────────────────────────────────────────────┘
```

## 核心实体

### CryptoAssetsTransfer（资产转账）

| 字段 | 说明 |
|------|------|
| accountId | 账户ID |
| balanceId | 钱包余额ID |
| currency | 币种 |
| amount | 金额 |
| fee | 手续费 (Gas) |
| action | 方向 (IN/OUT) |
| status | 交易状态 |
| fromAddress | 发送地址 |
| toAddress | 接收地址 |
| txHash | 交易哈希 |
| provider | 三方渠道 |

### CryptoAssetsWallet（钱包）

| 字段 | 说明 |
|------|------|
| walletId | 钱包ID |
| accountId | 账户ID |
| currency | 币种 |
| balance | 余额 |
| frozenBalance | 冻结余额 |
| availableBalance | 可用余额 |
| status | 状态 |

### CryptoAssetsAddress（地址）

| 字段 | 说明 |
|------|------|
| addressId | 地址ID |
| walletId | 钱包ID |
| address | 地址 |
| chain | 链类型 |
| label | 标签 |
| status | 状态 |

### PayoutRecord（出金记录）

| 字段 | 说明 |
|------|------|
| payoutId | 出金ID |
| accountId | 账户ID |
| amount | 金额 |
| currency | 币种 |
| fee | 手续费 |
| channel | 出金渠道 |
| status | 状态 |
| counterparty | 对手方 |

### 其它实体

| 实体 | 说明 |
|------|------|
| `CryptoAssetsTransaction` | 交易记录 |
| `CryptoAssetsRefund` | 退款记录 |
| `CryptoAssetsRate` | 汇率记录 |
| `CryptoAssetsQuote` | 报价记录 |
| `CryptoAssetsChain` | 链信息 |
| `CryptoAssetsCurrency` | 币种信息 |
| `SubAccountPool` | 子账户资金池 |
| `AddressScanQuota` | 地址扫描配额 |
| `AddressScanHistory` | 扫描历史 |
| `PayoutBatch` | 批量出金 |
| `PayoutTemplate` | 出金模板 |
| `CircleTransfer` | Circle 转账 |
| `CircleWallet` | Circle 钱包 |
| `CirclePayout` | Circle 出金 |
| `WalletBalanceSnapshot` | 钱包余额快照 |
| `FeeRateConfig` | 费率配置 |
| `ChainConfig` | 链配置 |
| `CurrencyConfig` | 币种配置 |
| `AssetStatistics` | 资产统计 |
| `AssetReport` | 资产报表 |
| `AssetAuditLog` | 资产审计日志 |
| `AssetComplianceRecord` | 合规记录 |
| `AssetRiskAssessment` | 风控评估 |
| `ColdWalletTransfer` | 冷钱包转账 |
| `HotWalletBalance` | 热钱包余额 |

## 核心服务

### CryptoAssetsTransferService — 转账服务

完整转账流程：

```
转账请求
    ↓
参数校验 (币种/金额/地址)
    ↓
余额检查 (availableBalance ≥ amount + fee)
    ↓
风控校验 (RiskService)
    ↓
冻结余额
    ↓
三方转账 (交易所/托管钱包)
    ↓
链上广播
    ↓
MQ 监听确认
    ↓
更新状态 (成功/失败)
    ↓
余额更新 + 解冻
    ↓
记录审计日志
```

**核心方法：**
- `transferOut()` — 统一出金入口
- `transferOutNotice()` — 出金通知
- `getTransferDetail()` — 转账详情
- `listTransfers()` — 转账列表
- `calculateFee()` — 手续费计算

### CryptoAssetsTransactionService — 交易查询

| 方法 | 说明 |
|------|------|
| `listTransactions()` | 交易列表 |
| `getTransactionDetail()` | 交易详情 |
| `exportTransactions()` | 交易导出 |

### CryptoAssetsWalletService — 钱包管理

| 方法 | 说明 |
|------|------|
| `getBalance()` | 余额查询 |
| `listBalances()` | 余额列表 |
| `freezeBalance()` | 冻结余额 |
| `unfreezeBalance()` | 解冻余额 |
| `sweepToColdWallet()` | 归集到冷钱包 |

### CryptoAssetsRateService — 汇率服务

| 方法 | 说明 |
|------|------|
| `getRate()` | 获取实时汇率 |
| `listRates()` | 汇率列表 |
| `calculateConversion()` | 计算兑换金额 |

### CryptoAssetsRefundService — 退款服务

| 方法 | 说明 |
|------|------|
| `refund()` | 发起退款 |
| `getRefundDetail()` | 退款详情 |
| `listRefunds()` | 退款列表 |

## 支付出金 (Payout)

### PayoutFactory — 出金工厂

```
PayoutFactory (策略模式)
  ├── GeoPayoutServiceImpl → Geo 渠道出金
  ├── RdWalletPayoutServiceImpl → RdWallet 出金
  └── ThunesPayoutServiceImpl → Thunes 出金
```

**核心流程：**
```
出金请求
    ↓
PayoutService 处理
    ↓
PayoutFactory 选择渠道
    ↓
渠道适配 → 三方出金
    ↓
状态跟踪
    ↓
MQ 通知 → 更新状态
```

### PayoutService

| 方法 | 说明 |
|------|------|
| `createPayout()` | 创建出金 |
| `getPayoutDetail()` | 出金详情 |
| `listPayouts()` | 出金列表 |
| `batchPayout()` | 批量出金 |
| `retryPayout()` | 重试出金 |
| `cancelPayout()` | 取消出金 |

## 钱包与地址管理

### 钱包结构

```
账户 (Account)
  └── 子账户资金池 (SubAccountPool)
        ├── 热钱包 (Hot Wallet)
        ├── 冷钱包 (Cold Wallet)
        └── 商户钱包 (Merchant Wallet)
              ├── BTC 钱包
              ├── ETH 钱包
              ├── USDT(ERC20) 钱包
              └── ...
```

### 地址生成

```
CryptoWalletAddressFactory
  ├── CoboAddressProvider → Cobo 地址
  ├── CregisAddressProvider → Cregis 地址
  ├── SafeheronAddressProvider → Safeheron 地址
  └── OKXAddressProvider → OKX 地址
```

### 共享额度

- `AddressScanQuotaService` — 地址扫描配额管理
- 每个商户有独立的扫描配额
- 配额不足时自动告警

## 汇率与报价

### 汇率服务

| 服务 | 说明 |
|------|------|
| `CryptoRateService` | 汇率查询与计算 |
| `CryptoQuoteService` | 报价生成与管理 |
| `CryptoRateHistoryService` | 历史汇率 |
| `CryptoRateAlertService` | 汇率告警 |
| `CryptoRateConversionService` | 汇率兑换计算 |

### 汇率来源

- OKX 行情
- Gate 行情
- HashKey 行情
- Circle 汇率
- 自定义汇率

## 报表导出

### ReportFactory — 报表工厂

```
ReportFactory (模板方法模式)
  └── AbstractReportHandler
        ├── CryptoAssetsReportHandler → 加密资产报表
        ├── PayoutReportHandler → 出金报表
        ├── TransactionReportHandler → 交易报表
        ├── BalanceReportHandler → 余额报表
        ├── FeeReportHandler → 手续费报表
        ├── WalletReportHandler → 钱包报表
        └── ComplianceReportHandler → 合规报表
```

## Circle 集成

### Circle 相关实体

| 实体 | 说明 |
|------|------|
| `CircleTransfer` | Circle 转账 |
| `CircleWallet` | Circle 钱包 |
| `CirclePayout` | Circle 出金 |
| `CircleTransaction` | Circle 交易 |
| `CircleBalance` | Circle 余额 |

### Circle 服务

| 服务 | 说明 |
|------|------|
| `CircleTransferService` | Circle 转账服务 |
| `CircleWalletService` | Circle 钱包服务 |
| `CirclePayoutService` | Circle 出金服务 |
| `CircleWebhookService` | Circle Webhook |
| `CircleCallbackService` | Circle 回调处理 |

## 链适配器

系统通过链适配器支持多链资产：

| 链 | 说明 |
|----|------|
| Bitcoin | BTC 主链 |
| Ethereum | ETH + ERC20 代币 |
| TRON | TRX + TRC20 代币 |
| Polygon | MATIC + 代币 |
| Solana | SOL + SPL 代币 |
| BSC | BNB + BEP20 代币 |
| Arbitrum | ARB 代币 |
| Optimism | OP 代币 |

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `common_all/assets/domain/entity/CryptoAssetsTransfer.java` | 资产转账实体 |
| `common_all/assets/domain/entity/CryptoAssetsWallet.java` | 钱包实体 |
| `common_all/assets/domain/entity/CryptoAssetsAddress.java` | 地址实体 |
| `common_all/assets/service/CryptoAssetsTransferService.java` | 转账服务 |
| `common_all/assets/service/CryptoAssetsTransactionService.java` | 交易查询 |
| `common_all/assets/service/CryptoAssetsWalletService.java` | 钱包管理 |
| `common_all/assets/service/CryptoAssetsRateService.java` | 汇率服务 |
| `common_all/assets/service/CryptoAssetsRefundService.java` | 退款服务 |
| `common_all/assets/service/payout/PayoutFactory.java` | 出金工厂 |
| `common_all/assets/service/payout/PayoutService.java` | 出金服务 |
| `common_all/assets/service/payout/impl/GeoPayoutServiceImpl.java` | Geo 出金 |
| `common_all/assets/service/payout/impl/RdWalletPayoutServiceImpl.java` | RdWallet 出金 |
| `common_all/assets/service/payout/impl/ThunesPayoutServiceImpl.java` | Thunes 出金 |
| `common_all/assets/service/report/ReportFactory.java` | 报表工厂 |
| `common_all/assets/service/report/handler/` | 报表处理器 |
| `common_all/assets/service/circle/CircleTransferService.java` | Circle 转账 |
| `common_all/assets/service/circle/CircleWalletService.java` | Circle 钱包 |
| `common_all/assets/service/circle/CirclePayoutService.java` | Circle 出金 |
| `common_all/assets/service/circle/CircleWebhookService.java` | Circle Webhook |
| `common_all/assets/service/rate/` | 汇率服务 |
| `common_all/assets/service/quote/` | 报价服务 |
| `common_all/assets/service/address/CryptoWalletAddressFactory.java` | 地址生成工厂 |
| `common_all/assets/service/address/SubAccountPool.java` | 子账户资金池 |
| `common_all/assets/service/address/AddressScanQuotaService.java` | 地址扫描配额 |
| `common_all/assets/service/status/` | 状态管理服务 |
| `common_all/assets/service/refactor/` | 重构相关服务 |
| `common_all/assets/domain/entity/circle/` | Circle 实体 |
| `common_all/assets/domain/entity/payout/` | 出金实体 |
| `common_all/assets/domain/entity/rate/` | 汇率实体 |
| `common_all/assets/enums/` | 资产枚举 |
| `common_all/assets/domain/dto/` | 资产 DTO |
