# Qbit 账户体系文档

> 整理时间: 2026-06-12
> 涉及项目: pay-core, qbit-assets, scan2pay-server, white-label-server, qbitpay_service

---

## 1. 整体架构概览

Qbit 账户体系采用 **Account (主体) + User (用户)** 的多层模型：

- **Account (主体)**: 代表一个公司/个人实体，是账户体系的核心
- **User (用户)**: 隶属于 Account 下的登录用户，一人一账号
- **Balance (钱包)**: 关联 Account，管理各币种余额
- **多系统共享**: 上游 qbit-assets 管理 Account 注册与认证，下游各个业务系统（pay-core, scan2pay-server, white-label-server）消费 Account 数据

```
qbit-assets (Account 主数据)
  ├── account 表 (主体信息)
  ├── account_extend 表 (扩展信息)
  ├── user 表 (登录用户)
  └── account_user 表 (主体-用户关联)

pay-core (收单/支付核心)
  ├── AcquiringWalletAccount (收款钱包)
  ├── Balance (余额)
  ├── BalanceTransaction (余额变动)
  └── Transaction (交易)

scan2pay-server (扫付/OpenAPI)
  └── 通过内部 API 调用 qbit-assets 获取 Account 信息

white-label-server (白标)
  ├── account (主体，同 account 表)
  ├── user (登录用户)
  └── account_user (关联)

qbitpay_service (量子卡/后台服务)
  └── 多个实体表关联 account 体系
```

---

## 2. 核心数据模型

### 2.1 Account (主体)

**数据库表**: `account`

Account 是 Qbit 账户体系的最顶层实体，代表一个法律实体（公司或个人）。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (Snowflake) | 唯一ID |
| parentAccountId | String | 父账户ID，用于账户层级 |
| verifiedName | String | 认证名称（实名） |
| verifiedNameEn | String | 认证英文名称 |
| accountType | String | 账户类型标签 |
| type | AssetAccountTypeEnum | 账户角色类型 |
| displayId | String | 用户可见ID |
| country | String | 国家/地区 |
| referralCodeId | String | 推荐码ID |
| prevUserId | String | 前用户ID |
| metaData | String | 元数据(JSON) |
| tenantId | Long | 租户ID |
| status | ActivationStatusEnum | 状态 |

### 2.2 User (用户)

**数据库表**: `user`

代表一个具体的自然人用户，一个 Account 下可以挂多个 User。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | Long (Snowflake) | 唯一ID |
| email | String | 登录邮箱 |
| phone | String | 手机号 |
| passwordPbkdf2 | String | PBKDF2加密密码 |
| otpSecret | String | OTP密钥 |
| otpEnabled | Boolean | 是否启用OTP |
| nickname | String | 昵称 |
| lastName | String | 姓 |
| firstName | String | 名 |
| status | ActivationStatusEnum | 状态 |
| authSource | AuthSourceEnum | 来源(LOCAL/SSO) |
| type | UserTypeEnum | 用户类型 |
| tenantId | Long | 租户ID |
| lastLoginTime | LocalDateTime | 最后登录时间 |

### 2.3 Account ↔ User 关联

**数据库表**: `account_user`

```
account (1) ──── account_user ──── user (N)
```

一对多关系: 一个 Account 可以关联多个 User（主用户 + 管理员 + 员工）。

### 2.4 Account Extend (扩展信息)

**数据库表**: `account_extend`

| 字段 | 说明 |
|------|------|
| accountId | 关联 account.id |
| outerAccountId | 三方账户ID |
| outerKycId | 三方KYC ID |
| budgetId | 三方 budgetId |
| walletId | Interlace 量子账户ID |
| kycStatus | KYC状态 |
| s2pKycStatus | 扫付KYC状态 |
| s2pEnabled | 是否启用扫付功能 |
| merchantCustomerId | 商户客户ID |

---

## 3. Account 类型体系 (AssetAccountTypeEnum)

