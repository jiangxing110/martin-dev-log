# OpenAPI 对外接口

## 概述

OpenAPI 是 Qbit 面向商户的开放 API 体系，提供标准化的 RESTful V3 接口，涵盖账户管理、卡片操作、加密货币转账、全球账户、付款、交易查询、Webhook 回调等能力。采用 API Key + Secret 认证方式，支持沙箱模拟测试和生产环境两种模式。

## 整体架构

```
┌──────────────────────────────────────────────────────────────────┐
│                        商户接入层                                  │
│  API Key + Secret → HMAC-SHA256 签名验证                          │
│  OpenapiClientCheckService → 客户端认证                            │
├──────────────────────────────────────────────────────────────────┤
│                       V3 接口层                                    │
│  account → 账户 KYC/KYB/详情                                      │
│  card → 卡管理/交易/冻结/解冻                                      │
│  cryptoconnect → 加密币充值/提现/地址校验                          │
│  global → 全球账户/汇款/结汇                                       │
│  payment → 付款                                                    │
│  transfer → 转账记录                                               │
│  statement → 账单                                                  │
│  webhook → 回调通知                                                │
├──────────────────────────────────────────────────────────────────┤
│                       核心服务层                                    │
│  OpenApiAccountService → 账户                                      │
│  OpenApiCardService → 卡片                                         │
│  OpenApiCryptoService → 加密币                                     │
│  OpenApiGlobalService → 全球账户                                   │
│  OpenApiPaymentService → 付款                                      │
│  OpenApiTransferService → 转账                                     │
├──────────────────────────────────────────────────────────────────┤
│                       Webhook 回调层                                │
│  OpenApiWebHookData → Webhook 数据实体                             │
│  OpenApiWebhookV3CallService → 回调发送                            │
│  TransWebhookDealService → 交易 Webhook 处理                      │
├──────────────────────────────────────────────────────────────────┤
│                       沙箱模拟层                                    │
│  SandboxService → 沙箱交易模拟                                     │
│  SandboxSimulateController → 沙箱接口                              │
└──────────────────────────────────────────────────────────────────┘
```

## 接口总览

### 1. 账户接口 (Account)

| 端点 | 方法 | 说明 |
|------|------|------|
| `/v3/account/kyc` | GET | KYC 信息查询 |
| `/v3/account/kyb` | GET | KYB 信息查询 |
| `/v3/account/cdd-kyb-detail` | GET | CDD/KYB 详情 |
| `/v3/account/kyc-detail` | GET | KYC 详情 |
| `/v3/account/negative-list` | GET | 负面清单查询 |

Controller: `OpenApiAccountV3Controller.java`

### 2. 卡片接口 (Card)

| 端点 | 方法 | 说明 |
|------|------|------|
| `/v3/card/create` | POST | 创建卡片 |
| `/v3/card/list` | GET | 卡片列表 |
| `/v3/card/detail` | GET | 卡片详情 |
| `/v3/card/suspend` | POST | 冻结卡片 |
| `/v3/card/enable` | POST | 解冻卡片 |
| `/v3/card/delete` | POST | 删除卡片 |
| `/v3/card/transactions` | GET | 交易记录 |
| `/v3/card/limit` | POST | 设置限额 |

Controller: `OpenApiCardV3Controller.java`

### 3. 加密币接口 (CryptoConnect)

| 端点 | 方法 | 说明 |
|------|------|------|
| `/v3/cryptoconnect/deposit` | GET | 充值信息 |
| `/v3/cryptoconnect/withdraw` | POST | 提现 |
| `/v3/cryptoconnect/withdraw/preview` | GET | 提现预览 |
| `/v3/cryptoconnect/address/validate` | POST | 地址校验 |
| `/v3/cryptoconnect/deposit/address` | GET | 充值地址 |

Controller: `OpenApiCryptoConnectV3Controller.java`

### 4. 全球账户接口 (Global)

