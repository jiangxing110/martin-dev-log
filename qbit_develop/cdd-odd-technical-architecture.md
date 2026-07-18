# CDD & ODD 技术架构文档

> 最后更新: 2026-06-12
> 项目: qbitpay-service (NestJS + TypeScript + GraphQL + TypeORM)

---

## 一、概述

### 1.1 什么是 CDD

**CDD (Customer Due Diligence)** — 客户尽职调查，是商户入驻时必须完成的核心 KYC/KYB 流程。包含：

- **Business KYC** (企业商户): 企业信息 + 董事/股东/最终受益人认证
- **Individual/Personal KYC** (个人商户): 个人身份信息 + 证件认证
- **KYB** (Know Your Business): 业务类型审核 (VirtualCard, Acquiring, MultiCurrencyAccount, DigitalCurrencies)

### 1.2 什么是 ODD

项目中有**两个 ODD 子系统**，共享 `src/modules/cdd/odd/` 目录但用途不同：

| 子系统 | 实体 | 表 | 用途 |
|--------|------|-----|------|
| **ODD 账户审查 (年审)** | `OddAccountReview` | `oddAccountReview` | 按风险等级定期审查商户账户 |
| **ODD 持续身份识别** | `Odd` | `odd` | 证件到期跟踪 & 更新 |

### 1.3 模块目录结构

```
src/modules/cdd/
├── odd/                          # ODD 子系统
│   ├── odd-account-review.resolver.ts
│   ├── odd-account-review.service.ts
│   ├── odd.resolver.ts
│   ├── odd.service.ts
│   └── odd.dto.ts
├── v2/                           # CDD v2 (主 API 面)
│   ├── controller/cdd-v2.controller.ts
│   ├── resolver/
│   │   ├── kyc-v2.resolver.ts
│   │   ├── kyb-v2.resolver.ts
│   │   ├── face-auth.resolver.ts
│   │   ├── cdd-individual.resolver.ts
│   │   └── file-qr-upload.resolver.ts
│   ├── service/
│   │   ├── kyc-v2.service.ts          (~3618行)
│   │   ├── kyc-individual-v2.service.ts (~1981行)
│   │   ├── face-auth.service.ts       (~1277行)
│   │   ├── kyb-v2.service.ts
│   │   ├── vendor-kyc.service.ts
│   │   ├── cdd.notice-v2.service.ts
│   │   └── file-qr-upload.service.ts
│   └── cdd-v2.dto.ts
├── blacklist/                     # CDD 黑名单
├── risk-rating/                   # 风险评级
├── zipcode/                       # 邮编填充
├── kyc.resolver.ts / kyc.service.ts
├── kyb.resolver.ts / kyb.service.ts
├── kyCase.service.ts
└── cdd.module.ts

src/entity/cdd/
├── cdd-ky-case.entity.ts           # CddKyCase
├── cdd-kyc.entity.ts               # CddKyc (含 KycTypeEnum)
├── cdd-kyb.entity.ts               # CddKyb, CddKybDetail
├── cdd-kyc-business-detail.entity.ts # CddKycBusinessDetail, CddBusinessPerson
├── cdd-kyc-individual-detail.entity.ts
├── cdd-company-business-information.entity.ts
├── cdd-risk-rating.entity.ts
├── face-auth.entity.ts             # FaceAuth
├── odd.entity.ts                   # ODD 持续身份识别
├── odd-account-review.entity.ts    # ODD 账户审查
└── cdd-black.entity.ts

src/modules/thirdparty/external/plaid/
└── plaid.service.ts               # Plaid Identity Verification 集成
```

---

## 二、CDD 核心流程

### 2.1 Business KYC 入驻流程

入口: `KycV2Resolver.createKycByV2` → `KycV2Service.createKyc()`

