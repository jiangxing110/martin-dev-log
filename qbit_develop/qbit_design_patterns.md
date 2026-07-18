# Qbit 设计模式全景

## 概述

本文档系统梳理 Qbit 项目中使用的设计模式，涵盖创建型、结构型、行为型及架构模式四个层次，结合具体代码位置和业务场景说明。

---

## 一、创建型模式 (Creational)

### 1.1 工厂模式 (Factory Pattern)

Qbit 中工厂模式是最广泛使用的模式，共 7 个核心工厂。

#### 统一结构

```
XXXFactory (implements InitializingBean)
  └── EnumMap<Enum, AbstractXXX>
       ├── Bean 1 (渠道 A)
       ├── Bean 2 (渠道 B)
       └── Bean 3 (渠道 C)

选择逻辑: factory.get(channelEnum).method()
发现机制: InitializingBean.afterPropertiesSet() 自动注册所有 AbstractXXX Bean
```

#### 工厂明细

| 工厂 | 注册方式 | 键类型 | 值基类 | 用途 |
|------|----------|--------|--------|------|
| `PaymentChannelFactory` | `InitializingBean` → `EnumMap` | `PaymentChannelEnum` (11) | `AbstractPaymentChannelService` | 出金渠道分发 |
| `QuantumCardChannelFactory` | `InitializingBean` → `Map` | `CardChannelEnum` | `AbstractQuantumCardService` | 卡组渠道分发 (BB/I2C) |
| `GlobalAccountProviderFactory` | `InitializingBean` → `Map` | `ProviderEnum` (11+) | `AbstractGlobalAccountProvider` | 全球账户供应商适配 |
| `FundingTransferFactory` | 策略查找 | `FundingTypeEnum` | `IFundingTransfer` | 资金划转策略 |
| `CryptoRateFactory` | `InitializingBean` → `Map` | 汇率源类型 | `CryptoRateHandler` | 汇率源选择 |
| `ReportFactory` | `InitializingBean` → `Map` | `ReportTypeEnum` | `AbstractReportGenerator` | 报表生成器 |
| `CryptoWalletAddressFactory` | 策略查找 | 链/币种 | 地址生成器 | 钱包地址生成 |

#### 示例: PaymentChannelFactory

```java
// 工厂定义
@Component
public class PaymentChannelFactory implements InitializingBean {
    private final Map<PaymentChannelEnum, AbstractPaymentChannelService> channelMap = new EnumMap<>(PaymentChannelEnum.class);
    private final List<AbstractPaymentChannelService> channelServices;

    @Override
    public void afterPropertiesSet() {
        for (AbstractPaymentChannelService service : channelServices) {
            channelMap.put(service.getChannel(), service);
        }
    }

    public AbstractPaymentChannelService getChannel(PaymentChannelEnum channel) {
        return channelMap.get(channel);
    }
}

// 使用
AbstractPaymentChannelService channel = paymentChannelFactory.getChannel(PaymentChannelEnum.CL);
channel.payout(request);
```

### 1.2 单例模式 (Singleton)

| 实现 | 位置 | 说明 |
|------|------|------|
| Spring `@Component` / `@Service` | 全系统 | 默认单例作用域 |
| `SecretValueResolver` DCL | `secretmanager/core/SecretValueResolver.java` | Double-Checked Locking 懒初始化 AWS SDK Client |
| `SecretValueCache` | `secretmanager/core/SecretValueCache.java` | 全局缓存实例 (ConcurrentHashMap) |

#### 示例: SecretValueResolver DCL

```java
private SecretValueResolver instance;

public SecretValueResolver getInstance() {
    if (instance == null) {
        synchronized (this) {
            if (instance == null) {
                this.instance = new SecretValueResolver(properties);
                this.instance.initAwsClient();
            }
        }
    }
    return instance;
}
```

### 1.3 建造者模式 (Builder)

| 位置 | 说明 |
|------|------|
| DTO/BO 构建 | 各模块构造复杂请求参数 |
| `DroolsRuleExecuteDto` 构造 | 规则执行参数组装 |
| API 响应构造 | 统一响应格式构建 |

