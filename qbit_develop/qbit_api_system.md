# Qbit API 体系 (API System)

> 基于 `gateway` (Spring Cloud Gateway) + `qbit-core` 代码库分析。
> API 体系涵盖网关路由、鉴权授权、限流、版本管理、异常处理、接口规范。
> 最后更新: 2025-06-12

---

## 1. 架构概览

### 1.1 整体拓扑

```
Client (商户/管理员/OpenAPI 调用方)
        │
        ▼
┌──────────────────────────────────────────────────┐
│              Gateway (端口 8888)                    │
│  Spring Cloud Gateway + Reactive                    │
│                                                    │
│  Global Filters:                                   │
│  GlobalIpDenyFilter → OriginalUrlEnsureFilter →    │
│  → GlobalRequestLoggingFilter → ... → NettyRouting │
│                                                    │
│  Route Filters (按路由配置):                        │
│  OpenApiTokenFilter → OpenApiAccessFilter →        │
│  OpenApiAuthRefresh → UserJwtAuth → UserRbacAuth   │
│                                                    │
│  限流: OpenApiRedisRateLimiter                     │
│  日志: GlobalLoggingFilter → MongoDB               │
│  异常: GlobalErrorWebExceptionHandler              │
└──────────────┬───────────────────────────────────┘
               │  反向代理
               ▼
┌──────────────────────────────────────────────────┐
│              qbit-core (端口 8080)                  │
│                                                    │
│  Interceptors:                                     │
│  TraceIdInterceptor → OpenApiIdempotencyInterceptor │
│                                                    │
│  Controller 层:                                    │
│  openapi/v3/**  OpenAPI V3 对外接口                │
│  openapi/**     OpenAPI V1/V2 遗留接口             │
│  admin/**       管理后台接口                        │
│  merchant/**    商户端接口                          │
│  api/log/**     日志查询接口                        │
│                                                    │
│  AOP:                                              │
│  ResponseFilterAspect → 拦截返回参数                │
│  OperationLineLogAspect → 操作日志自动记录          │
│                                                    │
│  异常处理:                                          │
│  GlobalExceptionHandler (全量)                     │
│  OpenapiV3ExceptionHandler (V3 专用)               │
└──────────────────────────────────────────────────┘
```

### 1.2 技术栈

| 组件 | 技术 |
|------|------|
| API 网关 | Spring Cloud Gateway 4.x (Reactive) |
| 服务发现 | Nacos (可禁用, 本地直连) |
| 配置中心 | Nacos (可禁用) |
| 鉴权 | JWT + Redis + Caffeine 多级缓存 |
| OpenAPI 鉴权 | Access Token (clientId/clientSecret) |
| 限流 | Redis 令牌桶 (自定义 OpenApiRedisRateLimiter) |
| 接口文档 | springdoc OpenAPI 3 (GroupedOpenApi) |
| 幂等 | Idempotency-Key 请求头 |
| 返回值 | `Result` (内部) / `ApiResult` (OpenAPI) |
| 跨域 | CORS WebFlux 过滤器 |

---

## 2. Gateway 过滤器链

### 2.1 执行顺序

| 优先级 | 过滤器 | 类型 | 说明 |
|--------|--------|------|------|
| -1 | `GlobalIpDenyFilter` | Global | IP 黑名单拦截 |
| HIGHEST_PRECEDENCE | `OriginalUrlEnsureFilter` | Global | 保存原始请求 URL |
| HIGHEST_PRECEDENCE + 1 | `GlobalRequestLoggingFilter` | Global | 请求体记录 + TraceId 注入 |
| (路由级别) | `OpenApiTokenFilter` | Route | OpenAPI access token 校验 |
| (路由级别) | `OpenApiAccessFilter` | Route | OpenAPI 客户端 IP 白名单 |
| (路由级别) | `OpenApiAuthRefresh` | Route | Refresh token 缓存缩短 |
| (路由级别) | `UserJwtAuthFilter` | Route | JWT 登录态校验 |
| (路由级别) | `UserRbacAuthFilter` | Route | RBAC 接口权限校验 |
| NettyRoutingFilter.ORDER - 100 | `GlobalLoggingFilter` | Global | 请求/响应日志 (MongoDB) |

### 2.2 GlobalIpDenyFilter

IP 黑名单全局过滤器，通过 `IpDenyManager.isBlocked(ip)` 检查，命中返回 403。

### 2.3 OriginalUrlEnsureFilter

确保 `GATEWAY_ORIGINAL_REQUEST_URL_ATTR` 存在，从 `X-Forwarded-*` 头提取对外真实 URI。

### 2.4 GlobalRequestLoggingFilter

