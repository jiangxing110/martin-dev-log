# 商户体系

## 概述

商户体系是 Qbit 面向 B 端商户的门户全栈，覆盖商户资产、加密货币、全球账户、量子卡、收款付款、商户管理、数据分析等 25+ 业务子域。采用多租户架构，支持分销商（Distributor）、代理商（Agency）、合作伙伴（Partner）等多种商户模型。

## 整体架构

```
┌────────────────────────────────────────────────────────────────────┐
│                       商户端 Controller 层                           │
│  AssetsController → 充提币/资产查询                                  │
│  CryptoAssetV2Controller → 加密资产 V2                               │
│  GlobalAccountMerchantController → 全球账户                          │
│  GlobalAccountPaymentController → 付款                               │
│  GlobalAccountDepositController → 入金                               │
│  QuantumCardMerchantController → 量子卡                              │
│  PayoutController → 出金                                            │
│  CollectionController → 收款                                        │
│  PayeeController → 收款人管理                                        │
│  ShopIntegrationController → 店铺集成                                │
│  TenantAdminController → 租户管理                                    │
├────────────────────────────────────────────────────────────────────┤
│                      Service 业务服务层                               │
│  merchant/assets/ → 资产服务                                         │
│  merchant/cryptoasset/ → 加密资产服务                                │
│  merchant/globalaccount/ → 全球账户服务                              │
│  merchant/quantum/ → 量子卡服务                                      │
│  merchant/payout/ → 出金服务                                         │
│  merchant/payee/ → 收款人服务                                        │
│  merchant/collection/ → 收款服务                                     │
│  merchant/distributor/ → 分销商服务                                  │
│  merchant/agency/ → 代理商服务                                       │
│  merchant/partner/ → 合作伙伴服务                                    │
│  merchant/shop/ → 店铺服务                                           │
│  merchant/analysis/ → 数据分析服务                                   │
├────────────────────────────────────────────────────────────────────┤
│                      公共业务域 (common_all)                          │
│  common_all/assets → 资产核心                                         │
│  common_all/globalaccount → 全球账户核心                              │
│  common_all/quantum → 量子卡核心                                     │
│  common_all/financing → 融资                                         │
│  common_all/analysis → 分析报表                                       │
│  common_all/compliance → 合规                                         │
├────────────────────────────────────────────────────────────────────┤
│                      商户管理子域                                      │
│  Tenant / Distributor / Agency / Partner / MerchantUser              │
└────────────────────────────────────────────────────────────────────┘
```

## 业务子模块

### 1. 资产服务 (Assets)

| 模块 | 说明 |
|------|------|
| `merchant/assets/controller/AssetsController.java` | 资产查询、充提币 |
| `merchant/assets/service/CryptoAssetsTransferService.java` | 链上转账 |
| `merchant/assets/service/CryptoAssetsTransactionService.java` | 交易查询 |
| `merchant/assets/service/CryptoAssetsWalletService.java` | 钱包管理 |
| `merchant/assets/service/CryptoAssetsRateService.java` | 汇率查询 |

### 2. 加密资产 V2 (CryptoAsset V2)

| 模块 | 说明 |
|------|------|
| `merchant/cryptoasset/v2/controller/CryptoAssetTransferV2Controller.java` | 提币/转账 |
| `merchant/cryptoasset/v2/controller/CryptoAssetV2Controller.java` | 费率/统计/余额 |
| `merchant/cryptoasset/v2/controller/CryptoAssetV2WalletController.java` | 钱包管理 |
| `merchant/cryptoasset/v2/service/CryptoAssetV2TransferService.java` | 链上转账服务 |
| `merchant/cryptoasset/v2/service/CryptoAssetV2TransactionService.java` | 交易查询 |
| `merchant/cryptoasset/v2/service/CryptoAssetV2WalletService.java` | 钱包管理 |
| `merchant/cryptoasset/v2/service/CryptoAssetV2ConvertService.java` | 币种兑换 |
| `merchant/cryptoasset/v2/service/CryptoAssetV2TransferRiskService.java` | 转账风控 |

### 3. 全球账户 (Global Account)

