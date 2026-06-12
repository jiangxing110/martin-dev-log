# 风险评级 & 名单筛查技术文档

> 最后更新: 2026-06-11
> 项目: qbitpay-service (NestJS + TypeScript + TypeORM + World-Check)

---

## 一、风险评级 (Risk Rating)

### 1.1 概述

风险评级是对商户账户进行风险量化评估的系统，结果直接影响：
- **ODD 账户审查周期** (High=6月, Middle=12月, Low=24月)
- **EDD 强化尽职调查** 触发条件

| 评级维度 | 说明 |
|---------|------|
| 实体 | `CddRiskRating` (表: `cddRiskRating`) |
| 评分方式 | V2: OptionScoreMap (本地), V3: Java Drools 规则引擎 |
| 源类型 | `sourceType`: Cdd (首次), Odd (审查周期) |

### 1.2 实体定义

**文件**: `src/entity/cdd/cdd-risk-rating.entity.ts`

| 字段 | 类型 | 说明 |
|------|------|------|
| `accountId` | UUID | 被评级的账户 ID |
| `sourceId` | UUID | 源 ID (关联 kyCaseId) |
| `sourceType` | Enum | `CddRiskRatingSourceTypeEnum.Cdd / Odd` |
| `accountRiskLevel` | Enum | `RiskLevelEnum.High / Middle / Low` — 最终风险等级 |
| `scoreJson` | JSON | 评分明细 (各维度分数) |
| `registryCountry` | Enum | 注册国家 |
| `entityType` | string | 公司主体类型 |
| `businessType` | string | 业务类型 |
| `directorNationality` | Enum | 董事/法人国籍风险等级 |
| `UBONationality` | Enum | UBO 国籍风险等级 |
| `directorAge` | Enum | 董事年龄区间 |
| `identityProofType` | Enum | 身份证明文件类型 |
| `scale` | Enum | 公司规模 |
| `registryTime` | Enum | 成立时间 |
| `workplace` | Enum | 办公场所 |
| `product` | Enum | 产品风险等级 (取最高风险产品) |
| `businessOperationCountry` | Enum | 业务面向国家风险等级 |
| `industry` | Enum | 行业风险等级 (Admin 填写) |
| `ownershipTransparency` | Enum | 股权透明度 (Admin 填写) |
| `PEPRelated` | bool | 是否 PEP (政治公众人物) |
| `negativeNews` | Enum | 负面新闻 |
| `individualNegativeNews` | Enum | 个人负面新闻 |
| `businessScene` | string | 业务场景/职业状态 |
| `nationality` | Enum | 国籍风险级别 |
| `attachments` | JSON | 附件列表 |
| `comment` | string | 备注 |

### 1.3 OptionScoreMap 评分引擎 (V2)

**文件**: `src/modules/cdd/risk-rating/risk-rating-helper.ts`

评分引擎基于 `Map<Element, Map<Option, Score>>` 结构，每个维度独立评分后加权求和：

```
总风险分数 = Σ(选项分数 × 权重)
```

#### 评分维度与权重

| 维度 | 权重 | 核心逻辑 |
|------|------|---------|
| `registryCountry` (注册国家) | 0.1 | HK=20, CN=10, US/GB/SG=50, KY=60, default=60 |
| `person_nationality` (人员国籍) | 1 | High=80, Middle=40, Low=10, default=40 |
| `entityType` (公司类型) | 0.15 | 每种实体类型有独立分数 (LLC=20, Corporation=10, 个体工商户=50...) |
| `scale` (公司规模) | 0.05 | 按员工数分级评分 |
| `directorAge` (董事年龄) | 0.05 | 按年龄区间评分 |
| `identityProofType` (证件类型) | 0.1 | 按证件类型评分 |
| `workplace` (办公场所) | 0.05 | 自有/租赁/居家等 |
| `businessOperationCountry` (业务面向国家) | 0.1 | 按目标国家风险等级 |
| `registryTime` (成立时间) | 0.2 | 成立越久分数越低 |
| `product` (产品类型) | 0.2 | 按产品风险等级 |
| `industry` (行业) | Admin 评分 | 由 Admin 在管理后台评定 |
| `ownershipTransparency` (股权透明度) | Admin 评分 | 由 Admin 在管理后台评定 |
| `negativeNews` (负面新闻) | Admin 评分 | 由 Admin 在管理后台评定 |
| `PEPRelated` (PEP) | Admin 评分 | 由 Admin 在管理后台评定 |

