# Qbit 权限体系文档

> 整理时间: 2026-06-12
> 涉及项目: qbit-assets (gateway + qbit-core), pay-core, scan2pay-server, white-label-server

---

## 1. 整体架构概览

Qbit 权限体系跨多个系统，分为四层：

```
┌─────────────────────────────────────────────────────────────────┐
│                   qbit-assets Gateway (API 网关)                  │
│   JWT 鉴权 → RBAC URL 鉴权 → 路由到后端                           │
│   过滤器链: UserJwtAuth → UserRbacAuth → OpenApiToken/Access     │
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│                   qbit-assets Core (主体应用)                     │
│   AuthorityAspect (AOP) + SystemRole/Menu/Function RBAC         │
│   数据权限 (DataScopeTypeEnum + Department)                      │
└──────┬──────────────┬──────────────────┬────────────────────────┘
       │              │                  │
┌──────▼─────┐ ┌──────▼──────┐ ┌────────▼──────────┐
│  pay-core   │ │ scan2pay    │ │ white-label-server │
│ AuthInter-  │ │ AuthInter-  │ │ Spring Security +  │
│ ceptor +    │ │ ceptor +    │ │ 独立 RBAC 体系     │
│ OpenAPI Auth│ │ OpenAPI Auth│ │ (t_rbac_*)        │
└────────────┘ └─────────────┘ └───────────────────┘
```

---

## 2. qbit-assets Gateway 网关鉴权体系

### 2.1 过滤器链

Gateway 通过 Spring Cloud Gateway 的 `GatewayFilterFactory` 实现鉴权，在路由配置中组合使用：

```
请求 → GlobalIpDenyFilter → UserJwtAuth → UserRbacAuth → OpenApiTokenFilter → OpenApiAccessFilter → 路由后端
```

#### UserJwtAuthGatewayFilterFactory

- 职责: JWT 登录态校验 + Session 校验
- 流程: 解析 `Authorization` 头 → JWT 解密提取 userId → Redis 校验 session token → 加载用户信息 (Redis 缓存 + DB 兜底)

```java
// 关键步骤
1. resolveUserContext(request)       // 解析 token -> userId
2. verifySession(ctx)                // Redis GET session token，比对是否一致
3. loadUserDto(userId)               // 从 Redis/DB 加载 GateWayUserDTO
```

- 校验通过后将 `GateWayUserDTO` 存入 `exchange.getAttributes()` → `GW_INTERLACE_LOGIN_USER`
- 配置项:
  - `common.auth.jwtSecret`: JWT 签名密钥
  - `common.auth.allowSessionIfMissing`: Session 不存在时是否放行（迁移期用）
  - `common.auth.failOpenOnRedisError`: Redis 异常时是否放行

#### UserRbacAuthGatewayFilterFactory

- 依赖: 必须配合 `UserJwtAuthGatewayFilterFactory` 使用，从 exchange 属性中读取 `LOGIN_USER_ID`
- 流程: 调用 `AuthManager.isAccess(request, userId)` 判断是否有权限
- 无权限 → `403 FORBIDDEN`
- 无 userId → `401 UNAUTHORIZED`

#### OpenApiTokenFilterGatewayFilterFactory

- 职责: OpenAPI 接口的 Token 鉴权
- 流程: 解析 OpenApiAccessToken → 重构请求头 (注入 clientId, accountId) → 以 client 的 Master 用户身份调用 AuthManager 进行权限校验
- Redis 缓存 OpenApiClient 信息 (TTL 1天)

#### OpenApiAccessFilterGatewayFilterFactory

- 职责: OpenAPI IP 白名单校验
- 流程: 获取 clientId → 查询关联 accountId → 查询该账户的 IP 白名单 → 校验请求来源 IP
- 缓存: Caffeine (本地) + Redis 二级缓存

### 2.2 AuthManager 鉴权核心

**位置**: `gateway/.../business/auth/manager/AuthManager.java`

