# 收单支付

## 概述

收单支付是 Qbit 的收款侧能力，为商户提供多种收款方式接入。目前 Qbit 的业务模式以出款（Payout）为核心，收单支付属于辅助模块（~30 文件），主要用于全球账户体系下的收款处理。

## 整体架构

```
┌──────────────────────────────────────────────────────────────────┐
│                       收款入口                                     │
│  全球账户入金 (GlobalAccountDepositController)                    │
│  收款模块 (common_all/globalaccount/collection/)                 │
├──────────────────────────────────────────────────────────────────┤
│                     收款处理层                                      │
│  CollectionController → 收款管理                                 │
│  CollectService → 收款服务                                        │
│  handler/ → 收款策略处理器                                        │
├──────────────────────────────────────────────────────────────────┤
│                     渠道层                                          │
│  银行转账 (Wire/ACH)                                              │
│  本地转账                                                         │
│  加密货币充值                                                     │
└──────────────────────────────────────────────────────────────────┘
```

## 核心流程

```
收款请求
    ↓
CollectionController 接收
    ↓
CollectService 处理
    ↓
handler/ 策略处理器 → 按渠道分发
    ↓
渠道入金确认 (Wire/ACH/本地转账)
    ↓
GlobalAccountTransactionService.transferIn()
    ↓
BalanceService 更新余额
    ↓
商户通知 (Webhook/MQ)
```

## 收款模块

### 控制器

| Controller | 说明 |
|------------|------|
| `CollectionController` | 收款管理 (merchant) |
| `GlobalAccountDepositController` | 全球账户入金 (merchant) |

### 处理器 (handler)

收款模块使用策略模式处理不同场景的收款逻辑：

```
handler/
  ├── context/ → 策略上下文
  ├── impl/ → 策略实现
  └── service/ → 策略服务
```

### 收款渠道

| 渠道 | 说明 |
|------|------|
| 银行转账 | Wire Transfer / ACH |
| 本地转账 | 各国本地清算系统 |
| 加密货币 | USDT/BTC/ETH 等充值 |

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `common_all/globalaccount/collection/` | 收款模块 |
| `common_all/globalaccount/collection/controller/` | 收款 Controller |
| `common_all/globalaccount/collection/handler/` | 收款处理器 |
| `common_all/globalaccount/collection/handler/context/` | 策略上下文 |
| `common_all/globalaccount/collection/handler/impl/` | 策略实现 |
| `common_all/globalaccount/collection/handler/service/` | 策略服务 |
| `common_all/globalaccount/service/CollectService.java` | 收款服务 |
| `merchant/collection/controller/CollectionController.java` | 商户端收款 |
| `merchant/collection/service/CollectionService.java` | 商户端收款服务 |
| `merchant/globalaccount/controller/GlobalAccountDepositController.java` | 入金管理 |
