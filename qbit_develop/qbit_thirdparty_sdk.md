# 三方 SDK 封装 (qbit-assets-thirdparty)

## 概述

`qbit-assets-thirdparty` 是 Qbit 独立的第三方 SDK 封装模块，以多模块 Maven 工程组织，为每个外部服务提供独立的 SDK 封装。涵盖交易所（OKX/Gate/HashKey）、链上安全（Chainalysis/BlockSec）、托管钱包（Safeheron）、加密库（Libsodium）以及通用 API 客户端基库。

## 模块架构

```
qbit-assets-thirdparty/
├── qbit-assets-thirdparty-api          → 通用 API 客户端基库
├── qbit-assets-thirdparty-okx          → OKX 交易所 SDK
├── qbit-assets-thirdparty-gate         → Gate.io 交易所 SDK
├── qbit-assets-thirdparty-hashkey      → HashKey 交易所 SDK
├── qbit-assets-thirdparty-chainalysis  → Chainalysis AML SDK
├── qbit-assets-thirdparty-blocksec     → BlockSec 安全 SDK
├── qbit-assets-thirdparty-safeheron    → Safeheron 托管钱包 SDK
└── qbit-assets-thirdparty-libsodium    → Libsodium 加密库
```

## 通用 API 客户端基库 (api)

### 架构

```
qbit-assets-thirdparty-api
├── ApiClient.java              → API 客户端
├── ApiAbstractClient.java      → 抽象客户端基类
├── ApiResponse.java            → API 响应封装
├── auth/
│   ├── Authentication.java     → 认证接口
│   ├── ApiKeyAuth.java         → API Key 认证
│   ├── HttpBasicAuth.java      → HTTP Basic 认证
│   └── HttpBearerAuth.java     → Bearer Token 认证
├── enums/
│   └── ParameterLocation.java  → 参数位置枚举
├── exception/
│   └── ApiException.java       → API 异常
├── model/
│   ├── RequestFile.java        → 请求文件模型
│   └── Response.java           → 响应模型
└── utils/
    └── OkHttpUtil.java         → OkHttp 工具类
```

### 认证方式

| 认证类 | 说明 |
|--------|------|
| `ApiKeyAuth` | API Key + Secret 签名认证 |
| `HttpBasicAuth` | HTTP Basic 基础认证 |
| `HttpBearerAuth` | Bearer Token 认证 |

## OKX SDK

OKX 交易所 SDK，封装行情查询、交易下单、账户管理、提现等接口。

| 组件 | 说明 |
|------|------|
| 用途 | OKX 行情、交易、提现 |
| 认证 | API Key + Secret + Passphrase |
| 支持 | 现货、合约、钱包、充提币 |

## Gate SDK

Gate.io 交易所 SDK。

| 组件 | 说明 |
|------|------|
| 用途 | Gate 行情、交易 |
| 认证 | API Key + Secret |

## HashKey SDK

HashKey 合规交易所 SDK。

| 组件 | 说明 |
|------|------|
| 用途 | HashKey 合规交易 |
| 认证 | API Key + Secret |
| 特点 | 合规定级交易所，持牌经营 |

## Chainalysis SDK

Chainalysis 链上 AML 监控 SDK，用于加密货币交易的反洗钱筛查。

| 组件 | 说明 |
|------|------|
| 用途 | 链上交易 AML 监控 |
| 功能 | 地址风险评分、交易追踪、合规报告 |

## BlockSec SDK

BlockSec 区块链安全审计 SDK。

| 组件 | 说明 |
|------|------|
| 用途 | 智能合约安全审计 |
| 功能 | 合约检测、安全分析 |

## Safeheron SDK

Safeheron 托管钱包 SDK，用于加密资产的安全托管和转账。

| 组件 | 说明 |
|------|------|
| 用途 | 加密资产托管钱包 |
| 功能 | 钱包创建、转账签名、地址管理 |

## Libsodium 加密库

基于 libsodium 的加密工具库，提供对称/非对称加密、数字签名等能力。

### 核心类

| 类 | 说明 |
|----|------|
| `Sodium` | 原生接口定义 |
| `SodiumJava` | Java 实现 |
| `LazySodium` | 懒加载封装 |
| `LazySodiumJava` | Java 懒加载实现 |

### 工具类

| 工具类 | 说明 |
|--------|------|
| `KeyPair` | 密钥对生成 |
| `Key` | 密钥管理 |
| `BaseChecker` | 基础校验 |
| `Base64Java` | Base64 编解码 |
| `Base64Facade` | Base64 门面 |
| `HexMessageEncoder` | Hex 消息编码 |
| `Base64MessageEncoder` | Base64 消息编码 |
| `DetachedEncrypt` | 分离加密 |
| `DetachedDecrypt` | 分离解密 |
| `SessionPair` | 会话密钥对 |
| `LibraryLoader` | 动态库加载 |
| `LibraryLoadingException` | 加载异常 |

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `thirdparty-api/src/main/java/.../api/ApiClient.java` | API 客户端 |
| `thirdparty-api/src/main/java/.../api/ApiAbstractClient.java` | 抽象客户端 |
| `thirdparty-api/src/main/java/.../api/ApiResponse.java` | 响应封装 |
| `thirdparty-api/src/main/java/.../api/auth/` | 认证方式（4种） |
| `thirdparty-api/src/main/java/.../api/exception/ApiException.java` | API 异常 |
| `thirdparty-okx/` | OKX SDK |
| `thirdparty-gate/` | Gate SDK |
| `thirdparty-hashkey/` | HashKey SDK |
| `thirdparty-chainalysis/` | Chainalysis SDK |
| `thirdparty-blocksec/` | BlockSec SDK |
| `thirdparty-safeheron/` | Safeheron SDK |
| `thirdparty-libsodium/` | Libsodium 加密库 |
