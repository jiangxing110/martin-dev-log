# 核心系统 (Core)

## 概述

Core 是 Qbit 的框架基础层，为所有业务模块提供公共基础设施支撑，包括全局配置管理、安全认证、异常处理体系、注解驱动的数据权限/操作日志、事件驱动机制、清算结算、通用服务等。是 qbit-core 应用的中枢骨架。

## 整体架构

```
┌──────────────────────────────────────────────────────────────────┐
│                       全局配置层                                    │
│  RedisConfig / RedissonConfig / DataSourceConfig / DroolsConfig   │
│  CorsConfig / JsonConfig / I18nConfig / SwaggerConfig            │
│  AsyncThreadPoolConfig / RestTemplateConfig / OkHttpConfig       │
│  CustomExceptionConfiguration / ModelMapperConfig / CaptchaConfig│
│  QbitProperties / QbitMetaObjectHandler                          │
├──────────────────────────────────────────────────────────────────┤
│                       安全认证层                                    │
│  security/jwt/ → JWT 认证                                        │
│  security/captchas/ → 验证码                                     │
│  security/google/ → Google Authenticator                         │
├──────────────────────────────────────────────────────────────────┤
│                       异常处理层                                    │
│  GlobalExceptionHandler → 全局异常处理                            │
│  OpenapiV3ExceptionHandler → OpenAPI 异常处理                     │
│  ExceptionCodeFactory → 业务异常工厂                              │
│  CustomerException / CustomException                              │
├──────────────────────────────────────────────────────────────────┤
│                       注解体系                                      │
│  @DataScope / @DataScopeTenant → 数据权限                         │
│  @IOperationLog → 操作日志                                       │
│  @IUser / @IAccount → 当前用户/账户注入                          │
│  @DailyStatementScope → 日结范围                                 │
│  @ScanForSubdomain → 子域扫描                                    │
├──────────────────────────────────────────────────────────────────┤
│                       通用服务层                                    │
│  RedisService / IdempotentService / ExportService                │
│  HttpService / PaymentTypeService / SystemTagsService             │
│  AccountBusinessStatusService / RefusalRateService                │
│  ApnsPushService / BusinessMaterialRequestService                 │
│  OpenApiWebHookDataService / QbitStatementService                 │
│  SupplierTransactionService / ExchangeRateDifferenceRecordService │
├──────────────────────────────────────────────────────────────────┤
│                       事件驱动层                                    │
│  TransactionChangeEvent / TransactionCreateEvent                  │
│  BalanceNegativeEvent / BusinessAccountEvent                     │
│  MonthBillExportEvent / CardCreatedEventListener                 │
│  apn/ → APN 事件                                                  │
├──────────────────────────────────────────────────────────────────┤
│                       清算结算层 (clear)                            │
│  handler/ → 清算处理器                                           │
│  publisher/ → 清算事件发布                                       │
│  service/ → 清算服务                                             │
│  model/ → 清算模型                                               │
├──────────────────────────────────────────────────────────────────┤
│                       AOP 通知层 (Advice)                          │
│  RequestLoggerAdvice → 请求日志记录                               │
│  AssetsTransferHook → 资产转账钩子                               │
│  FinancingTransferHook → 融资转账钩子                             │
└──────────────────────────────────────────────────────────────────┘
```

## 全局配置

| 配置类 | 说明 |
|--------|------|
| `DataSourceConfig` | 多数据源配置（PostgreSQL 主从） |
| `RedisConfig` | Redis 连接与序列化配置 |
| `RedissonConfig` | Redisson 分布式锁配置 |
| `DroolsAutoConfiguration` | Drools 规则引擎配置 |
| `CorsConfig` | 跨域配置 |
| `JsonConfig` | Jackson 全局序列化配置（Long 转 String 等） |
| `I18nConfig` | 国际化配置 |
| `SwaggerConfig` | SpringDoc OpenAPI 配置 |
| `AsyncThreadPoolConfig` | 异步线程池配置 |
| `AsyncTaskDecorator` | 异步任务上下文传递 |
| `RestTemplateConfig` | HTTP 客户端配置 |
| `OkHttpConfig` | OkHttp 客户端配置 |
| `CaptchaConfig` | 验证码配置 |
| `CustomExceptionConfiguration` | 异常配置 |
| `ModelMapperConfig` | 对象映射配置 |
| `QbitProperties` | 应用全局属性 |
| `QbitMetaObjectHandler` | MyBatis-Plus 元对象处理器（自动填充 createTime/updateTime） |
| `QbitRequestWrapper` | 请求包装器 |

## 安全认证

### JWT

| 组件 | 说明 |
|------|------|
| `security/jwt/CustomerAccessDeniedHandler.java` | 访问拒绝处理器 |
| `security/jwt/CustomerAuthenticationEntryPoint.java` | 认证入口点 |

### 验证码

- 图形验证码生成与校验
- Google Authenticator 集成

## 异常体系

| 组件 | 说明 |
|------|------|
| `GlobalExceptionHandler` | 全局异常处理器（@ControllerAdvice） |
| `OpenapiV3ExceptionHandler` | OpenAPI V3 异常处理 |
| `ExceptionCodeFactory` | 业务异常码工厂 |
| `CustomerException` | 自定义业务异常 |
| `CustomException` | 自定义异常 |
| `QbitError` | 错误码定义 |
| `TransactionSyncException` | 交易同步异常 |