Account 的角色由 `AssetAccountTypeEnum` 定义，覆盖所有业务场景：

### 3.1 核心账户类型

| 类型 | 说明 |
|------|------|
| Qbit | Qbit 内部账户 |
| Merchant | 商户（标准商户） |
| Channel | 合伙人（渠道方） |
| MasterAccount | 母账号 |
| SubAccount | 子账号 |
| TestAccount | 测试账户 |

### 3.2 账户层级关系

```
MasterAccount (母账号)
  ├── SubAccount (子账号)
  ├── Merchant (商户)
  │   ├── Employee (员工)
  │   └── ...
  └── Channel / NewChannel (渠道方)
```

- **MasterAccount**: 聚合多个子账户的顶层主体
- **SubAccount**: 隶属于母账号的子单元
- **parentAccountId** 字段维护父子关系

### 3.3 API/开放平台类型

| 类型 | 说明 |
|------|------|
| ApiClient | API客户端账户 |
| ApiClientCustomer | API客户的客户 |
| ApiClientHolder | API持有人 (parentAccountId为ApiClientCustomer) |
| ApiWithdraw | 提现账户 |

API客户层级:
```
ApiClient (API主体)
  └── ApiClientCustomer (API客户的客户)
       └── ApiClientHolder (API持有人)
```

### 3.4 收单清算类型

| 类型 | 说明 |
|------|------|
| AcquiringMerchantForAgent | 代理商下商户 |
| AcquiringMerchantForDirectPartner | 直清机构下商户 |
| AcquiringMerchantForIndirectPartner | 间清机构下商户 |
| AcquiringDirectPartner | 直清机构 |
| AcquiringIndirectPartner | 间清机构 |

### 3.5 运营/渠道类型

| 类型 | 说明 |
|------|------|
| Agent | 服务商（能登录 admin 后台） |
| NewChannel | 渠道方（能登录 admin 后台） |
| IndividualChannel | 个人版渠道商（负责获客个人版客户） |
| WhiteLabelAdmin | 白标admin（可登录白标admin端） |
| Employee | 员工账户 |
| CNYSettle | CNY结算账户 |
| NewOpenAccount | 新开公司业务的账户 |
| AssetBuyer | 资产买家 |

### 3.6 Account Owner 类型

Account 还通过 `accountType` 字段区分实体性质：

| 类型 | 说明 |
|------|------|
| Individual | 个人账户 |
| Business | 企业账户 |

---

## 4. Account 状态体系

### 4.1 ActivationStatusEnum (通用状态)

| 状态 | 说明 |
|------|------|
| Active | 激活/正常 |
| Readonly | 只读 |
| Pending | 刚创建/处理中 |
| Inactive | 关停 |
| Frozen | 冻结 |
| Processing | 处理中 |
| Other | 其他 |
| Cleared | 清退 |
| Control | 管控(仅管理员可解控) |

### 4.2 AccountCountryStatusEnum (国家注册状态)

| 状态 | 说明 |
|------|------|
| PROCESSING | 处理中 |
| ACTIVATED | 已激活 |
| REJECTED | 拒绝 |

### 4.3 UserStatusEnum (pay-core 用户状态)

| 状态 | 说明 |
|------|------|
| INVITING | 邀请中 |
| ENABLE | 启用 |
| DISABLE | 禁用 |
| DELETED | 已删除 |

### 4.4 AccountStatusEnum (pay-core 账户状态)

| 状态 | 说明 |
|------|------|
| ENABLE | 启用 |
| DISABLE | 禁用 |

---

## 5. 用户类型 (UserTypeEnum)

| 类型 | 说明 |
|------|------|
| Master | 主用户（Account所有者） |
| Admin | 添加的管理员 |
| Employee | 添加的员工 |
| Robot | 机器人用户 |

### AuthSourceEnum (认证来源)

| 来源 | 说明 |
|------|------|
| LOCAL | 本地账号密码登录 |
| SSO | 单点登录 |

---

## 6. 钱包/余额体系 (Balance System)