**分数 → 等级映射** (在 `DataToRiskLevel` 中定义):

```
分数区间 → 风险等级
[0, 30)   → Low
[30, 60)  → Middle
[60, +∞)  → High
```

#### 评分过程

```
ratingRaskV3(cddRiskRating, accountExtend, bridgeService)
├── 读取各字段值 → OptionScoreMap 查询分数
├── 人员评分: 取 directorNationality + UBONationality 两者最高分
├── 产品评分: 取所有产品中的最高风险等级
├── 加权求和
├── DataToRiskLevel 映射等级
└── 返回 RiskScoreAndElementLevel { score, level, elements }
```

### 1.4 V3 Java Drools 评分

V3 版本通过 Java 端 Drools 规则引擎执行，由 `bridgeService` 调用:

```
ratingRaskV3()
└── bridgeService 调用 Java 侧 Drools 规则引擎
    └── 返回评分结果 (与 V2 互补)
```

V2 和 V3 的执行路径在 `getRiskScore()` 方法中统一管理:

```typescript
public async getRiskScore(param: CddRiskRating): Promise<RiskScoreAndElementLevel> {
    const accountExtend = await this.accountExtendRepo.findOneOrFail({ accountId: param.accountId });
    return await this.optionScoreMap.ratingRaskV3(param, accountExtend, this.bridgeService);
}
```

### 1.5 风险评级触发时机

```
┌─────────────────────────────────────────────────────────────────┐
│ 风险评级触发场景                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. KYC 创建时:                                                  │
│     createKycExecute() → autoRiskRating()                        │
│                                                                 │
│  2. KYB 审核时:                                                  │
│     reviewKybStep2() → autoRiskRating(cddKyb)                    │
│     └─ 当 KYB MultiCurrencyAccount 通过时触发自动评级              │
│                                                                 │
│  3. ODD 账户审查创建时:                                           │
│     OddAccountReviewHook → 同步 CddRiskRating (sourceType: Odd)  │
│                                                                 │
│  4. 管理员手动:                                                   │
│     RiskRatingResolver.setRiskLevel() → 管理员界面手动评级         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.6 风险评级与 EDD 联动

```
CddRiskRating 创建/更新
└─ CddRiskRatingHook.afterInsertHandle / afterUpdateHandle
    └─ EddCaseService.createEddCaseByCddRiskRating(entity)
        └─ 根据风险等级触发 EDD 强化尽职调查案件
```

### 1.7 核心文件

| 文件 | 行数 (约) | 说明 |
|------|----------|------|
| `src/modules/cdd/risk-rating/risk-rating.service.ts` | — | 风险评级业务逻辑 |
| `src/modules/cdd/risk-rating/risk-rating-helper.ts` | ~500 | OptionScoreMap 评分引擎 + DataToRiskLevel 映射 |
| `src/modules/cdd/risk-rating/risk-rating.dto.ts` | — | DTO 定义 |
| `src/modules/cdd/risk-rating/risk-rating.dao.ts` | — | DAO 数据访问层 |
| `src/entity/cdd/cdd-risk-rating.entity.ts` | 175 | 实体定义 |
| `src/modules/edd/edd-case.service.ts` | — | EDD 案件管理 (由风险评级触发) |

---

## 二、名单筛查 (Names Screening)

### 2.1 概述

名单筛查 (Names Screening) 集成 **World-Check** (全球知名 AML 制裁名单数据库)，在商户入驻及持续监控过程中对商户及其关联人进行反洗钱筛查。

| 维度 | 说明 |
|------|------|
| 集成系统 | World-Check (通过 qbit-aml-module 中间层) |
| 筛查范围 | 企业名称 + 董事/股东/UBO/授权人 |
| 筛查时机 | Onboarding (入驻), PeriodicalReview (ODD 审查), OngoingDD (回溯) |
| 审核流程 | L1 初审 → L2 复审 (二段式审核) |
| 实体 | `NamesScreeningCase`, `NamesScreeningAlert` |

### 2.2 筛查触发时机

```
┌─────────────────────────────────────────────────────────────────┐
│ 名单筛查触发场景                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Business KYC 创建时:                                         │
│     createKycExecute()
│     └─ businessKycNamesScreening(personList, businessDetail)     │
│         └─ triggerReason: Onboarding                             │
│                                                                 │
│  2. Individual/Personal KYC 创建时:                              │
│     createKycExecute() → individualKycNamesScreening()           │
│         └─ triggerReason: Onboarding                             │
│                                                                 │
│  3. ODD 审查期间 KYB 创建时:                                      │
│     KybV2Service → namesScreening (对应 BusinessOdd KYC)         │
│         └─ triggerReason: PeriodicalReview                       │
│                                                                 │
│  4. 回溯性筛查 (定时任务):                                        │
│     Queue: BacktrackingScreening                                 │
│     └─ 重新筛查已有已通过商户                                      │
│         └─ triggerReason: OngoingDD                              │
│                                                                 │
│  5. LiteKyb 专用筛查:                                             │
│     liteKybNamesScreening()                                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.3 筛查流程