---

## 二、结构型模式 (Structural)

### 2.1 适配器模式 (Adapter)

| 实现位置 | 适配目标 | 说明 |
|----------|----------|------|
| `qbit-assets-thirdparty/api/ApiClient.java` | 各交易所/第三方 API | 统一 HTTP 客户端接口 |
| `AbstractPaymentChannelService` → 各渠道实现 | CL/EP/GEO/L2/NIUM/... | 统一出金接口适配不同第三方渠道 |
| `AbstractGlobalAccountProvider` → 各供应商实现 | CurrencyCloud/EasyEuro/SolidFI/... | 统一全球账户供应商接口 |
| `AbstractQuantumCardService` → 各卡组 | BB/I2C | 统一卡组渠道接口 |

#### 示例: 第三方 SDK 适配层

```
thirdparty-api 定义统一接口:
  ApiClient.java          → HTTP 客户端基类
  Authentication.java     → 认证接口
  ApiResponse.java        → 响应封装

各 SDK 适配:
  thirdparty-okx          → 适配 OKX REST API
  thirdparty-gate         → 适配 Gate REST API
  thirdparty-hashkey      → 适配 HashKey REST API
  thirdparty-safeheron    → 适配 Safeheron API
  thirdparty-chainalysis  → 适配 Chainalysis API
```

### 2.2 代理模式 (Proxy)

| 实现位置 | 代理类型 | 说明 |
|----------|----------|------|
| AOP `@DataScope` | 动态代理 | 自动拼接 SQL 数据权限过滤条件 |
| AOP `@IOperationLog` | 动态代理 | 自动记录操作日志 |
| AOP `@IUser` / `@IAccount` | 动态代理 | 自动注入当前用户/账户 |
| `RequestLoggerAdvice` | Spring AOP | Controller 层请求日志记录 |
| `AssetsTransferHook` | Spring AOP | 资产转账钩子 |
| `FinancingTransferHook` | Spring AOP | 融资转账钩子 |

#### 示例: @DataScope AOP

```java
// 注解
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface DataScope {
    String type() default "";
}

// 使用
@DataScope
@GetMapping("/list")
public Result<List<AccountVO>> list(AccountQuery query) {
    // 自动拼接 SQL: WHERE account.merchant_id = #{currentMerchantId}
    return service.list(query);
}
```

### 2.3 组合模式 (Composite)

| 位置 | 说明 |
|------|------|
| Drools 规则组 (RuleGroup → Rule → DroolsRule) | 规则组包含多条规则，规则包含条件+结果 |
| 账户树 (主账户 → 子账户) | 主账户管理多个子账户 |
| 产品配置树 | 产品包含多个费率配置 |

### 2.4 外观模式 (Facade)

| 位置 | 说明 |
|------|------|
| `FundingService` | 资金操作的统一入口，封装底层资金划转/冻结/返现 |
| `DroolsRuleService` | 规则执行的统一入口，封装引擎加载/匹配/结果收集 |
| `CryptoAssetV2TransferService` | 加密资产转账的统一入口 |

---

## 三、行为型模式 (Behavioral)

### 3.1 策略模式 (Strategy)

Qbit 的策略模式通常与工厂模式配合使用：工厂负责路由选择，策略实现负责具体算法。

| 策略接口 | 实现数 | 用途 |
|----------|--------|------|
| `IFundingTransfer` | 3+ | 不同资金划转策略 |
| `WeightParameterFlow` | 3 | 交易/账户/系统三级权重策略 |
| `CryptoRateHandler` | 5 | 不同汇率源策略 (Qbit/OKX/Gate/Custom/Curve) |
| 报表生成器 | 多 | 不同报表类型策略 |

#### 示例: WeightParameterFlow 策略

