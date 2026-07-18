# 合伙人系统 - qbit-assets 模块

> 项目路径：`/Users/martinjiang/IdeaProjects/qbit-assets`
> 技术栈：Spring Boot 3.0.2 + Java 17 + MyBatis-Plus + PostgreSQL

## 模块结构

合伙人模块按职责分为三个子域，位于 `common_all/partner/` 下：

```
common_all/partner/
├── manage/           # 合作伙伴管理（生态展示、供应商）
├── merchant/         # 合伙人返佣（提成、订单、提现）
└── commission/       # 渠道方返佣（周期结算、趋势分析）
```

### 总览（83 个 Java 源文件）

| 层 | manage | merchant | commission |
|---|--------|----------|------------|
| Entity | `Partner.java` | `PartnerOrder.java`, `PartnerBankAccount.java` | `ChannelCommission.java` |
| Mapper | `PartnerMapper.java` | `PartnerOrderMapper.java` | `ChannelCommissionMapper.java` |
| Service | `PartnerService.java` | `PartnerOrderService.java`, `PartnerAccountService.java` | `ChannelCommissionService.java` |
| DTO | 7 个 | 3 个 | 2 个 |
| VO | 3 个 | 21 个 | 5 个 |
| BO | - | - | 2 个 |
| Enum | `PartnerStatusEnum.java` | - | - |

---

## 模块一：合作伙伴管理（manage）

### 核心实体

**`Partner.java`**（表 `partners`，继承 `BaseV4`）

| 字段 | 类型 | 说明 |
|------|------|------|
| module | String | 模块分类 |
| name | String | 名称 |
| logo | String | Logo |
| description | String | 描述 |
| website | String | 官网地址 |
| language | String | 语言 |
| sort | Integer | 排序 |
| status | PartnerStatusEnum | ONLINE/OFFLINE |
| type | String | `partners`（合作伙伴）/`supplier`（供应商） |
| accountId | String | 关联账户 ID |
| inviteAccountId | String | 邀请人账户 ID |
| visibleMerchantSystem | String | 系统透出（Qbit/iPeakion） |
| visibleSpecialClients | String | 特约客户 |
| paymentKeyword | String | 收款方关键词 |
| customerSource | String | 客户来源（background/invitation） |

### 业务逻辑

- `PartnerServiceImpl`：CRUD + 名称唯一性检查 + 排序 + 语言/状态/类型过滤
- Mapper XML 包含复杂的 `partners` + `account` + `accountExtend` + `supplier_apply` 联表查询
- 供应商类型 `type = 'supplier'` 的查询与后端收款方查询集成

### API 接口

| 控制器 | 路径 | 说明 |
|--------|------|------|
| `AdminPartnerController` | `api/admin/partners` | Admin CRUD、上下线 |
| `PartnerController` | `api/v2/partners/list` | 商户端列表（按语言，无需登录） |

### VO

- `PartnerVO`：标准返回
- `EcoPartnerVO`：生态页面展示（logoName, logUrl）
- `PartnerAndAccountVO`：关联账户信息（verifiedName, displayId, systemType, 关联销售、结算信息）

---

## 模块二：合伙人返佣（merchant）

这是**最核心、最复杂**的子系统。

### 核心实体

**`PartnerOrder.java`**（表 `"partnerOrder"`，继承 `Base`）

| 字段 | 类型 | 说明 |
|------|------|------|
| accountId | String | 合伙人账户 ID |
| customerId | String | 客户账户 ID |
| sourceId | String | 源订单 ID |
| bankAccountId | String | 银行账户 ID |
| businessType | PartnerOrderTypeEnum | 业务类型（提成类型） |
| settlementAmount | BigDecimal | 结汇金额（非 CNY 需换算） |
| settlementCurrency | CryptoConversionCurrencyEnum | 结汇币种 |
| amount | BigDecimal | 实际到账金额 |
| currency | CryptoConversionCurrencyEnum | 实际到账币种 |
| fee | BigDecimal | 手续费 |
| tax | BigDecimal | 税费 |
| status | TransactionStatusEnum | 订单状态 |
| displayStatus | PartnerOrderDisplayStatusEnum | 业务展示状态 |
| partnerPromoteBusinessType | ProductEnum | 推广业务类型 |
| merchantShow | boolean | 是否对用户展示 |
| isCompute | boolean | 是否已计入统计 |
| systemType | String | 系统类型（QBIT/QbitInternational） |
| transferId | String | 转账 ID |
| rawData | Object | 原始数据（JSON） |
| comment | Object | 审核评论（JSON） |