核心方法 `isAccess(request, userId)`:

```
isAccess(request, userId)
  ├── checkUrl(url, method)         // 该 URL 是否需要鉴权
  │     ├── Caffeine 缓存查询       // useCaffeine=true 时优先
  │     ├── Redis 缓存查询 (5min TTL)
  │     └── DB: system_function 表 checkType=1 ?
  │
  └── checkUserUrl(userId, url, method)  // 用户是否有权限
        ├── 获取用户角色列表 (Redis/DB)
        ├── 超级管理员? → 直接放行
        └── anyRoleMatch(roles, urlKey)
              └── 每个角色查询 URL Set 是否包含该 URL
                    ├── Caffeine 缓存 (60min TTL, 20万上限)
                    └── Redis 缓存 (5min TTL) → DB 兜底
```

**关键设计**:
- 任意角色匹配到 URL 即放行（短路）
- 超级管理员配置 `superRoleId`，完全绕过权限检查
- 并发控制 `roleUrlFetchConcurrency` (默认4) 防止 Redis 放大

### 2.3 网关数据模型

| 表 | 实体 | 说明 |
|-----|------|------|
| `system_function` | `GateWaySystemFunction` | URL 接口定义。`checkType`: 0=不校验, 1=校验权限 |
| `system_user_role` | `GateWaySystemUserRole` | 用户-角色关联 (userId + roleId) |
| `"user"` | `GateWayUser` | 用户表 (phone, email, userType, systemType, status) |
| `"accountUser"` | `GateWayAccountUser` | 账户-用户关联 (accountId + userId + roleId) |

### 2.4 网关用户类型

```java
public enum UserTypeEnum {
    Master,             // 主用户
    Robot,              // 机器人
    OperationManager,   // 运营管理员
    Admin,              // 管理员
    Employee            // 员工
}
```

### 2.5 缓存架构

网关采用 **Caffeine (本地) + Redis (分布式)** 二级缓存：

| 缓存内容 | Caffeine TTL | Redis TTL | 说明 |
|---------|-------------|-----------|------|
| 用户→角色列表 | 15min | 5min | 50万上限 |
| 角色→URL集合(Set) | 60min | 5min | 20万上限, O(1)查询 |
| URL→是否需要鉴权 | 120min | 5min | 50万上限, MQ失效 |
| 用户信息(Auth Token) | ✗ | 正缓存1天/负缓存30s | Redis优先, DB兜底 |
| Session Token | ✗ | Session TTL | 强制Redis校验 |

---

## 3. qbit-assets Core 核心权限体系

### 3.1 AuthorityAspect 权限切面

**位置**: `qbit-core/.../common/aspect/AuthorityAspect.java`

通过 AOP 拦截所有 `*Controller` 方法，实现接口级权限校验：

```java
@Pointcut("execution(* com.qbit..*Controller.*(..))")
```

**流程**:
```
before(joinPoint)
  ├── 超级管理员(SuperAdmin) → 直接放行
  ├── NoAuth(INTERNAL) → 放行（内部调用）
  ├── NoAuth(OPENAPI) → 校验 access token 有效性
  ├── URL 白名单 (SKIP_CHECK_URLS) → 放行
  ├── 查询该 URL 是否需要校验 (checkType=1?)
  ├── 页面路由校验 pageCheck(route-path, url) ← 校验前端路由是否有该 URL 权限
  └── 遍历用户角色→URL列表 → 匹配成功放行, 否则 403
```

**skip URLs**: 内置约12个免校验地址（菜单路由、部门列表等）

### 3.2 Core RBAC 数据模型