- OpenTelemetry traceId/spanId → 注入 `X-Trace-Id`/`X-Span-Id` 请求头
- 按路由配置选择性记录请求体，`ServerHttpRequestDecorator` 保证可重复读取

### 2.5 GlobalLoggingFilter

请求完成后异步记录 `GateWayRequestLog` → MongoDB，含耗时/方法/URI/路由目标。

### 2.6 GlobalErrorWebExceptionHandler

Gateway 全局异常处理，路由异常时同样记录 MongoDB 日志并返回统一错误。

---

## 3. 鉴权体系

### 3.1 双轨鉴权

```
/open-api/* 路径 → OpenAPI 鉴权链 (Token + 访问控制 + Refresh)
其他路径      → User JWT 鉴权链 (JWT + RBAC)
```

### 3.2 OpenAPI 鉴权

**三条 Filter 工厂 (按路由配置组合):**

| 过滤器 | 职责 |
|--------|------|
| `OpenApiTokenFilter` | 解析 accessToken → 查询 `OpenApiAccessToken` 表 → 从 Redis 获取 `OpenApiClient` → 重构请求头 (X-Client-Id, X-Account-Id) |
| `OpenApiAccessFilter` | 校验 `X-Client-Id`、IP 白名单 (`IpWhiteListConfig`)、客户端状态 |
| `OpenApiAuthRefresh` | 仅用于 refresh-token 接口，Lua 脚本缩短 Redis 缓存 TTL |

**核心实体:** `OpenApiAccessToken`(令牌), `OpenApiClient`(客户端), `IpWhiteListConfig`(IP 白名单)

### 3.3 User JWT 鉴权

- **UserJwtAuthFilter:** 解析 JWT → Redis 缓存校验 → 用户信息注入 exchange
- **UserRbacAuthFilter:** 基于 RBAC 的接口权限校验

### 3.4 AuthManager 鉴权核心

```
isAccess(request, userId)
  ├─ checkUrl(url, method): Caffeine → Redis 两级判断 URL 是否需要校验
  └─ checkUserUrl(userId, url, method):
      ├─ Caffeine 缓存用户角色
      ├─ Redis 查询角色 → 回填 Caffeine
      └─ anyRoleMatch(roleIds, urlKey):
          ├─ 超级管理员直接放行
          └─ Flux.flatMap 并发查各角色 URL 权限 Set → 任意命中放行
```

**数据源:** `GateWaySystemUserRole`(用户-角色), `GateWaySystemFunction`(角色-功能-URL)

**缓存:** Caffeine (本地) + Redis (分布式)，双重缓存减少数据库压力。Redis 异常时默认拒绝 (安全优先)。

### 3.5 配置项

- `common.auth.jwt-secret` — JWT 签名密钥
- `common.auth.allow-session-if-missing` — 缺 Token 是否放行
- `common.auth.fail-open-on-redis-error` — Redis 异常时放行策略

---

## 4. 接口版本与组织

### 4.1 OpenAPI V3 (`/open-api/v3/**`)

| 域 | Controller | 主要能力 |
|----|-----------|----------|
| 账户 | `OpenApiAccountV3Controller` | 账户信息、余额 |
| 量子卡 | `OpenApiCardV3Controller` | 开卡、卡片管理、交易 |
| 持卡人 | `CardholderOpenApiV3Controller` | 持卡人管理 |
| 预算 | `BudgetOpenApiV3Controller` | 预算管理 |
| 量子账户 | `OpenApiQuantumAccountV3Controller` | 量子账户操作 |
| 全球账户 | `OpenApiGlobalAccountV3Controller` | 全球账户、汇款 |
| Crypto | 5 个 `OpenApiV3CryptoConnect*Controller` | 钱包、转账、兑换、归集、退款 |
| 付款 | `OpenApiPayoutV3Controller` | 出金付款 |
| 收款人 | `OpenApiPayeeV3Controller` | 收款人管理 |
| 业务转账 | `OpenApiBusinessTransferController` | 内部转账 |
| Webhook | `OpenApiWebhookV3CallController` | Webhook 回调管理 |
| 文件 | `OpenApiFileV3Controller` | 文件上传 |
| 对账单 | `DailyStatementController` | 日对账单 |
| 法律实体 | `OpenApiApplyLegalEntityController` | 法律实体申请 |

### 4.2 OpenAPI V1/V2 (`/open-api/**`)

出金/收款人相关遗留接口: `OpenApiPayoutController`, `OpenApiPayeeController`

### 4.3 Admin 管理后台 (`/api/admin/**`)

按业务域组织: 风控、账户、加密资产、理财、资金报表、API 客户管理、CSM 等。