```java
// 策略接口
public interface WeightParameterFlow {
    List<PayOutWeight> handle(PayoutWeightDTO input);
}

// 策略实现: 交易维度
@Component
public class PayoutWeightTransactionFlow implements WeightParameterFlow {
    public List<PayOutWeight> handle(PayoutWeightDTO input) {
        // 按 transactionId 查询权重
    }
}

// 策略实现: 账户维度
@Component
public class PayoutWeightAccountFlow implements WeightParameterFlow {
    public List<PayOutWeight> handle(PayoutWeightDTO input) {
        // 按 accountId 查询权重 (排除交易级)
    }
}

// 策略实现: 系统维度
@Component
public class PayoutWeightSystemFlow implements WeightParameterFlow {
    public List<PayOutWeight> handle(PayoutWeightDTO input) {
        // 查询系统默认权重
    }
}
```

### 3.2 模板方法模式 (Template Method)

模板方法定义算法骨架，子类实现具体步骤。

#### AbstractPaymentChannelService

```
抽象方法 (子类必须实现):
  ├── getChannel()           → 返回渠道枚举
  ├── sendInquiry()          → 询价请求
  ├── doPay()                → 实际出金
  ├── getBalance()           → 查询余额
  ├── doQueryThirdPartyAvailable() → 三方可用余额
  ├── doQueryThirdPartyAll()       → 三方全部余额
  ├── doQueryMasterAvailable()     → 主账户可用余额
  └── doWalletToWalletTransfer()   → 钱包间转账

模板方法 (骨架固定):
  ├── inquiry()              → 询价流程: 保存→调用→更新
  ├── payout()               → 出金流程: 加锁→检查→询价→执行→回调→结算
  ├── payoutPreCheckWithinDeficitThreshold() → 出金前检查
  ├── createPayoutTransactionRecord()       → 创建交易记录
  ├── paymentWebhook()       → Webhook 回调
  └── checkBalance()         → 余额检查
```

#### AbstractQuantumCardService

```
模板方法 (骨架):
  ├── open()                 → 开卡流程
  ├── freeze() / unfreeze()  → 冻结/解冻
  ├── delete()               → 删卡
  ├── updateLimit()          → 限额更新
  └── ...                    → 其他卡操作

子类实现:
  ├── BB 卡组实现
  └── I2C 卡组实现
```

#### AbstractGlobalAccountProvider

```
模板方法 (骨架):
  ├── openAccount()          → 开户流程
  ├── createTransaction()    → 交易创建
  ├── queryBalance()         → 余额查询
  ├── conversion()           → 结汇/换汇
  └── ...                    → 其他操作

子类实现 (11个):
  ├── CurrencyCloudProvider
  ├── EasyEuroProvider (EP)
  ├── SolidFIProvider
  ├── ColumnProvider
  ├── PyvioProvider
  ├── HFProvider (汇付国际)
  ├── ThunesProvider
  ├── RD / RF Provider
  ├── QBProvider (闪付钱包)
  ├── ZB / TZ / IL Provider
  └── L2Provider (已下线)
```

### 3.3 观察者模式 / 事件驱动 (Observer / Event-Driven)

Qbit 基于 Spring Event 和 RocketMQ 实现事件驱动架构。

#### Spring Event (同步/异步)

```
事件:
  ├── TransactionChangeEvent      → 交易变更
  ├── TransactionCreateEvent      → 交易创建
  ├── BalanceNegativeEvent        → 余额为负
  ├── BusinessAccountEvent        → 业务账户
  ├── MonthBillExportEvent        → 月账单导出
  └── CardCreatedEvent            → 卡创建

监听器:
  ├── AgencyFeeListener           → 代理费率监听
  ├── BusinessAccountListener     → 业务账户监听
  ├── MonthBillExportListener     → 月账单导出监听
  └── CardCreatedEventListener   → 卡创建监听
```

#### RocketMQ (异步解耦)

```
生产者 → RocketMQ → 消费者

业务域:
  ├── 加密资产 → 充值通知/转账确认/风控通知/退款广播
  ├── 量子卡   → 卡状态变更/交易通知/分组操作
  ├── 全球账户 → 入金通知/转账状态/汇率更新
  ├── 资金管理 → 资金事件通知
  ├── 风控     → 风控结果通知/告警分发
  └── 通知     → 邮件/站内信/Webhook 消息发送
```

#### 事件类型对比