```
Names Screening 发起
│
├── Business KYC 名单筛查
│   ├─ 企业主体名称 → NamesScreeningCase 创建
│   │   ├─ subjectType: Company
│   │   └─ 调用 World-Check API 查询
│   │
│   ├─ 董事/股东/UBO 个人 → NamesScreeningCase 创建
│   │   ├─ subjectType: Person
│   │   ├─ 姓名 + 出生日期 + 国籍
│   │   └─ 调用 World-Check API 查询
│   │
│   └─ L1 初审结果
│       ├─ 无命中 (NoHit) → 自动通过
│       ├─ 白名单 → 自动通过
│       ├─ L1强命中 → L2 复审
│       └─ L2 结果:
│           ├─ 确认命中 (Confirmed) → 标记黑名单
│           └─ 误报 (FalsePositive) → 豁免(Immunity)记录
│
├── Individual KYC 名单筛查
│   ├─ 个人实名信息 → World-Check 查询
│   └─ 同上 L1/L2 审核
│
└── 回溯性筛查
    ├─ 凌晨定时任务: backtrackingScreening()
    ├─ 从 Java 侧获取已通过 KYC 列表
    └─ 逐个入队列: BacktrackingScreening → 重新跑筛查
```

### 2.4 实体定义

#### NamesScreeningCase (筛查案件)

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 主键 |
| `accountId` | UUID | 账户 ID |
| `kyCaseId` | UUID | 关联 CDD Case |
| `kycId` | UUID | 关联 KYC |
| `recordType` | Enum | `BusinessKyc`, `PersonalKyc`, `IndividualKyc`, `PhysicalCard` 等 |
| `subjectType` | Enum | `Company`, `Person` |
| `subjectName` | string | 主体名称 |
| `subjectNameEn` | string | 主体英文名称 |
| `triggerReason` | Enum | `Onboarding`, `PeriodicalReview`, `OngoingDD` |
| `caseStatus` | Enum | `L1Review`, `L2Review`, `Closed`, `AwaitingCustomerSubmission` 等 |
| `tags` | JSON | 标签 (命中类型) |
| `threeId` | string | World-Check 三方案件 ID |
| `reviewResult` | Enum | `NoHit`, `Confirmed`, `FalsePositive` 等 |
| `isShow` | bool | 是否显示 |

#### NamesScreeningAlert (筛查告警)

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | UUID | 主键 |
| `namesScreeningCaseId` | UUID | 关联筛查案件 |
| `uid` | int | World-Check Alert UID |
| `referenceId` | string | World-Check 引用 ID |
| `systemResult` | Enum | 系统命中结果 |
| `manualResult` | Enum | 人工审核结果 |
| `matchedName` | string | 匹配的名称 |

### 2.5 L1/L2 审核流程

```
筛查结果命中
│
├── L1Review (初审)
│   ├─ 合规人员查看 World-Check 原始数据
│   ├─ 判断是否为真实命中
│   │   ├─ 误报 → 标记 FalsePositive → 记录豁免 (Immunity)
│   │   └─ 疑似命中 → L2Review
│   │
│   └─ L1Review2 (补充初审)
│       └─ 初次初审需要补材料时
│
├── L2Review (复审)
│   ├─ 高级合规人员二段审核
│   ├─ 确认命中 → Confirmed
│   │   └─ 标记黑名单 → 账户拒绝/冻结
│   └─ 误报 → FalsePositive
│
├── AwaitingCustomerSubmission (待客户补充)
│   └─ 需要客户提供解释材料
│
└── Closed (已关闭)
    └─ 最终结果: NoHit / Confirmed / FalsePositive
```

### 2.6 回溯性筛查 (Backtracking Screening)

**文件**: `src/modules/cdd/cdd.queue.service.ts`