| 表 | 实体 | 说明 |
|-----|------|------|
| `system_role` | `SystemRole` | 角色。含 name, code, status, dataScopeType, platformType |
| `system_user_role` | `SystemUserRole` | 用户-角色关联 (userId + roleId) |
| `system_role_menu` | `SystemRoleMenu` | 角色-菜单关联 (roleId + menuId) |
| `system_menu` | `SystemMenu` | 菜单/按钮。type: DIRECTORY/MENU/BUTTON/TAB, permission 为权限key |
| `system_function` | `SystemFunction` | URL 接口定义。checkType: 0=不校验, 1=校验权限 |
| `department` | `Department` | 部门。支持层级 (pid), 用于数据权限过滤 |

### 3.3 菜单权限 (Menu Permission)

`SystemMenu` 采用四级类型：
- `DIRECTORY(0)`: 目录
- `MENU(1)`: 菜单页面
- `BUTTON(2)`: 页面按钮/操作
- `TAB(3)`: 页签

`permission` 字段命名规则: `系统:模块:操作`，如 `DEVELOPMENT-INTEGRATION_SETTINGS-SECRET_KEY-DETAILS`

`pageCheck` 机制: 请求头 `route-path` → 查询 SystemMenu → 校验该菜单/子按钮是否配置了该 URL → 没有则拒绝

### 3.4 角色数据范围 (DataScope)

```java
public enum DataScopeTypeEnum {
    ALL(1),             // 全部数据
    DEPT_CUSTOM(2),     // 指定部门
    DEPT_ONLY(3),       // 仅所在部门
    DEPT_AND_CHILD(4),  // 部门及以下
    SELF(5)             // 仅自己
}
```

`SystemRole` 中的 `dataScopeDeptIds` 存储指定部门的 ID 列表（逗号分隔）。

### 3.5 PermissionEnum 权限枚举

```java
public enum PermissionEnum {
    DEVELOPMENT_INTEGRATION_SETTINGS_SECRET_KEY_DETAILS("DEVELOPMENT-INTEGRATION_SETTINGS-SECRET_KEY-DETAILS"),
    DEVELOPMENT_INTEGRATION_SETTINGS_SECRET_KEY_CREATE("DEVELOPMENT-INTEGRATION_SETTINGS-SECRET_KEY-CREATE"),
    // ... 更多
}
```

---

## 4. white-label-server RBAC 权限体系

### 4.1 架构

white-label-server 拥有**独立完整**的 RBAC 权限系统，与 qbit-assets 的权限体系分离：

```
Spring Security Filter Chain
  └── JwtAuthenticationFilter (登录认证)
        └── BaseAuthorizationManager (授权决策)
              └── 自定义 RBAC 实现 (t_rbac_* 表)
```

### 4.2 JWT 登录认证

**位置**: `middleware/spring-boot-starter-jwt-auth`

**登录端点**: `POST /{appType}/api/v1/auth/login/{loginMethod}`

- `loginMethod`: 支持多种登录方式（账号密码、OTP 等）
- `appType`: ADMIN / MEMBER
- 认证成功返回: `accessToken` + `refreshToken` (JWT 双 Token)
- Token 中封装 `JwtUser` 信息

**JwtAuthenticationFilter** 继承 `AbstractAuthenticationProcessingFilter`:
1. 解析路径变量获取 loginMethod 和 appType
2. 构建 `JwtAuthenticationToken` (未认证)
3. 调用 `AuthenticationManager` 认证
4. 成功 → 生成 JWT Token → 返回 TokenResponse
5. 失败 → 返回错误信息

### 4.3 Spring Security 授权

**BaseAuthorizationManager**: 自定义授权管理器接口，继承 `AuthorizationManager<RequestAuthorizationContext>`：

```java
public interface BaseAuthorizationManager extends AuthorizationManager<RequestAuthorizationContext> {
    boolean hasPermission(Authentication authentication, HttpServletRequest request,
                         String requestPath, String httpMethod);
}
```

实现 `check()` 方法，由 Spring Security 自动调用进行授权决策。

### 4.4 RBAC 数据模型 (MyBatis-Flex)