| 特性 | Spring Event | RocketMQ |
|------|-------------|----------|
| 同步/异步 | 两者皆可 (@Async) | 全异步 |
| 可靠性 | JVM 内存 | 持久化 + 重试 |
| 延迟 | 微秒级 | 毫秒级 |
| 跨服务 | 不支持 | 支持 |
| 适用场景 | 同进程内部解耦 | 跨服务异步通知 |

### 3.4 责任链模式 (Chain of Responsibility)

Qbit 中有三条责任链，分别在网关、路由和规则引擎中。

#### 网关过滤器链

```
Gateway Filter Chain:
  ├── GlobalIpDenyFilter               → IP 黑名单
  ├── GlobalLoggingFilter               → 全局日志
  ├── GlobalRequestLoggingFilter        → 请求日志
  ├── UserJwtAuthFilter / OpenApiTokenFilter → 认证
  ├── UserRbacAuthFilter / OpenApiAccessFilter → 鉴权
  └── OriginalUrlEnsureFilter          → URL 保留
```

#### 出金过滤器链 (PlatformsFilterContext)

```
PlatformsFilterChain (10 filters):
  ├── ① GlobalFilterHandle             → 全球账户路由
  ├── ② ThFilterHandle                → THUNES 渠道过滤
  ├── ③ RdFilterHandle                → RD 渠道过滤
  ├── ④ EpFilterHandle                → EP 渠道过滤
  ├── ⑤ ClFilterHandle                → CL 渠道过滤
  ├── ⑥ ZbFilterHandle                → ZB 渠道过滤
  ├── ⑦ GeoFilterHandle               → GEO 渠道过滤
  ├── ⑧ TzFilterHandle                → TZ 渠道过滤
  ├── ⑨ AgencyPaymentFilterHandle     → 代付管控
  └── ⑩ MasterFilterHandle            → 主账户路由
```

#### Drools 规则链

```
规则匹配顺序 (按 salience 优先级):
  ├── 拦截规则 (最高优先级)
  ├── 告警规则
  ├── 限额规则
  ├── 标签规则
  └── 评级规则 (最低优先级)
```

#### 共同结构

```
interface ChainHandler {
    Result handle(Context input);
}

class ChainContext {
    List<ChainHandler> handlers;
    
    Result execute(Context input) {
        for (ChainHandler handler : handlers) {
            Result result = handler.handle(input);
            // 可以短路 (某些链)
            // 可以传递 (过滤器链)
        }
    }
}
```

### 3.5 迭代器模式 (Iterator)

| 位置 | 说明 |
|------|------|
| MyBatis-Plus 分页查询 | 游标遍历大量数据 |
| XXL-Job 分片任务 | 按分片参数遍历数据子集 |
| 报表导出 (ExportService) | 分批导出大数据量 |

### 3.6 状态模式 (State)

| 位置 | 状态机 | 说明 |
|------|--------|------|
| `CryptoAssetsTransfer` | 转账状态: PENDING → PROCESSING → SUCCESS/FAILED | 链上转账生命周期 |
| `PaymentTransactionRecord` | 交易状态: PENDING → SUCCESS/FAILED/REFUNDED | 出金交易状态 |
| 量子卡 | 卡状态: ACTIVE/FROZEN/DELETED | 卡片生命周期 |
| `FundingOrder` | 资金状态: 初始化/处理中/成功/失败 | 资金订单状态 |

### 3.7 中介者模式 (Mediator)

| 位置 | 说明 |
|------|------|
| `AllRatePlatformContext` | 中介者协调费率查询、过滤器链、最优渠道选择 |
| `PaymentCommonCheckContext` | 中介者协调多个前置校验器的执行 |
| MQ 消息队列 | 消息队列作为生产者和消费者的中介 |

#### 示例: AllRatePlatformContext

```
AllRatePlatformContext.getRateList()
  ├── 调用 DB 查询可用渠道+费率
  ├── 委托 PlatformsFilterContext 过滤
  └── 委托 getOptimalChannel 选择最优渠道
```

---

## 四、架构模式 (Architectural)

### 4.1 管道过滤器模式 (Pipes and Filters)

