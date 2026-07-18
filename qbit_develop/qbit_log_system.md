# Qbit 日志体系 (Logging System)

> 基于 `qbit-assets` (Spring Boot) + `gateway` (Spring Cloud Gateway) 代码库分析。
> 日志体系涵盖应用日志、操作审计日志、API 接口日志、风控规则日志、链路追踪。
> 最后更新: 2025-06-12

---

## 1. 架构概览

### 1.1 技术栈

| 组件 | 技术 |
|------|------|
| 日志框架 | Logback (Spring Boot 默认) |
| 日志平台 | 阿里云 SLS (Log Service) |
| 链路追踪 | OpenTelemetry + MDC |
| 操作审计日志 | `operationLog` 表 (PostgreSQL) |
| API 接口日志 | `api_interface_log` 表 (PostgreSQL) |
| 风控规则日志 | `drools_rule_log` 表 (PostgreSQL) |
| 标签规则日志 | `tag_rule_log` 表 (PostgreSQL) |
| 定时同步 | XXL-Job |
| 消息追踪 | RocketMQ 消息属性透传 |

### 1.2 日志分层

```
请求入口 (Gateway)
  ├── GlobalRequestLoggingFilter — 请求体记录 + TraceId 注入
  └── GlobalLoggingFilter — 请求/响应日志 + MongoDB 持久化
       │
       ▼
qbit-core 应用
  ├── TraceIdInterceptor — OpenTelemetry Span → MDC → X-Request-Id 响应头
  ├── Logback Appenders — 文件(按级别滚动) + Console + SLS
  ├── OperationLineLogAspect — AOP 操作日志自动记录
  ├── ApiInterfaceLogService — API 接口调用日志
  ├── DroolsRuleLogsService — 风控规则执行日志
  ├── ControlWarningRuleLogService — 管控/预警规则日志
  └── TagRuleLogService — 标签规则命中日志
       │
       ▼
外部系统
  ├── 阿里云 SLS — 应用日志集中存储与查询
  ├── PostgreSQL — 结构化业务日志 (operationLog/api_interface_log/...)
  └── MongoDB (Gateway) — 网关请求日志
```

---

## 2. 链路追踪 (TraceId)

### 2.1 整体链路

```
用户请求 → Gateway(OpenTelemetry) → qbit-core(OpenTelemetry) → MQ/MQ消费端 → 下游
               │                        │                          │
               ├─ X-Trace-Id Header     ├─ X-Request-Id Response   ├─ x-trace-id UserProperty
               └─ MDC(traceId)          └─ MDC(traceId)            └─ MDC(traceId)
```

### 2.2 TraceIdInterceptor — qbit-core 入口

**路径:** `qbit-core/.../common/interceptor/TraceIdInterceptor.java`

`HandlerInterceptor`: 从 `Span.current().getSpanContext()` 获取 traceId → `MDC.put(Constant.TRACE_ID, traceId)` → `response.addHeader("X-Request-Id", traceId)`。若 OpenTelemetry traceId 不可用，调用 `HexUtil.generateTraceId()` 自生成。afterCompletion 清理 MDC。

### 2.3 TraceIdUtil — 工具类

**路径:** `qbit-core/.../common/utils/TraceIdUtil.java`

- `newTraceId()`: 使用 `IdWorker.getId()` 生成数值型 traceId
- `enter()`: 生成新 traceId 注入 MDC，返回 `AutoCloseable Scope`，try-with-resources 自动清理
- `enter(traceId)`: 使用已有 traceId 进入作用域

### 2.4 TraceMdcUtil — Gateway 侧

**路径:** `gateway/.../logger/util/TraceMdcUtil.java`

响应式环境 MDC 工具，`runWithTrace`/`getWithTrace` 模式，执行前后保存/恢复 MDC 上下文，支持 traceId + spanId 双字段。

### 2.5 MqTraceUtil — MQ 链路透传

**路径:** `qbit-core/.../mq/ons/MqTraceUtil.java`

- `inject(message)`: 发送前将 MDC traceId 写入消息属性 `x-trace-id`
- `restore(message)`: 消费端从消息属性恢复 traceId 到 MDC
- 不污染业务 DTO，消费端若消息携带 traceId 则覆盖 MDC 现有值

---

## 3. 应用日志 (Logback + SLS)

### 3.1 日志格式

```
%d{yyyy-MM-dd HH:mm:ss.SSS} %X{traceId} %X{serverIp} %X{serverName} %highlight(-%5level) %cyan(%logger{100}:%L): %msg%n
```

包含: 时间、TraceId、服务器 IP、服务器名、日志级别、Logger、行号、消息

### 3.2 Appender 配置

