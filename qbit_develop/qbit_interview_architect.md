# Qbit 资深架构师面试题

> 基于 Qbit 跨境支付与加密资产管理平台的实际架构设计。
> 每题均包含: 题目 → 考察点 → 参考答案。

---

## 一、架构设计类

### Q1. 支付路由的架构设计

**题目：**
Qbit 支持 11 个出金渠道（CL/EP/GEO/L2/NIUM/Thunes/ZB/TZ/RD/RF/Offline），每个渠道有不同的费率、清算模式、支持币种和到账时效。请设计一个可扩展的出金路由架构，重点说明：

1. 如何做到新渠道可插拔接入（不改核心代码）？
2. 如何在高并发下做最优渠道选择（同时考虑费率、时效、渠道可用性）？
3. 如何处理渠道降级和熔断？

**考察点：**
- 策略模式 + 工厂模式的实际应用
- 管道过滤器模式的设计
- 并发编程（CompletableFuture 并行询价、超时处理）
- 熔断降级的设计思路
- 可扩展性设计

**参考答案：**

**1. 可插拔渠道接入**

采用工厂模式 + 模板方法模式 + SPI 机制实现：

```java
// 工厂: InitializingBean 自动收集所有渠道实现
@Component
public class PaymentChannelFactory implements InitializingBean {
    private final Map<PaymentChannelEnum, AbstractPaymentChannelService> channelMap
        = new EnumMap<>(PaymentChannelEnum.class);
    private final List<AbstractPaymentChannelService> channelServices;

    @Override
    public void afterPropertiesSet() {
        for (AbstractPaymentChannelService service : channelServices) {
            channelMap.put(service.getChannel(), service);
        }
    }
}

// 模板方法: 出金骨架固定，子类只实现差异化步骤
public abstract class AbstractPaymentChannelService {
    // 模板方法 - 子类不可重写
    public final PayoutResult payout(PayoutRequest request) {
        lock();
        checkBalance();
        inquiry();       // 询价 - 调用抽象方法 sendInquiry()
        deficitCheck();
        doPay();         // 出金 - 调用抽象方法 doPay()
        webhook();
        settlement();
    }

    // 抽象方法 - 各渠道差异化实现
    protected abstract InquiryResult sendInquiry(InquiryRequest request);
    protected abstract PayResult doPay(PayRequest request);
    protected abstract PaymentChannelEnum getChannel();
}
```

新增渠道只需: ① 继承 `AbstractPaymentChannelService` ② 实现抽象方法 ③ 注册为 Spring Bean。零改动现有代码。

**2. 高并发最优渠道选择**

并行询价 + 成本比较策略:

```java
// 并行询价: 所有可用渠道同时询价，5s 超时
List<CompletableFuture<RateResult>> futures = channels.stream()
    .map(ch -> CompletableFuture
        .supplyAsync(() -> inquiry(ch, request))
        .completeOnTimeout(null, 5, TimeUnit.SECONDS))
    .collect(Collectors.toList());

CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();

// 成本比较: amount + fee 最小的渠道
RateResult best = results.stream()
    .filter(Objects::nonNull)
    .min(Comparator.comparing(r -> r.getAmount().add(r.getFee())))
    .orElseThrow(() -> new NoAvailableChannelException("所有渠道不可用"));
```

**3. 渠道降级和熔断**

- 询价超时 → `completeOnTimeout(null, 5s)` 标记不可用，自动排除
- 连续失败 → 计数阈值触发熔断，后续请求跳过该渠道
- 节假日 → 不询价，直接选第一个可用渠道
- 权重降级 → 失败渠道 weight 置 0
- 过滤器链 → 前置过滤器在渠道异常时直接过滤

---

### Q2. 全球账户的多供应商适配设计

**题目：**
Qbit 全球账户对接了 11 个境外银行/支付供应商（CurrencyCloud、EasyEuro、Column、SolidFI 等），每个开户流程、交易接口、结算方式都不同。请设计供应商适配架构：