| 模块 | 说明 |
|------|------|
| `merchant/globalaccount/controller/GlobalAccountMerchantController.java` | 全球账户概览 |
| `merchant/globalaccount/controller/GlobalAccountPaymentController.java` | 付款 |
| `merchant/globalaccount/controller/GlobalAccountDepositController.java` | 入金 |
| `merchant/globalaccount/controller/GlobalAccountRefundController.java` | 退款 |
| `merchant/globalaccount/controller/GlobalReceiverController.java` | 收款人管理 |
| `merchant/globalaccount/controller/GlobalSettlementExchangeMerchantController.java` | 结汇换汇 |
| `merchant/globalaccount/service/GlobalSettlementExchangeMerchantService.java` | 结算换汇服务 |
| `merchant/globalaccount/service/check/GlobalAccountWebCheckService.java` | Web 风控校验 |

### 4. 量子卡 (Quantum Card)

| 模块 | 说明 |
|------|------|
| `merchant/quantum/card/controller/QuantumCardMerchantController.java` | 量子卡管理 |
| `merchant/quantum/card/service/QuantumCardMerchantService.java` | 卡服务 |
| `merchant/quantum/account/controller/QuantumAccountMerchantController.java` | 量子账户 |
| `merchant/quantum/account/service/QuantumAccountMerchantService.java` | 量子账户服务 |

### 5. 出金 (Payout)

| 模块 | 说明 |
|------|------|
| `merchant/payout/controller/PayoutController.java` | 出金管理 |
| `merchant/payout/service/PayoutService.java` | 出金服务 |

### 6. 收款 (Collection)

| 模块 | 说明 |
|------|------|
| `merchant/collection/controller/CollectionController.java` | 收款管理 |
| `merchant/collection/service/CollectionService.java` | 收款服务 |

### 7. 收款人 (Payee)

| 模块 | 说明 |
|------|------|
| `merchant/payee/controller/PayeeController.java` | 收款人管理 |
| `merchant/payee/service/PayeeService.java` | 收款人服务 |

### 8. 商户管理 (Tenant)

| 模块 | 说明 |
|------|------|
| `merchant/tenant/controller/TenantAdminController.java` | 租户管理 |
| `merchant/tenant/service/TenantAdminService.java` | 租户管理服务 |
| `merchant/tenant/service/TenantCreateService.java` | 租户创建 |
| `merchant/tenant/entity/Tenant.java` | 租户实体 |

### 9. 分销商 (Distributor)

| 模块 | 说明 |
|------|------|
| `merchant/distributor/controller/DistributorController.java` | 分销商管理 |
| `merchant/distributor/service/DistributorService.java` | 分销商服务 |

### 10. 代理商 (Agency)

| 模块 | 说明 |
|------|------|
| `merchant/agency/controller/AgencyController.java` | 代理商管理 |
| `merchant/agency/service/AgencyService.java` | 代理商服务 |

### 11. 合作伙伴 (Partner)

| 模块 | 说明 |
|------|------|
| `merchant/partner/controller/PartnerController.java` | 合作伙伴管理 |
| `merchant/partner/service/PartnerService.java` | 合作伙伴服务 |

### 12. 店铺集成 (Shop Integration)

| 模块 | 说明 |
|------|------|
| `merchant/shop/controller/ShopIntegrationController.java` | 店铺集成管理 |
| `merchant/shop/service/ShopIntegrationService.java` | 店铺集成服务 |

### 13. 数据分析 (Analysis)

| 模块 | 说明 |
|------|------|
| `merchant/analysis/controller/` | 分析 Controller（24个） |
| `merchant/analysis/service/` | 分析服务 |

### 14. 消息与通知

| 模块 | 说明 |
|------|------|
| `merchant/message/controller/MessageController.java` | 消息管理 |
| `merchant/message/service/MessageService.java` | 消息服务 |

### 15. 其它子模块

| 子模块 | 说明 |
|--------|------|
| `merchant/financing/` | 融资服务 |
| `merchant/funding/` | 资金管理 |
| `merchant/compliance/` | 合规管理 |
| `merchant/report/` | 报表导出 |
| `merchant/setting/` | 商户设置 |
| `merchant/webhook/` | Webhook 配置 |
| `merchant/kyc/` | KYC 管理 |
| `merchant/contract/` | 合同管理 |
| `merchant/fee/` | 费率管理 |
| `merchant/risk/` | 风控管理 |

## 核心实体

### Tenant（租户）

| 字段 | 说明 |
|------|------|
| tenantId | 租户ID |
| tenantName | 租户名称 |
| status | 状态 |
| tenantType | 租户类型 |
| parentTenantId | 父租户ID |
| distributorId | 关联分销商 |
| agencyId | 关联代理商 |

### PayeeInfo（收款人）