| 位置 | 说明 |
|------|------|
| PlatformsFilterContext | 10 个过滤器顺序执行，管道传递渠道列表 |
| PaymentCommonCheckContext | 多个校验器顺序执行 |
| Gateway Filter Chain | 9 个过滤器顺序执行 |

### 4.2 SPI / 插件模式

| 位置 | 说明 |
|------|------|
| `PaymentCommonCheckHandle` | `PaymentCommonCheckContext` 自动发现所有 Bean 并执行 |
| `BeforeRoutingCheck` | `PaymentCommonCheckContext` 自动发现所有路由前校验 |
| `IPlatformsFilter` | `PlatformsFilterContext` 自动发现所有过滤器 |

#### 结构

```java
// SPI 接口
public interface PaymentCommonCheckHandle {
    void check(CheckDTO input);
}

// SPI 实现 (被自动发现)
@Component
public class GlobalAccountKycCheckParam implements PaymentCommonCheckHandle {
    public void check(CheckDTO input) { /* KYB 校验 */ }
}

@Component
public class CheckSameNameParam implements PaymentCommonCheckHandle {
    public void check(CheckDTO input) { /* 同名付款校验 */ }
}

// SPI 上下文 (自动收集所有实现)
@Component
public class PaymentCommonCheckContext {
    @Autowired
    private List<PaymentCommonCheckHandle> checkHandles;

    public void run(CheckDTO input) {
        for (PaymentCommonCheckHandle handle : checkHandles) {
            handle.check(input);
        }
    }
}
```

### 4.3 分层架构 (Layered Architecture)

Qbit 整体采用 5 层架构：

```
客户端层 (Merchant Portal / Admin / OpenAPI / Mobile / Partner)
    ↓
网关层 (Spring Cloud Gateway: 认证/鉴权/限流/日志/IP黑白名单)
    ↓
应用层 (Merchant / Admin / Common 三大业务域 + Core 基础框架)
    ↓
数据层 (PostgreSQL / Redis / RocketMQ / S3 / AWS Secrets Manager)
    ↓
三方集成层 (OKX / Gate / HashKey / Safeheron / Chainalysis / 银行渠道)
```

### 4.4 仓储模式 (Repository)

| 位置 | 说明 |
|------|------|
| MyBatis-Plus Mapper 接口 | 标准 CRUD 封装 |
| `BaseMapper<T>` 扩展 | 通用增删改查 + 分页 |
| 各 Service 层 | 业务逻辑与数据访问分离 |

### 4.5 CQRS 模式

| 位置 | 说明 |
|------|------|
| 分析报表 ODS/DWD/DWS 分层 | 读写分离，分析查询与业务处理分离 |
| PostgreSQL 主从架构 | 主库写入，从库只读查询 |
| 报表服务 | 专门的报表数据通路，独立于业务库 |

### 4.6 事件溯源 (Event Sourcing) 简化版

| 位置 | 说明 |
|------|------|
| `FundingEvent` | 资金操作事件记录，完整操作轨迹 |
| 交易状态机状态变更记录 | 交易状态转换的历史记录 |
| 对账差异记录 | 对账不一致事件记录 |

---

## 五、模式关系图

```
                           工厂模式
                              │
              ┌───────────────┼───────────────┐
              │               │               │
         策略模式          模板方法          适配器模式
         (算法)          (骨架)            (渠道适配)
              │               │
              ├───────────────┤
              │               │
         责任链模式        事件驱动 (观察者)
         (过滤器链)          │
                          MQ 消息
                     (异步解耦)
                              │
                         代理模式 (AOP)
                         数据权限/操作日志
```

### 典型组合: 出金路由

```
PaymentCommonCheckContext      → SPI 模式 (自动发现校验器)
  └── check 校验链              → 责任链模式

AllRatePlatformContext          → 中介者模式
  ├── PlatformsFilterContext    → 管道过滤器模式 (10 filters)
  ├── getOptimalChannel        → 策略模式 (询价+成本比较)
  └── WeightParameterFlow      → 策略模式 (3 级权重)

PaymentChannelFactory           → 工厂模式
  └── AbstractPaymentChannelService   → 模板方法模式
        └── 各渠道实现                → 策略模式
```

