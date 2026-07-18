# Plaid 人脸认证回调流程文档

> 最后更新: 2026-06-11
> 项目: qbitpay-service (NestJS + TypeScript + Plaid API)

---

## 一、整体架构

### 1.1 流程总览

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Plaid 人脸认证全流程                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│ ┌──────────────┐    ┌──────────────────┐    ┌───────────────────┐       │
│ │ generatorUrl │───>│ 创建 Plaid 会话  │───>│ 用户跳转 Plaid    │       │
│ │ ByCdd()      │    │ thirdId=idv_xxx  │    │ 完成证件+活体检测  │       │
│ └──────────────┘    └──────────────────┘    └────────┬──────────┘       │
│                                                      │                   │
│                                                      ▼                   │
│ ┌──────────────────┐    ┌──────────────────┐    ┌──────────────┐        │
│ │ reviewFaceAuth() │<───│ FaceAuthReview   │<───│ Plaid Webhook│        │
│ │ (Queue 消费者)    │    │ Queue(延迟1s)    │    │ POST回调     │        │
│ └──────────────────┘    └──────────────────┘    └──────────────┘        │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 目录结构

```
src/modules/thirdparty/external/plaid/
├── plaid.controller.ts          # REST 入口: POST /plaid/webhook
└── plaid.service.ts             # 核心逻辑: 会话创建、Webhook处理、附件同步

src/modules/cdd/v2/
├── service/face-auth.service.ts  # FaceAuth 业务逻辑(generatorPlaidUrl、reviewFaceAuth)
└── resolver/face-auth.resolver.ts # GraphQL 接口
```

---

## 二、发起 Plaid 认证

### 2.1 入口

发起路径: `FaceAuthResolver.generatorFaceAuthUrl` Mutation
→ `FaceAuthService.generatorUrl()` → `generatorUrlByCdd()` → `generatorPlaidUrl()`

### 2.2 generatorPlaidUrl 方法

**文件**: `face-auth.service.ts:705-770`

```
generatorPlaidUrl(account, faceAuth, kyc, person)
│
├─ 已有第三方会话 (faceAuth.thirdId 已存在)
│   └─ plaidService.getIdentityVerification(thirdId)
│       ├─ 会话状态 active → 自动 retry (重新创建)
│       └─ 会话已完成 → 返回已有 shareable_url
│
├─ 首次创建
│   ├─ 确定平台 (platform):
│   │   ├─ Qbit 国内 → ClientPlatformEnum.Qbit
│   │   ├─ Qbit 国际 → ClientPlatformEnum.iPeakoin
│   │   ├─ CertificateValidate + Qbit → CertificateValidateQbit
│   │   └─ CertificateValidate + iPeakoin → CertificateValidateIPeakoin
│   │
│   ├─ 构建用户信息 (buildIdentityVerificationRequestUser)
│   │   ├─ client_user_id = person.fromId (核心关联字段)
│   │   └─ name, phone, email, address, birthday
│   │
│   ├─ 调用 Plaid API 创建会话
│   │   └─ plaidService.createIdentityVerification(platform, {
│   │       is_shareable: true,
│   │       gave_consent: true,
│   │       user: userObject,
│   │   })
│   │
│   └─ 更新 faceAuth.thirdId = data.id (保存 idv_xxx)
│
└─ 返回 { url: shareable_url, timestamp }
```

### 2.3 buildIdentityVerificationRequestUser

**文件**: `face-auth.service.ts:593-694`

构建 Plaid 用户对象的关键逻辑：

```typescript
const userObject = {
  client_user_id: person?.fromId || kyc.accountId,  // 回调解耦关键字段
};
```

| 字段 | 来源 | 说明 |
|------|------|------|
| `client_user_id` | `person.fromId` | 与 faceAuth.fromId 一致，webhook 回调时用于定位 |
| `name.given_name` | person.name.firstName(En) | Plaid 用户名字 |
| `name.family_name` | person.name.lastName(En) | Plaid 用户姓氏 |
| `phone_number` | person.phone | 手机号 |
| `email_address` | person.email | 邮箱 |
| `address` | 构建的地址对象 | street/city/region/country/postal_code |
| `date_of_birth` | person.birthday | 生日 (YYYY-MM-DD 格式校验) |