1. 如何统一不同供应商的开户和交易接口差异？
2. 如何在不停机情况下切换或升级供应商？
3. 如何设计供应商的隔离和灰度策略？

**考察点：**
- 适配器模式 + 工厂模式
- 接口隔离原则
- 灰度发布策略
- 防冲击设计

**参考答案：**

**1. 统一接口设计**

三层抽象：`GlobalAccountProviderFactory` (工厂路由) → `AbstractGlobalAccountProvider` (模板方法骨架) → 各 Provider 实现。

```java
public interface GlobalAccountProvider {
    AccountResult openAccount(OpenAccountRequest request);
    AccountResult queryAccount(String accountId);
    BalanceResult queryBalance(String accountId);
    TransactionResult createTransaction(TransactionRequest request);
    ConversionResult getQuote(ConversionRequest request);
    ConversionResult executeConversion(ConversionRequest request);
    WebhookResult handleWebhook(WebhookRequest request);
}
```

**2. 不停机切换**

```
阶段1: 双写 — 新旧同时接收数据，验证一致性
阶段2: 灰度切流 — 1% → 5% → 20% → 50% → 100%
  通过 accountId hash 或商户白名单控制
  每阶段监控: 成功率、延迟、对账差异
阶段3: 下线旧供应商 — 确认稳定后关闭
```

**3. 供应商隔离**

- 商户级别: PayOutWeight 表控制可见性（weight=0 则不可见）
- 过滤器链: 渠道异常时自动过滤
- 连接池: 各供应商独立连接池，互不影响
- 熔断器: 每个供应商独立熔断

---

## 二、分布式系统类

### Q3. 分布式事务与最终一致性

**题目：**
Qbit 中一个典型的加密货币提币流程涉及：风控检查 → 费用计算 → 资产冻结 → 链上转账 → 对账确认。这个流程跨越多个模块，且链上转账可能耗时数分钟到数小时。

1. 如何保证这个流程的数据一致性？
2. 如何处理链上转账超时或失败的回滚？
3. 如果某一步骤重复执行，如何保证幂等？

**考察点：**
- 分布式事务理论（TCC/SAGA/可靠事件）
- 最终一致性、补偿事务
- 幂等性设计、状态机

**参考答案：**

**1. SAGA + 状态机 + 可靠事件**

```
阶段1 (预留):
  风控检查 → 通过 → 记录结果 (幂等键: sourceTransactionId)
  费用计算 → 通过 → 生成费用记录 (幂等键: sourceTransactionId + feeType)
  资产冻结 → 锁定资产 (幂等键: sourceTransactionId + "FREEZE")

阶段2 (执行):
  链上转账 → 获 txHash → 状态 PROCESSING
    ├── 成功 → SUCCESS → 解冻 → 扣余额
    ├── 失败 → FAILED → 解冻 → 补偿
    └── 超时 → 定时任务扫描 → 链上确认

阶段3 (确认):
  对账 → MQ 消费对账结果 → 最终状态确认
```

**2. 超时/失败处理**

```
失败: 链上交易失败
  → 标记 FAILED → 资产解冻 → 通知商户

超时: 长时间未确认
  → XXL-Job 每 5 分钟扫描 PROCESSING > 30 分钟的交易
  → 调用区块链 RPC 查询实际状态
    ├── 已确认 → SUCCESS
    ├── 已失败 → FAILED + 解冻
    └── 待确认 → 继续等待 (可配最大等待时间)
  → 超最大等待 → 强制失败 + 补偿

补偿: TransactionChangeEvent → 监听器处理
  每笔补偿有独立事务 ID，支持幂等重试
```

**3. 幂等设计**

```java
// 幂等键: sourceTransactionId + 业务类型
IdempotentService.tryExecute(idempotentKey, () -> {
    // 分布式锁 + 幂等表
    if (redisLock.tryLock(idempotentKey)) {
        try {
            if (idempotentTable.exists(idempotentKey)) return false;
            doBusiness();
            idempotentTable.save(idempotentKey);
            return true;
        } finally {
            redisLock.unlock(idempotentKey);
        }
    }
    return false;
});
```

