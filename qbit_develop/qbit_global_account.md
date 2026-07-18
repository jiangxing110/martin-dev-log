# 全球账户体系

## 概述

全球账户体系是 Qbit 的跨境支付核心基础设施，提供多币种银行账户管理、跨境转账、结汇/换汇、资金归集等能力。系统对接多个境外银行/支付渠道（CurrencyCloud、EasyEuro、Column 等），为商户提供一站式全球收款和付款服务。

## 整体架构

```
┌───────────────────────────────────────────────────────────────┐
│                       管理端 (Admin)                           │
│  AdminGlobalAccountController → 全球账户管理                    │
│  AdminGlobalAccountCustomerController → 客户管理               │
│  AdminGlobalSubAccountController → 子账户管理                   │
│  AdminGlobalAccountCddKybController → KYB 审核                 │
│  AdminGlobalAccountEddController → EDD 管理                    │
│  AdminGlobalAccountEpInfoController → EP 信息                  │
│  AdminGlobalAccountRefundController → 退款管理                  │
│  AdminGlobalAccountTagController → 标签管理                     │
│  AdminPaymentController → 付款管理                              │
│  AdminCnySettleController → 人民币结算                          │
├───────────────────────────────────────────────────────────────┤
│                       商户端 (Merchant)                         │
│  GlobalAccountMerchantController → 全球账户                     │
│  GlobalAccountDepositController → 入金                          │
│  GlobalAccountPaymentController → 付款                          │
│  GlobalAccountRefundController → 退款                           │
│  GlobalReceiverController → 收款人管理                           │
│  GlobalSettlementExchangeMerchantController → 结汇换汇          │
├───────────────────────────────────────────────────────────────┤
│                      核心服务层                                 │
│  GlobalAccountService → 账户管理/开户/CDD/KYB                   │
│  GlobalAccountTransactionService → 入金/出金/转账               │
│  GlobalAccountTransferService → 查询统计                        │
│  GlobalAccountPaymentService → 付款处理                         │
│  GlobalAccountRefundService → 退款                              │
│  GlobalAccountCreateService → 账户开通                          │
│  GlobalConversionService → 结汇/换汇                            │
│  GlobalSubAccountService → 子账户管理                           │
│  GlobalPayerService → 付款人管理                                │
│  GlobalReceiverService → 收款人管理                             │
│  BankAccountService → 银行账户管理                               │
│  BankService → 银行服务                                         │
│  TransferBusinessCodeService → 业务码管理                       │
│  TradeTransferLimitService → 交易限额                           │
├───────────────────────────────────────────────────────────────┤
│                      渠道适配层                                 │
│  GlobalAccountProviderFactory → 渠道工厂                         │
│  ├─ CurrencyCloud                                              │
│  ├─ EasyEuro / EP                                              │
│  ├─ SolidFI                                                    │
│  ├─ Column                                                     │
│  ├─ Pyvio                                                      │
│  ├─ HF (汇付国际)                                              │
│  ├─ Thunes                                                     │
│  ├─ RD / RF                                                    │
│  ├─ QB (闪付钱包)                                              │
│  ├─ ZB / TZ / IL                                               │
│  └─ L2 (已下线)                                                │
└───────────────────────────────────────────────────────────────┘
```

## 核心实体

### GlobalAccountCustomer (`globalAccountCustomer`)

全球账户客户主体：

| 字段 | 说明 |
|------|------|
| accountId | 关联账户ID |
| adminUserId | 管理人用户ID |
| status | 客户状态 (GlobalAccountCustomerStatusEnum) |
| provider | 渠道 (CurrencyCloud/EasyEuro 等) |
| complianceStatus | 合规状态 (KycStatusEnum) |
| accountName | 账户名称 |
| escrowAccountType | 托管账户类型 |
| parentAccountId | 父账户ID |
| customerType | 客户类型 |

### GlobalSubAccount (`globalSubAccount`)

全球账户子账户：

| 字段 | 说明 |
|------|------|
| accountId | 主体账户ID |
| subAccountId | 子账户ID |
| balanceId | 钱包ID |
| currency | 币种 |
| provider | 渠道 |
| status | 状态 |
| isEnabled | 是否启用 |
| holderId | 持有人ID |
| originAccountId | 原始账户ID |

### BankAccount (`bankAccount`)

银行账户信息：

| 字段 | 说明 |
|------|------|
| accountId | 账户ID |
| balanceId | 余额ID |
| accountName | 账户名称 |
| accountNo | 账户号码 |
| bankName | 银行名称 |
| swift | SWIFT 代码 |
| routingNumber | 路由号 |
| branchName | 分行名称 |

### Transfer (`transfer`)

转账交易记录：

| 字段 | 说明 |
|------|------|
| accountId | 账户ID |
| currency | 币种 |
| originAmount | 原始金额 |
| counterparty | 对手方 |
| businessType | 业务类型 (Inbound/Outbound/Fee) |
| provider | 渠道 |

### 其他实体

| 实体 | 说明 |
|------|------|
| `GlobalConversion` | 结汇/换汇记录 |
| `GlobalPayer` | 付款人信息 |
| `GlobalReceiver` | 收款人信息 |
| `CcContact` | 联系人信息 |
| `CcAccountContactRelation` | 账户联系人关系 |
| `CNYSettleQuota` | 人民币结算额度 |
| `CNYSettleTransaction` | 人民币结算交易 |
| `GlobalAccountEddRecord` | EDD 记录 |
| `GlobalAccountLegalPersonIdSupplement` | 法人身份补充 |
| `TransferCase` | 转账案例/工单 |
| `GlobalAccountTag` | 账户标签 |

## 核心业务流程

### 账户开通流程