### 2.4 平台与模板

**文件**: `plaid.service.ts:77-88`

```typescript
private readonly idVerTemplates: Record<string, string>;
```

Plaid 平台选择逻辑:

```
ClientPlatformEnum
├─ Qbit → Qbit国内模板
├─ iPeakoin → iPeakoin国际模板
├─ CertificateValidateQbit → Qbit 认证模板
├─ CertificateValidateIPeakoin → iPeakoin 认证模板
├─ Physical_Card_Qbit → 实体卡Qbit模板
├─ Physical_Card_IPeakoin → 实体卡iPeakoin模板
└─ Physical_Card_API → API客户模板
```

### 2.5 沙箱环境

非生产环境，Plaid 用户信息会被覆盖为魔法值以跳过真实验证：

```typescript
if (!isProd) {
  user.email_address = 'example@plaid.com';
  user.name = { given_name: 'Knope', family_name: 'Leslie' };
  user.phone_number = '+14155550123';
  if (user.address) user.date_of_birth = '1975-01-18';
}
```

---

## 三、Webhook 回调处理

### 3.1 入口

```
Plaid → POST /plaid/webhook
       → PlaidController.webhook(body, res)
       → PlaidService.webhook(body)
```

**Controller**: `plaid.controller.ts:13-18`

```typescript
@NoAuth()
@Post('webhook')
public async webhook(@Body() body: any, @Res() res: Response) {
  Logger4.log('plaid webhook: ', body);
  await this.service.webhook(body);
  res.status(200).json({ status: 'received' });
}
```

### 3.2 webhook 分发

**文件**: `plaid.service.ts:561-576`

```
webhook(body)
│
├─ 环境检查
│   └─ body.environment !== currentEnvironment → 丢弃
│
├─ 分发 webhook_type
│   └─ IDENTITY_VERIFICATION
│       └─ handleIdVerWebhook(body.webhook_code)
│           ├─ STATUS_UPDATED → updateRecordForIDVSession(body.identity_verification_id)
│           └─ 其他 code → 忽略日志
│
└─ 只处理 IDENTITY_VERIFICATION.STATUS_UPDATED
```

---

## 四、核心回调: updateRecordForIDVSession

**文件**: `plaid.service.ts:329-473`

### 4.1 完整流程图

```
updateRecordForIDVSession(idvSession)
│
├─ [1] 获取 Plaid 会话详情
│   └─ identityVerificationGet({ identity_verification_id: idvSession })
│
├─ [2] 获取 fromId
│   ├─ fromId = data.client_user_id
│   └─ UUID 校验失败 → return
│
├─ [3] 状态映射
│   ├─ success         → BasisStatusEnum.Success
│   ├─ pending_review  → BasisStatusEnum.Fail
│   ├─ failed          → BasisStatusEnum.Fail
│   └─ active/其他     → BasisStatusEnum.Na → return
│
├─ [4] 同步证件附件到 OSS
│   └─ synchronizationFrontAttachment(fromId, documents)
│       ├─ 取最后一份证件 → original_front
│       ├─ 下载到 OSS: /senseId/{fromId}/{timestamp}/front.{ext}
│       └─ 更新 faceAuth.originalFileUrl / originalBackFileUrl
│
├─ [5] 同步活体视频/自拍到 OSS
│   └─ synchronizationFaceVideo(fromId, selfies)
│       ├─ 视频 → OSS: /senseId/{fromId}/{timestamp}/face.mp4
│       │   └─ faceAuth.uploadFileUrl = OSS URL
│       └─ 自拍 → OSS: /senseId/{fromId}/{timestamp}/face.{ext}
│           └─ faceAuth.imageUrl = OSS URL
│
├─ [6] 解析证件信息
│   └─ getIdCardInfo(documents) → { identificationType, issuing_country, id_number, date_of_birth }
│
├─ [7] 查询 FaceAuth 记录
│   └─ faceAuthRepo.findOne({ fromId, isLatest: true })
│       ├─ 不存在 → return
│       └─ 已终态(Success/Rejected) → return
│
├─ [8] 更新 PhysicalCard/User 证件信息
│   └─ recordType ∈ [PhysicalCard, User]
│       └─ 更新 country, type, idNumber, rawData, name
│
├─ [9] CDD 证件不匹配检测
│   └─ status=Success && recordType=Cdd
│       └─ trySendMismatchNotification()
│           └─ 证件与 CDD 登记不一致 → 发送合规机器人通知
│
├─ [10] 失败→成功重置
│    └─ status=Success && record.status=Fail
│        ├─ 直接更新 faceAuth.status = Success
│        └─ notificationCdd() → return
│
└─ [11] 队列异步审核
    └─ Queue: FaceAuthReview (延迟1s)
        └─ faceAuthReviewSubscription() → reviewFaceAuth(robot, payload)
            ├─ 旧记录 isLatest=false
            └─ 新记录 status=Success, userId=robot.id
```