```
┌──────────────────────────────────────────────────────────────┐
│ Business KYC 入驻流程                                         │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  1. 验证 ODD 账户审查状态 (BusinessOdd 时)                      │
│  2. kyCaseService.createCase() 创建 CddKyCase                 │
│  3. kycService.checkKycBlacklist() 黑名单检查                   │
│  4. 经济制裁国家自动拒绝                                        │
│  5. 中国个体工商户注册≤3个月自动拒绝                              │
│  6. createKycExecute() 核心执行:                               │
│     ├─ 创建 CddKyc 记录                                       │
│     ├─ 创建 CddKycBusinessDetail (企业信息)                     │
│     ├─ 创建 CddBusinessPerson (董事/股东/UBO)                   │
│     ├─ 创建 FaceAuth 记录 (每人的活体认证入口)                    │
│     ├─ Names Screening (姓名筛查)                               │
│     ├─ 保存实际控制人信息                                       │
│     └─ 保存企业工商信息 + 自动通过 DigitalCurrencies KYB         │
│  7. Compliance Engine 黑名单引擎查询                             │
│  8. 发送通知 & 同步待办清单                                    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 Personal/Individual KYC 入驻流程

入口: `KycIndividualV2Service.createKyc()`

```
┌──────────────────────────────────────────────────────────────┐
│ Personal KYC 入驻流程                                         │
├──────────────────────────────────────────────────────────────┤
│  1. checkIndividualKyc() 身份证号去重检查                       │
│  2. 创建 CddKyCase                                           │
│  3. 黑名单检查 (身份证号)                                      │
│  4. 创建 FaceAuth 记录                                        │
│  5. 三要素验证 (仅 CN: 调用阿里云实名认证)                       │
│  6. 创建 CddKyc + CddKycIndividualDetail                      │
│  7. 创建 CddKyb (业务类型 + VirtualCard)                       │
│  8. 更新待办清单                                              │
└──────────────────────────────────────────────────────────────┘
```

### 2.3 KYC 审核流程

入口: `KycV2Resolver.reviewKycByV2` → `KycV2Service.reviewKyc()`

状态流转条件: 当前 status 必须是 `Pending | CheckAdditional | ManualConfirmation | SystemDetection`

```
reviewKyc(user, input)
├── reviewKycAction(data)
│   ├── checkAdditionalKyc() 补充资料检查
│   │   ├─ Pass → 检查是否缺少附件 → AwaitAdditional
│   │   └─ Reject(Request) → 关闭待补充项
│   ├── checkFaceAuth() 人脸重置
│   │   └─ 特定 kyRequestList 拒绝类型 → 克隆 FaceAuth 重置为 Na
│   ├── createOrUpdateKyc() 更新 KYC 状态
│   ├── 创建操作日志 (CddKyRecord)
│   └── 更新 Case 时间戳
├── Passed → CRM 关联线索, 开通 QbitCard 角色
├── AwaitAdditional/CheckAdditional/Passed → 自动申请开户, 同步供应商
└── 发送审核通知
```

### 2.4 关键实体

| 实体 | 表 | 核心字段 | 用途 |
|------|-----|---------|------|
| `CddKyCase` | `cddKyCase` | `accountId`, `customerUpdateTime`, `reviewUpdateTime` | Case 容器，关联 KYC+KYB |
| `CddKyc` | `cddKyc` | `kyCaseId`, `kycType`, `status`, `isLatest` | KYC 主记录 |
| `CddKyb` | `cddKyb` | `kyCaseId`, `businessType`(ProductEnum), `status` | KYB 记录 |
| `CddKycBusinessDetail` | `cddKycBusinessDetail` | `kycId`, `businessName`, `businessID`, `registrationRegion` | 企业详情 |
| `CddBusinessPerson` | `cddBusinessPerson` | `kycId`, `name`, `identification`, `fromId`, `personType` | 企业关联人 |
| `CddKycIndividualDetail` | `cddKycIndividualDetail` | `kycId`, `firstName`, `identification`, `address` | 个人 KYC 详情 |
| `FaceAuth` | `faceAuth` | `recordId`, `recordType`, `fromId`, `status`, `thirdId` | 人脸/证件认证 |
| `CddRiskRating` | `cddRiskRating` | `accountId`, `riskLevel`, `sourceType` | 风险评级 |

---

## 三、ODD 账户审查 (年审)

### 3.1 概述

**ODD 账户审查 (OddAccountReview)** 是按商户风险等级定期触发的审查流程：

| 风险等级 | 审查周期 |
|---------|---------|
| High | 6 个月 |
| Middle | 12 个月 |
| Low | 24 个月 |

### 3.2 触发机制

```
┌────────────────────────────────────────────────────────────────┐
│ 触发方式                        │ Cron 时间       │ 说明       │
├────────────────────────────────┼────────────────┼────────────┤
│ triggerByCddRiskRating() V1    │ 按需 / 调度     │ 查询指定周期内  │
│                                │                │ 更新的评级记录  │
│ triggerByCddRiskRatingV2() V2  │ 每天 01:00     │ 无时间限制 +   │
│                                │                │ 空评级记录处理  │
│ triggerByOddAccountReview()    │ 每天 01:00     │ 已完成审查的    │
│                                │                │ 账户续期触发    │
│ createOddAccountReviewV2()     │ 管理员手动      │ 手动发起点    │
│                                │ (Mutation)     │              │
│ updateOddAccountReviewStatus() │ 每 5 分钟      │ 监控客户提交   │
│                                │ (Cron)         │ 状态          │
└────────────────────────────────┴────────────────┴────────────┘
```

### 3.3 生命周期

```
Status + Result 联动流转:

                            管理员: 完结处置(Na)
创建 → Processing ────────→ AdditionalRecording ────→ Closed
         │                    ↑                           │
         │                    │ (仅能再选 Success 或       │
         │                    │   RiskDisposal 才能到      │
         │                    │   Closed)                  │
         │                                                 │
         ├──→ Request ────→ Pending ───────────────────────┤
         │     (通知客户)     (客户已提交)                    │
         │                                                  │
         ├─────────────────────────────────────────────────┤
         │  Closed (完结) 的 Result:                          │
         │  ├─ Success      → 审核通过                       │
         │  ├─ RiskDisposal → 风险处置                       │
         │  └─ (不可为 Na, Na 只能走 AdditionalRecording)     │
         │                                                  │
         └──→ 自动关闭 (客户 7 天未提交 → Pending, isSubmitCdd=false)
```

详细状态说明:

| 状态 | 说明 | 触发场景 |
|------|------|---------|
| `Processing` | 待处理 | 刚创建/系统触发时 |
| `Request` | 待候补(待补录) | 创建时进入 / 管理员选择"待补录"后 |
| `Pending` | 待审核 | 客户提交材料后 / `updateOddAccountReviewStatus()` 自动检测通过 |
| `AdditionalRecording` | 材料补充 | **仅管理员审核时选择"完结处置"(Na)** 可到达 |
| `Closed` | 已完结 | 管理员审核时选择"调查通过"(Success) / "风险处置"(RiskDisposal) |

> **AdditionalRecording 的关键规则**: 只能在管理员审核时通过选择 **reviewResult = Na (完结处置)** 到达。进入 AdditionalRecording 后，前端隐藏"完结处置"选项，仅能选"调查通过"或"风险处置"推进到 Closed。*没有其他代码路径能将 status 设为 AdditionalRecording。*

### 3.4 审查流程

```
OddAccountReview 创建
│
├─ OddAccountReviewHook.afterInsert()
│   ├─ 创建 CddKyc (kycType: BusinessOdd) — 独立的 KYC 副本
│   ├─ 创建 CddKyb (businessType + "Odd" 后缀, 如 VirtualCardOdd)
│   ├─ 同步风险评估数据
│   └─ cancelCddPendingTodos() 取消 CDD 待办
│       └─ 取消该账户下 CDD 所有未完成(Na)的待补录代办
│           ├─ 条件: kycType=Business, status=Na, key∈[10个指定Key]
│           └─ 操作: status → Canceled
│
├─ 客户提交材料
│   ├─ FaceAuth 完成 (人的认证)
│   ├─ KYC/KYB 数据提交
│   └─ updateOddAccountReviewStatus() 自动检测
│
├─ 管理员审查: reviewOddAccountReview()
│   ├─ Closed + Success → 审核通过
│   │   └─ syncKycAndKybByOdd() 同步回主 CDD KYC/KYB
│   ├─ Closed + RiskDisposal → 风险处置
│   └─ AdditionalRecording + Na → 完结处置(退回补录)
│
├─ 电商店铺通过触发 ODD KYB 自动通过
│   └─ syncGlobalAccountKybStatusByShop()
│       └─ MultiCurrencyAccountOdd KYB 自动通过后
│           └─ OddAccountReview 更新为 Pending (包括已完结的记录)
│
└─ ODD 过期自动冻结
    ├─ Request > 31天 → 自动冻结 (只读)
    └─ 国际版: 60/87/90天 阶梯式冻结
