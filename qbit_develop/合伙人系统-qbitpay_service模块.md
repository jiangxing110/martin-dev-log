# 合伙人系统 - qbitpay_service 模块

> 项目路径：`/Users/martinjiang/WebstormProjects/qbitpay_service`
> 技术栈：NestJS + TypeScript + TypeORM + GraphQL（NestJS-Query）

## 模块结构

```
src/modules/partner/
├── partner.module.ts                    # 模块定义
├── partner.dto.ts                       # DTO、InputType、VO 定义
├── controller/
│   └── partner-controller.ts            # REST 控制器
├── service/
│   ├── partner-account.service.ts       # 合伙人账户服务（注册、指派、客户列表）
│   ├── partner-order.service.ts         # 合伙人订单服务（提成计算、审核、提现）
│   ├── partner-bank-account.service.ts  # 合伙人银行账户服务
│   └── channel-commission.service.ts    # 渠道佣金服务
└── resolver/
    ├── partner-account.resolver.ts      # GraphQL Resolver - 账户
    ├── partner-order.resolver.ts        # GraphQL Resolver - 订单
    └── partner-bank-account.resolver.ts # GraphQL Resolver - 银行账户
```

### 辅助模块

```
src/modules/ecosystem/
├── eco-partner.service.ts               # 生态合作伙伴服务（空壳）
└── eco-partner.resolver.ts              # 生态合作伙伴 Resolver

src/modules/partner-hub/
├── partner-hub.module.ts                # Partner Hub 模块
└── partner-hub.resolver.ts             # Partner Hub Resolver

src/modules/schedule/partner/
└── partner-schedule.ts                  # 合伙人定时任务

src/modules/data-loader/
├── eco-partner.data-loader.ts           # 生态合作伙伴 DataLoader
├── external-partner.data-loader.ts      # 外部合作伙伴 DataLoader
└── partner-bank-account.data-loader.ts  # 银行账户 DataLoader

src/modules/apply/apply-handler/
├── eco-partner-apply-handler.service.ts # 生态合作申请处理
└── partner-business-fee-apply-handler.service.ts # 合伙人商务费率申请

src/scripts/partner/
└── partner.script.ts                    # 合伙人脚本

src/modules/event-subscriber-register/
└── partner-order.hooks.ts              # 合伙人订单事件订阅
```

### 数据实体

```
src/entity/partner/
├── partner-order.entity.ts              # 合伙人订单表
├── partner-bank-account.entity.ts       # 合伙人银行账户表
└── channel-commission.entity.ts         # 渠道佣金表

src/entity/ecosystem/
└── eco-partner.entity.ts               # 生态合作伙伴表
```

### 枚举

```
src/common/enum/
├── partner-order.enum.ts               # PartnerOrderTypeEnum 订单类型
└── account-general-type.enum.ts        # 包含 Channel（合伙人）类型
```

---

## 核心服务详解

### 1. PartnerAccountService（合伙人账户服务）

**文件：** `src/modules/partner/service/partner-account.service.ts`（767 行）

主要功能：

| 方法 | 说明 |
|------|------|
| `wxPartnerReg()` | 国内版合伙人注册 |
| `overseasPartnerReg()` | 海外版合伙人注册 |
| `registerPartner()` | 合伙人注册核心逻辑 |
| `assignPartner()` | 指派合伙人（替换客户邀请码） |
| `addCommission()` | 指派合伙人后补提成 |
| `addCommissionByJava()` | 通过 Java 接口补提成 |
| `findCustomerAccountList()` | 客户列表查询（含多表关联） |
| `findCustomerAccountListV2()` | 客户列表 V2（基于当前用户） |
| `updatePartnerPromoteBusinessType()` | 变更合伙人推广业务类型 |
| `createEffectiveCode()` | 创建 6 位用户码 |
| `partnerReferralCode()` | 查询合伙人邀请码 |
| `getReferralCodeIdByPartner()` | 获取合伙人对应的邀请码 ID |
| `customerDetailWaitingCount()` | 待补客户人数 |

### 2. PartnerOrderService（合伙人订单服务）

**文件：** `src/modules/partner/service/partner-order.service.ts`（2728 行，系统中最复杂的服务之一）

