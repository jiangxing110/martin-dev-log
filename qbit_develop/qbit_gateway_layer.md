# 网关层

## 概述

网关层基于 Spring Cloud Gateway 构建，是 Qbit 系统的 API 统一入口，负责请求路由、认证鉴权、IP 黑白名单、日志记录、限流熔断等横切关注点。支持商户端、管理端、OpenAPI 三种流量入口的统一治理。

## 整体架构

```
┌──────────────────────────────────────────────────────────────────┐
│                        客户端请求                                  │
│  商户端 / 管理端 / OpenAPI                                        │
└─────────────────────────┬────────────────────────────────────────┘
                          │
┌─────────────────────────▼────────────────────────────────────────┐
│                      Gateway 网关层                                │
│                                                                  │
│  GlobalIpDenyFilter → IP 黑名单拦截                               │
│  GlobalLoggingFilter → 全局日志记录                               │
│  GlobalRequestLoggingFilter → 请求日志记录                        │
│                                                                  │
│  OpenApiTokenFilter → OpenAPI 令牌认证                            │
│  OpenApiAuthRefreshFilter → OpenAPI 认证刷新                      │
│  OpenApiAccessFilter → OpenAPI 访问控制                           │
│                                                                  │
│  UserJwtAuthFilter → JWT 用户认证                                 │
│  UserRbacAuthFilter → RBAC 权限校验                               │
│                                                                  │
│  OriginalUrlEnsureFilter → 原始 URL 保留                          │
│                                                                  │
│  GlobalErrorWebExceptionHandler → 全局异常处理                    │
└─────────────────────────┬────────────────────────────────────────┘
                          │
┌─────────────────────────▼────────────────────────────────────────┐
│                       后端服务                                     │
│  qbit-core (8080) / 第三方服务                                     │
└──────────────────────────────────────────────────────────────────┘
```

## 过滤器链

网关采用责任链模式，请求按顺序经过以下过滤器：

```
请求进入
    ↓
① GlobalIpDenyFilter
   IP 黑名单检查（内存缓存 + Redis）
   拒绝恶意 IP
    ↓
② GlobalLoggingFilter
   全局请求日志（请求方法、路径、耗时、状态码）
    ↓
③ GlobalRequestLoggingFilter
   详细请求日志（Header、Body、参数）
    ↓
④ 路由匹配
   ↓ 商户端路径         ↓ 管理端路径         ↓ OpenAPI 路径
   UserJwtAuthFilter → UserJwtAuthFilter → OpenApiTokenFilter
   UserRbacAuthFilter → UserRbacAuthFilter → OpenApiAccessFilter
   ↓                   ↓                   ↓
   ⑤ 转发到后端服务
    ↓
⑥ GlobalErrorWebExceptionHandler (异常时)
   统一错误响应
```

### 过滤器详解

| 过滤器 | 优先级 | 说明 |
|--------|--------|------|
| `GlobalIpDenyFilter` | 最高 | IP 黑名单拦截，基于内存 + Redis |
| `GlobalLoggingFilter` | 高 | 全局请求日志（Method/URI/Status/耗时） |
| `GlobalRequestLoggingFilter` | 高 | 详细请求日志（请求体、请求头） |
| `OpenApiTokenFilterGatewayFilterFactory` | 中 | OpenAPI 令牌认证，校验 API Key + Signature |
| `OpenApiAuthRefreshGatewayFilterFactory` | 中 | OpenAPI 认证缓存刷新 |
| `OpenApiAccessFilterGatewayFilterFactory` | 中 | OpenAPI 访问控制（IP 白名单、频率限制） |
| `UserJwtAuthGatewayFilterFactory` | 中 | JWT 用户令牌认证 |
| `UserRbacAuthGatewayFilterFactory` | 中 | RBAC 权限校验 |
| `OriginalUrlEnsureFilter` | 低 | 保留原始请求 URL |

## 业务模块

### auth（认证）

- 认证逻辑：JWT 生成/验证、API Key 管理
- 会话管理：Redis 会话缓存

### common（公共）

- 公共过滤器共享逻辑
- 工具类和常量

### ip（IP 管理）

- IP 黑名单维护
- IP 地理信息
- IP 频率统计

### logger（日志）

- 请求日志格式定义
- 日志采集和上报

### mq（消息）

- 网关层 MQ 消息发送
- 异步日志处理

### openapi（OpenAPI）

- OpenAPI 客户端管理
- API Key 校验
- 签名计算和验证

## 路由配置

| 路由 | 目标服务 | 说明 |
|------|---------|------|
| `/merchant/**` | qbit-core | 商户端 |
| `/admin/**` | qbit-core | 管理端 |
| `/openapi/**` | qbit-core | OpenAPI |
| `/v3/**` | qbit-core | API V3 |

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `gateway/filter/GlobalIpDenyFilter.java` | IP 黑名单 |
| `gateway/filter/GlobalLoggingFilter.java` | 全局日志 |
| `gateway/filter/GlobalRequestLoggingFilter.java` | 请求日志 |
| `gateway/filter/UserJwtAuthGatewayFilterFactory.java` | JWT 认证 |
| `gateway/filter/UserRbacAuthGatewayFilterFactory.java` | RBAC 权限 |
| `gateway/filter/OpenApiTokenFilterGatewayFilterFactory.java` | OpenAPI 令牌 |
| `gateway/filter/OpenApiAuthRefreshGatewayFilterFactory.java` | API 认证刷新 |
| `gateway/filter/OpenApiAccessFilterGatewayFilterFactory.java` | API 访问控制 |
| `gateway/filter/OriginalUrlEnsureFilter.java` | 原始 URL |
| `gateway/handler/GlobalErrorWebExceptionHandler.java` | 全局异常 |
| `gateway/business/auth/` | 认证业务 |
| `gateway/business/common/` | 公共业务 |
| `gateway/business/ip/` | IP 管理 |
| `gateway/business/logger/` | 日志管理 |
| `gateway/business/mq/` | MQ 消息 |
| `gateway/business/openapi/` | OpenAPI 业务 |
| `gateway/config/` | 网关配置 |
| `gateway/exception/` | 异常定义 |
| `gateway/util/` | 工具类 |