```

### 3.5 定时调度

定义在 `CddSchedule` 中:

| 任务 | 时间 | 说明 |
|------|------|------|
| `triggerByCddRiskRatingV2` | 每天 01:00 | 触发新 ODD 审查 |
| `noticeCustomerByNewOdd` | 每天 01:00 | 通知待办客户 |
| `oddAutoFrozen` | 每天 01:00 | 超时自动冻结 |
| `updateOddAccountReviewStatus` | 每 5 分钟 | 监控客户提交状态 |
| `oddAccountReviewTodoBySchedule` | 每周 | 待办重提醒 |

### 3.6 管理员审核完结处置判断 (前端)

**项目**: `qbit-admin-v3/src/views/odd/examination/detail/_components/detail/_components/examination/index.tsx`

管理员审核时，reviewResult 与 status 的联动：

| 按钮 | reviewResult | 提交的 status | 条件 |
|------|-------------|--------------|------|
| 调查通过 | `Success` | `Closed` | 无限制 |
| 风险处置 | `RiskDisposal` | `Closed` | 无限制 |
| 完结处置 | `Na` | `AdditionalRecording` | **当前 status !== AdditionalRecording** |
| 待补录 | `Na` (前端映射) | `Request` | 无限制 |

**完结处置"按钮隐藏条件**:
```tsx
// 当当前 status === AdditionalRecording 时隐藏"完结处置"按钮
{detail.value?.status !== OddAccountReviewEnum.AdditionalRecording &&
  <el-radio-button label={OddAccountReviewResultEnum.Na}>完结处置</el-radio-button>}
```

> 隐藏原因: 完结处置的作用就是**将 status 设为 AdditionalRecording**。如果已经在 AdditionalRecording，再选完结处置等于原地踏步。此时只能选"调查通过"或"风险处置"来推进到 Closed。

提交时的状态映射 (`submit` 方法):
```typescript
// StatusRequest 是前端自定义常量 "StatusRequest"
formData.reviewResult === StatusRequest 
  ? OddAccountReviewResultEnum.Na   // 待补录 → Na
  : formData.reviewResult            // 其他情况原样提交
```

### 3.7 全球账户 KYB 自动通过触发 ODD

**入口**: `kyb-v2.service.ts` → `syncGlobalAccountKybStatusByShop()` (电商客户报备店铺通过时触发)

```
电商客户报备店铺 → 店铺审核通过
  └─ syncGlobalAccountKybStatusByShop()
      └─ MultiCurrencyAccountOdd KYB 自动通过
          └─ OddAccountReview 更新: status = Pending (含已完结的记录)
```

**代码位置** (`kyb-v2.service.ts` 约 972-980 行):
```typescript
if (kyb.businessType === ProductEnum.MultiCurrencyAccountOdd) {
  await this.oddAccountReviewRepo.update(
    { accountId: kyb.accountId },
    { status: OddAccountReviewEnum.Pending },
  );
}
```

> 注意: 此处**不取消 CDD 代办**。CDD 待办取消仅在 `OddAccountReviewHook.cancelCddPendingTodos()` 中处理（ODD case 创建时触发）。

---

## 四、ODD 持续身份识别

### 4.1 概述

**ODD (持续身份识别)** 跟踪商户/个人证件到期，及时通知更新。

| 字段 | 说明 |
|------|------|
| 实体 | `Odd` (表: `odd`) |
| 来源类型 | `BusinessKyc`, `PersonalKyc`, `Administrators` |
| 证件类型 | 护照、身份证、驾照、营业执照等 |
| 状态 | `Processing → Notice → Pending → Request / Closed / Passed / Rejected` |

### 4.2 与 CDD 联动

```
ODD 通过时:
├─ sourceType === BusinessKyc
│   └─ Queue: UpdateCddByOdd → KycV2Service.updateCddByOdd()
│      ├─ 更新企业字段 (经营期限)
│      ├─ 更新人员证件信息
│      ├─ 更新附件
│      └─ 创建操作日志
├─ sourceType === PersonalKyc
│   └─ Queue: UpdatePersonCddByOdd
└─ sourceType === Administrators
    └─ 直接更新管理员用户数据
```

---

## 五、FaceAuth 人脸/证件认证系统

### 5.1 实体定义

| 字段 | 类型 | 说明 |
|------|------|------|
| `accountId` | UUID | 账户 ID |
| `recordId` | UUID | 关联记录 ID (KyCaseId) |
| `recordType` | Enum | `Cdd`, `PhysicalCard`, `User` |
| `fromId` | UUID | 人员追踪 ID (关联 CddBusinessPerson.fromId) |
| `authType` | Enum | `Face`, `CertificateValidate`, `CertificateInHand` |
| `status` | Enum | `Pending`, `Na`, `Success`, `Fail` |
| `thirdId` | varchar | 第三方平台会话 ID (Plaid idv_xxx) |
| `country` | varchar | 证件国家 |
| `type` | Enum | 证件类型 (PASSPORT, HK-HKID, US-DLN 等) |
| `personType` | Enum | 人员角色 (BeneficialOwner, Partner, Authorizer 等) |
| `isLatest` | boolean | 是否最新记录 |
| `originalFileUrl` | varchar | 证件正面照 URL |
| `originalBackFileUrl` | varchar | 证件反面照 URL |
| `rawData` | JSON | 第三方原始数据 |
| `isApi` | boolean | 是否通过 API 创建 |

### 5.2 认证流程

```
┌─────────────────────────────────────────────────────────────────┐
│ FaceAuth 认证流程                                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  generatorUrlByCdd()                                            │
│  └─ 获取当前 FaceAuth 记录                                       │
│     ├─ Status 必须是 Fail 或 Na                                   │
│     └─ 配额检查 (CN: 5次/天, Plaid: 2次)                         │
│                                                                 │
│  ┌─ CN 用户 (CNRIC) ──────────────────────────────────────┐    │
│  │  生成 QR Code URL → 用户在系统自建页面完成活体检测        │    │
│  │  返回 QR 页面 URL + 静默活体 → 人脸比对 → 更新状态        │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  ┌─ 海外用户 (非 CNRIC) ──────────────────────────────────┐    │
│  │  generatorPlaidUrl() → 创建 Plaid Identity Verification    │    │
│  │  1. Plaid 会话创建 → thirdId = idv_xxx                    │    │
│  │  2. client_user_id = person.fromId                         │    │
│  │  3. 用户跳转 Plaid 完成证件上传+活体检测                    │    │
│  │  4. Plaid → POST /plaid/webhook (STATUS_UPDATED)          │    │
│  │  5. updateRecordForIDVSession() 处理回调                   │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  审核: reviewFaceAuth()                                         │
│  ├─ recordType === Cdd → WebSocket 通知商户端                    │
│  │   └─ 成功时 → 检查 BusinessOdd KYC, 触发待办重提交             │
│  ├─ recordType === PhysicalCard → WebSocket 通知 + 队列处理      │
│  └─ recordType === User → WebSocket 通知到个人                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 5.3 Plaid Webhook 回调处理