### 4.4 Merchant 商户端 (`/api/**`)

商户侧业务接口及日志查询 (`/api/log/**`)。

---

## 5. API 响应与异常

### 5.1 双响应模型

| 类 | 场景 | code 类型 | 默认成功 |
|----|------|-----------|----------|
| `Result<T>` | 内部接口 | int | code=200 |
| `ApiResult<T>` | OpenAPI | String | code="000000" |

### 5.2 三层异常处理

| 层 | 处理器 | 范围 |
|----|--------|------|
| Gateway | `GlobalErrorWebExceptionHandler` | 路由异常 |
| qbit-core 全量 | `GlobalExceptionHandler` | 全量 Controller |
| qbit-core V3 | `OpenapiV3ExceptionHandler` | `com.qbit.openapi.v3` 包 |

**异常码规范:** OpenAPI V3 7 位码截取为 6 位 (PPBBCC 格式)，生产环境隐藏内部错误。

---

## 6. 幂等机制

**OpenApiIdempotencyInterceptor:**

- 请求头 `Idempotency-Key` + `accountId` + `requestUri` 三元组幂等
- 仅 POST/PUT/PATCH，`@IdempotencyIgnore` 注解跳过
- 状态: PENDING → SUCCESS/FAILED，命中 SUCCESS 直接返回缓存响应

---

## 7. OpenAPI 文档 (SwaggerConfig)

**`GroupedOpenApi` 分组:**

| 分组 | 包路径 |
|------|--------|
| Core | `com.qbit.core` |
| 加密资产 | `com.qbit.assets` |
| 粒子理财 | `com.qbit.financing.v1/v2` |
| 数据分析 | `com.qbit.analysis` |
| 资金 | `com.qbit.funding` |
| (admin) 版本 | 各域排除 `.controller.admin` |

---

## 8. 限流 (OpenApiRedisRateLimiter)

- Redis 令牌桶算法，Lua 脚本原子操作
- 按 `clientId | HTTP Method | Path` 限流 Key
- 支持 clientId 级别动态阈值 (`ReplenishRate`/`BurstCapacity`)
- 可动态开关

---

## 9. 路径速查

| 模块 | 路径 |
|------|------|
| Gateway 本地配置 | `gateway/src/main/resources/application-local.yml` |
| IP 黑名单 | `gateway/.../filter/GlobalIpDenyFilter.java` |
| 请求体日志 | `gateway/.../filter/GlobalRequestLoggingFilter.java` |
| 全局日志 | `gateway/.../filter/GlobalLoggingFilter.java` |
| Gateway 异常处理 | `gateway/.../handler/GlobalErrorWebExceptionHandler.java` |
| JWT 鉴权 | `gateway/.../filter/UserJwtAuthGatewayFilterFactory.java` |
| RBAC 鉴权 | `gateway/.../filter/UserRbacAuthGatewayFilterFactory.java` |
| AuthManager | `gateway/.../auth/manager/AuthManager.java` |
| OpenAPI Token 过滤器 | `gateway/.../filter/OpenApiTokenFilterGatewayFilterFactory.java` |
| OpenAPI 访问控制 | `gateway/.../filter/OpenApiAccessFilterGatewayFilterFactory.java` |
| OpenAPI 限流器 | `gateway/.../openapi/ratelimit/OpenApiRedisRateLimiter.java` |
| CORS | `gateway/.../config/CorsGlobalConfiguration.java` |
| API 内部响应 | `qbit-core/.../common/utils/Result.java` |
| API OpenAPI 响应 | `qbit-core/.../common/utils/ApiResult.java` |
| 响应拦截 AOP | `qbit-core/.../common/aspect/ResponseFilterAspect.java` |
| 全局异常处理 | `qbit-core/.../core/exception/GlobalExceptionHandler.java` |
| V3 异常处理 | `qbit-core/.../core/exception/OpenapiV3ExceptionHandler.java` |
| Swagger 配置 | `qbit-core/.../core/config/SwaggerConfig.java` |
| 幂等拦截器 | `qbit-core/.../common/interceptor/OpenApiIdempotencyInterceptor.java` |
| OpenAPI V3 控制器 | `qbit-core/.../openapi/v3/*/controller/` |
| OpenAPI V1 控制器 | `qbit-core/.../openapi/payout/controller/` |
| Admin 风控 | `qbit-core/.../admin/risk/controller/` |
| OpenAPI Token 实体 | `gateway/.../openapi/accesstoken/domain/entity/OpenApiAccessToken.java` |
| OpenAPI Client 实体 | `gateway/.../openapi/accesstoken/domain/entity/OpenApiClient.java` |