---

### Q4. MQ 消息可靠性保障

**题目：**
Qbit 大量依赖 RocketMQ 进行异步解耦。请设计 MQ 消息的可靠性保障：

1. 保证消息不丢失
2. 保证消息至少被消费一次（可重复消费）
3. 保证消费端幂等
4. 处理消息积压场景

**考察点：**
- MQ 可靠性模型
- 幂等消费设计
- 积压处理策略

**参考答案：**

**1. 消息不丢失（三层保证）**

```
生产端:
  同步发送 + 回调确认 → 失败重试 3 次 → 最终写入本地失败消息表
  → XXL-Job 定时扫描失败表 → 重新投递

Broker:
  同步刷盘 (SYNC_FLUSH) + 主从同步复制

消费端:
  业务成功后才 ACK → 失败 RECONSUME_LATER → 超最大重试进死信队列
```

**2. 消费端幂等**

```java
// 消息 ID 或业务 key 幂等消费
String bizKey = extractBizKey(msg);
if (idempotentService.hasProcessed(bizKey, msg.getTopic())) {
    // 已消费, 跳过
    continue;
}
try {
    processMessage(msg);
    idempotentService.markProcessed(bizKey, msg.getTopic());
} catch (Exception e) {
    if (msg.getReconsumeTimes() >= MAX_RECONSUME) {
        deadLetterService.send(msg); // 死信队列
        return CONSUME_SUCCESS;
    }
    return RECONSUME_LATER;
}
```

**3. 积压处理**

- 水平扩展消费者（增加 Consumer 实例）
- 临时关闭非关键消息处理
- 批量消费（32 条 → 100 条）
- 监控 consumer 堆积量 + 阈值告警
- 生产端限流（Drools 控制发送速率）

---

## 三、规则引擎设计类

### Q5. Drools 规则引擎在企业级应用中的架构设计

**题目：**
Qbit 用 Drools 管理 8 个 DRL 文件、几十条规则，覆盖风控/费用/路由/合规。

1. 为什么选择 Drools 而非硬编码？什么场景下 Drools 是反模式？
2. 如何设计规则的分组、优先级、冲突解决？
3. 如何实现新规则的灰度验证？
4. 如何处理规则执行效率问题？

**考察点：**
- 规则引擎选型评估
- Rete 算法理解
- 规则工程化
- 性能优化

**参考答案：**

**1. 适用 vs 反模式**

适用 Drools：
- 规则多且频繁变更（风控阈值每周调整）
- 规则有复杂组合关系（A 且 (B 或 C) 且 D...）
- 需要审计跟踪（命中哪条规则、原因、时间）

Drools 是反模式：
- 规则 < 5 条且几乎不变 → if-else 更简单
- 超高并发纳秒级延迟要求 → Rete 网络编译有开销
- 规则极其简单（单条件判断）→ 决策表/DB 配置更好
- 团队无 Drools 维护能力 → 规则引擎变黑盒

**2. 规则分组与优先级**

```
业务域分组 (8 组):
  CryptoOutbound.drl / CurrencyOutbound.drl
  MerchantRiskAction.drl / CommonRiskAction.drl
  ApiClinetRiskAction.drl / MultiAccountRiskAction.drl
  QbitRiskRatingAction.drl / QbitInternationalRiskRatingAction.drl

规则类型:
  拦截规则 (salience=100) → 命中直接拒绝
  告警规则 (salience=50)  → 不拦截
  限额规则                  → 控制频率/金额
  标签规则                  → 命中打标签
  评级规则 (salience=0)    → 计算风险等级

冲突解决:
  salience 优先级 → activation-group 互斥 → 加载顺序
```

**3. 灰度验证**

```
KieBase 隔离:
  生产 KieBase: 已发布的 DRL
  灰度 KieBase: 含新规则的 DRL
  根据 accountId hash 决定用哪个

A/B 模式:
  新规则只记录不阻断 (insertLogical GrayRuleResult)
  对比灰度组 vs 对照组的风控命中率
```