异常处理流程：

```
Controller 业务执行
    ↓ 抛异常
CustomException / CustomerException / RuntimeException
    ↓
GlobalExceptionHandler 拦截
    ↓
根据异常类型 → 统一响应格式 Result.fail()
    ↓
记录详细日志 + traceId
```

## 注解体系

| 注解 | 说明 |
|------|------|
| `@DataScope` | 数据权限过滤（自动拼接 SQL 权限条件） |
| `@DataScopeSubAccount` | 子账户数据权限 |
| `@DataScopeTenant` | 租户数据权限 |
| `@IOperationLog` | 操作日志记录（AOP 自动记录） |
| `@IUser` | 当前用户注入 |
| `@IAccount` | 当前账户注入 |
| `@IAccountExtend` | 账户扩展信息注入 |
| `@ICustomerCategory` | 客户分类注入 |
| `@ISalesAccountRelation` | 销售账户关系注入 |
| `@IReferralCodeRelation` | 推荐码关系注入 |
| `@DailyStatementScope` | 日结范围注解 |
| `@ScanForSubdomain` | 子域扫描注解 |
| `@SubdomainField` | 子域字段注解 |

## 通用服务

| 服务 | 说明 |
|------|------|
| `RedisService` | Redis 操作封装（缓存、分布式锁） |
| `IdempotentService` | 幂等性校验 |
| `ExportService` | 通用导出服务 |
| `HttpService` | HTTP 请求封装 |
| `PaymentTypeService` | 支付类型查询 |
| `SystemTagsService` | 系统标签管理 |
| `AccountBusinessStatusService` | 账户业务状态 |
| `RefusalRateService` | 拒付率计算 |
| `ApnsPushService` | APNs 推送服务 |
| `BusinessMaterialRequestService` | 业务资料请求 |
| `OpenApiWebHookDataService` | Webhook 数据管理 |
| `QbitStatementService` | 账单服务 |
| `SupplierTransactionService` | 供应商交易服务 |
| `ExchangeRateDifferenceRecordService` | 汇率差额记录 |
| `ICardService` | 卡服务接口 |

## 事件驱动

| 事件 | 说明 |
|------|------|
| `TransactionChangeEvent` | 交易变更事件 |
| `TransactionCreateEvent` | 交易创建事件 |
| `BalanceNegativeEvent` | 余额为负事件 |
| `BusinessAccountEvent` | 业务账户事件 |
| `MonthBillExportEvent` | 月账单导出事件 |
| `CardCreatedEventListener` | 卡创建监听器 |

## AOP 通知

| Advice | 说明 |
|--------|------|
| `RequestLoggerAdvice` | 请求日志记录（Controller 层 AOP） |
| `AssetsTransferHook` | 资产转账钩子 |
| `FinancingTransferHook` | 融资转账钩子 |

## Handler 处理器

| Handler | 说明 |
|---------|------|
| `CsvI18nHeaderCellWriteHandler` | CSV 国际化表头处理器 |
| `ExcelI18nHeaderCellWriteHandler` | Excel 国际化表头处理器 |
| `channel/*` | 渠道处理器 |

## Event 监听器

| 监听器 | 说明 |
|--------|------|
| `AgencyFeeListener` | 代理费率监听 |
| `BusinessAccountListener` | 业务账户监听 |
| `MonthBillExportListener` | 月账单导出监听 |

## 枚举体系

Core 模块承载了大量跨域通用枚举：

| 枚举 | 说明 |
|------|------|
| `BizTypeEnum` | 业务类型 |
| `SourceChannel` | 来源渠道 |
| `PermissionEnum` | 权限枚举 |
| `LanguageEnum` | 语言枚举 |
| `DeviceTypeEnum` | 设备类型 |
| `CashFlowDirection` | 资金流向 |
| `AvailableStatusEnum` | 可用状态 |
| `MaterialStatusEnum` | 资料状态 |
| `NoticeTaskEnum` | 通知任务枚举 |
| `WebhookTypeEnum` | Webhook 类型 |
| `risk/` | 风控相关枚举 |

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `core/config/` | 全局配置类（18+） |
| `core/security/jwt/` | JWT 安全 |
| `core/security/captchas/` | 验证码 |
| `core/security/google/` | Google Authenticator |
| `core/exception/GlobalExceptionHandler.java` | 全局异常处理 |
| `core/exception/ExceptionCodeFactory.java` | 异常码工厂 |
| `core/annotation/DataScope.java` | 数据权限注解 |
| `core/annotation/IOperationLog.java` | 操作日志注解 |
| `core/annotation/IUser.java` | 用户注入注解 |
| `core/annotation/IAccount.java` | 账户注入注解 |
| `core/advice/RequestLoggerAdvice.java` | 请求日志 AOP |
| `core/handler/` | 导出处理器 |
| `core/event/TransactionChangeEvent.java` | 交易变更事件 |
| `core/service/RedisService.java` | Redis 服务 |
| `core/service/IdempotentService.java` | 幂等服务 |
| `core/service/ExportService.java` | 导出服务 |
| `core/listener/` | 事件监听器 |
| `core/enums/` | 通用枚举（30+） |
| `core/clear/` | 清算结算模块 |
| `core/converter/` | 转换器 |
| `core/dto/` | 公共 DTO（100+） |
| `core/vo/` | 公共 VO（50+） |
| `core/bo/` | 公共 BO（30+） |