| Appender | 目标 | 级别 | 保留时间 |
|----------|------|------|----------|
| `DEBUG` | 滚动文件 | DEBUG | 15 天 |
| `INFO` | 滚动文件 | INFO | 30 天 |
| `WARN` | 滚动文件 | WARN | 30 天 |
| `ERROR` | 滚动文件 | ERROR | 30 天 |
| `STDOUT` | 控制台 | >= INFO | - |
| `SLS` | 阿里云 SLS | >= INFO | - |

文件命名: `${LOG_HOME}/qbit-log-{level}.%d{yyyy-MM-dd}.log`。Package logger (`com.qbit`) DEBUG 级别引用全部 Appender；Root logger INFO 级别仅 STDOUT + SLS。

### 3.3 SLS Appender (阿里云日志服务)

**路径:** `qbit-core/.../common/SlsAppender.java`

自定义 Logback Appender:

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `batchSize` | 100 | 批量发送条数 |
| `flushInterval` | 3000ms | 刷新间隔 |
| `maxRetries` | 3 | 最大重试次数 |
| `queueCapacity` | 10000 | 事件队列容量 |
| `compressionType` | LZ4 | 压缩类型 |

- 异步处理: `LinkedBlockingQueue` + 后台工作线程
- 批量发送: 满 batchSize 或达 flushInterval 触发，pendingRetryBatch 独立队列重试
- MDC 属性自动携带 (带 `mdc.` 前缀)
- 异常堆栈截断 (20000 字符)
- 优雅关闭: 停止时先处理剩余队列
- 启动时若 endpoint 为空则跳过 (本地开发兼容)

### 3.4 TruncatedMessageConverter

**路径:** `qbit-core/.../common/TruncatedMessageConverter.java`

日志消息超过 5000 字符时截断并追加 `...`。

### 3.5 TinyLog 配置

**路径:** `qbit-core/src/main/resources/tinylog.properties`

```properties
writer=file
level=info
writer.backups=7
writer.filename=log.txt
writer.policies=daily
```

备用/基础日志配置，按天轮转，保留 7 天。

---

## 4. 操作审计日志 (OperationLog)

### 4.1 概述

Qbit 最核心的业务审计日志系统，记录所有关键业务操作。

| 字段 | 类型 | 说明 |
|------|------|------|
| `userId` | String | 操作人 ID |
| `accountId` | String | 所属账户 |
| `businessType` | String | 业务类型 (~500+ 枚举值) |
| `recordId` | String | 业务记录 ID |
| `type` | String | C/U/R/D (增删改查) |
| `previousStatus` | String | 操作前状态 |
| `currentStatus` | String | 操作后状态 |
| `data` | JSONB | 操作详情 (变更内容/差异) |
| `occurrenceTime` | Timestamptz | 发生时间 |
| `comment` / `userComment` | JSONB | 系统/用户备注 |
| `operationAccountType` | String | 操作方类型 |

### 4.2 BusinessType 枚举

**路径:** `OperationLogEnums.java` (1895 行)

约 500+ 业务类型常量，覆盖量子卡、全球账户、加密资产、合规 (CDD/EDD/KYC)、风控、商户、OpenAPI 管理等全业务域。

### 4.3 自动记录机制

**OperationLineLogAspect:** AOP 切面，方法标注 `@AddOperationLineLog` 时自动记录，自动填充 userId/accountId/createTime。

**OperationLogUtils:** 3 个 `addLog` 重载方法，自动设置 `operationAccountType = ApiClient`。

### 4.4 查询接口

| 接口 | 说明 |
|------|------|
| `POST /api/log/query` | 操作日志分页查询 (从库) |
| `POST /api/log/query/login/count` | 登录次数统计 |

内部接口 (`@NoAuth(NoAuth.INTERNAL)`)

### 4.5 主库复杂查询 (OperationLogMapper.xml)

- `assetsOpen` — 资产开通统计
- `selectComplianceCddStatistics` — CDD 审核统计 (KYB/KYC/BaaS 区分)
- `selectComplianceApplyStatistics` — 各类申请统计
- `getFollowCSMAccountLog` — CSM 跟进日志
- `getRealIp` — 最后登录 IP 查询
- `billOperationLog` — 账单操作日志
- `inactiveAccountPage` — 销户记录分页

---

## 5. API 接口日志 (ApiInterfaceLog)

**表名:** `api_interface_log` | **Service:** `ApiInterfaceLogService`

**定时同步 (XXL-Job `sync_open_api_log`):** 默认同步前一天数据，支持 QueryFilterDTO 自定义时间范围。

**Mapper:** `ApiInterfaceLog.xml` — 身份验证趋势统计 (Sumsub/Plaid)、批量去重查询。

---

## 6. 风控/规则日志

### 6.1 Drools 规则执行日志 (drools_rule_log)

**Service:** `DroolsRuleLogsService`