**4. 性能优化**

- 最严格条件放最前面（short-circuit）
- 使用 KieSession Pool 避免重复创建
- 按业务域拆分 DRL，只加载相关规则
- 非关键规则（评级/标签）异步执行
- 稳定结果加缓存（同一商户同笔交易多次检查）

---

## 四、安全架构类

### Q6. 密钥管理架构设计

**题目：**
Qbit Secret Manager 支持 `qsm://secretId#field` 和 `${qsm:secretId#field}` 两种格式。

1. 为什么设计两套引用格式？
2. Spring 启动时如何在配置加载阶段就完成密钥解析？
3. 如何设计两级缓存避免每次请求 AWS API？
4. AWS Secrets Manager 启动时不可用怎么办？

**考察点：**
- Spring EnvironmentPostProcessor
- 缓存策略（两级缓存、TTL、懒过期）
- 容错设计 (fail-fast vs fail-safe)

**参考答案：**

**1. 两套格式**

```
qsm://secretId#field (直接引用):
  整个配置值就是一个密钥
  如 apiKey: qsm://qbit/prod/payment#apiKey

${qsm:secretId#field} (内嵌引用):
  配置值只有部分是密钥
  如 datasource.url 非敏感 + username/password 敏感
  兼容 Spring ${...} 占位符语法

优势: grep 可审计、密钥集中管理、轮换不重启
```

**2. EnvironmentPostProcessor**

利用 Spring 的 `EnvironmentPostProcessor` 在 ApplicationContext 刷新前完成解析，优先级 `HIGHEST_PRECEDENCE + 20`：

```java
public void postProcessEnvironment(ConfigurableEnvironment env, SpringApplication app) {
    // 1. 检查开关
    // 2. 扫描所有 PropertySource 中的密钥引用
    // 3. 初始化 SecretValueResolver (AWS SDK 懒初始化)
    // 4. 解析所有引用 → Map<String, Object>
    // 5. 注入 MapPropertySource (最高优先级)
    // → Bean 初始化时看到的已经是解析后的值
}
```

**3. 两级缓存**

```
fieldValueCache (一级):
  Key: "secretId#field" → Value: 最终值
  避免重复 JSON 解析

rawSecretCache (二级):
  Key: "secretId" → Value: 原始 JSON
  避免重复请求 AWS API

解析流程:
  resolve("qbit/prod/db#password")
    → fieldValueCache.get → 命中直接返回
    → rawSecretCache.get → 命中则 JSON 解析
    → AWS API 查询 → rawCache 写入 → JSON 解析 → fieldCache 写入

特性: TTL 12h, ConcurrentHashMap, 懒过期
```

**4. 容错**

```
fail-fast = true (生产):
  启动失败 → 密钥缺失直接不可用，早失败比晚失败好

fail-fast = false (开发):
  记录 WARN → 继续启动，保持原始引用字符串，首次访问懒解析
```

---

## 五、高可用与容灾类

### Q7. 数据库架构与数据一致性

**题目：**
Qbit 使用 PostgreSQL 主从架构 + MyBatis-Plus。

1. 如何设计多数据源读写分离？
2. 主从延迟导致业务读到旧数据怎么办？
3. 如果量级到百万商户、日均千万交易，如何分库分表？
4. 数据库 schema 变更的零停机方案？

**考察点：**
- 读写分离、数据一致性
- 分库分表策略
- 在线 schema 变更

**参考答案：**

**1. 读写分离**

AOP + 注解路由：`@Master` 强制走主库，默认查询走从库。

读/写分离规则：
- `insert*/update*/delete*` 自动走主库
- `select*/get*/query*` 自动走从库
- `@Master` 注解覆盖

**2. 主从延迟处理**

- 写后强制读主库（支付结果、风控判断 → `@Master`）
- Redis 缓存中间层 → 写入更新缓存
- Session 级别标记（商户刚操作后 5 秒内走主库）
- 从库延迟监控 + 延迟超阈值熔断切主库

