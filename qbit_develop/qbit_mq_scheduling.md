# MQ / 消息调度

## 概述

MQ/消息调度是 Qbit 的异步消息处理和定时任务调度基础设施，基于 RocketMQ 和 Redis 实现消息驱动，结合 XXL-Job 实现分布式定时任务调度，支撑系统内的异步解耦、事件通知、数据同步、任务编排等场景。

## 整体架构

```
┌──────────────────────────────────────────────────────────────────┐
│                      消息中间件层                                  │
│  RocketMQ → 核心消息队列                                          │
│  Redis → 缓存消息/延迟队列                                       │
│  ONS → 阿里云 ONS（兼容 RocketMQ）                               │
├──────────────────────────────────────────────────────────────────┤
│                      MQ 监听器层                                   │
│  mq/ons/ → ONS 监听器                                            │
│  mq/redis/ → Redis 消息监听                                      │
│  mq/statement/ → 账单消息处理                                     │
├──────────────────────────────────────────────────────────────────┤
│                     定时任务层 (XXL-Job)                           │
│  job/ → 全部定时任务                                               │
│    资产/卡/全球账户/融资/合规/通知等                               │
├──────────────────────────────────────────────────────────────────┤
│                     消息生产者层                                    │
│  各业务模块 (merchant/admin/common_all) 中分散的消息发送          │
└──────────────────────────────────────────────────────────────────┘
```

## MQ 消息

### 消息类型

| 类型 | 中间件 | 用途 |
|------|--------|------|
| 业务事件 | RocketMQ | 交易通知、状态变更、风控告警 |
| 延迟消息 | RocketMQ | 延迟结算、超时处理 |
| 缓存消息 | Redis | 缓存同步、分布式锁通知 |
| 账单消息 | RocketMQ | 对账/账单生成 |

### MQ 模块

| 模块 | 说明 |
|------|------|
| `mq/ons/` | ONS 消息监听 |
| `mq/redis/` | Redis 消息处理 |
| `mq/statement/` | 账单消息处理 |

### MQ 应用场景

| 业务域 | 消息用途 |
|--------|----------|
| 加密资产 | 充值通知、转账确认、风控通知、退款广播 |
| 量子卡 | 卡状态变更、交易通知、分组操作 |
| 全球账户 | 入金通知、转账状态、汇率更新 |
| 资金管理 | 资金事件通知 |
| 风控 | 风控结果通知、告警分发 |
| 通知 | 邮件/站内信/Webhook 消息发送 |
| 对账 | 对账结果通知 |

## 定时任务

### 任务列表

| 任务 | 说明 |
|------|------|
| `job/assets/` | 资产相关定时任务 |
| `job/card/` | 量子卡定时任务 |
| `job/qbitcard/` | 量子卡附加任务 |
| `job/globalaccount/` | 全球账户定时任务 |
| `job/financing/` | 融资定时任务 |
| `job/compliance/` | 合规定时任务 |
| `job/notification/` | 通知定时任务 |
| `job/openapi/` | OpenAPI 定时任务 |
| `job/payout/` | 出金定时任务 |
| `job/account/` | 账户定时任务 |
| `job/analysis/` | 分析定时任务 |
| `job/alert/` | 告警定时任务 |
| `job/cache/` | 缓存定时任务 |
| `job/cc/` | CurrencyCloud 定时任务 |
| `job/clear/` | 清算定时任务 |
| `job/cny/` | 人民币结算定时任务 |
| `job/companyAssets/` | 公司资产定时任务 |
| `job/contract/` | 合同定时任务 |
| `job/csm/` | CSM 定时任务 |
| `job/email/` | 邮件定时任务 |
| `job/fix/` | 数据修复定时任务 |
| `job/fund/` | 资金定时任务 |
| `job/partner/` | 合作伙伴定时任务 |
| `job/pyvio/` | Pyvio 定时任务 |
| `job/bb/` | BB 渠道定时任务 |
| `job/qichacha/` | 企查查数据同步 |

### 任务类型

| 类型 | 说明 |
|------|------|
| 数据同步 | 定时同步三方数据 |
| 状态检查 | 检查并更新超时/挂起状态 |
| 对账批处理 | 日终对账、差异处理 |
| 通知推送 | 批量消息推送 |
| 数据清理 | 过期数据清理 |
| 报表生成 | 定时报表生成 |
| 缓存刷新 | 定时刷新缓存 |
| 重试处理 | 失败任务重试 |

### 任务架构

```
XXL-Job Admin (调度中心)
    ↓
XXL-Job Executor (qbit-core)
    ↓
任务分发
    ↓
具体 Job 执行
    ↓
结果回调
```

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `mq/ons/` | ONS 消息监听器 |
| `mq/redis/` | Redis 消息监听 |
| `mq/statement/` | 账单消息处理 |
| `job/assets/` | 资产定时任务 |
| `job/card/` | 卡定时任务 |
| `job/qbitcard/` | 量子卡定时任务 |
| `job/globalaccount/` | 全球账户定时任务 |
| `job/financing/` | 融资定时任务 |
| `job/compliance/` | 合规定时任务 |
| `job/notification/` | 通知定时任务 |
| `job/openapi/` | OpenAPI 定时任务 |
| `job/payout/` | 出金定时任务 |
| `job/account/` | 账户定时任务 |
| `job/analysis/` | 分析定时任务 |
| `job/alert/` | 告警定时任务 |
| `job/cache/` | 缓存定时任务 |
| `job/cc/` | CurrencyCloud 任务 |
| `job/clear/` | 清算任务 |
| `job/cny/` | 人民币结算任务 |
| `job/companyAssets/` | 公司资产任务 |
| `job/contract/` | 合同任务 |
| `job/csm/` | CSM 任务 |
| `job/email/` | 邮件任务 |
| `job/fix/` | 数据修复 |
| `job/fund/` | 资金任务 |
| `job/partner/` | 合作伙伴任务 |
| `job/pyvio/` | Pyvio 任务 |
| `job/bb/` | BB 渠道任务 |
| `job/qichacha/` | 企查查同步 |