### 4.2 状态映射

| Plaid Session Status | 映射结果 | 行为 |
|---------------------|---------|------|
| `success` | `Success` | 正常通过，继续后续流程 |
| `pending_review` | `Fail` | 待人工审核 → 提示用户重新拍摄 |
| `failed` | `Fail` | 失败 → 提示用户重新拍摄 |
| `active` | `Na` | 会话进行中 → 直接 return |
| `expired` | `Na` | 已过期 → 直接 return |
| `canceled` | `Na` | 已取消 → 直接 return |

### 4.3 边界处理

```
┌─ Na 直接 return ──────────────────────────────────┐
│  Plaid webhook 可能在会话 active 状态就触发回调,      │
│  此时没有有效状态变更，直接跳过不处理。                 │
└──────────────────────────────────────────────────┘

┌─ fromId UUID 校验 ───────────────────────────────┐
│  client_user_id 不是合法 UUID → 非本系统创建，丢弃。  │
└──────────────────────────────────────────────────┘

┌─ 已终态不再修改 ─────────────────────────────────┐
│  faceAuth.status 已是 Success/Rejected → 不允许修改, │
│  防止覆盖审核结果。                                 │
└──────────────────────────────────────────────────┘

┌─ 失败→成功特殊重置 ─────────────────────────────┐
│  管理员在 Plaid 后台手动重置人脸状态后，              │
│  新成功回调可直接更新（跳过审核队列）。               │
└──────────────────────────────────────────────────┘
```

---

## 五、附件同步

### 5.1 synchronizationFrontAttachment

**文件**: `plaid.service.ts:129-161`

```
synchronizationFrontAttachment(fromId, documents)
│
├─ 取最后一份证件文档的 original_front URL
├─ 下载到 OSS: /senseId/{fromId}/{YYYYMMDDHHmmss}/front.{ext}
├─ 有背面照 → OSS: /senseId/{fromId}/{YYYYMMDDHHmmss}/back.{ext}
├─ 更新 faceAuth { fromId, isLatest: true }
│   ├─ originalFileUrl = OSS 正面照
│   └─ originalBackFileUrl = OSS 背面照
└─ 这是 Plaid 平台上的证件照片，非用户上传
```

### 5.2 synchronizationFaceVideo

**文件**: `plaid.service.ts:170-204`

```
synchronizationFaceVideo(fromId, selfies)
│
├─ 取最后一份活体记录
├─ 有视频 → OSS: /senseId/{fromId}/{timestamp}/face.mp4
│   └─ faceAuth.uploadFileUrl
├─ 有自拍(无视频降级) → OSS: /senseId/{fromId}/{timestamp}/face.{ext}
│   └─ faceAuth.imageUrl
└─ 更新 faceAuth { fromId, isLatest: true }
```

---

## 六、证件不匹配检测

**文件**: `plaid.service.ts:278-322`

### 6.1 比对流程

```
trySendMismatchNotification(record, documents)
│
├─ 取 Plaid 证件信息: category, id_number, issuing_country
├─ 查 CDD 人员信息: getPerson(accountId, recordId, fromId)
│   └─ person.identification.type + number
├─ 比对
│   ├─ 一致 → return
│   └─ 不一致 → 发送合规机器人通知
│       ├─ 模板: Common_Robot_Notice
│       └─ 内容: "主体名称：{name}, 人脸识别证件ID与CDD证件ID不一致"
└─ 仅对 recordType === Cdd 执行
```

### 6.2 证件类型映射 (convertIdType)

**文件**: `plaid.service.ts:255-270`