| 端点 | 方法 | 说明 |
|------|------|------|
| `/v3/global/account` | GET | 账户信息 |
| `/v3/global/transfer` | POST | 汇款 |
| `/v3/global/conversion` | POST | 结汇换汇 |
| `/v3/global/balance` | GET | 余额查询 |
| `/v3/global/transaction` | GET | 交易记录 |

Controller: `OpenApiGlobalV3Controller.java`

### 5. 付款接口 (Payment)

| 端点 | 方法 | 说明 |
|------|------|------|
| `/v3/payment/create` | POST | 创建付款 |
| `/v3/payment/detail` | GET | 付款详情 |
| `/v3/payment/list` | GET | 付款列表 |

Controller: `OpenApiPaymentV3Controller.java`

### 6. 转账接口 (Transfer)

| 端点 | 方法 | 说明 |
|------|------|------|
| `/v3/transfer/detail` | GET | 转账详情 |
| `/v3/transfer/list` | GET | 转账列表 |

Controller: `OpenApiTransferV3Controller.java`

### 7. 账单接口 (Statement)

| 端点 | 方法 | 说明 |
|------|------|------|
| `/v3/statement` | GET | 账单查询 |

### 8. Webhook 回调

| 事件 | 说明 |
|------|------|
| `transfer.status.changed` | 转账状态变更 |
| `card.transaction` | 卡交易通知 |
| `crypto.deposit` | 加密币充值到账 |
| `crypto.withdraw` | 加密币提现完成 |
| `global.transfer` | 全球账户转账 |

## 核心服务

### OpenApiAccountService

| 方法 | 说明 |
|------|------|
| `accountKyc()` | KYC 信息查询 |
| `accountKyb()` | KYB 信息查询 |
| `getCddKybDetail()` | CDD/KYB 详情 |
| `getAccountKycDetail()` | KYC 详情 |
| `negativeAccountList()` | 负面清单查询 |

### OpenApiCardService

| 方法 | 说明 |
|------|------|
| `createCard()` | 创建卡片 |
| `listCards()` | 卡列表 |
| `getCardDetail()` | 卡详情 |
| `suspendCard()` | 冻结卡片 |
| `enableCard()` | 解冻卡片 |
| `deleteCard()` | 删除卡片 |
| `listTransactions()` | 交易记录 |
| `setLimit()` | 设置限额 |

### OpenApiCryptoService

| 方法 | 说明 |
|------|------|
| `getDepositInfo()` | 充值信息 |
| `withdraw()` | 提现 |
| `previewWithdraw()` | 提现预览 |
| `validateAddress()` | 地址校验 |
| `getDepositAddress()` | 充值地址 |

### OpenApiGlobalService

| 方法 | 说明 |
|------|------|
| `getAccount()` | 账户信息 |
| `transfer()` | 汇款 |
| `conversion()` | 结汇换汇 |
| `getBalance()` | 余额查询 |
| `listTransactions()` | 交易记录 |

### OpenApiPaymentService

| 方法 | 说明 |
|------|------|
| `createPayment()` | 创建付款 |
| `getPaymentDetail()` | 付款详情 |
| `listPayments()` | 付款列表 |

### OpenApiTransferService

| 方法 | 说明 |
|------|------|
| `getTransferDetail()` | 转账详情 |
| `listTransfers()` | 转账列表 |

## 认证与鉴权

### API Key + Secret 认证

```
商户请求头:
  X-API-Key: <api_key>
  X-Signature: <HMAC-SHA256(secret, body + timestamp)>
  X-Timestamp: <timestamp>

校验流程:
  1. OpenapiClientCheckService 根据 api_key 查找客户端
  2. 校验客户端状态 (enabled/disabled)
  3. 校验签名 (HMAC-SHA256)
  4. 校验时间戳窗口 (防重放)
  5. 校验 IP 白名单
```

### 权限控制

- 每个 API Key 可绑定特定接口权限
- 支持按接口粒度控制访问
- 支持 IP 白名单限制
- 支持调用频率限制