```
backtrackingScreening() (定时任务)
│
├── 从 Java 侧 /admin/core/cdd/kyc/list 获取已通过 KYC
│   ├─ kycStatus: Passed
│   ├─ 筛选 Business/Individual/Personal 类型
│   └─ accountStatus: Active/Readonly/Control
│
├── Queue: BacktrackingScreening
│   └── backtrackingScreeningProcess(queue)
│       ├── kycType === Individual
│       │   └─ individualKycNamesScreening(kyc)
│       ├── kycType === Personal
│       │   └─ individualKycNamesScreening(kyc)
│       └── kycType === Business / Employee
│           └─ businessKycNamesScreening(kyCaseId)
│
└── 筛查时间范围: 2024-09-19 之后的已通过记录会被跳过
```

### 2.7 豁免列表 (Immunity)

当筛查结果被确认为误报 (FalsePositive) 后，记录会进入豁免列表:

**文件**: `src/modules/names-screening/names-screening-immunity.service.ts`

- 同一主体再次筛查时自动跳过
- 避免重复告警

### 2.8 核心文件

| 文件 | 行数 (约) | 说明 |
|------|----------|------|
| `src/modules/names-screening/names-screening.service.ts` | ~1800 | 名单筛查主服务 (筛查发起、Case/Alert 管理、审核) |
| `src/modules/names-screening/names-screening.dto.ts` | ~1900 | DTO 定义 (输入/输出、World-Check 接口模型) |
| `src/modules/names-screening/names-screening-immunity.service.ts` | — | 豁免列表管理 |
| `src/modules/cdd/cdd.queue.service.ts` | — | 回溯筛查队列处理器 |
| `src/entity/names-screening/names-screening-case.entity.ts` | — | 筛查案件实体 |
| `src/entity/names-screening/names-screening.alert.entity.ts` | — | 筛查告警实体 |
| `src/common/enum/names-screening.enum.ts` | — | 筛查枚举 (CaseStatusEnum, HitTypeEnum, ReviewResultEnum 等) |

---

## 三、风险评级 & 名单筛查联动

### 3.1 KYC 创建时的双流程

```
createKycExecute()
├── autoRiskRating()              ← 风险评级
│   └─ 计算风险分数，写入 CddRiskRating
│
└── businessKycNamesScreening()   ← 名单筛查 (异步)
    └─ 发起 World-Check 查询，创建 NamesScreeningCase
```

### 3.2 KYB 审核时的联动

```
reviewKybStep2()
├── globalAccountMultipleService.autoApplyOpenCustomer()  ← 自动开户
├── autoRiskRating(cddKyb)                               ← 重新评级
└── KybNotice()                                          ← 通知
```

### 3.3 ODD 审查周期中的联动

```
ODD 账户审查创建
│
├── OddAccountReviewHook
│   ├─ 创建 BusinessOdd KYC
│   ├─ 复制 CddBusinessPerson
│   ├─ 创建 Odd 后缀 KYB
│   └─ 同步 CddRiskRating (sourceType: Odd)
│
└── 审查过程中
    ├─ 如果有新 FaceAuth → 更新状态
    └─ 审查完成 → syncKycAndKybByOdd()
```

### 3.4 全量核心文件

| 文件 | 说明 |
|------|------|
| `src/modules/cdd/risk-rating/risk-rating.service.ts` | 风险评级主服务 |
| `src/modules/cdd/risk-rating/risk-rating-helper.ts` | OptionScoreMap 评分引擎 |
| `src/modules/cdd/risk-rating/risk-rating.dto.ts` | 风险评级 DTO |
| `src/modules/cdd/risk-rating/risk-rating.dao.ts` | 风险评级 DAO |
| `src/modules/names-screening/names-screening.service.ts` | 名单筛查主服务 |
| `src/modules/names-screening/names-screening.dto.ts` | 名单筛查 DTO |
| `src/modules/names-screening/names-screening-immunity.service.ts` | 豁免列表 |
| `src/modules/cdd/cdd.queue.service.ts` | 回溯筛查队列 |
| `src/modules/edd/edd-case.service.ts` | EDD 案件管理 |
| `src/modules/event-subscriber-register/cdd-risk-rating.hook.ts` | 风险评级 Hook → EDD |
| `src/entity/cdd/cdd-risk-rating.entity.ts` | 风险评级实体 |
| `src/entity/names-screening/names-screening-case.entity.ts` | 筛查案件实体 |
| `src/entity/names-screening/names-screening.alert.entity.ts` | 筛查告警实体 |
| `src/common/enum/cdd.enum.ts` | CDD 枚举 (含风险评级字段) |
| `src/common/enum/names-screening.enum.ts` | 筛查枚举 |