### 6.1 Balance (钱包) — `balance` 表

| 字段 | 说明 |
|------|------|
| accountId | 关联 account.id |
| currency | 币种 |
| available | 可用余额 |
| pending | 处理中金额 |
| frozen | 冻结金额 |
| walletType | 钱包类型 |
| status | 状态 |
| systemUniqueId | 系统唯一ID |

### 6.2 Transaction (交易) — `transaction` 表

| 字段 | 说明 |
|------|------|
| accountId | 账户ID |
| balanceId | 钱包ID |
| operationType | ADD(加钱) / SUB(减钱) |
| type | add/sub/frozen/unfrozen |
| currency | 币种 |
| unionId | 多交易统一ID |
| cost | 金额(正负) |
| fee | 费用(永远负数) |
| effectAmount | 实际影响金额 = cost + fee |
| status | Pending/Closed/Fail |

### 6.3 BalanceTransaction (余额变动日志)

继承 Transaction，额外记录：
- transactionId: 关联交易ID
- sqlExecuteList: 执行的SQL
- available/pending/frozen: 变动后数值

### 6.4 余额操作流水

```
可用余额 (available)
  ├── addBalanceAvailable()   增加
  ├── subBalanceAvailable()   减少 (校验可用>金额)
  └── subTrxBalanceAvailable() 减少(可到负数，结算户)

处理中 (pending)
  ├── addBalancePending()     增加
  └── subBalancePending()     减少

冻结 (frozen)
  ├── addBalanceFrozen()      增加
  └── subBalanceFrozen()      减少
```

### 6.5 Wallet 类型

- **AcquiringWalletAccount** (`payment_payee_wallet_account`): 收单业务收款钱包
  - 关联 acquiring_account_id
  - chain_type: 链
  - currency: 币种
  - account_number: 钱包地址/银行账号
  - tenant_id: 租户

---

## 7. 收单系统账户 (pay-core Acquiring)

### 7.1 收单商户

- Merchant模块: `merchant/` 管理商户入驻
- AcquiringCore: 核心收单流程
  - Customer (acquiring_customer): 收单客户信息
  - Wallet Account: 收款钱包
  - 账户支付配置 (AccountPaymentConfig)

### 7.2 收单层级

```
AcquiringDirectPartner (直清机构)
  └── AcquiringMerchantForDirectPartner (直清商户)

AcquiringIndirectPartner (间清机构)
  └── AcquiringMerchantForIndirectPartner (间清商户)

Agent (代理商)
  └── AcquiringMerchantForAgent (代理商户)
```

### 7.3 Engine 模块

| 模块 | 功能 |
|------|------|
| acquiring-core | 核心收单引擎（Liteflow编排） |
| engine | 收单引擎独立服务 |
| customer | 客户管理 |
| merchant | 商户管理 |
| risk | 风控 |
| admin | 管理后台API |
| open-api | 开放API |
| partner-hub | 合作伙伴中心 |
| integration | 集成服务 |

---

## 8. 白标 & 会员端账户 (white-label-server)

### 8.1 架构

```
app-admin (运营端)
  ├── Account管理
  ├── WhiteLabelAdmin类型登录
  └── RBAC权限

app-member (会员端)
  ├── Account登录(商户端)
  └── 业务操作
```

### 8.2 账户模型

白标 `Account` 实体与 qbit-assets 的 `account` 表共用:
- `AccountGeneralTypeEnum.MERCHANT`: 商户类型
- `AccountOwnerTypeEnum.INDIVIDUAL/BUSINESS`: 个人/企业
- `ActivationStatusEnum`: 账户状态（Active/Readonly/Pending/Inactive/Frozen/Processing/Other/Cleared/Control）

### 8.3 认证体系

- **JWT Token认证** (JwtService)
  - access token + refresh token
  - 基于 JwtUser 对象
- **密码**: PBKDF2 加密存储
- **OTP**: 可选二次验证
- **两种App类型**: ADMIN(运营端), MEMBER(会员端)