| Plaid 证件类型 | 国家 | 系统类型 |
|---------------|------|---------|
| `DriversLicense` | US | `USDLN` |
| `DriversLicense` | CA | `CADLN` |
| `Passport` | 任意 | `PASSPORT` |
| 其他 | 任意 | `UNKNID` |

### 6.3 证件信息解析 (getIdCardInfo)

**文件**: `plaid.service.ts:493-536`

| Document Category | 国家 | 系统类型 |
|------------------|------|---------|
| `Passport` | 任意 | `PASSPORT` |
| `IdCard` | CN | `CNRIC` |
| `IdCard` | HK | `HKHKID` |
| `IdCard` | SG | `SGNRIC` |
| `IdCard` | MY | `MYNRIC` |
| `IdCard` | US | `USNRIC` |
| `IdCard` | CA | `CANRIC` |
| `DriversLicense` | US | `USDLN` |
| `DriversLicense` | CA | `CADLN` |
| `DriversLicense` | 其他 | `DLN` |
| `ResidencePermitCard` | 任意 | `GovernmentIssuedIDCard` |
| `ResidentCard` | 任意 | `GovernmentIssuedIDCard` |

---

## 七、队列异步审核

### 7.1 FaceAuthReview Queue

**发布者**: `PlaidService.updateRecordForIDVSession`

```typescript
// plaid.service.ts:448-465
this.queueService.addQueue(QueueProcessEnum.FaceAuthReview, {
  fromId,       // person.fromId
  accountId,    // 账户 ID
  kyCaseId,     // KyCase ID (CDD/ODD 区分在此)
  message,      // 错误提示 (成功="" / 失败="识别有误,请重新拍摄")
  code,         // 成功=0 / 失败=10100
  status,       // Success / Fail
}, { delay: 1000 });
```

**消费者**: `FaceAuthService.faceAuthReviewSubscription`

```typescript
// face-auth.service.ts:1256-1261
@QueueSubscriber(QueueProcessEnum.FaceAuthReview)
async faceAuthReviewSubscription({ data }) {
  const payload = data.data;
  const robot = await this.robotService.getQbitRobot();
  await this.reviewFaceAuth(robot, payload);
}
```

### 7.2 reviewFaceAuth 审核方法

**文件**: `face-auth.service.ts:405-557`

```
reviewFaceAuth(user, data)
│
├─ 校验
│   ├─ status ∈ [Success, Fail]
│   └─ faceAuth 当前状态 ∉ [Success, Fail] (防止重复)
│
├─ 更新记录
│   ├─ 旧记录 isLatest=false
│   └─ 新记录: status, userId, isLatest=true
│
├─ recordType === Cdd ─────────────────────
│   ├─ 更新 kyCase.customerUpdateTime
│   ├─ 检查 BusinessOdd 全部通过 → 触发待办
│   └─ WebSocket (topic: face_auth)
│
├─ recordType === PhysicalCard ────────────
│   ├─ 解析身份证信息
│   ├─ WebSocket (topic: physical_card_face_auth)
│   └─ API来源 → Queue: PhysicalCardIdentity
│
└─ recordType === User ────────────────────
    ├─ 解析用户信息
    └─ WebSocket (topic: user_face_auth)
```

---

## 八、数据库更新

### 8.1 faceAuth 表变更

```
阶段1: 会话创建
  id: xxx, thirdId: null, fromId: yyy, status: Na, isLatest: true
  ↓
  id: xxx, thirdId: idv_abc123, fromId: yyy, status: Na, isLatest: true
  (update: thirdId)

阶段2: Plaid 回调 - 附件同步
  UPDATE faceAuth SET originalFileUrl=..., uploadFileUrl=..., imageUrl=...
  WHERE fromId=yyy AND isLatest=true

阶段3: 审核通过 (reviewFaceAuth)
  UPDATE faceAuth SET isLatest=false WHERE id=old_id
  INSERT faceAuth (new_id, fromId, status=Success, isLatest=true, userId=robotId, ...)
```

### 8.2 字段映射