**`PartnerBankAccount.java`**（表 `"partnerBankAccount"`，继承 `NoIdBaseV1`）

| 字段 | 说明 |
|------|------|
| accountId | 合伙人账户 ID |
| bankAccountName | 银行账户名称 |
| bankAccountNo | 银行账号/加密地址 |
| bankName | 银行名称/链名 |
| branchName | 分行名称 |
| currency | 币种 |
| status | 状态 |
| payeeId | 收款人 ID |

### 核心服务

**`PartnerOrderServiceImpl.java`**（650+ 行）

关键业务方法：

| 方法 | 说明 |
|------|------|
| `createPartnerOrder()` | 从 CryptoAssetsTransfer 创建合伙订单 |
| `addCommission()` | 补提成（用于指派合伙人后） |
| `sendMonthCommission()` | web3 月度佣金发放 |
| `orderPage()` / `withdrawOrderPage()` | 订单/提现分页查询 |
| `export()` / `withdrawExport()` | Excel 导出 |
| `overdueRebatesDeducted()` | 超期返佣抵扣 |
| `getPaymentFee()` | 查询提现手续费 |
| `updateOrderInfo()` | 更新订单信息（佣金比例） |
| `updateOrderProfitHistory()` | 更新订单利润历史 |

**`PartnerAccountServiceImpl.java`**

| 方法 | 说明 |
|------|------|
| `partnerPage()` | 合伙人分页查询 |
| `customerPage()` | 客户分页查询 |
| `partnerExport()` / `customerExport()` | Excel 导出 |
| `getPartnerStatisticsByWeapp()` | 小程序端余额统计 |

### Mapper XML

**`PartnerOrderMapper.xml`**（722 行，最复杂的 Mapper XML）

核心查询：
- `partnerPage` / `customerPage`：合伙人/客户列表（多表 left join）
- `transferPage`：交易流水
- `withdrawOrderPage`：提现订单
- `monthProfitOrderPage`：月度利润
- `selectMonthCommission`：月结佣金
- `getPartnerBalanceVo`：余额
- `getOverdueRebateOrder`：超期返扣
- `partnerList`：合伙人列表

常用 SQL 片段：`partner`、`customer`、`getAccountCharging`、`transferOrderCol`、`orderSearch`

### BO 层（12 个文件）

位于 `core/bo/`，用于处理不同系统类型（QBIT/QbitInternational）的业务数据：

| BO | 说明 |
|----|------|
| `PartnerAccountBO.java` | 合伙人账户 |
| `PartnerAccountQbitInternationalBo.java` | 海外版合伙人账户 |
| `PartnerCustomerBO.java` | 客户信息 |
| `PartnerQbitInternationalCustomerBO.java` | 海外版客户信息 |
| `PartnerOrderBO.java` | 订单 |
| `PartnerInternationOrderBO.java` | 海外版订单 |
| `PartnerWithdrawOrderBO.java` | 提现订单 |
| `PartnerWithdrawInternationOrderBO.java` | 海外版提现订单 |
| `PartnerOverdueBO.java` | 超期信息 |
| `PartnerOverdueDeductedBO.java` | 超期抵扣 |
| `PartnerOverdueDeductedInternationBO.java` | 海外版超期抵扣 |
| `PartnerOverduWithdrawOrderBO.java` | 超期提现 |

### DTO（核心）

| DTO | 说明 |
|-----|------|
| `PartnerOrderDTO.java` | 订单搜索条件（customerName, partnerName, systemType, businessTypes, displayStatus 等） |
| `AddCommissionDTO.java` | 补提成（accountId, userId, partnerAccountId） |
| `PartnerPaymentDTO.java` | 付款费用查询（transferType, countryCode, receiveCurrency, feeType） |

### VO（21 个）

| VO | 说明 |
|----|------|
| `PartnerAccountVO.java` | 合伙人账户信息 |
| `PartnerAccountDetailVO.java` | 合伙人详情（注册数、KYB 通过数、余额等） |
| `PartnerAccountUserVO.java` | 用户信息 |
| `PartnerCustomerVO.java` | 客户信息 |
| `PartnerCustomerOrderVO.java` | 客户订单 |
| `PartnerCustomerAccountDetailVO.java` | 客户账户详情 |
| `PartnerOrderVO.java` | 订单信息 |
| `PartnerOrderProfitSourceVO.java` | 利润来源 |
| `PartnerOrderSourceVO.java` | 订单来源 |
| `PartnerStatisticsVO.java` | 统计信息 |
| `PartnerWithdrawOrderVO.java` | 提现订单 |
| `PartnerOverdueRebatesVO.java` | 超期返扣 |
| `PartnerBankAccountVO.java` | 银行账户 |
| `ChannelTradeTrendVO.java` | 渠道交易趋势 |
| `StaffTradeVolumeVO.java` | 员工交易量 |