路径: `POST /plaid/webhook` → `PlaidController.webhook()` → `PlaidService.webhook()`

```
webhook(body)
├─ 环境检查 (environment 匹配)
├─ 分发 webhook_type
│   └─ IDENTITY_VERIFICATION
│       └─ handleIdVerWebhook(code)
│           └─ STATUS_UPDATED
│               └─ updateRecordForIDVSession(idvSession)
│
updateRecordForIDVSession(idvSession)
├─ Plaid API 获取会话数据
├─ fromId = data.client_user_id (UUID 校验)
├─ 状态映射:
│   ├─ success       → BasisStatusEnum.Success
│   ├─ pending_review → BasisStatusEnum.Fail
│   ├─ failed        → BasisStatusEnum.Fail
│   └─ active/其他   → BasisStatusEnum.Na (直接 return)
├─ 同步证件附件 (OSS 上传)
├─ 同步活体视频/自拍
├─ 查询 FaceAuth: { fromId, isLatest: true }
│   └─ 已进入终态 (Success/Rejected) → return
├─ 更新 PhysicalCard/User 的证件信息
├─ CDD 成功时 → trySendMismatchNotification()
├─ 失败→成功重置 → 直接更新
└─ Queue: FaceAuthReview (延迟 1s)
    └─ faceAuthReviewSubscription → reviewFaceAuth(robot, payload)
```

### 5.4 认证与 ODD 联动

FaceAuth 是连接 CDD 和 ODD 的重要桥梁：

```
FaceAuth 创建 (insert)
└─ FaceAuthHook.afterInsert()
    └─ oddAccountReviewService.updateOddAccountReviewStatus(faceAuth.recordId)

FaceAuth 审核成功 (reviewFaceAuth → recordType === Cdd)
└─ 检查 BusinessOdd KYC 状态
    ├─ 查找 { recordId: kyc.kyCaseId, status ≠ Success, isLatest: true }
    └─ 全部通过 → Queue: UpsertAccountToDoList(RejectBusinessKYCOdd)
```

---

## 六、CDD 与 ODD 交互

### 6.1 BusinessOdd KYC 类型

`KycTypeEnum.BusinessOdd` 是 ODD 账户审查在 KYC 系统中的独立副本：

| 特性 | 说明 |
|------|------|
| 创建时机 | `OddAccountReviewHook.afterInsert()` |
| 用途 | 审查周期内隔离商户 KYC 数据修改 |
| 同步回主 CDD | `syncKycAndKybByOdd()` 在审查关闭时触发 |
| 产品后缀 | `VirtualCardOdd`, `MultiCurrencyAccountOdd`, `DigitalCurrenciesOdd` |

### 6.2 联动流程

```
定时触发生成 ODD
│
├─ triggerByCddRiskRatingV2()
│   └─ createOddAccountReviewV2()
│       ├─ OddAccountReview 创建
│       └─ OddAccountReviewHook
│           └─ BusinessOdd KYC + Odd 后缀 KYB 创建
│
├─ 客户提交材料
│   ├─ FaceAuth 通过 (Plaid 或 QR 流程)
│   │   └─ FaceAuthHook → updateOddAccountReviewStatus()
│   └─ KYC/KYB 数据提交
│
├─ updateOddAccountReviewStatus() 自动检测
│   ├─ 已提交 + 有人脸 → Pending (isSubmitCdd=true)
│   └─ 7天未提交 → Closed (isSubmitCdd=false)
│
├─ 管理员审查
│   └─ reviewOddAccountReview()
│       ├─ Closed+Success → syncKycAndKybByOdd()
│       └─ Closed+RiskDisposal → 风险处置
│
└─ ODD 持续身份识别 (证件更新)
    └─ OddService.submitOdd() → Queue
        ├─ UpdateCddByOdd (Business)
        └─ UpdatePersonCddByOdd (Personal)
```

### 6.3 队列消息汇总

| Queue 类型 | 发布者 | 消费者 | 说明 |
|-----------|--------|--------|------|
| `FaceAuthReview` | `PlaidService` | `FaceAuthService` | 异步人脸审核 |
| `UpdateCddByOdd` | `OddService` | `KycV2Service` | ODD 回写 CDD |
| `UpdatePersonCddByOdd` | `OddService` | — | 个人 ODD 回写 |
| `UpdateCddByFaceAuth` | `cdd.notice-v2.service` | `KycV2Service` | 人脸证件同步至 CDD |
| `UpsertAccountToDoList` | 多处 | `AccountToDoService` | 待办清单 |
| `ComplianceEngineCheckKyc` | `KycV2Service` | `ComplianceEngineService` | 合规检查 |

---

## 七、关键枚举

### 7.1 KycTypeEnum

| 值 | 说明 |
|------|------|
| `Business` | 企业 KYC |
| `Individual` | 量子子账户 |
| `Personal` | 个人 KYC |
| `BusinessOdd` | 企业-账户审查 |
| `Supplier` | 供应商 |
| `AssetBuyer` | Crypto 买方 |
| `Employee` | 员工 |

### 7.2 FaceAuthRecordTypeEnum

| 值 | 说明 |
|------|------|
| `Cdd` | CDD/ODD KYC 人脸 |
| `PhysicalCard` | 实体卡 |
| `User` | 员工/管理员 |

### 7.3 FaceAuthTypeEnum

| 值 | 说明 |
|------|------|
| `Face` | 人脸识别 |
| `CertificateValidate` | 证件认证 |
| `CertificateInHand` | 手持证件照 |

### 7.4 BasisStatusEnum

| 值 | 说明 |
|------|------|
| `Pending` | 待处理 |
| `Na` | 未开始/默认 |
| `Success` | 通过 |
| `Fail` | 失败 |
| `Rejected` | 已拒绝 |

### 7.5 OddAccountReviewEnum

| 值 | 说明 |
|------|------|
| `Processing` | 待处理 |
| `Request` | 待候补(待补录) |
| `Pending` | 待审核 |
| `AdditionalRecording` | 材料补充 |
| `Closed` | 已完结 |

### 7.6 OddStatusEnum