**3. 分库分表（千万日交易量级）**

```
商户维度分 16 库: merchant_id % 16
  同一商户全部数据在同一库 (避免跨库事务)

交易按月分表: transaction_202601
  查询限时间范围 → 直接定位月表

全局 ID: 雪花算法

跨库方案:
  商户维度查询 → 同库完成
  运营跨库查询 → 分析库 (ODS/DWD/DWS)
  禁止跨库 JOIN → 应用层聚合

中间件: ShardingSphere-JDBC
```

**4. 零停机 Schema 变更**

- 新增列 (NULLABLE) → 瞬间完成，只改元数据
- 新增 NOT NULL 列 → 分三步: ADD → 填充 → ALTER SET NOT NULL
- 修改列 → 新列双写 + 回填 + 切换
- 重命名 → 新旧双写 + 灰度切换

---

### Q8. 缓存架构设计

**题目：**
Qbit 使用 Redis 7 + Redisson。

1. 如何设计缓存策略（缓存什么、TTL、失效策略）？
2. 缓存穿透、击穿、雪崩的应对方案？
3. Redisson 分布式锁在 GC pause / 进程崩溃时的可靠性？
4. Redis 集群故障时如何降级？

**考察点：**
- 缓存策略、三兄弟问题
- 分布式锁 (看门狗)
- 降级容灾

**参考答案：**

**1. 缓存策略**

```
缓存分层: L1 Caffeine (热点) + L2 Redis (集群共享)

TTL 策略:
  业务配置 (费率/渠道) → 5-30 分钟
  会话 (JWT/用户) → 15 分钟-2 小时
  业务缓存 (余额/商户) → 1-5 分钟
  分布式锁 → 30s + 看门狗续期
  计数/限流 → 秒级

失效:
  主动 (数据变更时 evict) + 被动 (TTL) + 周期预热
```

**2. 缓存三兄弟**

```
穿透 (不存在的数据打到 DB):
  布隆过滤器 + 空值缓存 (短 TTL) + 参数校验

击穿 (热点 key 失效):
  互斥锁重建 + 热点数据永不过期

雪崩 (大量 key 同时过期):
  TTL 随机打散 (±30%) + 多级缓存 + DB 限流
```

**3. 分布式锁可靠性**

```java
// Redisson 看门狗: 默认 30s 锁 + 每 10s 续期
RLock lock = redissonClient.getLock("qbit:lock:" + key);
lock.lock(30, TimeUnit.SECONDS);
try { /* 业务 */ } finally { lock.unlock(); }

// GC pause 30s+ → 锁自动释放 (需业务幂等)
// 进程崩溃 → 30s 后自动释放 (无死锁)
// Redis 主从切换锁丢失 → Redlock 算法 (多数节点写)
```

**4. 降级策略**

```
一级 (部分 key 不可用): 非关键缓存降级，本地缓存兜底
二级 (Redis 全不可用): 所有读降级到 DB + 限流 + 锁降级乐观锁
三级 (极端场景): 热点数据静态化 + 降级页面

恢复: 逐步恢复 + 预热热 key，防止雪崩
```

---

## 六、典型故障排查类

### Q9. 线上故障排查：出金失败率突增

**题目：**
告警：出金失败率从 0.5% 突增到 15%。

背景：最近无上线、失败集中在渠道 CL、日志显示 timeout/connection reset、其他渠道正常。

**考察点：**
- 故障排查方法论
- 应急响应流程
- 根因分析

**参考答案：**

```
Step 1: 止损
  ① 检查 CL 是否已熔断
  ② 未熔断 → 人工降级 (PayOutWeight weight=0 或 Admin 禁用)
  ③ 通知 CL 服务商 → 确认对方状态

Step 2: 定位根因
  检查: 连接池? 响应时间? 错误日志? IP 白名单? SSL 证书? 第三方状态页?

Step 3: 可能根因
  └── 第三方故障 / 证书过期 / 我方 IP 被限 / 跨境网络波动

Step 4: 恢复 + 复盘
  ① 为什么熔断没触发? → 阈值过高? 检查周期太长?
  ② 告警及时? → 应 1 分钟内感知
  ③ 预防: 证书到期前 7 天告警 + 第三方健康大盘 + 自动降级机制
```

