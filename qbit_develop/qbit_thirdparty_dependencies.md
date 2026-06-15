# 三方依赖体系

## 概述

Qbit 系统集成大量第三方服务，涵盖支付通道、卡组、加密货币、KYC/合规、通知、风控等多个领域。整体架构分为三层：外部第三方集成、内部微服务依赖、独立 SDK 模块。

## 分层架构

```
┌─────────────────────────────────────────────────────────┐
│                  业务服务层 (Service)                      │
│  调用三方的业务逻辑，通过 SDK / Feign / HTTP 访问下层      │
├─────────────────────────────────────────────────────────┤
│              集成适配层 (thirdparty/)                      │
│  ┌───────────────────┐  ┌──────────────────────────┐     │
│  │  external/         │  │  internal/               │     │
│  │  外部三方集成       │  │  内部微服务 / 工具        │     │
│  │  (支付/卡组/加密货币)│  │  (通知/风控/翻译)        │     │
│  └───────────────────┘  └──────────────────────────┘     │
├─────────────────────────────────────────────────────────┤
│              SDK 层 (qbit-assets-thirdparty/)             │
│   统一请求框架 IRequest + SdkUrlEnums + SdkRelated        │
│   独立 SDK 模块封装各三方 API                              │
├─────────────────────────────────────────────────────────┤
│                  基础设施层                                │
│   HTTP 客户端、签名工具、重试/降级、配置中心                │
└─────────────────────────────────────────────────────────┘
```

## 配置体系

### ThirdPartyProperties

`ThirdPartyProperties.java` — `@ConfigurationProperties(prefix = "thirdparty")`，集中管理所有三方配置：

- `namesScreening` — 名称筛查
- `notify` — 通知服务
- `beepay` / `shopline` / `shoplazza` — 支付通道
- `apiLayer` — API 网关
- `okx` — OKX 交易所
- `translate` — 翻译服务
- `thunes` — Thunes 汇款
- `routefusion` — RouteFusion
- `rainCards` — RainCards
- `sumsub` — Sumsub KYC
- `thepennyinc` / `slash` / `orenda` — 卡组
- `beosin` / `chainalysis` — 链上安全
- `cregis` / `okLink` — 加密货币
- `slbClient` — SLB 客户端

## 外部三方集成 (thirdparty/external/)

### 支付通道 (14 个)

| 集成 | 文件数 | 说明 |
|------|--------|------|
| CL (Column) | 73 | Column 支付通道 |
| EP (EasyPay) | 7 | EasyPay 通道 |
| GEO | ~30 | GEO 支付，含 6 个 SDK endpoint |
| L2 (Layer2) | 67 | Layer2 支付通道 |
| Nium | ~40 | Nium 汇款，14 个 SDK endpoint |
| Offline | ~20 | 线下支付通道 |
| RD | ~15 | RD 支付，含 SDK 签名 |
| RF (RouteFusion) | ~25 | RouteFusion 汇款 |
| Thunes | ~35 | Thunes 汇款 |
| TZ | ~20 | TZ 支付通道 |
| ZB | 107 | 智宝支付（最大集成） |
| Beepay | ~30 | Beepay 支付 |
| Pyvio | ~30 | Pyvio 支付 |
| RainCards | ~25 | RainCards 发卡 |

### 卡组 (4 个)

| 集成 | 文件数 | 说明 |
|------|--------|------|
| BB (Binan/Bind) | 92 | 卡组通道，含 SDK/回调/对账 |
| I2C | 106 | I2C 卡组，最大卡组集成 |
| SL (Shopline) | 27 | Shopline 卡组 |
| ThePennyInc | ~18 | ThePennyInc 卡组 |

### 加密货币 (6 个)

| 集成 | 说明 |
|------|------|
| Cobo | Cobo 托管钱包 |
| Cregis | Cregis 钱包，3 个 SDK endpoint |
| Safeheron | Safeheron 托管 |
| OKX | OKX 交易所，行情/交易/提现 |
| Gate | Gate.io 交易所 |
| HashKey | HashKey 合规交易所 |

### KYC / 合规 (5 个)

| 集成 | 文件数 | 说明 |
|------|--------|------|
| Sumsub | 40 | KYC/KYB/AML 最大的合规集成 |
| NameAPI | ~5 | 名称真实性校验 |
| Plaid | ~10 | Plaid 银行账户验证 |
| Qichacha | ~8 | 企查查企业信息 |
| DocuSign | ~10 | DocuSign 电子签 |

### 其他

- Chainalysis — 链上 AML 监控
- Beosin — 智能合约安全审计
- OKLink — 区块链浏览器数据

## 内部服务依赖 (thirdparty/internal/)

### 微服务 (12 个)

| 服务 | 说明 |
|------|------|
| `namesScreening` | 名称筛查服务 |
| `notice` | 通知中心服务 |
| `notify` | 消息推送服务 |
| `apiLayer` | API 网关层 |
| `baidu` | 百度地图/翻译 |
| `xe` | XE 汇率服务 |
| `rd` | RD 内部服务 |
| `verifyCode` | 验证码服务 |
| `scan2pay` | Scan2Pay 服务 |
| `crypto` | 加密货币内部服务 |
| `beosin` | Beosin 安全服务 |
| `slbClient` | SLB 客户端 |