| 值 | 说明 |
|------|------|
| `Processing` | 待处理 |
| `Notice` | 已通知 |
| `Pending` | 待审核 |
| `Request` | 待补录 |
| `Closed` | 已完结 |
| `Rejected` | 已拒绝 |
| `Passed` | 已完成 |

### 7.7 ProductEnum (ODD 后缀)

| 值 | 说明 |
|------|------|
| `VirtualCardOdd` | 审查期虚拟卡业务隔离 |
| `MultiCurrencyAccountOdd` | 审查期多币种账户隔离 |
| `DigitalCurrenciesOdd` | 审查期数字货币隔离 |

---

## 八、事件订阅者 (Entity Subscribers)

### 8.0 基础架构

所有 CDD Hook 分为两类:

**基于 `BaseHook<T>` 抽象类** (支持事务提交后执行):
- `CddKycHook`
- `CddKybHook`
- `CddRiskRatingHook`

**独立实现 `EntitySubscriberInterface`** (自定义事务处理逻辑):
- `FaceAuthHook`
- `OddAccountReviewHook`
- `CddKyRecordHook`
- `AccountHook`

`BaseHook<T>` 在 `afterTransactionCommit` 中自动判断事务是否活跃，确保 hook 在事务提交后才执行:

```typescript
export abstract class BaseHook<T> implements EntitySubscriberInterface<T> {
  public abstract listenTo(): any;

  protected abstract afterInsertHandle(entity: T): Promise<void> | void;
  protected abstract afterUpdateHandle(entity: T, beforeEntity?: T): Promise<void> | void;

  public afterTransactionCommit(event: TransactionCommitEvent): void {
    // 从事务 queryRunner.data 中取出缓存的 entity 并执行 hook
    let entity = queryRunner.data[this.insert];
    if (entity) {
      this.afterInsertHandle(entity);
      delete queryRunner.data[this.insert];
    }
    entity = queryRunner.data[this.update];
    if (entity) {
      this.afterUpdateHandle(entity);
      delete queryRunner.data[this.update];
    }
  }
}
```

### 8.1 CddKycHook

**文件**: `src/modules/event-subscriber-register/cdd-kyc.hook.ts`
**监听**: `CddKyc` 实体

```typescript
@EntitySubscriber(CddKyc)
afterInsert(entity)
  └─ afterInsertHandle(entity)
      ├─ kycType === BusinessOdd → oddAccountReviewService.updateOddAccountReviewStatus()
      └─ 其他类型 →
          ├─ updateUserReport()     → 同步 UserReport 状态
          ├─ sendWebhook()          → 发送 KYC.UPDATED webhook 回调
          └─ updateKybAccountTodo() → 自动通过 MultiCurrencyAccount KYB (当 KYC Passed + KYB AwaitAdditional)

afterUpdate(entity, beforeEntity)
  └─ kycType !== BusinessOdd →
      ├─ updateUserReport()
      └─ sendWebhook()
```

| 触发动作 | 说明 |
|---------|------|
| `updateUserReport()` | 个人版 KYC 状态变化 → 同步 UserReport (Submitted/Overruled/Refuse/Passed/Blacklisted) |
| `sendWebhook()` | 发送 `KYC.UPDATED` 事件到外部系统 (`/core/internal/webhook/send-webhook-v3`) |
| `updateKybAccountTodo()` | KYC Passed + MultiCurrencyAccount KYB AwaitAdditional → 自动 Pass KYB |
| BusinessOdd 特殊逻辑 | 仅更新 ODD 审查状态，不触发 webhook 及其他副作用 |

### 8.2 CddKybHook

**文件**: `src/modules/event-subscriber-register/cdd-kyb.hook.ts`
**监听**: `CddKyb` 实体

```typescript
@EntitySubscriber(CddKyb)
afterInsert(entity)
  ├─ 如果 businessType = MultiCurrencyAccountOdd / VirtualCardOdd
  │   └─ oddAccountReviewService.updateOddAccountReviewStatus()
  └─ afterUpdateHooks(entity)
      └─ sendWebhook() → 发送 KYB.UPDATED 事件

afterUpdate(entity)
  └─ afterUpdateHooks(entity)
      └─ sendWebhook() → 发送 KYB.UPDATED 事件
```

| 触发动作 | 说明 |
|---------|------|
| `sendWebhook()` | 发送 `KYB.UPDATED` 事件到外部系统，包含 `businessType` 枚举映射 (VirtualCard=0, ParticleFinance=1, Acquiring=2, DigitalCurrencies=3, MultiCurrencyAccount=4, LiteKyb=5) |
| ODD KYB insert | 仅 ODD 后缀产品触发 ODD 审查状态更新 |

### 8.3 CddRiskRatingHook

**文件**: `src/modules/event-subscriber-register/cdd-risk-rating.hook.ts`
**监听**: `CddRiskRating` 实体

```typescript
@EntitySubscriber(CddRiskRating)
afterInsert(entity)
  └─ eddCaseService.createEddCaseByCddRiskRating(entity)

afterUpdate(entity)
  └─ eddCaseService.createEddCaseByCddRiskRating(entity)
```

每次风险评级创建或更新后，自动检查是否需要创建 **EDD (Enhanced Due Diligence)** 案件。

### 8.4 FaceAuthHook

**文件**: `src/modules/event-subscriber-register/face-auth-hook.ts`
**监听**: `FaceAuth` 实体

```typescript
@EntitySubscriber(FaceAuth)
afterInsert(faceAuth)
  └─ afterInsertHooks(faceAuth)
      └─ oddAccountReviewService.updateOddAccountReviewStatus(faceAuth.recordId)
```

每个 FaceAuth 插入都会触发 ODD 账户审查状态检查。注意此 Hook **不继承 BaseHook**，直接在 `afterInsert` 中处理。

> 注意: 有一段被注释的代码 `systemReviewEmployeeKyc` 原本用于在 FaceAuth 成功后自动审核员工 KYC，当前已禁用。

### 8.5 OddAccountReviewHook

**文件**: `src/modules/event-subscriber-register/odd-account-review.hook.ts`
**监听**: `OddAccountReview` 实体