---

### Q10. 分布式链路追踪与性能调优

**题目：**
商户投诉 API 从 200ms 变成 2s。链路：商户 → OpenAPI → Gateway → 业务服务 → DB/Redis/渠道。

1. 如何快速定位瓶颈环节？
2. 如何排查 SQL 性能问题？
3. 排查发现某渠道询价从 200ms 变成 5s（该渠道已不可用），如何处理？

**考察点：**
- 链路追踪、SQL 性能分析
- 超时处理策略

**参考答案：**

**1. 链路追踪**

```java
// traceId (MDC) + 每个调用环节计时
[traceId: abc] 2320ms - PaymentChannelService#getOptimalChannel
[traceId: abc]   2100ms - CLChannelService#sendInquiry  ← 瓶颈
[traceId: abc]     50ms - ThunesChannelService#sendInquiry
```

优化方向：引入 OpenTelemetry/SkyWalking 全自动追踪。

**2. SQL 性能排查**

```
慢 SQL → PostgreSQL 慢查询日志 (200ms 阈值)
pg_stat_statements → 累计最慢 SQL TOP N

典型问题:
  N+1 → 改批量查询 / JOIN
  索引缺失 → EXPLAIN ANALYZE → 加索引
  大表扫描 → 查询必须带时间范围
```

**3. 不可用渠道的处理**

- 询价前检查熔断器 → 已熔断跳过
- 超时从 5s 缩短到 2s: `completeOnTimeout(null, 2, TimeUnit.SECONDS)`
- 已收集 2 个可用渠道 → 提前继续，不等剩余的
- 热门渠道询价结果缓存 30 秒
- 连续询价失败 → 实时告警

---

## 七、微服务架构设计类

### Q11. 单体 vs 微服务的架构演进

**题目：**
Qbit 目前是 Spring Boot 单体（qbit-core）包含所有模块。

1. 什么阶段做拆分？过早/过晚的风险？
2. 按什么原则拆分？第一批拆什么？
3. 拆分后如何应对分布式事务、跨服务查询、调用链变长？

**考察点：**
- 架构演进思维、康威定律
- DDD 限界上下文
- 微服务陷阱意识

**参考答案：**

**1. 拆分时机**

```
早期 (<50 万行, <10 人): 单体优先
中期 (50-200 万行, 10-30 人): 适度拆分 ← 黄金时期
晚期 (>200 万行, >30 人): 必须拆分

过早风险:
  分布式复杂性提前引入
  需求变更跨服务修改成本高
  不确定正确的服务边界

过晚风险:
  耦合严重，拆分成本指数增长
  构建/部署 > 15 分钟
  团队互相阻塞
```

**2. 拆分原则**

```
按业务域 (DDD 限界上下文):
  一个域变更不影响其他域

按变更频率:
  高频 → 独立服务 / 低频 → 保留

按数据所有权:
  每个服务自己的数据，其他服务 API 访问

按团队 (康威定律):
  一个服务一个团队

建议顺序:
  Gateway → Secret Manager → OpenAPI
  → 量子卡 → 加密资产 → 全球账户 → 商户
  → 通知 → 对账 → 报表
```

**3. 应对方案**

```
分布式事务:
  避免跨服务事务 → SAGA + 幂等 + 补偿 → 最终一致性

跨服务查询:
  API Gateway 聚合 / CQRS + 物化视图 / 分析库同步

调用链变长:
  全链路追踪 / 异步调用 / 缓存 / 服务网格

部署:
  容器化 + CI/CD + 契约测试 + 混沌工程
```

---

### Q12. 关键数据模型设计

**题目：**
Qbit 的核心交易涉及风控、费用、资产、交易、对账等多条记录串联。请设计交易核心数据模型。

