# 加密货币体系

## 概述

Qbit 加密货币体系支持多链数字资产的托管、转账、兑换、风控和合规管理。系统对接多个交易所和托管钱包，提供统一的加密资产服务层，覆盖商户端和管理端两种视角。

## 整体架构

```
┌──────────────────────────────────────────────────────────┐
│                       商户端 (Merchant)                    │
│  CryptoAssetTransferV2Controller → 提币/转账              │
│  CryptoAssetV2Controller → 费率/统计/余额                 │
│  CryptoAssetV2WalletController → 钱包管理                 │
├──────────────────────────────────────────────────────────┤
│                       管理端 (Admin)                      │
│  AdminCryptoAssetV2Controller → 管理概览                  │
│  AdminCryptoAssetV2AccountController → 账户管理           │
│  AdminCryptoAssetV2BlockchainTransferController → 链上审核 │
│  AdminCryptoAssetV2CoinController → 币种管理              │
│  AdminCryptoAssetV2CurrencyPairController → 交易对管理    │
│  AdminCryptoAssetV2WalletController → 钱包管理            │
├──────────────────────────────────────────────────────────┤
│                    链上转账服务层                           │
│  CryptoAssetV2TransferService → 提币/预览/安全设置          │
│  CryptoAssetV2TransactionService → 交易查询               │
│  CryptoAssetV2BlockchainRefundService → 链上退款           │
│  CryptoAssetV2ConvertService → 币种兑换                   │
├──────────────────────────────────────────────────────────┤
│                    风控 & 合规层                            │
│  CryptoAssetV2TransferRiskService → 转账风控              │
│  CryptoRiskExternalKytService → KYT 链上追踪              │
│  CryptoRiskExternalKyaService → KYA 地址分析              │
│  CryptoTransferTraceService → 交易溯源                    │
├──────────────────────────────────────────────────────────┤
│                   钱包 & 地址管理层                          │
│  CryptoAssetV2WalletService → 子钱包/归集                 │
│  CryptoAssetV2ShareQuotaService → 共享额度                │
│  CryptoAddressScanQuotaService → 地址扫描配额             │
│  BlockchainAddressScannerService → 区块链地址扫描          │
├──────────────────────────────────────────────────────────┤
│                    汇率 & 交易对层                          │
│  CryptoAssetV2CurrencyPairService → 交易对                │
│  CryptoRateFactory → 汇率工厂                              │
│  ├─ CryptoRateQbitHandler → Qbit 内部汇率                 │
│  ├─ CryptoRateOkxHandler → OKX 汇率                       │
│  ├─ CryptoRateGateHandler → Gate 汇率                     │
│  ├─ CryptoRateCustomHandler → 自定义汇率                   │
│  └─ CryptoRateCurveHandler → 曲线处理                     │
├──────────────────────────────────────────────────────────┤
│                    三方托管/交易所层                         │
│  Cobo / Cregis / Safeheron / OKX / Gate / HashKey          │
└──────────────────────────────────────────────────────────┘
```

## 核心实体

### CryptoAssetsTransfer

链上转账交易实体，记录完整的转账生命周期。

| 字段 | 说明 |
|------|------|
| accountId | 账户ID |
| currency | 币种 |
| amount | 转账金额 |
| fee | 手续费(Gas) |
| fromAddress | 发送地址 |
| toAddress | 接收地址 |
| txHash | 交易哈希 |
| status | 交易状态 |
| provider | 渠道(Cobo/OKX 等) |

### 共享额度相关

- **CryptoAddressScanQuota** — 地址扫描配额
- **CryptoAddressScanQuotaLog** — 配额使用日志
- **CryptoAddressScanHistory** — 扫描历史

### 风控相关

- **CryptoRiskExternalKyt** — KYT 链上交易风控记录
- **CryptoRiskExternalKytAlert** — KYT 告警记录
- **CryptoRiskExternalKya** — KYA 地址分析记录
- **CryptoTransferTrace** — 交易溯源信息

### 币种映射

- **ThirdPartyCoinMapping** — 三方币种映射关系

## 商户端 (Merchant) 能力

### CryptoAssetV2Service — 加密资产服务

- `listFeeRates()` — 账户费率列表
- `getStatistics()` — Dashboard 统计
- `listBalances()` — 账户余额列表

### CryptoAssetV2TransferService — 链上转账

完整转账流程：

```
提币预览 (withdrawalPreview)
    ↓
安全设置 (getSecuritySetting)
    ↓
创建交易 (creation)
    ↓
风控校验 (CryptoAssetV2TransferRiskService)
    ↓
链上广播 (三方托管/交易所)
    ↓
交易确认 (MQ 监听器)
    ↓
状态更新
```

- `withdrawalPreview()` — 提币预览 (含 Gas 费、跨链费)
- `getSecuritySetting()` — 安全设置
- `creation()` — 创建链上提币交易
- `getVerified()` — 验证交易
- 继承 `IService<CryptoAssetsTransfer>`

### CryptoAssetV2TransactionService — 交易查询

- 交易列表/详情
- 状态跟踪

### CryptoAssetV2WalletService — 钱包管理

- 子钱包管理
- 资金归集 (Sweeping)

### CryptoAssetV2ShareQuotaService — 共享额度

- 地址扫描共享额度管理

### CryptoAssetV2BlockchainRefundService — 链上退款

- 区块链退款处理
- 退款通知 (MQ Listener)

### CryptoAssetV2ConvertService — 币种兑换

- 加密货币内部兑换

## 管理端 (Admin) 能力