## SDK 请求框架

### 核心接口

`IRequest.java` — 抽象请求基类，泛型 `<P, R>`：
- `headers()` — 默认空请求头
- `getParamType()` — 参数类型
- `getSdkUrl()` — 抽象方法，子类返回 `SdkUrlEnums`
- `getRequestMode()` — 默认 POST
- `getUpload()` — 默认否

### URL 注册中心

`SdkUrlEnums.java` — 枚举维护所有 SDK endpoint URL，每个值关联 `SdkRelated` 签名策略：

- GEO — 6 个 endpoint (GeoSdkRelated)
- Cregis — 3 个 endpoint (CregisRelated)
- Node 系统 — 12 个 endpoint (NodeSystemSdkRelated)
- Nium — 14 个 endpoint (NiumSdkRelated)
- RD — 若干 endpoint (RdAuthSdkRelated)

### 签名策略

`SdkRelated.java` — 签名接口，各集成实现自己的签名逻辑：
- `GeoSdkRelated` — GEO 通道签名
- `CregisRelated` — Cregis 钱包签名
- `NodeSystemSdkRelated` — Node 系统签名
- `NiumSdkRelated` — Nium 签名
- `RdAuthSdkRelated` — RD 认证签名

`CommonConstant.java` 中注册所有 `SdkRelated` 实例。

## 独立 SDK 模块 (qbit-assets-thirdparty/)

8 个独立 Maven 模块，打包为独立 jar，供其他服务引入：

| 模块 | 说明 |
|------|------|
| `thirdparty-bb` | BB 卡组 SDK |
| `thirdparty-i2c` | I2C 卡组 SDK |
| `thirdparty-geo` | GEO 支付 SDK |
| `thirdparty-nium` | Nium SDK |
| `thirdparty-cregis` | Cregis 钱包 SDK |
| `thirdparty-rd` | RD SDK |
| `thirdparty-sl` | Shopline SDK |
| `thirdparty-thunes` | Thunes SDK |

每个模块内部结构：
- `request/` — 请求 DTO，继承 `IRequest`
- `response/` — 响应 DTO
- `client/` — HTTP 客户端封装
- `config/` — 模块配置

## 集成模式

1. **直接 SDK 调用** — 通过 `IRequest` 框架，封装签名和 HTTP 调用
2. **Feign 客户端** — 内部微服务间通过 Feign 调用
3. **MQ 异步** — 对账、结算等场景通过 RocketMQ 解耦
4. **回调 (Webhook)** — 支付通道/卡组通过回调通知结果
5. **定时任务** — 对账、余额快照通过 XXL-Job 调度

## 路径速查

### 外部集成
- `thirdparty/external/column/` — Column 支付 (73 files)
- `thirdparty/external/easypay/` — EasyPay (7 files)
- `thirdparty/external/geo/` — GEO (~30 files)
- `thirdparty/external/layer2/` — Layer2 (67 files)
- `thirdparty/external/nium/` — Nium (~40 files)
- `thirdparty/external/offline/` — 线下支付 (~20 files)
- `thirdparty/external/rd/` — RD (~15 files)
- `thirdparty/external/routefusion/` — RouteFusion (~25 files)
- `thirdparty/external/thunes/` — Thunes (~35 files)
- `thirdparty/external/tz/` — TZ (~20 files)
- `thirdparty/external/zb/` — ZB (107 files)
- `thirdparty/external/beepay/` — Beepay (~30 files)
- `thirdparty/external/pyvio/` — Pyvio (~30 files)
- `thirdparty/external/raincards/` — RainCards (~25 files)
- `thirdparty/external/bb/` — BB 卡组 (92 files)
- `thirdparty/external/i2c/` — I2C 卡组 (106 files)
- `thirdparty/external/shopline/` — Shopline 卡组 (27 files)
- `thirdparty/external/thepennyinc/` — ThePennyInc (~18 files)
- `thirdparty/external/[cobo|cregis|safeheron|okx|gate|hashkey]/` — 加密货币
- `thirdparty/external/sumsub/` — Sumsub (40 files)
- `thirdparty/external/[nameapi|plaid|qichacha|docusign]/` — KYC/合规

### 内部依赖
- `thirdparty/internal/[namescreening|notice|notify|apilayer|baidu|xe|rd|verifycode|scan2pay|crypto|beosin]/`

### 核心框架
- `thirdparty/common/request/IRequest.java` — 请求基类
- `thirdparty/common/enums/SdkUrlEnums.java` — URL 注册表
- `thirdparty/common/constant/CommonConstant.java` — SDK 签名注册
- `thirdparty/common/properties/ThirdPartyProperties.java` — 配置中心

### SDK 模块
- `qbit-assets-thirdparty/thirdparty-*/` — 8 个独立模块