### 8.4 白标账户详情

WhiteLabelAccountDetailsVO:
| 字段 | 说明 |
|------|------|
| displayId | 展示ID |
| accountId | 账户ID |
| verifiedName | 主体名称 |
| brandName | 品牌名称 |
| appDomain | C端域名 |
| adminDomain | Admin域名 |
| email | 登录邮箱 |
| logo | 品牌Logo |
| favicon | 网站图标 |
| color | 品牌色 |

---

## 9. Scan2Pay 账户集成 (scan2pay-server)

### 9.1 登录流程

Scan2Pay 不维护独立的 Account 数据，通过内部 API 调用 qbit-assets：

```
Admin登录:
  scan2pay → POST assetHost + ADMIN_LOGIN_AUTH_URL → qbit-assets
  → 返回 InnerAuthAdminVO { User, AssetAccount, AssetAccountMap }

Merchant登录:
  scan2pay → GET gateway + MERCHANT_AUTH_URL → qbit-assets
  → 返回 User { Account }
```

### 9.2 用户上下文

- **UserContext** (FastThreadLocal): 存储当前线程登录用户
- **User**: 当前登录用户信息
- **Account (AccountInfo)**: 用户所属主体
- **AssetAccount**: 完整账户信息（qbit-assets 返回）
- **AssetAccountMap**: account ID 映射

### 9.3 商户余额

- **MerchantBalanceService**: 查询商户各币种余额
- **BalanceController**: 余额查询API
- **WalletController**: 钱包管理
- **TopUpsRecordController**: 充值记录

---

## 10. Fee 费率体系 (AccountFeeType)

费率达到数百种类型，按大类分组：

### 10.1 全球账户费率

| 分类 | 示例 |
|------|------|
| 结汇汇率优惠 | SettleRate |
| 付款服务费 | PaymentServiceOffers |
| 入金手续费 | GlobalAccountInbound, GlobalAccountInbound2 |
| 大额阈值 | GlobalAccountExceedThreshold, GlobalAccountExceedThresholdRate |
| 账户互转 | GlobalAccountTransferFee |
| 基础币种汇率加点 | BaseCurrencyRateAdd |

### 10.2 量子卡费率

| 分类 | 示例 |
|------|------|
| 开卡费 | OpenCard, FreeOpenCard |
| Markup费 | QuantumCardMarkUpFeePercentage, QuantumCardMarkUpFeeFixedValue |
| 跨境费率 | QuantumCardCrossBorderFeeBaseRate |
| FX Markup | QuantumCardFxMarkupFeeRate |
| 交易撤销费 | QuantumCardTransactionReversalFee |
| ATM费 | QuantumCardATMFee |
| Apple Pay费 | QuantumCardApplePayFee |
| 非活跃费 | QuantumCardNotActiveFee |
| 结算费 | QuantumCardSettlementFeeDom/Int |
| 实体卡制卡费 | QuantumCardMakeCardFee, ShoppingFee |

### 10.3 加密资产费率

| 类型 | 说明 |
|------|------|
| CryptoTransfer | 加密资产交易手续费 |
| CryptoExchange | 加密资产交易手续费(各阶梯) |
| CryptoUSDInbound / CryptoUSDCInbound | 入金手续费 |
| CryptoStablecoinExchangeTransfer | 稳定币转账换汇费 |
| TransferOutCrossChain | 跨链手续费 |

### 10.4 国际转账费率

按币种和清算网络细分：
- SWIFT (SHA/OUR): USD, EUR, GBP, HKD, AUD, AED, ILS, CAD, SGD, JPY, CNH等
- 本地清算: CHATS(HKD/USD/CNH), FPS(GBP), SEPA(EUR), ACH(USD), FAST(SGD)等

### 10.5 API 客户费率 (Caas 月付)

RatePlan 模式，包括所有量子卡相关费率的 CaaS 版本。

---

## 11. 认证 & 安全体系

### 11.1 认证方式