## Webhook 回调系统

### Webhook 数据实体

| 字段 | 说明 |
|------|------|
| webhookId | Webhook ID |
| accountId | 账户ID |
| eventType | 事件类型 |
| data | 回调数据 (JSON) |
| status | 发送状态 (pending/sent/failed) |
| retryCount | 重试次数 |
| maxRetries | 最大重试次数 |
| nextRetryTime | 下次重试时间 |

### 回调流程

```
业务事件发生
    ↓
OpenApiWebhookV3CallService 构建回调数据
    ↓
TransWebhookDealService 处理交易回调
    ↓
HTTP POST → 商户回调 URL
    ↓
成功 → 更新状态为 sent
失败 → 重试 (指数退避)
    ↓
超过最大重试次数 → 标记为 failed
```

### Webhook 重试策略

- 指数退避: 1min → 5min → 30min → 2h → 6h → 24h
- 最大重试次数: 6 次
- 支持手动重新发送

## 沙箱模拟 (Sandbox)

### 沙箱能力

| 功能 | 说明 |
|------|------|
| 模拟交易 | 模拟充提币、转账、付款 |
| 状态模拟 | 模拟各种交易状态 |
| 回调模拟 | 模拟 Webhook 回调 |
| 数据隔离 | 沙箱数据与生产隔离 |

### 沙箱实现

- `SandboxService` — 沙箱核心服务
- `SandboxSimulateController` — 沙箱模拟接口
- 沙箱环境使用独立的 API Key
- 沙箱交易不实际发生资金流转

## Handler 层

```
OpenApiHandlerFactory
  ├── AccountHandler → 账户相关处理
  ├── CardHandler → 卡片相关处理
  ├── CryptoHandler → 加密币相关处理
  ├── GlobalHandler → 全球账户处理
  ├── PaymentHandler → 付款处理
  └── TransferHandler → 转账处理
```

Handler 采用策略模式，根据业务类型分发到对应的处理器。

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `openapi/v3/controller/OpenApiAccountV3Controller.java` | 账户接口 |
| `openapi/v3/controller/OpenApiCardV3Controller.java` | 卡片接口 |
| `openapi/v3/controller/OpenApiCryptoConnectV3Controller.java` | 加密币接口 |
| `openapi/v3/controller/OpenApiGlobalV3Controller.java` | 全球账户接口 |
| `openapi/v3/controller/OpenApiPaymentV3Controller.java` | 付款接口 |
| `openapi/v3/controller/OpenApiTransferV3Controller.java` | 转账接口 |
| `openapi/v3/service/OpenApiAccountService.java` | 账户服务 |
| `openapi/v3/service/OpenApiCardService.java` | 卡片服务 |
| `openapi/v3/service/OpenApiCryptoService.java` | 加密币服务 |
| `openapi/v3/service/OpenApiGlobalService.java` | 全球账户服务 |
| `openapi/v3/service/OpenApiPaymentService.java` | 付款服务 |
| `openapi/v3/service/OpenApiTransferService.java` | 转账服务 |
| `openapi/v3/service/OpenapiClientCheckService.java` | 客户端认证 |
| `openapi/v3/service/webhook/OpenApiWebhookV3CallService.java` | Webhook 回调发送 |
| `openapi/v3/service/webhook/TransWebhookDealService.java` | 交易 Webhook 处理 |
| `openapi/v3/service/webhook/OpenApiWebHookData.java` | Webhook 数据实体 |
| `openapi/v3/service/sandbox/SandboxService.java` | 沙箱服务 |
| `openapi/v3/service/sandbox/SandboxSimulateController.java` | 沙箱模拟接口 |
| `openapi/v3/handler/OpenApiHandlerFactory.java` | Handler 工厂 |
| `openapi/v3/handler/` | Handler 策略实现 |
| `openapi/v3/dto/` | V3 接口 DTO |
| `openapi/enums/` | OpenAPI 枚举 |
| `openapi/entity/` | OpenAPI 实体 |