| 表 | 实体 | 说明 |
|-----|------|------|
| `t_rbac_role` | `RbacRole` | 角色。roleCode, roleName, roleType(SYSTEM/BUSINESS/CUSTOM), parentId, roleLevel |
| `t_rbac_resource` | `RbacResource` | 资源。resourceCode, resourceType(MENU/BUTTON/API), resourceUrl, operation |
| `t_rbac_user_role` | `RbacUserRole` | 用户-角色关联 (userId + roleId) |
| `t_rbac_role_resource` | `RbacRoleResource` | 角色-资源直接关联。grantType(GRANT/DENY), limitedOperations, 支持有效期 |

### 4.5 关键设计

- **直接关联**: 角色 ↔ 资源直接关联，去除中间权限层
- **拒绝优先**: `GrantTypeEnum.DENY` 支持显式拒绝，覆盖 GRANT
- **操作限制**: `limitedOperations` 限制角色对资源的具体操作（READ/WRITE/DELETE/EXECUTE/MANAGE）
- **有效期**: `effectiveTime` / `expireTime` 支持临时授权
- **角色层级**: `parentId` + `roleLevel` 支持角色继承

### 4.6 RbacUserPermissionService

```java
public interface RbacUserPermissionService {
    List<RbacRoleDTO> getUserRoles(Long userId);                    // 获取用户角色
    List<RbacResourceDTO> getUserResources(Long userId);            // 获取用户资源权限
    List<RbacResourceTreeDTO> getUserResourceTree(Long userId);     // 资源树形结构
    boolean hasRole(Long userId, String roleCode);                  // 检查角色
    boolean hasResourceAccess(Long userId, String resourcePath, String httpMethod); // 检查资源访问
}
```

### 4.7 枚举

| 枚举 | 值 |
|------|------|
| `RoleTypeEnum` | SYSTEM, BUSINESS, CUSTOM |
| `ResourceTypeEnum` | MENU, BUTTON, API |
| `GrantTypeEnum` | GRANT, DENY |
| `OperationEnum` | READ, WRITE, DELETE, EXECUTE, MANAGE |
| `HttpMethodEnum` | GET, POST, PUT, DELETE, PATCH |
| `StatusEnum` | DISABLED, ENABLED |

---

## 5. pay-core 鉴权体系

### 5.1 AuthInterceptor (Admin/Merchant)

**位置**: `pay/common/.../interceptor/AuthInterceptor.java`

`HandlerInterceptor` 实现，拦截 Admin 和 Merchant 端请求：

```
preHandle(request)
  ├── 解析 Authorization Token
  ├── Redis 缓存查询 (1h TTL)
  │     └── 格式: QBIT_USER_AUTH_TOKEN + authToken + isAdminRequest
  ├── Miss → 调用 qbit-assets 内部 API 获取认证信息
  │     ├── isAdminRequest → getAdminLogin(authToken) → InnerAuthAdminVO
  │     └── !isAdminRequest → getMerchantLogin(authToken) → User + AccountMap
  ├── 设置 UserContext (FastThreadLocal)
  └── 解析 TenantContext → TenantContextHolder
```

Admin 和 Merchant 的用户模型不同:
- Admin: 直接序列化为 `User` 对象
- Merchant: 包含 `data.innerAuthUser.accountInfo.accountMap` 层级，需解析 `accountMapId`

### 5.2 InternalAuthInterceptor (内部API)

**位置**: `pay/integration/.../interceptor/InternalAuthInterceptor.java`

基于 HMAC-SHA 签名校验的内部接口鉴权：

```
headers: x-sign, x-nonce-str, x-timestamp
签名算法: SHA256(method + url + timestamp + nonce + body) @ 共享密钥
```

- 时间戳 5 分钟内有效
- Nonce 长度 ≥ 32 位

### 5.3 OpenApiAuthInterceptor

**位置**: `pay/open-api/.../aop/OpenApiAuthInterceptor.java`