```typescript
@EntitySubscriber(OddAccountReview)
afterInsert(oddAccountReview)
  └─ createKycAndKyb(oddAccountReview, queryRunner)
      ├─ 从旧的 KyCase 获取 Complete KYC 数据
      ├─ 创建 CddKyc (kycType: BusinessOdd)
      │   ├─ 复制 CddBusinessPerson (清空 fromId 重新生成)
      │   ├─ 复制 CddKycBusinessDetail
      │   ├─ 复制 CddCompanyBusinessInformation
      │   └─ isDoNamesScreening: false (奇数审查不重复筛查)
      ├─ 创建 CddKyb (原有 Passed KYB 复制 + "Odd" 后缀)
      │   ├─ VirtualCard → VirtualCardOdd
      │   └─ MultiCurrencyAccount → MultiCurrencyAccountOdd
      ├─ 同步 CddRiskRating (sourceType: Cdd → Odd)
      └─ cancelCddPendingTodos() 取消 CDD 代办
```

| 步骤 | 说明 |
|------|------|
| 获取旧数据 | 从最近一次 Closed 或当前 Case 获取已有 KYC/KYB 数据 |
| 创建 BusinessOdd KYC | 使用 robot 用户，不触发 names screening，不创建 FaceAuth |
| 创建 Odd KYB | 遍历已通过的 KYB (VirtualCard, MultiCurrencyAccount)，创建 `{product}Odd` 副本 |
| 同步风险评级 | 复制 CddRiskRating，sourceType 改为 Odd，sourceId 改为新 kyCaseId |
| 取消 CDD 代办 | 取消该账号 CDD 所有未完成的待补录代办 (详见下方) |

**cancelCddPendingTodos 详细逻辑**:
```typescript
// 1. 查找该账户所有 Business KYC 的 kyCaseId
cddKycIds = await cddKycRepo.find({
  accountId: info.accountId,
  kycType: KycTypeEnum.Business,
}, select: ['kyCaseId'])

// 2. 将这些 kyCaseId 作为 recordId，取消未完成的代办
queryRunner.manager.update(AccountToDo, {
  accountId: info.accountId,
  recordId: In(ids),        // 所有 CDD kyCaseId
  key: In([                 // 以下 10 种代办
    RequestVirtualCardKyb,
    RequestMultiCurrencyAccountKyb,
    RequestDigitalCurrenciesKyb,
    RequestParticleFinanceKyb,
    RequestAcquiringKyb,
    RequestAdditionMultiCurrencyAccountKyb,
    CreateShop,
    businessCertificate,
    RejectMultiCurrencyAccountOdd,
    RejectVirtualCardOdd,
  ]),
  status: BasisStatusEnum.Na, // 仅取消未处理的
}, {
  status: BasisStatusEnum.Canceled,
})
```

> 取消逻辑放在 `createKycAndKyb()` 末尾，使用 `queryRunner.manager` 确保与 ODD case 创建在同一事务中。仅影响 `status = Na` 且 key 在指定范围内的待办。

### 8.6 CddKyRecordHook

**文件**: `src/modules/event-subscriber-register/cdd-ky-record.hook.ts`
**监听**: `CddKyRecord` 实体 (操作日志)

```typescript
@EntitySubscriber(CddKyRecord)
afterInsert(entities)
  └─ afterInsertHooks(entities)
      ├─ partnerOrderService.searchKybAndCreateSpreadOrder()  ← "趣拿钱" 推广订单
      │   └─ 仅当 kyType = GLOBAL_ACCOUNTS_KYB / QBIT_CARD_KYB / KYC
      └─ createCoupon(cddKyRecord)                            ← 优惠券发放
          ├─ 过滤: 仅 GLOBAL_ACCOUNTS_KYB / QBIT_CARD_KYB
          ├─ 排除: 个人版 API 子账户、迁移客户
          ├─ sendQbitCardAccountDiscount() → 量子卡优惠券
          │   ├─ 优惠券类型: NewAccountCreateCard / MarketEventCreateCard (V2/V3)
          │   ├─ 已有优惠券不再重复发放
          │   └─ 邀请码渠道可覆盖默认开卡数
          └─ sendGlobalAccountDiscount() → 全球账户优惠券
              ├─ 优惠券类型: GlobalAccountPaymentCNY / MarketGlobalAccountPaymentCNY
              ├─ 仅限通过指定邀请码注册的用户
              └─ 每人限领一次
```

| 触发动作 | 说明 |
|---------|------|
| `searchKybAndCreateSpreadOrder()` | KYB 通过后触发推广订单 (趣拿钱) |
| `createCoupon()` | 量子卡/全球账户 KYB 通过后自动发放优惠券 |

### 8.7 AccountHook

**文件**: `src/modules/event-subscriber-register/account.hook.ts`
**监听**: `Account` 实体

```typescript
@EntitySubscriber(Account)
afterInsert(account)
  └─ afterAccountInsert(account)
      ├─ createMarqetaCoupon(account)  → Marqeta 活动优惠券 (50张)
      └─ createSalesAccountRelation()  → 子账户同步销售关系

afterUpdate(account)
  └─ afterUpdateHooks(account)
      ├─ status === Cleared → clearedGlobalReceiver() → 停用所有收款方
      └─ status ∈ [Frozen, Cleared, Readonly] → sendNotice()
          └─ 通知销售和运营人员账户状态变更/清退
```

| 触发动作 | 说明 |
|---------|------|
| `createMarqetaCoupon()` | 新注册账户发放 Marqeta 活动优惠券，判断活动时间窗口 |
| `createSalesAccountRelation()` | 子账户创建时自动关联上级账户的销售关系 |
| `clearedGlobalReceiver()` | 账户清退时自动停用所有 GlobalReceiver |
| `sendNotice()` | 账户冻结/清退/只读时通知销售和运营人员 |

---

### 8.8 Hook 汇总表

| Hook | 监听实体 | 触发时机 | 核心动作 | 继承 BaseHook |
|------|---------|---------|---------|-------------|
| CddKycHook | CddKyc | Insert/Update | 同步 UserReport、发 Webhook、自动通过 KYB | 是 |
| CddKybHook | CddKyb | Insert/Update | 发 Webhook、更新 ODD 状态 | 是 |
| CddRiskRatingHook | CddRiskRating | Insert/Update | 创建 EDD 案件 | 是 |
| FaceAuthHook | FaceAuth | Insert | 更新 ODD 审查状态 | 否 |
| OddAccountReviewHook | OddAccountReview | Insert | 创建 BusinessOdd KYC + Odd KYB | 否 |
| CddKyRecordHook | CddKyRecord | Insert | 推广订单、发放优惠券 | 否 |
| AccountHook | Account | Insert/Update | 优惠券、销售关系、清退通知 | 否 |

## 九、核心文件清单

### 9.1 CDD 核心文件

