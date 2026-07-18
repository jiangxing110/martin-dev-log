# 资金管理

## 概述

资金管理模块负责内部资金的划转、调拨、冻结、解冻等操作，是 Qbit 内部资金流转的核心基础设施。通过工厂策略模式支持多渠道资金操作，覆盖现金返现、资金冻结、资金划转等场景。

## 整体架构

```
┌──────────────────────────────────────────────────────────────────┐
│                     核心服务层                                      │
│  FundingService → 资金主服务                                      │
│  FundingTransferService → 资金划转服务                            │
│  IFundingTransfer → 资金划转接口                                  │
│  FundingFrozenService → 资金冻结服务                              │
│  CashBackBonusService → 现金返现服务                              │
├──────────────────────────────────────────────────────────────────┤
│                     工厂策略层                                      │
│  FundingTransferFactory → 资金划转工厂                            │
│  IFundingTransfer 实现类 → 各渠道资金操作                         │
├──────────────────────────────────────────────────────────────────┤
│                     数据层                                          │
│  FundingOrder → 资金订单                                          │
│  FundingFrozen → 资金冻结记录                                     │
│  FundingTransfer → 资金划转记录                                   │
│  FundingEvent → 资金事件                                          │
├──────────────────────────────────────────────────────────────────┤
│                     MQ 监听器                                      │
│  listener/ → 资金事件监听                                         │
└──────────────────────────────────────────────────────────────────┘
```

## 核心服务

### FundingService

| 方法 | 说明 |
|------|------|
| `funding()` | 资金操作入口 |
| `queryBalance()` | 查询资金余额 |
| `queryFundingRecords()` | 查询资金记录 |

### FundingTransferService

| 方法 | 说明 |
|------|------|
| `transfer()` | 资金划转 |
| `batchTransfer()` | 批量资金划转 |

### FundingFrozenService

| 方法 | 说明 |
|------|------|
| `freeze()` | 冻结资金 |
| `unfreeze()` | 解冻资金 |
| `queryFrozen()` | 查询冻结记录 |

### CashBackBonusService

| 方法 | 说明 |
|------|------|
| `calculateCashBack()` | 计算返现 |
| `executeCashBack()` | 执行返现 |

## FundingTransferFactory

```
FundingTransferFactory
  └── IFundingTransfer (策略接口)
        ├── 渠道 A 实现
        ├── 渠道 B 实现
        └── 渠道 C 实现
```

## 核心实体

| 实体 | 说明 |
|------|------|
| `FundingOrder` | 资金订单 |
| `FundingFrozen` | 资金冻结记录 |
| `FundingTransfer` | 资金划转记录 |
| `FundingEvent` | 资金事件 |

## 枚举

| 枚举 | 说明 |
|------|------|
| `FundingStatusEnum` | 资金状态 |
| `FundingTypeEnum` | 资金类型 |
| `FundingDirectionEnum` | 资金方向 |

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `common_all/funding/service/FundingService.java` | 资金主服务 |
| `common_all/funding/service/FundingTransferService.java` | 资金划转服务 |
| `common_all/funding/service/IFundingTransfer.java` | 资金划转接口 |
| `common_all/funding/service/FundingFrozenService.java` | 资金冻结服务 |
| `common_all/funding/service/CashBackBonusService.java` | 现金返现服务 |
| `common_all/funding/service/impl/` | 资金服务实现 |
| `common_all/funding/service/convert/` | 资金转换 |
| `common_all/funding/service/validator/` | 资金校验 |
| `common_all/funding/service/utils/` | 资金工具类 |
| `common_all/funding/domain/entity/` | 资金实体 |
| `common_all/funding/domain/dto/` | 资金 DTO |
| `common_all/funding/domain/bo/` | 资金 BO |
| `common_all/funding/domain/vo/` | 资金 VO |
| `common_all/funding/domain/event/` | 资金事件 |
| `common_all/funding/enums/` | 资金枚举 |
| `common_all/funding/mapper/` | 资金 Mapper |
| `common_all/funding/listener/` | 资金 MQ 监听器 |
| `common_all/funding/FundingTransferFactory.java` | 资金划转工厂 |