### Controller

**Merchant（商户端）：**
| 控制器 | 路径 | 功能 |
|--------|------|------|
| `PartnerAccountController` | `api/core/partner/account` | 客户列表、统计 |
| `PartnerOrderController` | `api/core/partner/order` | 补提成、付款费用、订单列表、交易列表 |

**Admin（管理端）：**
| 控制器 | 功能 |
|--------|------|
| `PartnerAccountAdminController` | 合伙人/客户分页查询及导出 |
| `PartnerOrderAdminController` | 订单分页、提现分页、超期抵扣分页及导出 |
| `PartnerOrderAdminController` | 月度佣金发放、历史订单利润更新 |

### Cross-controllers

| 控制器 | 功能 |
|--------|------|
| `ChannelAdminAccountController` | 渠道账户管理（Admin） |
| `ChannelTradeAdminController` | 渠道交易明细（全球账户、量子账户、加密资产、金融订单、Vendor 订单） |

---

## 模块三：渠道方返佣（commission）

### 核心实体

**`ChannelCommission.java`**（表 `"channelCommission"`，继承 `BaseV5`）

| 字段 | 说明 |
|------|------|
| accountId | 账户 ID |
| channelCommissionType | 佣金类型 |
| businessType | 业务类型 |
| accountSystemType | 系统类型 |
| detail | 详情 |
| timeType | Month/Quarter |
| settleAmount | 结算金额 |
| url | 相关链接 |
| attachments | 附件 |

### 服务能力

`ChannelCommissionServiceImpl`：

| 方法 | 说明 |
|------|------|
| `getChannelCommission()` | 查询渠道佣金列表 |
| `exportDetail()` | 导出明细 |
| `recordCommission()` | 记录佣金 |
| `getChannelCommissionTrends()` | 趋势图数据 |
| `getClientStaffTradeVolume()` | 客户员工交易量 |
| `getChannelTradeTrends()` | 渠道交易趋势 |
| `createChannelCommission()` | 管理员创建佣金记录 |
| `getChannelStatistic()` | 渠道统计 |
| `getChannelMonthlySettleAmount()` | 月度结算金额 |
| `getAccountInvite()` | 邀请账户查询 |

---

## 定时任务

位于 `job/partner/`：

### PartnerCommissionJob

| Job Handler | 说明 |
|------------|------|
| `partner_commission_Job` | 月度佣金发放（QbitInternational） |
| `partner_send_notice` | 政策变更通知 |
| `history_order_info_job` | 历史订单信息按月更新 |
| `history_order_profit_job` | 历史订单利润更新 |
| `overdue_rebates_deducted_job` | 超期返佣抵扣任务 |

### ChannelCommissionJob

渠道佣金相关的跑批任务，调用 `ChannelCommissionService`。

---

## 枚举列表

位于 `common/enums/` 和 `common_all/`：

| 枚举 | 说明 |
|------|------|
| `PartnerOrderTypeEnum` | 订单业务类型（17 种） |
| `PartnerOrderDisplayStatusEnum` | 订单展示状态（Na, Pending, CEOReviewPassed, FinanceReviewPassed, Processing, Closed, Fail, Rejected） |
| `PartnerStatusEnum` | 合作伙伴状态（ONLINE, OFFLINE） |
| `PartnerFeeType` | 费用类型（目前仅 AccountDeposit） |
| `ExternalPartnerSettleTypeEnum` | 外部合作伙伴结算类型（CustomersNumber, TransactionAmount, CustomersNumberAndTransactionAmount, NoCommission） |
| `ChannelSourceEnum` | 渠道来源（含 Partner） |
| `ReferralCodeTypeEnum` | 邀请码类型（含 Partner） |

---

## 数据库表汇总

| 表名 | 说明 | 模块 |
|------|------|------|
| `partners` | 合作伙伴/供应商 | manage |
| `"partnerOrder"` | 合伙人订单（提成记录） | merchant |
| `"partnerBankAccount"` | 合伙人银行账户 | merchant |
| `"channelCommission"` | 渠道佣金记录 | commission |
| `"referralCode"` | 邀请码 | 公共 |
| `"salesAccountRelation"` | 销售关系 | 公共 |
