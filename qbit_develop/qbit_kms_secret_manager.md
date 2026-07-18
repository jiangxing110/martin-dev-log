# KMS / Secret Manager

## 概述

Secret Manager 是 Qbit 的密钥管理基础设施（CLAUDE.md 中记为 `kms/`，代码中为 `secretmanager/`），基于 AWS Secrets Manager 实现敏感配置的集中管理和安全解析。系统通过 Spring EnvironmentPostProcessor 机制，在应用启动阶段自动扫描并解析配置中的密钥引用，支持本地缓存、二级缓存策略、静态凭证和默认凭证链等多种凭证获取方式。

## 整体架构

```
┌──────────────────────────────────────────────────────────────────┐
│                      Spring Environment 层                        │
│  application.yml / application-{profile}.yml                     │
│  配置值中嵌入 secret 引用:                                       │
│    qsm://secretId#field                                          │
│    ${qsm:secretId#field}                                         │
└──────────────────────────┬───────────────────────────────────────┘
                           ↓
┌──────────────────────────┴───────────────────────────────────────┐
│              SecretManagerEnvironmentPostProcessor                │
│              (EnvironmentPostProcessor, HighestPrecedence + 20)   │
│                                                                  │
│  ① 绑定 qbit.secret-manager 配置                                  │
│  ② 开关关闭 → 跳过                                               │
│  ③ 扫描 Environment → 无 secret 引用 → 跳过                      │
│  ④ 存在引用 → 初始化 SecretValueResolver                          │
│  ⑤ 解析全部引用 → 高优先级 PropertySource 覆盖                    │
└──────────────────────────┬───────────────────────────────────────┘
                           ↓
┌──────────────────────────┴───────────────────────────────────────┐
│                         核心解析层                                  │
│                                                                  │
│  SecretRefParser → 识别两种格式并解析为 SecretRef                  │
│  SecretValueResolver → AWS SecretsManager 查询 + 二级缓存         │
│  SecretJsonExtractor → 从 JSON 中提取指定 field                   │
│  SecretValueCache → 内存缓存 (ConcurrentHashMap + TTL)           │
│                                                                  │
│  缓存策略:                                                        │
│  ├── 一级: fieldValueCache (secretId#field → 最终值)             │
│  └── 二级: rawSecretCache (secretId → 原始 JSON)                │
└──────────────────────────┬───────────────────────────────────────┘
                           ↓
┌──────────────────────────┴───────────────────────────────────────┐
│                      AWS Secrets Manager                          │
│  region: us-west-1 (默认)                                        │
│  凭证: 优先 AK/SK → 兜底 DefaultCredentialsProvider              │
│  Endpoint: 可选覆盖 (本地 mock / 代理)                            │
└──────────────────────────────────────────────────────────────────┘
```

## 引用格式

### 直接引用 (Direct Ref)

适用于整个配置项就是一个 secret 值：

```yaml
qbit:
  payment:
    apiKey: qsm://qbit/prod/payment#apiKey
```

### 内嵌引用 (Inline Ref)

适用于配置项中部分值为 secret：

```yaml
spring:
  datasource:
    url: jdbc:postgresql://host:5432/db
    username: ${qsm:qbit/prod/db#username}
    password: ${qsm:qbit/prod/db#password}
```

### 格式定义

```
qsm://secretId#field        → 直接引用，field 可选
${qsm:secretId#field}       → 内嵌引用，field 可选

不指定 field 时返回整个 secret 原文
指定 field 时从 secret JSON 中提取对应字段
```

## 核心组件

### SecretRef（密钥引用模型）

| 字段 | 说明 |
|------|------|
| raw | 原始引用字符串 |
| secretId | AWS Secrets Manager 中的 secretId |
| field | 可选，JSON 字段名 |

### SecretRefParser（引用解析器）