流程:
1. 从 Header 获取 token (`x-access-token` / `x-ipeakoin-access-token`)
2. Redis 缓存查询 (1h TTL)
3. Miss → 调用 qbit-assets 节点 API 校验 token
4. 解析返回的 `SessionUserDTO` → 设置 `OpenApiUserContext`
5. 解析 `TenantContext`

---

## 6. scan2pay-server 鉴权体系

### 6.1 AuthInterceptor (Admin/Merchant)

**位置**: `app-web-common/.../config/AuthInterceptor.java`

与 pay-core 的 AuthInterceptor 类似:

```
preHandle(request)
  ├── 解析 Authorization Token
  ├── Redis 缓存查询 (1h TTL)
  ├── Miss → 调用 qbit-assets 内部 API
  │     ├── isAdminRequest → getAdminLogin(authToken)
  │     └── !isAdminRequest → getMerchantLogin(authToken)
  └── 设置 UserContext (FastThreadLocal)
```

### 6.2 OpenApiAuthInterceptor

**位置**: `app-web-openapi/.../config/OpenApiAuthInterceptor.java`

流程:
1. 从 Header 获取 token (`x-access-token` / `x-ipeakoin-access-token` / `x-qbit-access-token`)
2. Redis 缓存查询
3. Miss → `accessTokenService.getAccessToken(authToken)` 校验
4. 校验商户状态 (`merchantInfoService.getMerchantInfoByUuid`)
5. 解析租户
6. 设置 `OpenApiUserContext`
7. 根据 `systemType` 设置国际化语言环境 (英文/中文)

---

## 7. 平台类型体系 (PlatformType)

`PlatformTypeEnum` (qbit-assets Core) 和 `GateWayPlatformTypeEnum` (Gateway) 定义了所有平台类型，两者结构一致：

| 值 | 枚举 | 说明 |
|-----|------|------|
| 0 | ADMIN | Qbit Admin 管理端 |
| 1 | MERCHANT | 商户端 |
| 2 | IPEAKOIN | iPeakoin 海外版 |
| 3 | CHANNEL_ADMIN | 渠道方管理端 |
| 4 | WHITE_LABEL_ADMIN | 白标系统 Admin |
| 5 | WHITE_LABEL_MERCHANT | 白标系统商户端 |
| 6 | REBATE_ADMIN | 渠道返佣 Admin |
| 7 | INTERLACE_ADMIN | Interlace 海外版后台 |
| 8 | CHANNEL_ADMIN_INTERLACE | 渠道方海外版后台 |
| 9 | WHITE_LABEL_CHANNEL_ADMIN | 白标渠道方后台 |
| 10 | ACQUIRING_ADMIN | 收单后台 |
| 11 | ACQUIRING_AGENT_ADMIN | 收单代理商后台 |
| 12 | ACQUIRING_ISP_ADMIN | 收单机构后台 |
| 13 | ACQUIRING_AGENT_ADMIN_INTERLACE | 收单代理商海外版 |
| 14 | ACQUIRING_ISP_ADMIN_INTERLACE | 收单机构海外版 |
| 15 | OPEN_API | Open API |
| 16 | DISTRIBUTOR_WEB | 分发商 |

`AccountSystemTypeEnum` 区分系统版本:
- `QBIT`: 大陆版
- `QbitInternational`: 国际版 (iPeakoin)

---

## 8. 数据权限体系

`DataScopeTypeEnum` 定义了 5 级数据范围:

```
ALL(1)            全部数据 ─── 无限制
DEPT_CUSTOM(2)    指定部门 ─── role.dataScopeDeptIds 指定
DEPT_ONLY(3)      所在部门 ─── 仅用户所属部门
DEPT_AND_CHILD(4) 部门及以下 ── 部门及其子部门
SELF(5)           仅自己 ─── 仅自己的数据
```

`Department` 表通过 `pid` 维护部门层级关系。
`DataPermission` 类定义了字段级别的数据权限控制 (field + fieldType + value)。

