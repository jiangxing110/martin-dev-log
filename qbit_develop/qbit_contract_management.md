# 合同管理

## 概述

合同管理系统负责商户合同的创建、审批、签署、归档全生命周期管理，支持合同模板管理、合同信息维护、电子签署、到期提醒等功能。覆盖管理端和商户端两种视角。

## 整体架构

```
┌──────────────────────────────────────────────────────────────────┐
│                       管理端 (Admin)                               │
│  ContractApplyAdminController → 合同申请管理                      │
│  ContractInfoAdminController → 合同信息管理                       │
│  ContractTemplateAdminController → 合同模板管理                   │
├──────────────────────────────────────────────────────────────────┤
│                       商户端 (Merchant)                            │
│  merchant/contract/ → 商户合同管理                                │
├──────────────────────────────────────────────────────────────────┤
│                     核心服务层                                      │
│  common_all/contract/service/ → 合同服务                          │
│  common_all/contract/manager/ → 合同管理器                        │
│  common_all/contract/mapper/ → 合同 Mapper                        │
├──────────────────────────────────────────────────────────────────┤
│                     数据层                                          │
│  ContractInfo → 合同信息                                          │
│  ContractApply → 合同申请                                         │
│  ContractTemplate → 合同模板                                      │
│  ContractSign → 合同签署                                          │
└──────────────────────────────────────────────────────────────────┘
```

## 核心实体

| 实体 | 说明 |
|------|------|
| `ContractInfo` | 合同信息（编号、名称、类型、状态、有效期、金额） |
| `ContractApply` | 合同申请（申请人、审核人、申请状态） |
| `ContractTemplate` | 合同模板（模板名称、内容模板、适用场景） |
| `ContractSign` | 合同签署记录（签署方、签署时间、签署方式） |

## 合同生命周期

```
创建合同 (ContractApply)
    ↓
Admin 审核
    ↓
审核通过 → 生成合同 (ContractInfo)
    ↓
电子签署
    ↓
合同生效
    ↓
到期提醒
    ↓
合同终止/续签
```

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `common_all/contract/entity/` | 合同实体 |
| `common_all/contract/enums/` | 合同枚举 |
| `common_all/contract/service/` | 合同服务 |
| `common_all/contract/mapper/` | 合同 Mapper |
| `common_all/contract/manager/` | 合同管理器 |
| `admin/contract/controller/ContractApplyAdminController.java` | 合同申请管理 |
| `admin/contract/controller/ContractInfoAdminController.java` | 合同信息管理 |
| `admin/contract/controller/ContractTemplateAdminController.java` | 合同模板管理 |
| `merchant/contract/` | 商户端合同 |
| `job/contract/` | 合同定时任务 |