### 典型组合: 启动期密钥解析

```
SecretManagerEnvironmentPostProcessor  → Spring SPI
  └── SecretRefParser                   → 解析器模式
  └── SecretValueResolver               → 单例模式 (DCL)
        └── SecretValueCache            → 缓存模式 (二级缓存)
        └── AWS Secrets Manager Client  → 适配器模式
```

---

## 六、模式速查表

| 模式 | 使用频率 | 关键所在 | 典型文件 |
|------|----------|----------|----------|
| 工厂模式 | ★★★★★ | 7 个核心工厂 | `*Factory.java` |
| 模板方法 | ★★★★★ | 3 个抽象基类 | `Abstract*Service.java` |
| 策略模式 | ★★★★★ | 多维度权重/费率 | `*Flow.java`, `*Handler.java` |
| 适配器模式 | ★★★★★ | SDK/渠道适配 | `Abstract*Service.java` 子类 |
| 责任链 | ★★★★ | 过滤器/校验链 | `*FilterHandle.java`, `*Check*.java` |
| 事件驱动 | ★★★★ | Spring Event + MQ | `*Event.java`, `*Listener.java` |
| 代理模式 | ★★★★ | AOP 注解 | `@DataScope`, `@IOperationLog` |
| 单例模式 | ★★★ | Spring + DCL | `SecretValueResolver` |
| SPI/插件 | ★★★ | 自动 Bean 发现 | `*Context.java` |
| 状态模式 | ★★★ | 交易/卡生命周期 | `*StatusEnum` |
| 中介者 | ★★ | 路由上下文 | `*Context.java` (协调类) |
| 建造者 | ★★ | 复杂对象构建 | DTO/BO 构建 |
| 组合模式 | ★★ | 规则组/账户树 | `RuleGroup.java` |
| 外观模式 | ★★ | 统一服务入口 | `DroolsRuleService` |
| CQRS | ★★ | 读写分离 | 分析报表/主从 |
| 仓储模式 | ★★ | MyBatis-Plus | `*Mapper.java` |

## 关键路径速查

| 路径 | 模式 |
|------|------|
| `core/payout/dispatch/PaymentChannelFactory.java` | 工厂 |
| `core/payout/dispatch/AbstractPaymentChannelService.java` | 模板方法 |
| `core/payout/handle/filter/*FilterHandle.java` (10个) | 责任链/过滤器 |
| `core/payout/handle/weight/*Flow.java` (3个) | 策略 |
| `core/payout/handle/check/*.java` | SPI/责任链 |
| `core/payout/handle/context/*Context.java` (5个) | 中介者 |
| `core/annotation/DataScope.java` | 代理 (AOP) |
| `core/annotation/IOperationLog.java` | 代理 (AOP) |
| `core/event/*Event.java` (6+) | 观察者/事件 |
| `core/listener/*Listener.java` (3+) | 观察者/事件 |
| `core/advice/*.java` (3个) | 代理 (AOP) |
| `secretmanager/core/SecretValueResolver.java` | 单例 (DCL) |
| `secretmanager/core/SecretValueCache.java` | 缓存模式 |
| `secretmanager/core/SecretRefParser.java` | 解析器 |
| `gateway/filter/*.java` (9个) | 责任链/过滤器 |
| `drools/resources/rules/*.drl` (8个) | 责任链 (规则链) |
| `qbit-assets-thirdparty/api/ApiClient.java` | 适配器 |
| `common_all/funding/FundingTransferFactory.java` | 工厂+策略 |
| `common_all/globalaccount/provider/GlobalAccountProviderFactory.java` | 工厂+适配器 |
| `common_all/cryptoasset/rate/CryptoRateFactory.java` | 工厂+策略 |
| `common_all/quantum/QuantumCardChannelFactory.java` | 工厂+模板方法 |
| `common_all/analysis/report/ReportFactory.java` | 工厂+策略 |
| `common_all/cryptoasset/wallet/CryptoWalletAddressFactory.java` | 工厂 |