| 字段 | 说明 |
|------|------|
| payeeId | 收款人ID |
| accountId | 账户ID |
| payeeName | 收款人名称 |
| payeeAccountNo | 收款人账号 |
| bankName | 银行名称 |
| swiftCode | SWIFT 代码 |
| routingNumber | 路由号 |
| status | 状态 |

### MerchantUser（商户用户）

| 字段 | 说明 |
|------|------|
| userId | 用户ID |
| tenantId | 租户ID |
| username | 用户名 |
| role | 角色 |
| status | 状态 |

## 多租户架构

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  分销商 A     │  │  分销商 B     │  │  分销商 C     │
│  Distributor │  │  Distributor │  │  Distributor │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                  │                  │
┌──────┴───────┐  ┌──────┴───────┐  ┌──────┴───────┐
│  租户 A1     │  │  租户 B1     │  │  租户 C1     │
│  租户 A2     │  │  租户 B2     │  │  租户 C2     │
└──────────────┘  └──────────────┘  └──────────────┘
       │                  │                  │
       └──────────────────┼──────────────────┘
                          │
                  ┌───────┴────────┐
                  │  Qbit Core     │
                  │  (多租户数据隔离)│
                  └────────────────┘
```

### 租户层级

- **分销商 (Distributor)** — 顶级渠道商，可管理多个租户
- **代理商 (Agency)** — 代理层级，可关联多个商户
- **合作伙伴 (Partner)** — 合作商户
- **商户 (Tenant)** — 实际使用系统的主体

### 数据隔离

- 通过 `accountId` / `tenantId` 字段实现逻辑隔离
- 查询时自动过滤当前租户数据
- 管理员可通过特定接口跨租户查询

## 公共 Controller 速查

| Controller | 路径 | 说明 |
|------------|------|------|
| `AssetsController` | `/assets` | 资产查询、充提币 |
| `CryptoAssetV2Controller` | `/crypto-v2` | 加密资产 V2 |
| `CryptoAssetTransferV2Controller` | `/crypto-v2/transfer` | 加密转账 |
| `CryptoAssetV2WalletController` | `/crypto-v2/wallet` | 加密钱包 |
| `GlobalAccountMerchantController` | `/global-account` | 全球账户 |
| `GlobalAccountPaymentController` | `/global-account/payment` | 全球账户付款 |
| `GlobalAccountDepositController` | `/global-account/deposit` | 全球账户入金 |
| `QuantumCardMerchantController` | `/quantum-card` | 量子卡 |
| `PayoutController` | `/payout` | 出金 |
| `CollectionController` | `/collection` | 收款 |
| `PayeeController` | `/payee` | 收款人 |

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `merchant/assets/controller/` | 资产 Controller |
| `merchant/assets/service/` | 资产服务 |
| `merchant/cryptoasset/v2/controller/` | 加密资产 V2 Controller |
| `merchant/cryptoasset/v2/service/` | 加密资产 V2 服务 |
| `merchant/globalaccount/controller/` | 全球账户 Controller（8个） |
| `merchant/globalaccount/service/` | 全球账户服务 |
| `merchant/quantum/card/controller/` | 量子卡 Controller |
| `merchant/quantum/card/service/` | 量子卡服务 |
| `merchant/quantum/account/controller/` | 量子账户 Controller |
| `merchant/quantum/account/service/` | 量子账户服务 |
| `merchant/payout/controller/` | 出金 Controller |
| `merchant/payout/service/` | 出金服务 |
| `merchant/collection/controller/` | 收款 Controller |
| `merchant/collection/service/` | 收款服务 |
| `merchant/payee/` | 收款人模块 |
| `merchant/tenant/` | 租户管理 |
| `merchant/distributor/` | 分销商管理 |
| `merchant/agency/` | 代理商管理 |
| `merchant/partner/` | 合作伙伴管理 |
| `merchant/shop/` | 店铺集成 |
| `merchant/analysis/controller/` | 分析 Controller（24个） |
| `merchant/analysis/service/` | 分析服务 |
| `merchant/message/` | 消息通知 |
| `merchant/financing/` | 融资 |
| `merchant/funding/` | 资金 |
| `merchant/compliance/` | 合规 |
| `merchant/report/` | 报表 |
| `merchant/setting/` | 设置 |
| `merchant/webhook/` | Webhook |
| `merchant/kyc/` | KYC |
| `merchant/fee/` | 费率 |
| `merchant/risk/` | 风控 |
