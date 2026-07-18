# 合规体系

## 概述

合规体系是 Qbit 的合规管理基础设施，涵盖 CDD（客户尽职调查）、EDD（增强尽职调查）、风险引擎、合规筛查等能力。系统对接多种外部合规数据源，实现商户准入审核、持续监控、风险评级等合规流程自动化。

## 整体架构

```
┌──────────────────────────────────────────────────────────────────┐
│                     核心模块                                        │
│  CDD (客户尽职调查) → 基础 KYC/KYB                                │
│  EDD (增强尽职调查) → 高风险客户额外审核                          │
│  Engine (合规引擎) → 规则驱动的合规判定                           │
│  Risk (合规风险) → 风险评级与筛查                                 │
├──────────────────────────────────────────────────────────────────┤
│                     管理端                                          │
│  AdminGlobalAccountCddKybController → CDD/KYB 审核               │
│  AdminGlobalAccountEddController → EDD 管理                       │
├──────────────────────────────────────────────────────────────────┤
│                     定时任务                                        │
│  job/compliance/ → 合规定时任务                                   │
│    定期筛查、风险重评、到期提醒                                   │
├──────────────────────────────────────────────────────────────────┤
│                     三方集成                                        │
│  合规数据源 → 外部 KYC/KYB 服务                                   │
│  制裁名单 → OFAC/UN 等制裁名单筛查                                │
│  PEP 名单 → 政治人物筛查                                          │
└──────────────────────────────────────────────────────────────────┘
```

## 核心模块

### CDD（客户尽职调查）

| 组件 | 说明 |
|------|------|
| `common_all/compliance/cdd/entity/` | CDD 实体 |
| `common_all/compliance/cdd/mapper/` | CDD Mapper |
| `common_all/compliance/cdd/service/` | CDD 服务 |

**CDD 流程：**
```
商户提交资料
    ↓
身份验证 (KYC)
    ↓
企业验证 (KYB)
    ↓
制裁名单筛查
    ↓
PEP 筛查
    ↓
CDD 审核完成
```

### EDD（增强尽职调查）

| 组件 | 说明 |
|------|------|
| `common_all/compliance/edd/domain/` | EDD 领域模型 |
| `common_all/compliance/edd/entity/` | EDD 实体 |
| `common_all/compliance/edd/mapper/` | EDD Mapper |
| `common_all/compliance/edd/service/` | EDD 服务 |

**EDD 触发条件：**
- 高风险行业（虚拟货币、跨境支付等）
- 高风险司法管辖区
- 大额交易
- 复杂股权结构
- 政治人物（PEP）

**EDD 流程：**
```
触发 EDD
    ↓
收集额外资料（资金来源、业务说明、股权结构等）
    ↓
Admin 人工审核
    ↓
EDD 记录归档
```

### Engine（合规引擎）

| 组件 | 说明 |
|------|------|
| `common_all/compliance/engine/domain/` | 引擎领域模型 |
| `common_all/compliance/engine/mapper/` | 引擎 Mapper |

### Risk（合规风险）

| 组件 | 说明 |
|------|------|
| `common_all/compliance/risk/` | 合规风险管理 |

## 核心实体

| 实体 | 说明 |
|------|------|
| `CddRecord` | CDD 审核记录 |
| `KycInfo` | KYC 信息 |
| `KybInfo` | KYB 信息 |
| `EddRecord` | EDD 审核记录 |
| `EddRecordDetail` | EDD 记录详情 |
| `ScreeningResult` | 筛查结果 |
| `RiskAssessment` | 风险评估 |
| `ComplianceCase` | 合规工单 |

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `common_all/compliance/cdd/entity/` | CDD 实体 |
| `common_all/compliance/cdd/mapper/` | CDD Mapper |
| `common_all/compliance/cdd/service/` | CDD 服务 |
| `common_all/compliance/edd/domain/` | EDD 领域模型 |
| `common_all/compliance/edd/entity/` | EDD 实体 |
| `common_all/compliance/edd/mapper/` | EDD Mapper |
| `common_all/compliance/edd/service/` | EDD 服务 |
| `common_all/compliance/engine/domain/` | 合规引擎领域模型 |
| `common_all/compliance/engine/mapper/` | 合规引擎数据层 |
| `common_all/compliance/risk/` | 合规风险 |
| `admin/globalaccount/controller/AdminGlobalAccountCddKybController.java` | CDD/KYB 审核 |
| `admin/globalaccount/controller/AdminGlobalAccountEddController.java` | EDD 管理 |
| `common_all/globalaccount/service/GlobalCddKybService.java` | CDD/KYB 服务 |
| `job/compliance/` | 合规定时任务 |
| `merchant/blockchain/compliance/` | 区块链合规 |