> 注: qbit-assets Core 的数据权限实现（RoleDataPermission 部分）处于半完成状态，`UserContext.getUserPermission()` 目前返回空 Map

---

## 9. 超级管理员机制

所有系统均有超级管理员概念：

| 系统 | 机制 | 说明 |
|------|------|------|
| qbit-assets Gateway | `GateWayAuthProperties.superRoleId` | 配置超级管理员 roleId，该角色下的用户完全绕过鉴权 |
| qbit-assets Core | `User.isSuperAdmin()` | User 实体标记 `superAdmin=true` 时，AuthorityAspect 跳过所有校验 |
| pay-core | `SpecialRoleEnums.SYSTEM("0")` | 系统角色 ID 为 "0" |

---

## 10. 鉴权缓存体系全景

```
请求到达
  │
  ├─ JWT Token → Redis Session 校验 (强制)
  │     └─ 用户信息缓存: Redis (1天) → DB (负缓存30s防穿透)
  │
  ├─ URL 是否需要鉴权
  │     ├─ Caffeine (120min, 50万)
  │     └─ Redis (5min) → DB (system_function)
  │
  ├─ 用户→角色列表
  │     ├─ Caffeine (15min, 50万)
  │     └─ Redis (5min) → DB (system_user_role)
  │
  ├─ 角色→URL Set
  │     ├─ Caffeine (60min, 20万, O(1) contains)
  │     └─ Redis (5min) → DB (system_role_menu + system_function)
  │
  └─ 缓存失效机制 (MQ 驱动)
        ├─ URL 鉴权变更 → updateUrlCheckAuthority()
        ├─ 角色权限变更 → deleteRoleUrls()
        └─ 用户角色变更 → deleteUserRoles()
```

---

## 11. 各系统鉴权对比

| 维度 | qbit-assets | pay-core | scan2pay-server | white-label-server |
|------|------------|----------|----------------|-------------------|
| **认证方式** | JWT + Redis Session | Token + Redis | Token + Redis | JWT (Spring Security) |
| **授权模型** | RBAC (URL级别) | 无独立授权 | 无独立授权 | RBAC (完整) |
| **拦截方式** | Gateway Filter | HandlerInterceptor | HandlerInterceptor | Spring Security Filter |
| **Auth缓存** | Caffeine + Redis | Redis | Redis | 自定义JWT |
| **数据权限** | DataScopeTypeEnum | 无 | 无 | 无 |
| **OpenAPI** | Token + IP白名单 | Token + 远程校验 | Token + 远程校验 | 无 |
| **内部API** | NoAuth注解 | HMAC签名 | 无 | 无 |

---

## 12. 关键枚举汇总

| 枚举 | 值 |
|------|------|
| `UserTypeEnum` (Gateway) | Master, Robot, OperationManager, Admin, Employee |
| `PlatformTypeEnum` | ADMIN(0) ~ DISTRIBUTOR_WEB(16) 共 17 种 |
| `AccountSystemTypeEnum` | QBIT(大陆版), QbitInternational(国际版) |
| `MenuTypeEnum` | DIRECTORY(0), MENU(1), BUTTON(2), TAB(3) |
| `DataScopeTypeEnum` | ALL(1), DEPT_CUSTOM(2), DEPT_ONLY(3), DEPT_AND_CHILD(4), SELF(5) |
| `StatusTypeEnum` | 0=正常, 1=停用 |
| `RoleTypeEnum` (WL) | SYSTEM, BUSINESS, CUSTOM |
| `ResourceTypeEnum` (WL) | MENU, BUTTON, API |
| `GrantTypeEnum` (WL) | GRANT, DENY |
| `OperationEnum` (WL) | READ, WRITE, DELETE, EXECUTE, MANAGE |
| `SpecialRoleEnums` | SYSTEM("0") |
| `Permission` (scan2pay) | PUBLIC(0), PRIVATE(1), GROUP(2) |