**考察点：**
- 领域模型设计
- 可追溯性、扩展性

**参考答案：**

```
Transaction (核心):
  transaction_id (PK)
  source_transaction_id (UK) ← 幂等键
  merchant_id / account_id / business_type
  amount / currency / status / channel
  create_time / update_time / trace_id
     │
     ├── RiskRecord: risk_id, tx_id(FK), risk_type, is_rejected, risk_level
     ├── FeeRecord:  fee_id, tx_id(FK), fee_type, amount, currency
     ├── AssetsRecord: asset_id, tx_id(FK), asset_type, amount_before, amount_after
     └── Reconciliation: recon_id, tx_id(FK), external_id, match_status, difference
```

设计要点：
- 幂等键 `source_transaction_id` 唯一索引
- 所有关联记录通过 `transaction_id` 连接，完整可追溯
- 状态机限制非法转换（如 SUCCESS → PENDING 不允许）
- `extraParams` Map 扩展字段，避免频繁 schema 变更

---

## 八、架构师软技能与取舍决策

### Q13. 架构设计的取舍

**题目：**
请回答以下场景的取舍：

1. 团队想引入 Event Sourcing + CQRS，但都没用过。引入还是坚持当前方案？
2. 商户要求 P99 < 100ms，但某流程涉及链上查询 (2-10s)。怎么设计？
3. 管理层要求 1 个月交付新产品，但架构需要大重构。怎么平衡？

**考察点：**
- 架构决策、风险评估
- 沟通说服、务实 vs 理想主义

**参考答案：**

**1. 不引入 Event Sourcing**

原因：
- 学习成本高、运维复杂、Schema 版本管理难
- 当前状态机 + 事件 + 对账体系已满足审计要求
- Event Sourcing 只在审计极严且需要完整事件重建时有优势

**2. 异步化 + 即时响应**

```
API 层面:
  POST → 立即返回 {status: "PENDING", requestId}
  GET  → 查询最终状态

商户交互:
  轮询: GET 定期查
  Webhook: 状态变更主动推送
```

**3. 不重构 + 防腐层 (Anti-Corruption Layer)**

```
① 划定新产品"特区"（独立模块/schema）
② 特区与旧区之间加防腐层
   OldModel → AntiCorruptionLayer → NewModel
③ 上线优先，重构推后
④ 新产品稳定后评估是否拆独立服务
```

---

### Q14. 技术选型：规则引擎

**题目：**
对比 Drools、自研表达式（Groovy/SpEL）、决策表/DB 配置三种方案。

**考察点：**
- 技术选型框架
- 多维度对比

**参考答案：**

| 维度 | Drools | 自研表达式 | 决策表/DB |
|------|--------|-----------|----------|
| 性能 | 中 | 高 | 最高 |
| 规则复杂度 | 高 | 中 | 低 |
| 非技术参与 | 低 | 中 | 高 |
| 运维成本 | 中 | 低 | 低 |
| 审计追踪 | 内置 | 需自建 | 需自建 |

**建议: 混合策略**

- 简单规则（单条件）→ 决策表/DB 配置（业务人员自配置）
- 中等规则（多条件组合）→ 自研表达式（灵活、团队熟悉）
- 复杂规则（跨维度交叉、推理）→ Drools（Rete 网络优势）

---

## 面试辅助索引

| 轮次 | 题目 | 考察重点 |
|------|------|----------|
| 初面 (技术深度) | Q5 规则引擎、Q8 缓存、Q9 故障排查 | 实战经验 |
| 二面 (架构能力) | Q1 支付路由、Q2 供应商适配、Q7 数据库 | 架构设计、取舍 |
| 三面 (系统设计) | Q3 分布式事务、Q6 密钥管理、Q11 微服务 | 分布式、演进思维 |
| 交叉面 (软技能) | Q13 取舍决策、Q14 技术选型 | 决策、沟通 |
| 终面 (全局视野) | Q4 MQ 可靠性、Q10 链路追踪 | 可观测性、系统性思考 |