| Plaid 数据 | FaceAuth 字段 | 更新时机 |
|-----------|--------------|---------|
| session.id | `thirdId` | 创建会话时 |
| documents[].original_front | `originalFileUrl` | Webhook 回调 |
| documents[].original_back | `originalBackFileUrl` | Webhook 回调 |
| selfie_check.video_url | `uploadFileUrl` | Webhook 回调 |
| selfie_check.image_url | `imageUrl` | Webhook 回调 |
| extracted_data | `rawData.idCardInfo` | PhysicalCard/User 类型 |
| user info | `rawData.threeUserInfo` | PhysicalCard/User 类型 |
| — | `status = Success` | reviewFaceAuth 执行 |

---

## 九、完整时序

```
T0   generatorFaceAuthUrl
     │
     ├─ 校验 faceAuth.status ∈ [Fail, Na]
     ├─ Plaid createIdentityVerification()
     └─ faceAuth.thirdId = idv_xxx
     │
T1   用户跳转 Plaid，完成证件上传 + 活体检测
     │
T2   POST /plaid/webhook (STATUS_UPDATED)
     │
     ├─ [环境检查] → 通过
     ├─ [状态映射] success → BasisStatusEnum.Success
     ├─ [附件同步] originalFileUrl / uploadFileUrl
     ├─ [查 FaceAuth] { fromId, isLatest: true } → 找到
     ├─ [不匹配检测] 通过
     └─ [队列] FaceAuthReview (延迟1s)
     │
T3   队列消费
     │
     ├─ reviewFaceAuth(robot, payload)
     ├─ 旧记录 isLatest=false
     ├─ 新记录 status=Success
     └─ WebSocket → 前端
     │
T4   前端收到 face_auth 通知 → 刷新 UI
```

---

## 十、配置文件

```typescript
// ConfigService.get('plaid')
{
  environment: 'sandbox' | 'production',
  clientId: '<plaid-client-id>',
  secret: '<plaid-secret>',
  dashboard: 'https://dashboard.plaid.com',
  idVerTemplates: {
    [ClientPlatformEnum.Qbit]: 'idvtmp_xxx',
    [ClientPlatformEnum.iPeakoin]: 'idvtmp_xxx',
    [ClientPlatformEnum.CertificateValidateQbit]: 'idvtmp_xxx',
    [ClientPlatformEnum.CertificateValidateIPeakoin]: 'idvtmp_xxx',
    [ClientPlatformEnum.Physical_Card_Qbit]: 'idvtmp_xxx',
    [ClientPlatformEnum.Physical_Card_IPeakoin]: 'idvtmp_xxx',
    [ClientPlatformEnum.Physical_Card_API]: 'idvtmp_xxx',
  }
}
```

---

## 十一、关键文件索引

| 文件 | 行数 | 关键方法 |
|------|------|---------|
| `src/modules/thirdparty/external/plaid/plaid.service.ts` | 640 | `webhook()`, `handleIdVerWebhook()`, `updateRecordForIDVSession()`, `synchronizationFrontAttachment()`, `synchronizationFaceVideo()`, `trySendMismatchNotification()`, `createIdentityVerification()` |
| `src/modules/thirdparty/external/plaid/plaid.controller.ts` | 19 | `POST /plaid/webhook` |
| `src/modules/cdd/v2/service/face-auth.service.ts` | 1277 | `generatorPlaidUrl()`, `buildIdentityVerificationRequestUser()`, `reviewFaceAuth()` |
| `src/entity/cdd/face-auth.entity.ts` | — | FaceAuth 实体定义 |

---

## 十二、常见排查

### Q: 回调收到但状态没更新？

| 原因 | 代码位置 | 表现 |
|------|---------|------|
| Plaid 会话尚在 active | 第 386-388 行 Na return | webhook 日志有记录，faceAuth 无变化 |
| 记录已终态 | 第 399-401 行 Success/Rejected return | 之前已被审核或回调处理过 |
| fromId 不是 UUID | 第 337-340 行 return | client_user_id 格式异常 |
| 环境不匹配 | 第 562-564 行 丢弃 | body.environment !== 配置 |

### Q: CDD 和 ODD 的回调独立吗？

独立。CDD 和 ODD 有不同的 `CddBusinessPerson.fromId` 和 `CddKyCase.id`，Plaid 会话 `client_user_id` 不同，互不干扰。

### Q: 如何手动查 Plaid 会话状态？

通过 `plaidService.getIdentityVerification(thirdId)` 查询, 或调 `identityVerificationGet` API 查看 `data.status`。
