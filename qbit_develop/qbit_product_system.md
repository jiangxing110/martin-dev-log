# Qbit 产品体系

> 涵盖 qbit-assets、white-label-server、gateway 三套项目的产品/业务体系。

## 目录

1. [系统版本与品牌](#1-系统版本与品牌)
2. [平台类型 (端)](#2-平台类型-端)
3. [账户类型体系](#3-账户类型体系)
4. [核心产品线](#4-核心产品线)
5. [量子卡产品体系](#5-量子卡产品体系)
6. [全球账户产品体系](#6-全球账户产品体系)
7. [加密资产产品体系](#7-加密资产产品体系)
8. [收单产品体系](#8-收单产品体系)
9. [出金/付款产品体系](#9-出金付款产品体系)
10. [粒子理财](#10-粒子理财)
11. [OpenAPI / BaaS 产品](#11-openapi--baas-产品)
12. [白标产品体系](#12-白标产品体系)
13. [分销商体系](#13-分销商体系)
14. [商户端产品模块](#14-商户端产品模块)
15. [产品能力控制](#15-产品能力控制)
16. [租户与多版本](#16-租户与多版本)

---

## 1. 系统版本与品牌

Qbit 按地域和品牌分为两个系统版本：

| 系统版本 | 品牌名 | 标识值 |
|---------|--------|--------|
| **大陆版** | Qbit | `QBIT` |
| **国际版** | iPeakoin / Interlace | `QbitInternational` |

**关键枚举**:
- `AccountSystemTypeEnum` (qbit-assets core): `QBIT("Qbit")` / `QbitInternational("iPeakoin")` — 账户系统类型
- `SystemTypeTransEnum` (qbit-assets core): `QBIT` / `QbitInternational` — 翻译枚举
- `TenantSystemVersionEnum` (common_all): `MAINLAND("mainland")` / `INTERNATIONAL("international")` — 租户系统版本

**SystemTypeResolver** — 统一解析工具：
- `isInternational(systemType)` — 判断是否为国际版
- `resolveTenantId(systemType)` — 解析租户 ID（Interlace / Qbit）
- `resolveSmsSignName(systemType)` — 解析短信签名
- 默认 `systemType` 为空时回退到 `QBIT`

**租户 (Tenant)**:
- `TenantIdEnum` — QBIT / INTERLACE 对应不同租户 ID
- `TenantDomainTypeEnum` — 租户域名类型
- `TenantPermissionEnum` — 租户权限配置
- `TenantAccountType` — 企业版/个人版

---

## 2. 平台类型 (端)

**文件**: `PlatformTypeEnum` (common_all) / `GateWayPlatformTypeEnum` (gateway)

17 个平台端，定义用户从哪个端登录以及对应的权限体系：

| 值 | 枚举 | 说明 |
|----|------|------|
| 0 | `ADMIN` | Qbit 管理后台 |
| 1 | `MERCHANT` | Qbit 商户端 |
| 2 | `IPEAKOIN` | iPeakoin 海外版商户端 |
| 3 | `CHANNEL_ADMIN` | 渠道方管理后台 |
| 4 | `WHITE_LABEL_ADMIN` | 白标系统管理后台 |
| 5 | `WHITE_LABEL_MERCHANT` | 白标系统商户端 |
| 6 | `REBATE_ADMIN` | 渠道返佣管理后台 |
| 7 | `INTERLACE_ADMIN` | Interlace 海外版管理后台 |
| 8 | `CHANNEL_ADMIN_INTERLACE` | 渠道方海外版后台 |
| 9 | `WHITE_LABEL_CHANNEL_ADMIN` | 白标渠道方后台 |
| 10 | `ACQUIRING_ADMIN` | 收单管理后台 |
| 11 | `ACQUIRING_AGENT_ADMIN` | 收单代理商后台 |
| 12 | `ACQUIRING_ISP_ADMIN` | 收单机构后台 |
| 13 | `ACQUIRING_AGENT_ADMIN_INTERLACE` | 收单代理商后台海外版 |
| 14 | `ACQUIRING_ISP_ADMIN_INTERLACE` | 收单机构后台海外版 |
| 15 | `OPEN_API` | OpenAPI 开放接口 |
| 16 | `DISTRIBUTOR_WEB` | 分销商 Web 端 |

---

## 3. 账户类型体系

**文件**: `AccountTypeEnum.java` (qbit-assets core)

| 账户类型 | 说明 | 典型用途 |
|---------|------|---------|
| `Qbit` | Qbit 内部账户 | 系统内部 |
| `Merchant` | 商户 | 主要客户类型 |
| `Channel` | 合伙人 | 渠道合作伙伴 |
| `SubAccount` | 子账号 | 商户下属子账户 |
| `MasterAccount` | 母账号 | 集团主账户 |
| `TestAccount` | 测试账户 | 测试环境 |
| `NewOpenAccount` | 新开公司账户 | 使用"新开公司"业务 |
| `ApiClient` | API 账户 | OpenAPI 客户 |
| `ApiClientCustomer` | API 客户 | API 客户的最终客户 |
| `ApiClientHolder` | API 持有人 | API 持有人（parent = ApiClientCustomer） |
| `ApiWithdraw` | 提现账户 | 提现专用 |
| `Agent` | 服务商 | 可登录 admin 后台的服务商 |
| `NewChannel` | 渠道方 | 可登录 admin 后台的渠道方 |
| `IndividualChannel` | 个人版渠道商 | 获客个人版客户 |
| `CNYSettle` | CNY 结算账户 | 人民币结算 |
| `AssetBuyer` | 资产买家 | 加密资产买家 |
| `WhiteLabelAdmin` | 白标管理员 | 登录白标管理端 |
| `Employee` | 员工账户 | 企业员工 |
| `AcquiringMerchantForAgent` | 代理商下商户 | 代理商子商户 |
| `AcquiringMerchantForDirectPartner` | 直清机构下商户 | 直清子商户 |
| `AcquiringMerchantForIndirectPartner` | 间清机构下商户 | 间清子商户 |
| `AcquiringDirectPartner` | 直清机构 | 直接清算机构 |
| `AcquiringIndirectPartner` | 间清机构 | 间接清算机构 |
| `Distributor` | 分销商 | 分销渠道 |
| `DistributorMasterMerchant` | 分销商下代理商 | 分销体系的代理商 |
| `DistributorSubMerchant` | 分销商子商户 | 分销体系的子商户 |

**静态分组**: `API_TYPES` = `List.of(ApiClient, ApiClientCustomer)`

---

## 4. 核心产品线

从代码模块和业务实体维度，Qbit 的核心产品线包括：

| 产品线 | 代码模块 | 核心实体 | 核心枚举 |
|-------|---------|---------|---------|
| **量子卡** | `common_all/quantum/` | `QuantumCard`, `Cardholder`, `CardBin` | `QuantumCardTypeEnum`, `BusinessModelEnum` |
| **全球账户** | `common_all/globalaccount/` | `GlobalAccountCustomer`, `GlobalSubAccount` | `GlobalAccountTypeEnum`, `TransferTypeEnum` |
| **加密资产** | `common_all/assets/` | `CryptoAssetWallet`, `CryptoAssetTransaction` | `ChainPlatform`, `CryptoAssetRiskLevelEnum` |
| **收单** | `common_all/pay/` | `Acquiring` | `AcquiringTransactionTypeEnum` |
| **出金/付款** | `common_all/payout/` | `PaymentTransaction`, `PaymentPayee` | `PaymentTypeEnum`, `PaymentBusinessTypeEnum` |
| **粒子理财** | `common_all/financing/` | `FundProduct`, `FundOrder`, `FundHolding` | `FundPlatformEnum`, `FundOrderTypeEnum` |
| **店铺** | `common_all/shop/` | `ShopOrder` | `ShopStatusEnum` |
| **分销商** | `merchant/distributor/` | Distributor 实体 | 自有枚举 |
| **OpenAPI** | `openapi/` | `OpenApiClient` | `ApiAccessTypeEnum` |

---

## 5. 量子卡产品体系

### 5.1 卡类型

**文件**: `QuantumCardTypeEnum`

| 类型 | 值 | 说明 |
|------|-----|------|
| `BUDGET` | `BudgetCard` | 额度卡（组钱包） |
| `RECHARGE` | `RechargeCard` | 储值卡 |

### 5.2 钱包类型

**文件**: `APICardWalletTypeEnum`

| 类型 | 值 | 说明 |
|------|-----|------|
| `QBIT_CARD_WALLET` | 0 | 量子账户钱包（主钱包） |
| `GROUP_WALLET` | 1 | 组钱包（额度卡用） |
| `RECHARGE_CARD_WALLET_TYPES` | 2 | 储值卡钱包 |

### 5.3 商业模式

**文件**: `BusinessModelEnum`

| 模式 | 说明 |
|------|------|
| `B2B_MOR` | B2B 商户发卡（主账户模式） |
| `B2B_GATEWAY` | B2B 网关模式 |
| `B2C_GATEWAY` | B2C 网关模式 |
| `B2C_MOR` | B2C 商户发卡 |
| `B2C_MOR_SHARETOKEN` | B2C 商户发卡（共享 Token） |

`getCommonValue()` 将 `B2C_MOR_SHARETOKEN` 归一化为 `B2C_MOR`。

### 5.4 卡供应商

从 `AccountExtend` 可看出支持的卡供应商：
- **Marqeta** — `allowCreateMarqetaCard`
- **Nium** — `allowCreateNiumCard`
- **Penny** — `allowCreatePennyCard`

### 5.5 物理卡

`common_all/quantum/physical_card/` 模块：
- `PhysicalCardProviderEnum` — 物理卡供应商
- `PhysicalCardMaterialEnum` — 材质（金属/塑料）
- `PhysicalCardDesignCategoryEnum` — 设计分类
- `PhysicalCardPatternEnum` — 图案
- `PhysicalCardInventoryProjectTypeEnum` — 库存项目类型

### 5.6 卡交易

`common_all/quantum/transaction/`:
- `TransactionScopeEnum` — 交易范围
- `BusinessCodeEnum` — 业务码
- `WalletBusinessCodeEnum` — 钱包业务码
- `CardChannelProvisionEnum` — 卡渠道准备

---

## 6. 全球账户产品体系

### 6.1 核心实体

`common_all/globalaccount/`:
- `GlobalAccountCustomer` — 全球账户客户
- `GlobalSubAccount` — 全球子账户（按币种）
- `BankAccount` — 银行账户信息

### 6.2 关键枚举

| 枚举 | 说明 | 关键值 |
|------|------|--------|
| `GlobalAccountTypeEnum` | 账户类型 | 按业务场景 |
| `GlobalAccountProviderEnum` | 供应商 | Circle, Zenus 等 |
| `TransferTypeEnum` | 转账类型 | 内部/外部转账 |
| `TransferBusinessTypeEnum` | 转账业务类型 | 区分业务场景 |
| `GlobalAccountRoutingTypeEnum` | 路由类型 | SWIFT / Local |
| `BankTypeEnum` | 银行类型 | 往来银行类型 |
| `KycStatusEnum` | KYC 状态 | 认证状态流转 |
| `GlobalAccountCustomerStatusEnum` | 客户状态 | 激活、冻结等 |
| `GlobalSubAccountStatusEnum` | 子账户状态 | 各币种账户状态 |
| `CurrencySymbolEnum` | 币种符号 | 支持币种 |

### 6.3 跨境转账

- SWIFT (OUR / SHA 模式) — 按币种区分费率
- 本地清算：CHATS(HKD)、FPS(HKD)、SEPA(EUR)、ACH(USD)、WIRE(USD)、FAST(SGD)、IBG(MYR)、PayNow(SGD)

---

## 7. 加密资产产品体系

### 7.1 关键枚举

| 枚举 | 说明 |
|------|------|
| `ChainPlatform` | 区块链平台（BTC, ETH, TRX 等多链） |
| `CryptoAssetRiskLevelEnum` | 风控等级 |
| `FundTypeEnum` | 资金类型 |
| `CryptoAssetPayoutEventTypeEnums` | 出金事件类型 |
| `PaymentChannelEnum` | 支付渠道（Circle 等） |
| `TripartiteChannelEnum` | 三方渠道 |

### 7.2 跨链与审计

- `CryptoCrossChainFee` — 跨链费用配置
- `CryptoAssetAuditFeeOnChain` — 审核上链费
- `CryptoAssetFastTransaction` — 快速交易

---

## 8. 收单产品体系

### 8.1 关键枚举

| 枚举 | 说明 | 关键值 |
|------|------|--------|
| `AcquiringTransactionTypeEnum` | 收单交易类型 | 卡支付/网关支付 |
| `PayTransactionTypeEnums` | 交易类型 | NORMAL / CHARGEBACK / RDR / ETHOCA |
| `TargetTypeEnums` | 渠道类型 | CHANNEL / MERCHANT / AGENT / PARTNER |

### 8.2 收单渠道层级

```
CHANNEL(渠道) → MERCHANT(商户)
├── AGENT(代理商) → AcquiringMerchantForAgent
├── PARTNER_DIRECT_CLEAR(直清) → AcquiringMerchantForDirectPartner
└── PARTNER_INDIRECT_CLEAR(间清) → AcquiringMerchantForIndirectPartner
```

### 8.3 管理后台细分

- `ACQUIRING_ADMIN` — 收单管理后台
- `ACQUIRING_AGENT_ADMIN` / `ACQUIRING_AGENT_ADMIN_INTERLACE` — 代理商后台
- `ACQUIRING_ISP_ADMIN` / `ACQUIRING_ISP_ADMIN_INTERLACE` — 机构后台

---

## 9. 出金/付款产品体系

### 9.1 核心模块

`common_all/payout/` 子模块：
- `dispatch` — 出金调度
- `callback` — 回调通知
- `webhook` — Webhook
- `handle` — 出金处理

### 9.2 关键枚举

| 枚举 | 说明 |
|------|------|
| `PaymentTypeEnum` | 付款类型 |
| `PaymentBusinessTypeEnum` | 付款业务类型 |
| `PaymentTransactionStatusEnum` | 交易状态机 |
| `PaymentModelEnum` | 付款模式 |
| `PayoutOutMoneyModeEnum` | 出金模式 |
| `SubPaymentModeEnum` | 子支付模式 |
| `RdOutwardProductCodeEnum` | 富港银行产品码 |

---

## 10. 粒子理财

| 实体 | 说明 |
|------|------|
| `FundProduct` | 基金产品 |
| `FundProductSnapshot` | 产品快照 |
| `FundOrder` | 基金订单 |
| `FundHolding` | 持仓 |
| `FundProfit` | 收益 |
| `FundQuotationCurve` | 净值曲线 |

**关键枚举**:

| 枚举 | 说明 |
|------|------|
| `FundPlatformEnum` | 基金平台（Habit、内部） |
| `FundOrderTypeEnum` | 订单类型（申购、赎回） |
| `FundOrderStatusEnum` | 订单状态 |
| `MainBusinessEnum` | 主营业务类型 |
| `AccountBusinessStatusPlatformEnum` | HABIT / INTERNAL |

---

## 11. OpenAPI / BaaS 产品

### 11.1 API 模块

`openapi/` 目录：

| 子模块 | 说明 |
|--------|------|
| `v3/card` | 卡管理 API |
| `v3/account` | 账户 API |
| `v3/global` | 全球账户 API |
| `v3/payment` | 付款 API |
| `v3/cryptoconnect` | 加密资产 API |
| `v3/transfer` | 转账 API |
| `v3/webhook` | Webhook 通知 |
| `v3/file` | 文件 API |
| `v3/progress` | 进度查询 |

### 11.2 API 客户类型

- `ApiClient` — API 主账户
- `ApiClientCustomer` — API 客户（最终客户）
- `ApiClientHolder` — API 持有人

### 11.3 API 客户枚举

| 枚举 | 说明 |
|------|------|
| `ApiAccessTypeEnum` | API 接入类型 |
| `ApiBusinessModeEnum` | API 业务模式 |
| `ApiCardBinTypeEnum` | API 卡 BIN 类型 |
| `ApiClientComplianceTypeEnum` | API 客户合规类型 |
| `ApiSourceEnum` | API 来源 |
| `ApiReviewStatusEnum` | API 审核状态 |
| `OnboardSourceEnum` | 入驻来源 |

---

## 12. 白标产品体系

### 12.1 项目模块

| 模块 | 说明 |
|------|------|
| `app-api-user` | 用户管理 API |
| `app-api-vcc` | 虚拟卡 API |
| `app-api-system` | 系统管理 API |
| `app-api-rbac` | RBAC 权限 API |
| `app-api-cdd` | CDD/KYC API |
| `app-api-cryptoconnect` | 加密连接 API |
| `app-api-file` | 文件服务 API |
| `app-api-notification` | 通知 API |
| `app-biz-*` | 业务实现模块 |
| `app-core` | 核心业务逻辑 |
| `middleware/spring-boot-starter-jwt-auth` | JWT 认证 Starter |

### 12.2 白标平台端

- `WHITE_LABEL_ADMIN(4)` — 白标运营商管理后台
- `WHITE_LABEL_MERCHANT(5)` — 白标商户端
- `WHITE_LABEL_CHANNEL_ADMIN(9)` — 白标渠道方后台

### 12.3 白标技术特点

- 独立 RBAC 体系（`t_rbac_*` 表）
- Spring Security + JWT 认证
- 角色类型：SYSTEM / BUSINESS / CUSTOM
- 资源类型：MENU / BUTTON / API 的 GRANT/DENY 模式

---

## 13. 分销商体系

`merchant/distributor/` — 独立模块：

### 13.1 分销商账户类型

- `Distributor` — 分销商（顶层）
- `DistributorMasterMerchant` — 分销商下代理商
- `DistributorSubMerchant` — 分销商子商户

### 13.2 平台端

`DISTRIBUTOR_WEB(16)` — 分销商专用 Web 端。

---

## 14. 商户端产品模块

商户端 (`merchant/`) 按业务域划分的产品模块：

| 模块 | 说明 |
|------|------|
| `account/` | 账户管理 |
| `api/client/` | API 客户管理 |
| `assets/` | 资产管理总览 |
| `balance/` | 余额管理 |
| `card/` | 卡管理 |
| `cryptoasset/` | 加密资产管理 |
| `distributor/` | 分销商管理 |
| `financing/` | 粒子理财 |
| `funding/` | 资金划转 |
| `globalaccount/` | 全球账户 |
| `payout/` | 出金付款 |
| `partner/` | 合作方管理 |
| `quantum/account/` | 量子账户 |
| `quantum/card/` | 量子卡 |
| `shop/` | 店铺管理 |
| `tenant/` | 租户管理 |
| `workflow/` | 工作流 |
| `ipk/` | iPeakoin 海外版 |

---

## 15. 产品能力控制

### 15.1 AccountExtend 字段

**文件**: `AccountExtend.java`

账户级别的产品能力开关：

| 字段 | 说明 |
|------|------|
| `kycStatus` | KYC 认证状态 |
| `kybStatus` | KYB 认证状态 |
| `allowCreatePennyCard` | Penny 卡开卡权限 |
| `allowCreateMarqetaCard` | Marqeta 卡开卡权限 |
| `allowCreateNiumCard` | Nium 卡开卡权限 |
| `qbitCardCountLimit` | 量子卡数量上限 |
| `physicalCardCountLimit` | 物理卡数量上限 |
| `globalAccountAvailable` | 全球账户可用 |
| `cnySettleAvailable` | CNY 结算可用 |
| `qbitAccountStatus` | 量子账户功能状态 |
| `globalAccountStatus` | 全球账户功能状态 |
| `cryptoFinanceStatus` | 加密理财功能状态 |
| `supplier` | 是否供应商 |
| `crossSystem` | 是否跨系统 |
| `employeeMaster` | 是否员工主账户 |
| `dormant` | 是否休眠客户 |
| `accessType` | API 接入类型 |
| `systemType` | 系统版本 (QBIT / QbitInternational) |

### 15.2 businessTypeStatus

可扩展的业务类型状态（Object 类型 JSON），控制各产品线的开通状态。

### 15.3 卡限额

```java
private Integer qbitCardCountLimit;      // 卡数量上限
private Integer physicalCardCountLimit;   // 物理卡上限
private Object openCardLimit;             // 开卡限额
private Object maxRelationShopCount;      // 最大店铺数
```

---

## 16. 租户与多版本

### 16.1 租户系统版本

| 枚举 | 值 | 说明 |
|------|-----|------|
| `TenantSystemVersionEnum.INTERNATIONAL` | `international` | 国际版 |
| `TenantSystemVersionEnum.MAINLAND` | `mainland` | 大陆版 |

### 16.2 租户账户类型

| 枚举 | 值 | 说明 |
|------|-----|------|
| `TenantAccountTypeEnum.BUSINESS` | `business` | 企业版 |
| `TenantAccountTypeEnum.PERSONAL` | `personal` | 个人版 |

### 16.3 租户解析链路

```
请求 → 域名/请求头 → SystemTypeResolver
→ 确定 systemType (QBIT / QbitInternational)
→ resolveTenantId → 确定租户 ID
→ 加载租户配置（权限、域名、版本、功能开关）
```

---

## 附录：关键枚举汇总

| 枚举文件 | 作用 |
|---------|------|
| `AccountSystemTypeEnum` | 系统版本 |
| `PlatformTypeEnum` | 平台/端类型 (17 种) |
| `AccountTypeEnum` | 账户类型 (25 种) |
| `TenantSystemVersionEnum` | 租户版本 |
| `TenantAccountTypeEnum` | 租户账户类型 |
| `QuantumCardTypeEnum` | 量子卡类型 |
| `BusinessModelEnum` | 量子卡商业模式 |
| `APICardWalletTypeEnum` | 钱包类型 |
| `GlobalAccountTypeEnum` | 全球账户类型 |
| `TransferTypeEnum` | 转账类型 |
| `BizTypeEnum` | 业务类型（虚拟卡、全球账户、加密资产、理财等）|
| `AccountBusinessStatusPlatformEnum` | 业务状态平台 |
| `ApiAccessTypeEnum` | API 接入类型 |
| `PaymentTypeEnum` | 付款类型 |
| `AcquiringTransactionTypeEnum` | 收单交易类型 |
| `FundPlatformEnum` | 基金平台 |
