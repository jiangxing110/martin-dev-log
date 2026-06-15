# CRM

## 概述

CRM 系统负责客户关系管理，涵盖线索管理、客户信息维护、跟进记录、推荐码管理、KOL 管理、客户分层等能力。主要面向管理端使用，支持多渠道客户数据整合和客户生命周期管理。

## 整体架构

```
┌──────────────────────────────────────────────────────────────────┐
│                       管理端 (Admin)                               │
│  AdminCrmController → CRM 主管理                                 │
│  AdminCrmReferralCodeController → 推荐码管理                      │
├──────────────────────────────────────────────────────────────────┤
│                     核心服务层                                      │
│  admin/crm/service/ → CRM 服务                                   │
│  admin/crm/domain/ → CRM 领域模型                                │
├──────────────────────────────────────────────────────────────────┤
│                     数据层                                          │
│  CrmCluePool → 线索池                                            │
│  CrmCustomer → 客户信息                                          │
│  CrmFollowRecord → 跟进记录                                      │
│  CrmReferralCode → 推荐码                                        │
├──────────────────────────────────────────────────────────────────┤
│                     枚举体系                                        │
│  CrmSourceEnum → 客户来源                                         │
│  CrmIndustryTypeEnum → 行业类型                                  │
│  CrmFollowTypeEnum → 跟进类型                                    │
│  CrmDegreeEnum → 客户程度                                        │
│  CrmTargetEnum → 客户目标                                        │
│  CrmCluePoolStatusEnum → 线索状态                                │
│  CrmAssociatedTypeEnum → 关联类型                                │
│  CrmGlobalAccountNeedEnum → 全球账户需求                         │
│  CrmContactInformationEnum → 联系方式                             │
│  ContactTypeEnum → 联系人类型                                     │
│  KolReferralCodeStatusEnum → KOL 推荐码状态                      │
│  SaleReferralCodeTypeEnum → 销售推荐码类型                       │
│  ReferralCodeStatusEnum → 推荐码状态                             │
│  BaiduClueSolutionTypeEnum → 百度线索方案                        │
│  CapacityUserTypeEnum → 能力用户类型                              │
└──────────────────────────────────────────────────────────────────┘
```

## 核心实体

| 实体 | 说明 |
|------|------|
| `CrmCluePool` | 线索池（来源、状态、分配人、跟进状态） |
| `CrmCustomer` | 客户信息（基本信息、联系方式、行业、需求） |
| `CrmFollowRecord` | 跟进记录（跟进人、跟进方式、内容、下次跟进时间） |
| `CrmReferralCode` | 推荐码（码值、类型、状态、使用记录） |
| `CrmMonthlyCustomer` | 月度客户统计 |

## 客户来源

| 来源枚举 | 说明 |
|----------|------|
| 百度 | 百度投放线索 |
| KOL | KOL/KOC 推荐 |
| 销售自拓 | 销售自主开发 |
| 推荐码 | 商户推荐 |
| 合作伙伴 | Partner 推荐 |
| 其他 | 其他渠道 |

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `admin/crm/controller/AdminCrmController.java` | CRM 主管理 |
| `admin/crm/controller/AdminCrmReferralCodeController.java` | 推荐码管理 |
| `admin/crm/service/` | CRM 服务 |
| `admin/crm/domain/` | CRM 领域模型 |
| `admin/crm/mapper/` | CRM Mapper |
| `admin/crm/job/` | CRM 定时任务 |
| `admin/crm/crm/` | CRM 枚举（15个） |
| `merchant/analysis/controller/crm/` | 商户端 CRM 分析 |
| `common_all/analysis/service/impl/crm/` | CRM 数据服务 |
| `common_all/assets/service/report/customer/crm/` | CRM 报表 |
