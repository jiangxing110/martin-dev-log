# 融资体系

## 概述

融资体系（粒子理财）是 Qbit 的供应链金融服务模块，为商户提供基于应收账款的融资、理财和资金管理能力。系统分 V1 和 V2 两套版本，支持融资申请、审核、放款、还款、利息计算等全流程管理。

## 整体架构

```
┌──────────────────────────────────────────────────────────────────┐
│                       管理端 (Admin)                               │
│  FinancingV1 / FinancingV2 → 融资管理                             │
│    审核、放款、还款、查询                                          │
├──────────────────────────────────────────────────────────────────┤
│                       商户端 (Merchant)                            │
│  FinancingV1 / FinancingV2 → 融资申请                              │
│    额度查询、融资申请、还款                                        │
├──────────────────────────────────────────────────────────────────┤
│                     核心服务层                                      │
│  FinancingService → V1 融资服务                                    │
│  FinancingV2Service → V2 融资服务                                  │
│  FinancingCalculator → 利息计算器                                  │
│  FinancingRiskAssessment → 风控评估                                │
├──────────────────────────────────────────────────────────────────┤
│                     数据层                                          │
│  FinancingOrder → 融资订单                                        │
│  FinancingRepayment → 还款记录                                    │
│  FinancingCredit → 授信额度                                       │
│  FinancingProduct → 融资产品                                      │
└──────────────────────────────────────────────────────────────────┘
```

## 版本对比

| 维度 | V1 | V2 |
|------|----|----|
| 定位 | 基础融资 | 增强融资 |
| 实体 | `financing/v1/` | `financing/v2/` |
| 服务 | `financing/v1/` | `financing/v2/` |
| 流程 | 基础申请审核 | 增强审批流程 |
| 风控 | 基础风控 | 多维风控评估 |

## 融资流程

```
商户提交融资申请
    ↓
FinancingRiskAssessment 风控评估
    ↓
Admin 审核
    ↓
放款 (Disbursement)
    ↓
利息计算 (FinancingCalculator)
    ↓
还款 (Repayment)
    ↓
结清
```

## 核心实体

| 实体 | 说明 |
|------|------|
| `FinancingOrder` | 融资订单（金额、期限、利率、状态） |
| `FinancingRepayment` | 还款计划（期数、应还金额、实还金额、状态） |
| `FinancingCredit` | 授信额度（总额度、已用额度、可用额度） |
| `FinancingProduct` | 融资产品（利率、期限、费率配置） |
| `FinancingCollateral` | 质押物信息 |

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `common_all/financing/v1/` | 融资 V1 公共模块 |
| `common_all/financing/v2/` | 融资 V2 公共模块 |
| `merchant/financing/v1/` | 商户端融资 V1 |
| `merchant/financing/v2/` | 商户端融资 V2 |
| `admin/financing/v1/` | 管理端融资 V1 |
| `admin/financing/v2/` | 管理端融资 V2 |
| `common_all/analysis/service/ParticleFinanceStatisticsService.java` | 融资统计 |