| 方法 | 说明 |
|------|------|
| `isDirectSecretRef(value)` | 判断是否为直接引用 (`qsm://` 开头) |
| `containsInlineSecretRef(value)` | 判断是否包含内嵌引用 (`${qsm:` 出现) |
| `parseDirect(value)` | 解析直接引用 |
| `parseInlineToken(token)` | 解析内嵌引用 token |

### SecretValueResolver（值解析器）

| 特性 | 说明 |
|------|------|
| 懒初始化 | 首次解析时才创建 AWS SDK Client |
| 二级缓存 | rawSecretCache + fieldValueCache |
| 并发安全 | DCL (Double-Checked Locking) 初始化 |
| 自动关闭 | @PreDestroy 关闭 AWS Client |

**解析流程：**
```
resolveSecret(SecretRef)
    ↓
① 检查 fieldValueCache (secretId#field)
   命中 → 直接返回
   未命中 →
    ↓
② 检查 rawSecretCache (secretId)
   命中 → 跳到步骤③
   未命中 → AWS API 查询 → rawSecretCache 写入
    ↓
③ SecretJsonExtractor 提取字段
    ↓
④ fieldValueCache 写入
    ↓
返回最终值
```

## 配置项

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `qbit.secret-manager.enabled` | `true` | 总开关 |
| `qbit.secret-manager.region` | `us-west-1` | AWS Region |
| `qbit.secret-manager.endpoint` | 无 | 可选，本地 mock/代理 |
| `qbit.secret-manager.fail-fast` | `true` | 解析失败是否中断启动 |
| `qbit.secret-manager.cache-enabled` | `true` | 本地缓存开关 |
| `qbit.secret-manager.cache-ttl` | `12h` | 缓存 TTL |
| `qbit.secret-manager.access-key` | 无 | 可选，静态凭证 AK |
| `qbit.secret-manager.secret-key` | 无 | 可选，静态凭证 SK |

## 缓存策略

### 二级缓存架构

```
请求: resolveSecret(secretId="qbit/prod/db", field="password")

fieldValueCache (key: "qbit/prod/db#password")
  └── 存在 → 直接返回 (避免重复 JSON 解析)
  └── 不存在 →

rawSecretCache (key: "qbit/prod/db")
  └── 存在 → JSON 解析 → fieldValueCache 写入
  └── 不存在 → AWS API 查询 → rawCache 写入 → JSON 解析 → fieldCache 写入

返回最终值
```

### 缓存特性

- 基于 `ConcurrentHashMap` 实现
- 统一 TTL 控制（默认 12 小时）
- 懒过期：get 时检查是否过期，过期则移除
- 线程安全

## 凭证获取

```
buildCredentialsProvider()
    ↓
accessKey + secretKey 都配置了？
    ↓ 是 → StaticCredentialsProvider (静态凭证)
    ↓ 否 → DefaultCredentialsProvider (默认凭证链)
         ├── EnvironmentVariableCredentialsProvider
         ├── SystemPropertyCredentialsProvider
         ├── WebIdentityTokenCredentialsProvider
         ├── ProfileCredentialsProvider
         └── InstanceProfileCredentialsProvider (EC2 IAM Role)
```

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `secretmanager/core/SecretRef.java` | Secret 引用模型 |
| `secretmanager/core/SecretRefParser.java` | 引用解析器 |
| `secretmanager/core/SecretValueService.java` | 解析服务接口 |
| `secretmanager/core/SecretValueResolver.java` | AWS 解析器实现 |
| `secretmanager/core/SecretValueCache.java` | 本地缓存 |
| `secretmanager/core/SecretJsonExtractor.java` | JSON 字段提取 |
| `secretmanager/util/SecretJsonUtils.java` | JSON 工具类 |
| `secretmanager/config/QbitSecretManagerProperties.java` | 配置属性 |
| `secretmanager/config/QbitSecretManagerAutoConfiguration.java` | 自动配置 |
| `secretmanager/env/SecretManagerEnvironmentPostProcessor.java` | 启动期解析器 |
| `secretmanager/constant/SecretManagerConstants.java` | 常量定义 |
