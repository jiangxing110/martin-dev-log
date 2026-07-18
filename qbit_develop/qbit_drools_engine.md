# Drools 规则引擎

## 概述

Drools 规则引擎是 Qbit 风控、费用计算、支付路由背后的核心决策系统。通过声明式规则（DRL 文件）实现复杂的业务逻辑编排，支持规则分组、优先级控制、结果收集、告警联动，覆盖风控拦截、交易限额、费用计算、合规筛查等场景。

## 整体架构

```
┌──────────────────────────────────────────────────────────────────┐
│                        规则调用层                                  │
│  DroolsRuleService → 规则执行入口                                 │
│  RuleGroupService → 规则分组管理                                  │
│  RuleLockService → 规则锁                                        │
│  RuleResultService → 规则结果收集                                 │
├──────────────────────────────────────────────────────────────────┤
│                        规则引擎层                                  │
│  ├─ 规则执行 (DroolsRuleExecuteDto)                              │
│  ├─ 结果处理 (DroolsResultExecuteDto)                            │
│  └─ 规则日志 (DroolsRuleLogsService)                             │
├──────────────────────────────────────────────────────────────────┤
│                        DRL 规则文件                                │
│  CryptoOutbound.drl → 加密币出金风控                              │
│  CurrencyOutbound.drl → 法币出金风控                              │
│  MerchantRiskAction.drl → 商户风控                                │
│  CommonRiskAction.drl → 通用风控                                  │
│  ApiClinetRiskAction.drl → API 风控                               │
│  MultiAccountRiskAction.drl → 多账户风控                          │
│  QbitRiskRatingAction.drl → 风险评级                              │
│  QbitInternationalRiskRatingAction.drl → 国际风险评级             │
├──────────────────────────────────────────────────────────────────┤
│                        规则处理器                                  │
│  TransactionAlertHandler → 交易告警处理                           │
│  ControlWarningRuleService → 控制/告警规则                        │
├──────────────────────────────────────────────────────────────────┤
│                        风控服务                                    │
│  DroolsRuleRiskService → 规则风控                                 │
│  RiskAlertService → 风险告警                                      │
│  RiskRatingService → 风险评级                                     │
│  DelaySettlementLabelService → 延迟结算标签                       │
│  ControlWarningRuleLogService → 控制告警日志                      │
└──────────────────────────────────────────────────────────────────┘
```

## 核心工作流

```
业务请求
    ↓
DroolsRuleService 构造规则参数 (DroolsRuleExecuteDto)
    ↓
RuleGroupService 获取命中的规则组
    ↓
加载 DRL 规则文件 → KieSession
    ↓
规则匹配 + 冲突解决 (优先级)
    ↓
规则动作执行 → DroolsResultExecuteDto 收集结果
    ↓
RuleResultService 持久化规则结果
    ↓
DroolsRuleLogsService 记录规则日志
    ↓
DroolsRuleRiskService 风控判定
    ↓
返回业务层处理结果
```

## 规则分组

### 业务域分组

| 分组 | 规则文件 | 用途 |
|------|---------|------|
| 加密资产 | `CryptoOutbound.drl` | 加密货币出金风控 |
| 法币 | `CurrencyOutbound.drl` | 法币出金风控 |
| 商户风控 | `MerchantRiskAction.drl` | 商户维度的风险规则 |
| 通用风控 | `CommonRiskAction.drl` | 跨业务通用风控规则 |
| API | `ApiClinetRiskAction.drl` | API 调用风控 |
| 多账户 | `MultiAccountRiskAction.drl` | 多账户关联风控 |
| 风险评级 | `QbitRiskRatingAction.drl` | 商户风险评级 |
| 国际评级 | `QbitInternationalRiskRatingAction.drl` | 国际业务风险评级 |

### 规则分类

| 类型 | 说明 |
|------|------|
| 拦截规则 | 命中后直接拒绝交易 |
| 告警规则 | 命中后触发告警，不拦截 |
| 评级规则 | 根据指标计算风险等级 |
| 标签规则 | 命中后给商户打标签 |
| 限额规则 | 控制交易金额/频次上限 |

## 核心实体

### DroolsRuleExecuteDto（规则执行入参）

| 字段 | 说明 |
|------|------|
| ruleGroup | 规则组标识 |
| businessType | 业务类型 |
| accountId | 账户ID |
| amount | 交易金额 |
| currency | 币种 |
| extraParams | 扩展参数 (Map) |

### DroolsResultExecuteDto（规则执行结果）

| 字段 | 说明 |
|------|------|
| isRejected | 是否拒绝 |
| rejectCode | 拒绝码 |
| rejectReason | 拒绝原因 |
| riskLevel | 风险等级 |
| alertMessages | 告警消息列表 |
| tags | 标签列表 |

## 核心服务

| 服务 | 说明 |
|------|------|
| `DroolsRuleService` | 规则执行入口 |
| `RuleGroupService` | 规则分组管理 |
| `RuleLockService` | 规则锁（防并发） |
| `RuleResultService` | 规则结果持久化 |
| `RuleService` | 规则基础服务 |
| `DroolsRuleLogsService` | 规则日志 |
| `DroolsRuleRiskService` | 风控判定服务 |
| `RiskAlertService` | 风险告警 |
| `RiskRatingService` | 风险评级 |
| `ControlWarningRuleService` | 控制/告警规则 |
| `ControlWarningRuleLogService` | 控制告警日志 |
| `DelaySettlementLabelService` | 延迟结算标签 |
| `TransactionAlertHandler` | 交易告警处理器 |

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `drools/service/DroolsRuleService.java` | 规则执行入口 |
| `drools/service/RuleGroupService.java` | 规则分组管理 |
| `drools/service/RuleLockService.java` | 规则锁 |
| `drools/service/RuleResultService.java` | 规则结果 |
| `drools/service/RuleService.java` | 规则基础服务 |
| `drools/service/DroolsRuleLogsService.java` | 规则日志 |
| `drools/service/DroolsRuleRiskService.java` | 规则风控 |
| `drools/service/RiskAlertService.java` | 风险告警 |
| `drools/service/RiskRatingService.java` | 风险评级 |
| `drools/service/ControlWarningRuleService.java` | 控制告警规则 |
| `drools/service/DelaySettlementLabelService.java` | 延迟结算标签 |
| `drools/domain/entity/` | 规则实体 |
| `drools/domain/dto/` | 规则 DTO |
| `drools/domain/bo/` | 规则 BO |
| `drools/domain/vo/` | 规则 VO |
| `drools/enums/` | 规则枚举 |
| `drools/handler/TransactionAlertHandler.java` | 交易告警处理器 |
| `drools/action/` | 规则动作 |
| `drools/annotation/` | 规则注解 |
| `drools/controller/` | 规则管理接口 |
| `drools/utils/` | 规则工具类 |
| `resources/rules/*.drl` | DRL 规则文件（8个） |