```
商户提交申请
    ↓
GlobalAccountCreateService 创建
    ↓
GlobalCddKybService → KYB 审核
    ↓
AdminGlobalAccountCddKybController 审核
    ↓
GlobalAccountService 激活
    ↓
BankAccountService 开通银行账户
    ↓
GlobalSubAccountService 创建子账户
```

### 入金 (Inbound)

```
GlobalAccountTransactionService.transferIn()
    ↓
渠道入金 (Wire / ACH / 本地转账)
    ↓
Webhook → TransferInboundWebhookService
    ↓
交易确认 → BalanceService 更新余额
```

### 出金 (Outbound)

```
GlobalAccountTransactionService.transferOut()
    ↓
TradeTransferLimitService → 交易限额检查
    ↓
GlobalAccountWebCheckService → 风控校验
    ↓
渠道出金 (CurrencyCloud / Column / Thunes 等)
    ↓
状态更新
```

### 结汇/换汇 (Conversion)

```
GlobalConversionService
    ↓
GlobalConversion → 汇率转换
    ↓
GlobalConversionTransferRelation → 关联转账
```

## 账单与结算

### 人民币结算体系

| 组件 | 说明 |
|------|------|
| `CNYSettleQuota` | 人民币结算额度 |
| `CNYSettleQuotaRecord` | 额度使用记录 |
| `CNYSettleTransaction` | 结算交易 |
| `CnySettleRecordService` | 结算记录服务 |
| `CnySettleUserInfoService` | 结算用户信息 |
| `AdminCnySettleController` | 管理端接口 |

### 收款 (Collection)

`common_all/globalaccount/collection/` 模块：
- `controller/` — 收款管理
- `handler/` — 策略处理器（context/impl/service）
- 支持多层收款处理流程

## 合规与风控

### CDD / KYB

- `GlobalCddKybService` — CDD 和 KYB 审核
- `AdminGlobalAccountCddKybController` — 管理端审核接口

### EDD

- `GlobalAccountEddRecord` / `GlobalAccountEddRecordDetail` — EDD 记录
- `AdminGlobalAccountEddService` — 管理端 EDD 服务

### 标签系统

- `GlobalAccountTag` / `GlobalAccountTagRefreshTask` — 账户标签
- `AdminGlobalAccountTagController` — 标签管理接口

## 核心枚举

| 枚举 | 说明 |
|------|------|
| `GlobalAccountProviderEnum` | 渠道提供商 (17个) |
| `GlobalAccountCustomerStatusEnum` | 客户状态 |
| `GlobalSubAccountStatusEnum` | 子账户状态 |
| `GlobalAccountTypeEnum` | 账户类型 |
| `KycStatusEnum` | KYC 状态 |
| `TransferBusinessTypeEnum` | 转账类型 (Inbound/Outbound/Fee) |
| `TransferTypeEnum` | 转账方式 |
| `TransferBusinessTypeDirection` | 业务方向 |
| `BankTypeEnum` | 银行类型 |
| `GlobalFeeTypeEnum` | 费用类型 |
| `GlobalFundResourceEnum` | 资金来源 |
| `GlobalAccountRoutingTypeEnum` | 路由类型 |
| `EscrowAccountTypeEnum` | 托管账户类型 |
| `CollectionNodeEnum` | 收款节点 |

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `common_all/globalaccount/domain/entity/GlobalAccountCustomer.java` | 全球账户客户主体 |
| `common_all/globalaccount/domain/entity/GlobalSubAccount.java` | 子账户 |
| `common_all/globalaccount/domain/entity/BankAccount.java` | 银行账户 |
| `common_all/globalaccount/domain/entity/Transfer.java` | 转账交易 |
| `common_all/globalaccount/domain/entity/GlobalConversion.java` | 结汇记录 |
| `common_all/globalaccount/domain/entity/GlobalReceiver.java` | 收款人 |
| `common_all/globalaccount/domain/entity/GlobalPayer.java` | 付款人 |
| `common_all/globalaccount/service/GlobalAccountService.java` | 账户服务 |
| `common_all/globalaccount/service/GlobalAccountTransactionService.java` | 转账交易 |
| `common_all/globalaccount/service/GlobalAccountTransferService.java` | 统计查询 |
| `common_all/globalaccount/service/GlobalAccountPaymentService.java` | 付款 |
| `common_all/globalaccount/service/GlobalAccountRefundService.java` | 退款 |
| `common_all/globalaccount/service/GlobalAccountCreateService.java` | 账户开通 |
| `common_all/globalaccount/service/GlobalConversionService.java` | 结汇换汇 |
| `common_all/globalaccount/service/GlobalCddKybService.java` | KYB 审核 |
| `common_all/globalaccount/service/BankAccountService.java` | 银行账户管理 |
| `common_all/globalaccount/service/CollectService.java` | 收款 |
| `common_all/globalaccount/service/TradeTransferLimitService.java` | 交易限额 |
| `common_all/globalaccount/service/TransferInboundWebhookService.java` | 入金 Webhook |
| `common_all/globalaccount/provider/GlobalAccountProviderFactory.java` | 渠道工厂 |
| `common_all/globalaccount/enums/` | 30+ 枚举 |
| `common_all/globalaccount/enums/risk/` | 风控枚举 |
| `common_all/globalaccount/collection/` | 收款模块 |
| `admin/globalaccount/controller/` | 管理端接口 (12个) |
| `merchant/globalaccount/controller/` | 商户端接口 (8个) |
| `merchant/globalaccount/service/GlobalSettlementExchangeMerchantService.java` | 商户结算换汇 |
| `merchant/globalaccount/service/check/GlobalAccountWebCheckService.java` | Web 风控校验 |
