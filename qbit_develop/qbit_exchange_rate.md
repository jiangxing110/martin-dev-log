# 汇率体系

## 概述

汇率体系提供多币种汇率管理和货币兑换能力，支持实时汇率查询、汇率转换、汇率配置管理。系统对接多个汇率源（OKX、Gate、HashKey、Circle、内部汇率），通过工厂模式实现多源汇率获取和切换。

## 整体架构

```
┌──────────────────────────────────────────────────────────────────┐
│                     汇率获取层 (Rate)                              │
│  common_all/rate/ → 汇率核心                                     │
│    provider/ → 汇率提供商                                        │
│    service/ → 汇率服务                                           │
│    controller/ → 汇率接口                                        │
│    domain/ → 汇率实体                                            │
│    application/ → 汇率应用层                                     │
├──────────────────────────────────────────────────────────────────┤
│                     汇率工厂层 (CryptoRateFactory)                  │
│  CryptoRateQbitHandler → Qbit 内部汇率                            │
│  CryptoRateOkxHandler → OKX 行情                                  │
│  CryptoRateGateHandler → Gate 行情                                │
│  CryptoRateCustomHandler → 自定义汇率                              │
│  CryptoRateCurveHandler → 曲线处理                                │
├──────────────────────────────────────────────────────────────────┤
│                     兑换服务层 (Exchange)                          │
│  common_all/exchange/ → 货币兑换                                 │
│    service/ → 兑换服务                                           │
│    domain/ → 兑换实体                                            │
│    enums/ → 兑换枚举                                             │
│    listener/ → 兑换事件监听                                      │
│    util/ → 兑换工具                                              │
├──────────────────────────────────────────────────────────────────┤
│                     汇率调度层 (ExchangeRate)                      │
│  common_all/exchangerate/ → 汇率调度                             │
│    dispatch/ → 汇率分发                                          │
│    domain/ → 调度领域模型                                        │
│    service/ → 调度服务                                           │
└──────────────────────────────────────────────────────────────────┘
```

## 核心模块

### Rate（汇率核心）

| 组件 | 说明 |
|------|------|
| `common_all/rate/provider/` | 汇率提供商 |
| `common_all/rate/service/` | 汇率服务 |
| `common_all/rate/controller/` | 汇率接口 |
| `common_all/rate/domain/` | 汇率实体 |

### CryptoRateFactory（汇率工厂）

```
CryptoRateFactory (策略模式)
  ├── CryptoRateQbitHandler → 内部汇率 (基础汇率)
  ├── CryptoRateOkxHandler → OKX 行情 (实时市价)
  ├── CryptoRateGateHandler → Gate 行情 (实时市价)
  ├── CryptoRateCustomHandler → 自定义汇率 (商户配置)
  └── CryptoRateCurveHandler → 曲线处理 (平滑/加权)
```

### Exchange（货币兑换）

| 组件 | 说明 |
|------|------|
| `common_all/exchange/service/` | 兑换服务 |
| `common_all/exchange/domain/` | 兑换实体 |
| `common_all/exchange/enums/` | 兑换枚举 |
| `common_all/exchange/listener/` | 兑换事件监听 |
| `common_all/exchange/util/` | 兑换工具类 |

### ExchangeRate（汇率调度）

| 组件 | 说明 |
|------|------|
| `common_all/exchangerate/dispatch/` | 汇率分发调度 |
| `common_all/exchangerate/domain/` | 调度领域模型 |
| `common_all/exchangerate/service/` | 调度服务 |

## 核心流程

```
汇率请求
    ↓
CryptoRateFactory 选择汇率源
    ↓
对应 Handler 获取汇率
    ↓
汇率计算 (买入价/卖出价/中间价)
    ↓
Exchange Service 执行兑换
    ↓
记录汇率日志
```

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `common_all/rate/service/` | 汇率服务 |
| `common_all/rate/provider/` | 汇率提供商 |
| `common_all/rate/controller/` | 汇率接口 |
| `common_all/rate/domain/` | 汇率实体 |
| `common_all/rate/application/` | 汇率应用层 |
| `common_all/exchange/service/` | 兑换服务 |
| `common_all/exchange/domain/` | 兑换实体 |
| `common_all/exchange/enums/` | 兑换枚举 |
| `common_all/exchange/listener/` | 兑换监听 |
| `common_all/exchange/util/` | 兑换工具 |
| `common_all/exchangerate/dispatch/` | 汇率分发 |
| `common_all/exchangerate/domain/` | 汇率调度领域 |
| `common_all/exchangerate/service/` | 汇率调度服务 |
| `merchant/cryptoasset/v2/factory/CryptoRateFactory.java` | 汇率工厂 |
| `merchant/cryptoasset/v2/factory/handler/CryptoRateQbitHandler.java` | Qbit 汇率 |
| `merchant/cryptoasset/v2/factory/handler/CryptoRateOkxHandler.java` | OKX 汇率 |
| `merchant/cryptoasset/v2/factory/handler/CryptoRateGateHandler.java` | Gate 汇率 |
| `merchant/cryptoasset/v2/factory/handler/CryptoRateCustomHandler.java` | 自定义汇率 |
| `merchant/cryptoasset/v2/factory/handler/CryptoRateCurveHandler.java` | 曲线处理 |