| 文件 | 行数 | 说明 |
|------|------|------|
| `src/modules/cdd/v2/service/kyc-v2.service.ts` | ~3618 | Business KYC 业务逻辑 |
| `src/modules/cdd/v2/service/kyc-individual-v2.service.ts` | ~1981 | 个人 KYC 业务逻辑 |
| `src/modules/cdd/v2/service/face-auth.service.ts` | ~1277 | 人脸认证业务逻辑 |
| `src/modules/cdd/v2/service/kyb-v2.service.ts` | — | KYB 业务逻辑 |
| `src/modules/cdd/v2/resolver/kyc-v2.resolver.ts` | — | KYC GraphQL 接口 |
| `src/modules/cdd/v2/resolver/face-auth.resolver.ts` | ~103 | FaceAuth GraphQL 接口 |
| `src/modules/cdd/v2/cdd-v2.dto.ts` | ~1600 | DTO 定义 |

### 9.2 ODD 核心文件

| 文件 | 说明 |
|------|------|
| `src/modules/cdd/odd/odd-account-review.service.ts` | 账户审查业务逻辑 |
| `src/modules/cdd/odd/odd-account-review.resolver.ts` | 账户审查 GraphQL 接口 |
| `src/modules/cdd/odd/odd.service.ts` | 持续身份识别业务逻辑 |
| `src/modules/cdd/odd/odd.resolver.ts` | 持续身份识别 GraphQL 接口 |
| `src/modules/cdd/odd/odd.dto.ts` | ODD DTO 定义 |

### 9.3 关联模块

| 文件 | 说明 |
|------|------|
| `src/modules/thirdparty/external/plaid/plaid.service.ts` | Plaid 身份认证集成 |
| `src/modules/event-subscriber-register/face-auth-hook.ts` | FaceAuth EventSubscriber |
| `src/modules/cdd/risk-rating/risk-rating.service.ts` | 风险评级服务 |
| `src/modules/cdd/blacklist/cdd-blacklist.service.ts` | CDD 黑名单 |
| `src/modules/export/odd/odd-account-review.export.service.ts` | ODD 审查数据导出 XLSX |
| `src/modules/global-account-v2/service/global-account-multiple.service.ts` | 全球账户自动开户 |
| `src/modules/global-account-v2/service/global-account-customer.service.ts` | 全球账户客户管理 |

### 9.4 实体定义

| 文件 | 表 |
|------|-----|
| `src/entity/cdd/cdd-ky-case.entity.ts` | `cddKyCase` |
| `src/entity/cdd/cdd-kyc.entity.ts` | `cddKyc` |
| `src/entity/cdd/cdd-kyb.entity.ts` | `cddKyb` |
| `src/entity/cdd/cdd-kyc-business-detail.entity.ts` | `cddKycBusinessDetail`, `cddBusinessPerson` |
| `src/entity/cdd/cdd-kyc-individual-detail.entity.ts` | `cddKycIndividualDetail` |
| `src/entity/cdd/face-auth.entity.ts` | `faceAuth` |
| `src/entity/cdd/odd.entity.ts` | `odd` |
| `src/entity/cdd/odd-account-review.entity.ts` | `oddAccountReview` |

---

## 十、常见问题

### Q: CDD 和 ODD 共享同一个 FaceAuth 记录吗？

不共享。CDD 和 ODD 各自有独立的 `CddKyCase` (不同 `recordId`)。FaceAuth 通过 `recordId` 关联到对应的 Case。但同一人在 CDD 和 ODD 中会有不同的 `faceAuth` 记录（不同 `fromId`），因为它们指向不同 Case 下的 `CddBusinessPerson`。

### Q: ODD 的 FaceAuth 状态为什么没更新？

可能原因：
1. **Plaid 会话未完成** — 用户还没完成 Plaid 验证，会话状态为 `active`，webhook 映射为 `Na` 直接 return
2. **管理员未审核** — CDD 通常是管理员手动调用 `reviewFaceAuth` 审核通过，ODD 需要等待 Plaid 回调
3. **配额限制** — Plaid 有 2 次认证次数限制

### Q: BusinessOdd 和普通 Business 有什么区别？

| 方面 | Business | BusinessOdd |
|------|----------|-------------|
| 目的 | 首次入驻 | 定期审查 |
| 创建 | 商户主动提交 | ODDHook 自动创建 |
| 独立性 | 主 KYC 数据 | KYC 副本，审查结束后同步回主 |
| KYB 类型 | VirtualCard | VirtualCardOdd (带后缀) |
| 名称筛查 | Onboarding | PeriodicalReview |
| 自动拒绝 | 有 (3个月规则) | 跳过 |

---

## 十一、全球账户状态流转 (Global Account)

### 11.1 概述

全球账户 (Global Account) 是商户在平台开通的多币种收款账户。开户流程由 CDD KYC/KYB 审核通过后自动触发。

| 维度 | 说明 |
|------|------|
| 核心实体 | `GlobalAccountCustomer` (客户), `GlobalSubAccount` (子账户) |
| 开户触发器 | KYC Passed + MultiCurrencyAccount KYB Passed/AwaitAdditional |
| 提供商匹配 | 按国家 + 货币 + 账户类型 + 资金来源匹配 |
| 提供商 | Currencycloud, SolidFi, Pyvio, Epay, Rf, Zb, QbWallet |

### 11.2 实体定义

#### GlobalAccountCustomer (全球账户客户)

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 主键 |
| `accountId` | UUID | 关联 Account |
| `provider` | Enum | `GlobalAccountProviderEnum` (Currencycloud, SolidFi 等) |
| `status` | Enum | `Active`, `Inactive`, `Processing`, `Pending` |
| `holderId` | string | 第三方渠道客户 ID |
| `customerId` | string | 第三方渠道客户编号 |

#### GlobalSubAccount (全球子账户)

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 主键 |
| `accountId` | UUID | 关联 Account |
| `customerId` | UUID | 关联 GlobalAccountCustomer |
| `provider` | Enum | 渠道提供商 |
| `currency` | Enum | 币种 |
| `accountType` | Enum | `OtherBankAccount`, `QBAccount` 等 |
| `status` | Enum | `GlobalSubAccountStatus` (见下表) |
| `subAccountNo` | string | 子账户号码 |
| `purpose` | string | 开户用途 (如 "kyb 审核通过自动开户") |

### 11.3 GlobalSubAccount 生命周期