主要功能：

| 方法 | 说明 |
|------|------|
| `createSpreadOrder()` | 创建推广订单（核心入口） |
| `createSettlementOrder()` | 创建结汇订单 |
| `createWithdrawOrder()` | 创建提现订单 |
| `reviewPartnerOrder()` | 审核合伙人订单 |
| `getFeeByInboundFee()` | 全球账户入金手续费合伙人分润 |
| `partnerQbitCardRecharge()` | 量子账户充值提成 |
| `searchKybAndCreateSpreadOrder()` | kyb 通过后创建推广订单 |
| `searchIsActionAndCreateSpreadOrderByGlobalAccount()` | 检测全球账户激活并创建订单 |
| `searchIsActionAndCreateSpreadOrderByQbitCard()` | 检测量子账户激活并创建订单 |
| `getPartnerStatistics()` | 合伙人金额统计（含余额计算） |
| `overseasPartner()` | 海外合伙人分润 |
| `estimateQuote()` | 询价接口 |
| `partnerTask()` | 飞书订阅事件处理 |

### 3. PartnerBankAccountService（银行账户服务）

**文件：** `src/modules/partner/service/partner-bank-account.service.ts`

主要功能：合伙人银行账户 CRUD、链地址 KYA 检查、提现币种链查询

### 4. ChannelCommissionService（渠道佣金服务）

**文件：** `src/modules/partner/service/channel-commission.service.ts`

目前为空壳实现，具体逻辑在 `qbit-assets` 的 `ChannelCommissionServiceImpl` 中。

---

## 合伙人注册流程

```
wxPartnerReg / overseasPartnerReg
        │
        ├─ 检查是否 2.0 客户手机号
        ├─ 验证短信/邮箱验证码
        ├─ 黑名单检查
        │
        └─ registerPartner()
            │
            ├─ 已有用户？检查重复注册
            ├─ 创建 User / Account / AccountExtend / AccountUser
            ├─ 关联邀请码（inviteCodeRes）
            ├─ 创建合伙人钱包（PartnerWallet 订单）
            ├─ 创建邀请码（ReferralCode）
            ├─ 建立销售关系（SalesAccountRelation）
            └─ 返回 JWT
```

---

## PartnerOrder 提成触发事件

| 触发事件 | 处理逻辑 |
|---------|---------|
| KYC/KYB 审核通过 | `searchKybAndCreateSpreadOrder()` → 创建注册提成订单 |
| 全球账户入金>=100USD | `searchIsActionAndCreateSpreadOrderByGlobalAccount()` → 创建激活提成 |
| 量子账户充值>=100USD | `searchIsActionAndCreateSpreadOrderByQbitCard()` → 创建量子激活提成 |
| 全球账户付款（结汇） | `createSettlementOrder()` → 创建结汇提成 |
| 全球账户入金完成 | `getFeeByInboundFee()` → 创建入金手续费分成 |
| 量子账户充值达标 | `partnerQbitCardRecharge()` → 创建充值阶梯提成 |
| 海外公司注册完成 | `overseasPartner()` → 创建公司注册提成 |
| 海外全球账户开户 | `overseasPartner()` → 创建开户费提成 |

---

## 提现审核（飞书集成）

通过 Queue 订阅飞书审批结果：

1. 合伙人发起提现 → 创建 `Pending` 订单
2. 飞书通知 CEO 审批
3. `partnerTask()` 接收飞书回调：
   - 审批 1（CEO 审核）→ `CEOReviewPassed` 或 `Rejected`
   - 审批 1.1（重审）→ 同上
   - 审批 2（财务审核）→ `FinanceReviewPassed` 或 `Rejected`
4. 财务审核通过后，web3 提币走 `assetsWithdraw()`，法币直接打款 → `Closed`

---

## GraphQL 接口

通过 Resolver 暴露 GraphQL 查询/变更：
- `PartnerAccountResolver`：客户列表、合伙人信息、统计数据
- `PartnerOrderResolver`：订单列表、提现、审核、统计数据
- `PartnerBankAccountResolver`：银行账户管理

---

## 定时任务

`partner-schedule.ts`：定时触发提成计算（每日跑批）