| 关键字段 | 说明 |
|----------|------|
| `customId` | 业务 ID |
| `businessType` | 执行场景 (如 Risk_Rating) |
| `droolsRuleId` / `droolsRuleName` | 规则集合/名称 |
| `ruleGroupResult` | 规则组是否命中 |
| `ruleGroupRealTimeValue` | 规则组实时值快照 (JSON) |
| `condition` | AND/OR |
| `result` | person_check / warning_alert / auto_passed |

**查询:** LEFT JOIN transfer/account/drools_rule_group 查询评级订单及详情。

### 6.2 管控/预警规则日志

**Service:** `ControlWarningRuleLogService`

`saveControlWarningLog` (3 重载)、`saveFraudAlertHistories`、`saveControlWarningLogV2`、`getHimMessage`、`autoControlNotice`。

### 6.3 标签规则日志 (tag_rule_log)

**Mapper:** `TagRuleLogMapper.xml`

记录标签规则命中详情: 条件快照、字段值快照、命中时间、执行批次号。

---

## 7. Gateway 日志

### 7.1 GlobalRequestLoggingFilter

**优先级:** `HIGHEST_PRECEDENCE + 1`

- OpenTelemetry traceId/spanId → 注入 `X-Trace-Id`/`X-Span-Id` 请求头
- 可选记录请求体，截断过长内容
- `ServerHttpRequestDecorator` 确保请求体可重复读取

### 7.2 GlobalLoggingFilter

**优先级:** `NettyRoutingFilter.ORDER - 100`

- 请求完成后异步记录日志
- 构建 `GateWayRequestLog` → `LogDispatcherService.sendLog` (MongoDB)
- 控制台输出: 方法/URI/耗时/路由目标/异常
- 健康检查路径过滤，`onErrorResume` 捕获路由异常

### 7.3 LoggerConfig 可配置项

- `consolePrintEnabled` — 控制台日志开关
- `writeMongoEnabled` — MongoDB 持久化开关
- `ignoreBodyRoutes` / `ignorePaths` — 忽略列表
- `openProdBody` — 生产环境请求体记录

---

## 8. 定时任务

| Job Handler | 说明 | 触发 |
|-------------|------|------|
| `sync_open_api_log` | API 接口日志同步 (OpenApiLogJob) | XXL-Job，默认前一天 |
| `csm_follow_log` | CSM 跟进提醒 (FollowLogCsmJob) | 每天 9:45 GMT+8 |

---

## 9. 路径速查

| 模块 | 路径 |
|------|------|
| Logback 配置 | `qbit-core/src/main/resources/logback-spring.xml` |
| SLS Appender | `qbit-core/.../common/SlsAppender.java` |
| 消息截断 | `qbit-core/.../common/TruncatedMessageConverter.java` |
| TinyLog | `qbit-core/src/main/resources/tinylog.properties` |
| TraceIdInterceptor | `qbit-core/.../common/interceptor/TraceIdInterceptor.java` |
| TraceIdUtil | `qbit-core/.../common/utils/TraceIdUtil.java` |
| MqTraceUtil | `qbit-core/.../mq/ons/MqTraceUtil.java` |
| 操作日志枚举 | `qbit-core/.../common/enums/OperationLogEnums.java` |
| 操作日志切面 | `qbit-core/.../common/aspect/OperationLineLogAspect.java` |
| 操作日志工具 | `qbit-core/.../openapi/utils/OperationLogUtils.java` |
| 操作日志 Controller | `qbit-core/.../merchant/log/controller/OperationLogController.java` |
| 操作日志 Mapper (主) | `mapper/OperationLogMapper.xml` |
| 操作日志 Mapper (从) | `mapper/slave/OperationLogSlaveMapper.xml` |
| API 接口日志 Service | `qbit-core/.../openapi/service/ApiInterfaceLogService.java` |
| API 接口日志 Mapper | `mapper/ApiInterfaceLog.xml` |
| Drools 规则日志 Service | `qbit-core/.../drools/service/DroolsRuleLogsService.java` |
| Drools 规则日志 Mapper | `mapper/DroolsRuleLogsMapper.xml` |
| 管控规则日志 Service | `qbit-core/.../drools/service/ControlWarningRuleLogService.java` |
| 标签规则日志 Mapper | `mapper/TagRuleLogMapper.xml` |
| Gateway 请求日志 Filter | `gateway/.../filter/GlobalRequestLoggingFilter.java` |
| Gateway 日志 Filter | `gateway/.../filter/GlobalLoggingFilter.java` |
| Gateway TraceMdcUtil | `gateway/.../logger/util/TraceMdcUtil.java` |
| XXL-Job: OpenAPI 日志同步 | `qbit-core/.../job/synchronization/OpenApiLogJob.java` |
| XXL-Job: CSM 跟进通知 | `qbit-core/.../job/csm/FollowLogCsmJob.java` |