```
                  ┌──────────────────────────────┐
                  │         Pending              │
                  │   (待开户: 客户申请未完成)      │
                  └─────────────┬────────────────┘
                                │ 渠道开户进行中
                                ▼
                  ┌──────────────────────────────┐
                  │        Processing            │
                  │   (处理中: 渠道开户完成/失败)    │
                  └─────────────┬────────────────┘
                                │ 激活成功
                                ▼
                  ┌──────────────────────────────┐
                  │          Active              │
                  │   (已激活: 可正常使用)          │
                  ├──────────────────────────────┤
                  │          Frozen              │
                  │   (已冻结)                     │
                  ├──────────────────────────────┤
                  │         Inactive             │
                  │   (已停用)                     │
                  └──────────────────────────────┘

特殊状态:
- Request: 问卷驳回 (需重新提交)
- Offline_Inactive: 渠道下线展示用 (实际 Active)
```

| 状态 | 含义 | 触发条件 |
|------|------|---------|
| `Pending` | 待开户 | 客户申请全球账户，渠道开户未完成 |
| `Processing` | 处理中 | 渠道开户完成/渠道自动开户失败 |
| `Active` | 已激活 | 开户成功，可正常使用 |
| `Inactive` | 已停用 | 手动停用或清退 |
| `Frozen` | 已冻结 | 风控冻结 |
| `Request` | 问卷驳回 | 渠道返回问卷需客户补充 |
| `Offline_Inactive` | 渠道下线 | 仅前端展示映射，数据库仍为 Active |

### 11.4 自动开户流程

**入口**: `reviewKybStep2()` → `autoApplyOpenCustomer(accountId)`

```
KYB 审核通过 (MultiCurrencyAccount)
│
└─ reviewKybStep2()
    └─ globalAccountMultipleService.autoApplyOpenCustomer(accountId)
        │
        ├── 前置检查
        │   ├─ isBlockedByApiAccessType() → 拒绝自动开户
        │   ├─ 已有进行中的 kyb 开户 → return
        │   ├─ 已有 Active 的 GlobalSubAccount → return
        │   └─ KYC 和 KYB 状态校验
        │
        ├── 判断账户类型
        │   ├─ QBAccount (QB 钱包)
        │   │   ├─ applyQbWallet(account, user, true) → 开通 QB 钱包
        │   │   └─ financeAutoReview() → 理财 KYB 自动通过
        │   │
        │   └─ OtherBankAccount / 其他
        │       ├─ 匹配国家码:
        │       │   ├─ OtherBankAccount → OtherCurrencyToCountryCodeMap[currency]
        │       │   └─ 其他 → GlobalAccountTypeEnumMap.get(accountType)
        │       │
        │       ├─ globalProviderAccRulesService.run() → 匹配提供商
        │       │   ├─ 匹配到 provider → applyOpenCustomer() 执行开户
        │       │   └─ 未匹配到 → 发送通知 (无渠道告警)
        │       │       ├─ Robot 通知: "KYB通过但是没有匹配到相应渠道"
        │       │       └─ 客户通知: 配置国家-货币信息
        │       │
        │       └─ applyOpenCustomer()
        │           ├─ 根据 provider 调用对应渠道开户 API
        │           │   ├─ Currencycloud → CCCreateAccount
        │           │   ├─ SolidFi → SolidFICreateCustomer
        │           │   ├─ Pyvio → CreatePyvioCustomer
        │           │   ├─ Epay → CreateEpCustomer
        │           │   ├─ Rf → CreateRfCustomer
        │           │   └─ Zb → CreateZbCustomer
        │           ├─ 创建 GlobalAccountCustomer (provider 渠道客户)
        │           └─ 创建 GlobalSubAccount (子账户, status: Pending/Processing)
        │
        └── 最终检查
            └─ 会计入账: openB2bSettle() 开通结算账户
```

### 11.5 提供商匹配规则

**文件**: `src/modules/global-account-v2/service/global-provider-acc-rules.service.ts`

```
globalProviderAccRulesService.run(accountId, countryCode, currency, accountType, fundSourceV3)
│
├── 输入: accountId + countryCode + currency + accountType + fundSourceV3
├── 查询可用提供商列表 (按国家+货币+账户类型)
├── 应用优先级规则
│   ├─ 资金来源 (fundSourceV3) 过滤
│   ├─ 账户类型兼容性检查
│   └─ 渠道可用性检查
└── 返回: { provider: GlobalAccountProviderEnum, config: {...} }
```

### 11.6 QB 钱包独立流程

```
QBAccount 账户类型 → applyQbWallet()
├─ 判断 accountType === QBAccount
├─ kyb status ∈ [Passed, AwaitAdditional]
├─ 调用 QB 渠道开户 API
├─ 创建 GlobalAccountCustomer (provider: QB)
├─ 创建 GlobalSubAccount (status: Active)
└─ financeAutoReview() → 理财 KYB 自动通过

注意: QB 钱包跳过提供商匹配规则，直接走独立开户逻辑
```

### 11.7 KYB 自动通过场景

在某些场景下，MultiCurrencyAccount KYB 自动通过，触发自动开户:

```
场景 1: KYC Passed + MultiCurrencyAccount KYB AwaitAdditional
└─ CddKycHook.updateKybAccountTodo()
    └─ KYC 状态为 Passed/CheckAdditional/AwaitAdditional 时
        └─ 自动 Pass MultiCurrencyAccount KYB (isOddSync: true)
            └─ reviewKybStep2() → autoApplyOpenCustomer()

场景 2: AdditionMultiCurrencyAccount KYB 通过
└─ reviewMultiCurrencyKyb()
    └─ 查找 AwaitAdditional 状态的 MultiCurrencyAccount KYB
        └─ 自动审核通过 → autoApplyOpenCustomer()
```

### 11.8 核心文件

| 文件 | 说明 |
|------|------|
| `src/modules/global-account-v2/service/global-account-multiple.service.ts` | 自动开户主服务 (autoApplyOpenCustomer, applyOpenCustomer) |
| `src/modules/global-account-v2/service/global-account-customer.service.ts` | 全球账户客户管理 (创建/更新/查询各渠道客户) |
| `src/modules/global-account-v2/service/global-provider-acc-rules.service.ts` | 提供商匹配规则引擎 |
| `src/entity/bank-account/global-account-customer.ts` | 全球账户客户实体 |
| `src/entity/bank-account/global-sub-account.entity.ts` | 全球子账户实体 |
| `src/common/enum/global-account.enum.ts` | 全球账户枚举 (GlobalSubAccountStatus, GlobalAccountProviderEnum 等) |