| 场景 | 方式 |
|------|------|
| Admin登录 | 账号密码 + 可选OTP |
| Merchant登录 | 账号密码 |
| API访问 | JWT Token / Access Token |
| OpenAPI | Token认证 |
| SSO | 单点登录 |

### 11.2 权限模型

- **RBAC** (Role-Based Access Control)
  - RbacUserRole 表: 用户-角色关联
  - 路由级权限控制 (UserRbacAuthGatewayFilterFactory)

### 11.3 安全策略

- 密码: PBKDF2 加密存储
- OTP: 基于时间的一次性密码
- JWT: 双Token机制 (access + refresh)
- 网关过滤: IP黑名单、Token验证、RBAC

---

## 12. 系统间账户流转

```
             开户/认证                    KYC/AML
                 │                         │
         ┌───────▼─────────────────────────▼──────────┐
         │             qbit-assets                    │
         │        (Account 注册/认证/风控)              │
         │  account / user / account_extend            │
         └───────┬──────────────────┬──────────────────┘
                 │                  │
        ┌────────▼────────┐  ┌─────▼─────────────┐
        │   pay-core      │  │  white-label-server│
        │  (收单/支付核心)   │  │   (白标商户管理)     │
        │  Balance/Transaction│  │  Account+User体系 │
        └─────────────────┘  └───────────────────┘
                 │
        ┌────────▼────────┐
        │  scan2pay-server│
        │  (扫付/OpenAPI)  │
        │  (读取Account)   │
        └─────────────────┘

        ┌─────────────────┐
        │  qbitpay_service │
        │(量子卡/报表/后台)  │
        └─────────────────┘
```

### 数据流向

1. **Account 注册**: 用户在 qbit-assets 注册 → 创建 account 记录
2. **KYC 认证**: qbit-assets 完成 AML/KYC → 更新 account_extend
3. **账户同步**:
   - pay-core 通过内部 API 读取 account 信息
   - scan2pay-server 通过内部 API 验证登录
   - white-label-server 直接读写 account/user/account_user 表（共用数据库）
   - qbitpay_service 作为后台服务，管理量子卡等业务

---

## 13. 关键枚举汇总

### Account 状态枚举

| 枚举 | 值 |
|------|------|
| ActivationStatusEnum | Active, Readonly, Pending, Inactive, Frozen, Processing, Other, Cleared, Control |
| AccountStatusEnum | ENABLE(0), DISABLE(1) |
| UserStatusEnum | INVITING(0), ENABLE(1), DISABLE(2), DELETED(3) |
| AccountCountryStatusEnum | PROCESSING, ACTIVATED, REJECTED |

### Account 类型枚举

| 枚举 | 值 |
|------|------|
| AssetAccountTypeEnum | Qbit, Merchant, Channel, SubAccount, MasterAccount, TestAccount, NewOpenAccount, ApiClient, ApiClientCustomer, ApiClientHolder, ApiWithdraw, Agent, NewChannel, IndividualChannel, CNYSettle, AssetBuyer, WhiteLabelAdmin, Employee, AcquiringMerchantForAgent, AcquiringMerchantForDirectPartner, AcquiringMerchantForIndirectPartner, AcquiringDirectPartner, AcquiringIndirectPartner |
| AccountGeneralTypeEnum | MERCHANT |
| AccountOwnerTypeEnum | INDIVIDUAL, BUSINESS |

### 用户枚举

| 枚举 | 值 |
|------|------|
| UserTypeEnum | Master, Robot, Admin, Employee |
| AuthSourceEnum | LOCAL, SSO |
| PlatformTypeEnum | ADMIN(0), MERCHANT(1) |
| SystemTypeEnum | QbitInternational, QBIT |

### 余额操作枚举

| 枚举 | 值 |
|------|------|
| BalanceOperationTypeEnum | ADD(1), SUB(-1) |
| TransactionTypeEnum | add, sub, frozen, unfrozen |
| TransactionStatusEnum | Pending, Closed, Fail |