| Controller | 说明 |
|------------|------|
| `AdminCryptoAssetV2Controller` | 资产概览管理 |
| `AdminCryptoAssetV2AccountController` | 加密账户管理 |
| `AdminCryptoAssetV2BlockchainTransferController` | 链上转账审核 |
| `AdminCryptoAssetV2CoinController` | 币种管理 (支持链、配置) |
| `AdminCryptoAssetV2CurrencyPairController` | 交易对管理 |
| `AdminCryptoAssetV2WalletController` | 钱包管理 |

## 汇率工厂模式

**CryptoRateFactory** + **CryptoRateAdapter** — 策略模式实现多源汇率获取：

| Handler | 来源 |
|---------|------|
| `CryptoRateQbitHandler` | Qbit 内部汇率 |
| `CryptoRateOkxHandler` | OKX 行情 |
| `CryptoRateGateHandler` | Gate 行情 |
| `CryptoRateCustomHandler` | 自定义汇率 |
| `CryptoRateCurveHandler` | 曲线处理 |

## 风控与合规

### CryptoAssetV2TransferRiskService — 转账风控

转账前的风控评估，包括：
- 地址风险评分
- 转账金额阈值
- 频率限制
- 白名单/黑名单

### KYT (Know Your Transaction)

- `CryptoRiskExternalKytService` — 调用三方 KYT 服务进行链上交易风控
- `CryptoRiskExternalKytAlertService` — KYT 告警处理

### KYA (Know Your Address)

- `CryptoRiskExternalKyaService` — 地址分析服务

### 交易溯源

- `CryptoTransferTraceService` — 链上交易溯源追踪

## MQ 监听器

| 监听器 | 说明 |
|--------|------|
| `CryptoAssetDepositNoticeListener` | 充值通知 |
| `CryptoAssetTransferWebhookListener` | 转账 Webhook |
| `CryptoAssetWalletWebhookListener` | 钱包 Webhook |
| `CryptoAssetBlockchainRefundBroadcastListener` | 退款广播 |
| `CryptoAssetBlockchainRefundNotificationListener` | 退款通知 |
| `CryptoAssetBlockchainRefundWebhookListener` | 退款 Webhook |
| `CryptoAssetDepositRiskNotificationListener` | 充值风控通知 |
| `CryptoAssetRemoveBlockchainTransferRiskListener` | 解除风控 |
| `CryptoAssetRiskFundUnfreezingNotificationListener` | 资金解冻通知 |

## 渠道支持

### 交易所

- **OKX** — OKX 行情、交易、提现
- **Gate** — Gate.io 交易
- **HashKey** — HashKey 合规交易所

### 托管钱包

- **Cobo** — Cobo 托管钱包
- **Cregis** — Cregis 钱包
- **Safeheron** — Safeheron 托管

### 链上安全

- **Chainalysis** — 链上 AML 监控
- **Beosin** — 智能合约安全审计
- **OKLink** — 区块链浏览器数据

## 枚举速查

### 渠道枚举

| 枚举 | 说明 |
|------|------|
| `BlockchainChannelEnum` | 区块链渠道 |
| `CoinSupportChannelEnum` | 币种支持渠道 |
| `CurrencyPairSupportChannelEnum` | 交易对支持渠道 |

### 其他枚举

| 枚举 | 说明 |
|------|------|
| `CryptoAddressScanSourceEventEnum` | 地址扫描来源事件 |
| `SpanKindEnum` | 溯源类型 |

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `merchant/cryptoasset/v2/service/CryptoAssetV2Service.java` | 加密资产服务接口 |
| `merchant/cryptoasset/v2/service/CryptoAssetV2TransferService.java` | 链上转账服务 |
| `merchant/cryptoasset/v2/service/CryptoAssetV2TransactionService.java` | 交易查询服务 |
| `merchant/cryptoasset/v2/service/CryptoAssetV2WalletService.java` | 钱包管理服务 |
| `merchant/cryptoasset/v2/service/CryptoAssetV2ShareQuotaService.java` | 共享额度服务 |
| `merchant/cryptoasset/v2/service/CryptoAssetV2BlockchainRefundService.java` | 链上退款服务 |
| `merchant/cryptoasset/v2/service/CryptoAssetV2ConvertService.java` | 币种兑换服务 |
| `merchant/cryptoasset/v2/service/CryptoAssetV2TransferRiskService.java` | 转账风控服务 |
| `merchant/cryptoasset/v2/service/CryptoRiskExternalKytService.java` | KYT 风控 |
| `merchant/cryptoasset/v2/service/CryptoRiskExternalKyaService.java` | KYA 风控 |
| `merchant/cryptoasset/v2/service/CryptoTransferTraceService.java` | 交易溯源 |
| `merchant/cryptoasset/v2/service/CryptoAssetV2CurrencyPairService.java` | 交易对管理 |
| `merchant/cryptoasset/v2/factory/CryptoRateFactory.java` | 汇率工厂 |
| `merchant/cryptoasset/v2/factory/handler/` | 汇率策略实现 |
| `merchant/cryptoasset/v2/listener/` | MQ 监听器 (9个) |
| `merchant/cryptoasset/v2/controller/` | 商户端 Controller |
| `merchant/cryptoasset/v2/enums/` | 渠道枚举 |
| `merchant/cryptoasset/v2/domain/entity/` | 实体 |
| `admin/cryptoasset/v2/controller/` | 管理端 Controller |
| `admin/cryptoasset/v2/service/` | 管理端服务 |
| `common_all/assets/service/report/crypto/` | 报表导出处理器 |
| `common_all/analysis/domain/vo/crypto/` | 分析视图对象 |
