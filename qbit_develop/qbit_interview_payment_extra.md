# 支付赛道面试补充题

> 补充题，覆盖 Java 底层 / Node.js / 区块链方向，聚焦支付场景实战。

---

## 一、Java 底层与支付场景

### J1. JVM 调优：支付系统的 GC 问题

**题目：**
你负责的支付系统在每天 14:00-15:00 出现频繁的 Full GC，接口响应从 200ms 飙升到 5s。你如何处理？

**考察点：**
- JVM 内存模型、GC 原理
- 问题排查工具（jstat/jmap/Arthas）
- 调优方案

**参考答案：**

```
Step 1: 确认现象
  - 通过监控发现: GC 耗时从 200ms → 3s，Full GC 频率从 1次/小时 → 1次/分钟
  - 接口 RT 飙升，伴随 CPU 飙高

Step 2: 定位根因
  - jstat -gcutil <pid> 1s: 观察 Old 区使用率，Full GC 后不下降 → 内存泄漏
  - jmap -histo <pid>: 找到 byte[]/char[] 或业务对象占用异常
  - jmap -dump:live 导出堆栈 → MAT 分析
  - Arthas: dashboard / memory / thread 排查

Step 3: 支付场景典型问题
  ┌─────────────────────────────────┬────────────────────────────────┐
  │ 问题类型                         │ 支付场景具体表现                │
  ├─────────────────────────────────┼────────────────────────────────┤
  │ 渠道回调未及时反序列化释放        │ RocketMQ 消息体太大，byte[] 堆积   │
  │ 商户报表导出没分页                │ 一次查询几十万条，List 占满 Old    │
  │ 分布式锁未释放 + 重试            │ Redisson 看门狗续期失败，锁残留   │
  │ 全量缓存加载                      │ 启动时加载全量费率表到堆内        │
  │ 对账大文件解析                    │ Excel/CSV 一次读入全部行          │
  └─────────────────────────────────┴────────────────────────────────┘

Step 4: 解决方案
  ┌──────────────────────┬──────────────────────────────────────┐
  │ 优化方向               │ 方案                                 │
  ├──────────────────────┼──────────────────────────────────────┤
  │ 渠道回调 Message         │ 限制 256KB+ 消息存 OBS，MQ 只传引用    │
  │ 报表导出               │ 游标分批查询 + 流式写入 (SXSSFWorkbook)  │
  │ P2P 对大对象实时计算     │ ThreadLocal + 池化对象复用              │
  │ 费率/渠道配置           │ Caffeine 本地缓存 + Redis L2            │
  │ 对账文件解析            │ SAX (流式) 解析 + 多线程分片处理          │
  └──────────────────────┴──────────────────────────────────────┘

Step 5: 长期预防
  - 上线前: GC 压测 + 配置调优（-Xms -Xmx 等）
  - 运行期: Full GC 告警 + 堆转储自动上传
  - 日常: Arthas 定时采样 + 内存泄漏自动化检测
```

---

### J2. 支付场景的并发编程

**题目：**
系统支持商户查询账户余额。商户 A 同时发来 2 个请求：请求 1（出金 5000）和请求 2（刷新余额），账户余额 10000。如果不加控制，会出现什么问题？请设计方案。

**考察点：**
- 竞态条件理解
- 锁机制（乐观/悲观）
- 账户余额的并发安全设计

**参考答案：**

**1. 问题分析**

```
不加控制时：
  请求 1: 读取余额 10000 → 计算 10000-5000=5000 → 写回 5000
  请求 2: 读取余额 10000 → 刷新显示 10000
                 ↑ 脏读：请求 2 读到旧余额

更严重的情况（同一商户并发出金）：
  请求 1(出金6000): 读余额10000 → 检查余额足够 → 写回4000
  请求 2(出金7000): 读余额10000 → 检查余额足够 → 写回3000
                 ↑ 超卖：实际余额只剩 3000，但两笔都成功了
```

**2. 数据库乐观锁方案（推荐）**

```sql
-- 添加 version 字段
UPDATE account SET balance = balance - 6000, version = version + 1
WHERE account_id = ? AND balance >= 6000 AND version = ?;

-- 影响行数 = 1 → 成功
-- 影响行数 = 0 → 重试或失败
```

**3. Redis 分布式锁方案**

```java
RLock lock = redissonClient.getLock("balance:lock:" + accountId);
lock.lock(5, TimeUnit.SECONDS);
try {
    Balance balance = balanceRepo.findByAccountId(accountId);
    if (balance.getAmount().compareTo(amount) < 0) {
        throw new InsufficientBalanceException();
    }
    balanceRepo.deduct(accountId, amount);
} finally {
    lock.unlock();
}
```

**4. 支付场景特殊考虑**

```
┌──────────────────┬──────────────────────────────────────────┐
│ 场景               │ 锁策略                                   │
├──────────────────┼──────────────────────────────────────────┤
│ 单账户并发出金       │ version 乐观锁 + 分布式锁兜底                │
│ 批量出金           │ 单账户加锁，多账户并行                       │
│ 余额查询           │ 无锁 (MVCC 读)                           │
│ 对账修复           │ 单笔人工修复加行锁                           │
│ 跨账户转账         │ 固定顺序加锁避免死锁                         │
└──────────────────┴──────────────────────────────────────────┘
```

---

### J3. 支付幂等设计

**题目：**
支付结果通知可能重复投递多次。请设计一个幂等方案，保证重复通知不会导致重复入账或重复处理。

**考察点：**
- 幂等键设计
- 分布式锁 + 幂等表
- 防重入判断

**参考答案：**

**1. 幂等键生成策略**

```java
// 每种业务场景生成唯一幂等键
// 支付回调: orderId + channel + channelSerialNo
// 充值入账: chainId + txHash + logIndex
// 对账修正: orderId + reconDate + operationType

String idempotentKey = buildIdempotentKey(orderId, channel, channelSerialNo);
```

**2. 幂等拦截器**

```java
public class IdempotentHandler {
    public boolean tryProcess(String bizKey, String bizType) {
        // 1. Redis 分布式锁 (防止并发)
        RLock lock = redissonClient.getLock("idempotent:" + bizKey);
        if (!lock.tryLock(3, 5, TimeUnit.SECONDS)) {
            throw new ConcurrentProcessException("并发处理中");
        }
        try {
            // 2. 幂等表判断 (唯一索引)
            IdempotentRecord record = idempotentMapper.selectByBizKey(bizKey);
            if (record != null) {
                return false; // 已处理, 跳过
            }
            // 3. 记录幂等 (先插入)
            idempotentMapper.insert(new IdempotentRecord(bizKey, bizType, Status.PROCESSING));
            return true; // 首次处理
        } finally {
            lock.unlock();
        }
    }

    public void complete(String bizKey, boolean success) {
        idempotentMapper.updateStatus(bizKey, success ? Status.SUCCESS : Status.FAILED);
    }
}
```

**3. 幂等表设计**

```sql
CREATE TABLE idempotent_record (
    id BIGSERIAL PRIMARY KEY,
    biz_key VARCHAR(128) NOT NULL,     -- 幂等键
    biz_type VARCHAR(32) NOT NULL,     -- 业务类型 (PAYMENT_CALLBACK/RECHARGE/RECONCIL)
    status VARCHAR(16) NOT NULL,       -- PROCESSING/SUCCESS/FAILED
    response_json TEXT,                -- 首次处理结果 (重复时直接返回)
    create_time TIMESTAMP DEFAULT NOW(),
    update_time TIMESTAMP,

    UNIQUE (biz_key)                  -- 唯一索引保证幂等
);

-- 定时清理: 保留 7 天, 避免表过大
```

**4. 重复消息的场景处理**

```
┌──────────────────┬────────────────────────────────────────┐
│ 重复场景           │ 幂等方案                                │
├──────────────────┼────────────────────────────────────────┤
│ MQ 消息重复消费     │ 消息 body 提取 bizKey → 幂等表判断         │
│ 渠道回调重复通知     │ channelCallbackId → 幂等表               │
│ 商户 API 重试      │ 商户请求中的 idempotentKey → 幂等表       │
│ 定时任务补偿        │ 扫描范围 + 补偿记录表                     │
│ 链上事件重复监听     │ chainId + txHash + logIndex            │
└──────────────────┴────────────────────────────────────────┘
```

---

### J4. Spring 事务在支付场景的坑

**题目：**
支付系统中，同一个 Service 里 `createOrder()` 内部调 `deductBalance()`，各自声明了 `@Transactional`。高并发下出现余额扣了但订单没创建成功的问题，为什么？

**考察点：**
- Spring 事务传播机制
- @Transactional 自调用失效
- 事务隔离级别

**参考答案：**

**1. 自调用陷阱**

```java
@Service
public class PaymentService {
    @Transactional
    public void createOrder(Order order) {
        // 1. 创建订单
        orderDao.insert(order);
        // 2. 扣余额
        this.deductBalance(order.getAccountId(), order.getAmount());
        //    ↑ 注意: this.deductBalance() 是自调用
        //    不走 AOP 代理 → @Transactional 不生效
        //    扣余额和创建订单不在同一个事务
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void deductBalance(Long accountId, BigDecimal amount) {
        accountDao.deduct(accountId, amount);
    }
}
```

**2. 解决方案**

```java
// 方案一: @Autowired 注入自身代理
@Service
public class PaymentService {
    @Autowired
    private PaymentService self; // 注入代理

    @Transactional
    public void createOrder(Order order) {
        orderDao.insert(order);
        self.deductBalance(order.getAccountId(), order.getAmount()); // 走代理
    }
}

// 方案二: 拆成两个 Service
// PaymentService → 事务编排
// AccountService → 余额操作事务

// 方案三: 编程式事务 (TransactionTemplate)
@Autowired
private TransactionTemplate txTemplate;

public void createOrder(Order order) {
    txTemplate.execute(status -> {
        orderDao.insert(order);
        accountDao.deduct(order.getAccountId(), order.getAmount());
        return null;
    });
}
```

**3. 支付场景的事务隔离**

```
┌────────────┬──────────┬──────────────────────────────────────┐
│ 隔离级别     │ 脏读     │ 支付场景                                 │
├────────────┼──────────┼──────────────────────────────────────┤
│ READ_UNCOMMITTED │ 可能    │ ❌ 从来不用于资金操作                     │
│ READ_COMMITTED   │ 不可能  │ ✅ PostgreSQL 默认, 适合大部分支付场景    │
│ REPEATABLE_READ  │ 不可能  │ ✅ 某些对账/报表场景需要                      │
│ SERIALIZABLE     │ 不可能  │ ❌ 性能差, 仅极端高安全场景                  │
└────────────┴──────────┴──────────────────────────────────────┘

典型场景：
  - 扣余额: 悲观锁 (SELECT ... FOR UPDATE) + READ_COMMITTED
  - 查询流水: READ_COMMITTED
  - 对账/报表: REPEATABLE_READ (防止同一事务内前后数据不一致)
```

---

### J5. MyBatis-Plus 批量操作的性能优化

**题目：**
对账系统每天需要插入 100 万条对账记录。直接用 MyBatis-Plus `saveBatch()` 发现非常慢（10万条需要 3 分钟）。如何优化？

**考察点：**
- MyBatis-Plus 批量原理
- JDBC Batch 机制
- 支付场景的大数据量处理

**参考答案：**

```
原因: MyBatis-Plus saveBatch() 默认逐条 INSERT，不是真正批量
  每条 INSERT 一次网络往返，100万条 = 100万次网络IO

方案一: 真正的 JDBC Batch
  jdbc:postgresql://host/db?reWriteBatchedInserts=true
  ↑ 最关键: PostgreSQL JDBC 驱动默认不批量重写，必须加这个参数

方案二: MyBatis 批量配置
  mybatis-plus:
    global-config:
      db-config:
        insert-strategy: not_null
    executor-type: batch  # 批量执行器

方案三: 分片 + 多线程 (百万级数据)
  ┌──────────────────────────────────────────────┐
  │ 主线程: 读取 CSV 按 5000 条一批分片            │
  │    → 提交到线程池 (8-16 线程)                   │
  │       → 每个线程处理一批, 批量 INSERT 5000 条    │
  │          → 每批完成后提交事务                    │
  └──────────────────────────────────────────────┘

性能对比 (100万条):
  ┌─────────────────────┬──────────────────────────┐
  │ 方案                 │ 耗时                      │
  ├─────────────────────┼──────────────────────────┤
  │ saveBatch() 默认     │ ~30 分钟                  │
  │ JDBC Batch           │ ~3 分钟                   │
  │ 分片 + 多线程 + Batch │ ~30 秒                   │
  └─────────────────────┴──────────────────────────┘
```

---

## 二、Node.js 支付场景

### N1. Node.js 在支付系统的定位

**题目：**
Node.js 在跨境支付系统中通常用在哪些环节？和 Java 怎么分工？

**考察点：**
- Node.js 适用场景理解
- 技术选型判断

**参考答案：**

```
Node.js 的定位: BFF (Backend For Frontend) + 轻量网关 + 实时推送

┌──────────────────┬─────────────────────────────────────────┐
│ 适合 Node.js 的    │ 不适合 Node.js 的                       │
├──────────────────┼─────────────────────────────────────────┤
│ 商户 OpenAPI 网关   │ 资金核心链路 (扣款/入账)                  │
│ 商户 Webhook 推送   │ 分布式事务编排 (SAGA)                    │
│ WebSocket 实时通知   │ 对账引擎                               │
│ 轻量渠道转发         │ 风控规则引擎 (Drools)                    │
│ 汇率/行情代理        │ 批处理/大数据量处理                       │
│ 管理后台 API         │ KMS/Secret Manager                    │
└──────────────────┴─────────────────────────────────────────┘

典型架构:
  Node.js BFF (Express/Fastify/Koa)
    → 商户 API 入口、Webhook 分发、WebSocket 状态推送
    → 调用下游 Java 核心服务 (gRPC/HTTP)
    → 不做资金操作，只做编排和转发

  Java 核心服务
    → 交易、账务、风控、对账、清结算
    → 资金安全由 Java 强类型 + 事务 + 审计保证
```

---

### N2. Node.js 异步流程控制

**题目：**
商户 Webhook 推送需要保证：按商户维度顺序投递、失败重试、退避策略。用 Node.js 怎么设计？

**考察点：**
- Node.js 异步编程
- 消息队列使用

**参考答案：**

```js
// 按商户分区 + 顺序消费 + 重试退避
class WebhookDispatcher {
  constructor() {
    this.queues = new Map(); // merchantId → Queue
  }

  // 按商户入队，保证同一商户顺序
  async dispatch(merchantId, event) {
    if (!this.queues.has(merchantId)) {
      this.queues.set(merchantId, []);
    }
    this.queues.get(merchantId).push(event);
    this.processQueue(merchantId);
  }

  async processQueue(merchantId) {
    if (this.processing.has(merchantId)) return;
    this.processing.add(merchantId);

    while (this.queues.get(merchantId)?.length > 0) {
      const event = this.queues.get(merchantId).shift();
      try {
        await this.sendWithRetry(event, 3); // 最多重试3次
      } catch (err) {
        // 进死信队列，后续人工处理
        await this.deadLetter(event, err);
      }
    }

    this.processing.delete(merchantId);
  }

  // 退避重试: 1s → 5s → 30s
  async sendWithRetry(event, maxRetries) {
    const delays = [1000, 5000, 30000];
    for (let i = 0; i < maxRetries; i++) {
      try {
        return await axios.post(event.callbackUrl, event.payload, {
          timeout: 10000,
        });
      } catch (err) {
        if (i === maxRetries - 1) throw err;
        await sleep(delays[i]);
      }
    }
  }
}
```

---

### N3. Node.js 内存泄漏排查

**题目：**
Node.js 服务运行 2 天后内存从 200MB 涨到 2GB。怎么排查？

**考察点：**
- Node.js 内存管理
- 排查手段

**参考答案：**

```
常见原因:
  1. 闭包未释放 (回调持有大对象引用)
  2. 全局变量或 Map 未清理 (商户 WebSocket 连接断开后未 remove)
  3. 大对象未及时 GC (渠道回调 JSON 未释放)
  4. 定时器未清除 (setInterval 忘记 clear)

排查步骤:
  Step 1: --inspect 开启 Chrome DevTools
  Step 2: heap snapshot 对比 (启动时 vs 2天后)
  Step 3: 找 retained size 最大的对象

支付场景典型泄漏:
  - WebSocket 商户连接，断开后 Map 未 delete
  - 渠道路由缓存，rate 更新无限追加
  - 对账文件 stream 未 destroy
```

---

### N4. Node.js 处理支付回调的坑

**题目：**
Node.js 接收支付渠道回调时，出现签名验证失败、幂等处理线程不安全等问题。怎么设计一个健壮的回调处理服务？

**考察点：**
- Node.js 单线程模型理解
- 回调处理架构

**参考答案：**

```js
// 健壮的支付回调处理器

class CallbackHandler {
  // 1. 签名验证
  async verifySignature(channel, headers, body) {
    const config = this.channelConfigs[channel];
    const sign = headers['x-signature'];
    const computed = crypto
      .createHmac('sha256', config.secret)
      .update(JSON.stringify(body))
      .digest('hex');
    if (sign !== computed) {
      throw new Error(`Signature mismatch: ${channel}`);
    }
  }

  // 2. 幂等处理 (单线程天然串行，但多实例需要分布式锁)
  async idempotentProcess(channel, callbackId, handler) {
    // Redis SET NX 实现分布式锁
    const lockKey = `callback:${channel}:${callbackId}`;
    const acquired = await redis.set(lockKey, '1', 'NX', 'EX', 60);
    if (!acquired) {
      return { status: 'duplicate' }; // 重复回调
    }
    return await handler();
  }

  // 3. 结果可靠投递 (防止回调处理中进程崩溃)
  async handle(channel, headers, body) {
    await this.verifySignature(channel, headers, body);

    return await this.idempotentProcess(channel, body.id, async () => {
      // 先保存回调原始记录
      await this.saveCallbackRecord(channel, body);

      // 发送到 MQ (由 Java 核心服务处理资金操作)
      // Node.js 只做转发不做资金操作
      await mqProducer.send({
        topic: 'payment_callback',
        key: body.orderId,
        value: JSON.stringify({ channel, body }),
      });

      return { status: 'accepted' };
    });
  }
}
```

---

## 三、区块链/加密货币支付

### B1. 链上充值确认机制

**题目：**
用户向平台地址转账 USDT，平台需要确认到账后才能入账。但链上交易可能被重组（reorg）、可能 pending 几小时、可能没到最小确认数。请设计充值确认和入账流程。

**考察点：**
- 链上交易确认机制
- 链重组处理
- 安全入账设计

**参考答案：**

```
Step 1: 事件监听
  轮询或 WebSocket 监听链上 Transfer 事件
  → 获取 txHash, from, to, value, logIndex

Step 2: 确认数等待
  ┌────────────┬────────────┐
  │ 链          │ 确认数要求    │
  ├────────────┼────────────┤
  │ Bitcoin    │ 6 个区块     │
  │ Ethereum   │ 12 个区块    │
  │ TRON       │ 19 个区块    │
  │ BSC        │ 15 个区块    │
  │ Polygon    │ 64 个区块    │
  └────────────┴────────────┘
  确认数不足 → 标记 PENDING，等待后续块

Step 3: 链重组检测
  ┌──────────────────────────────────────────────────┐
  │ 正常链: ... → Block 100 → Block 101 → Block 102  │
  │                              ↓ 重组               │
  │ 重组链: ... → Block 100 → Block 101'→ Block 102' │
  │                                                  │
  │ 检测: 发现 Block 101 的 parentHash 不对           │
  │   → 回滚 Block 101 中已入账的交易                  │
  │   → 重新处理 Block 101' 中的交易                   │
  └──────────────────────────────────────────────────┘

Step 4: 入账处理
  // 幂等键: chainId + txHash + logIndex (唯一)
  // 确认数达到后:
  //   1. 校验地址归属 (to address 是否为平台地址)
  //   2. 校验币种 (合约地址匹配)
  //   3. 校验金额 (>= 最小入账金额)
  //   4. 幂等表判断 (已入账就跳过)
  //   5. 入账: 增加平台账户余额 + 记录流水
  //   6. 通知商户

Step 5: 异常处理
  ┌────────────────┬─────────────────────────────┐
  │ 异常场景         │ 处理                          │
  ├────────────────┼─────────────────────────────┤
  │ 交易 pending 超过24h │ 标记为异常，人工核查          │
  │ 链重组导致回滚       │ 回滚已入账金额，重新处理新块    │
  │ 充值到旧地址         │ 检查地址是否在有效期内          │
  │ 金额小于最小入账     │ 记录但不入账，通知用户补足      │
  │ 合约地址不匹配       │ 跨链转账/空投，返回原地址      │
  └────────────────┴─────────────────────────────┘
```

---

### B2. 链上提现流程设计

**题目：**
商户申请提现加密货币。从风控→审核→上链广播→确认到账，涉及资金安全，请设计全流程。

**考察点：**
- 提现安全设计
- 多签/风控
- 链上广播管理

**参考答案：**

```
商户提现 → 系统风控 → 人工审核(按金额) → 链上广播 → 确认到账

1. 风控拦截
   - 地址黑名单/白名单
   - 单笔限额/日累计限额
   - 异常频次检测 (同地址频繁提现)
   - Chainalysis 地址风险评估

2. 人工审核（按金额分级）
   ┌──────────────┬──────────────────────────────┐
   │ 金额范围       │ 审核级别                       │
   ├──────────────┼──────────────────────────────┤
   │ < 1000 USDT  │ 自动 (Drools 规则通过即可)        │
   │ 1000-10000   │ 运营人工审核                      │
   │ 10000-50000  │ 运营 + 风控主管                   │
   │ > 50000      │ 运营 + 风控 + CEO                │
   └──────────────┴──────────────────────────────┘

3. 链上广播管理
   ┌────────────────┬──────────────────────────────┐
   │ 组件             │ 职责                          │
   ├────────────────┼──────────────────────────────┤
   │ 热钱包           │ 存少量资金，自动签名广播          │
   │ 冷钱包           │ 存大额资金，手动多签              │
   │ 广播队列         │ 按 nonce 顺序广播，防止交易卡住  │
   │ gas 管理         │ 动态调整 gas price，避免 pending │
   └────────────────┴──────────────────────────────┘

4. 确认到账
   - 获取 txHash → 轮询链上交易回执
   - 确认数达到 → 标记 SUCCESS
   - 交易失败 (out of gas / revert) → 回滚冻结 → 重新广播
   - 超过 N 块未确认 → 提高 gas 重新广播 (replace by fee)
```

---

### B3. 热钱包/冷钱包管理

**题目：**
平台持有大量加密资产，如何设计热钱包和冷钱包的资金管理方案？

**考察点：**
- 资产安全管理
- 多签/私钥管理
- 资金调度

**参考答案：**

```
1. 钱包分级
   ┌────────────┬──────────┬──────────┬──────────────────┐
   │ 钱包类型     │ 占资产  │ 私钥存储  │ 用途               │
   ├────────────┼──────────┼──────────┼──────────────────┤
   │ 热钱包       │ 5-10%    │ 服务器   │ 日常提现、自动出金    │
   │ 温钱包       │ 20-30%   │ HSM      │ 大额提现、多签       │
   │ 冷钱包       │ 60-70%   │ 离线     │ 长期存储、资产安全   │
   └────────────┴──────────┴──────────┴──────────────────┘

2. 资金调度策略
   ┌──────────────────────────────────────────────────┐
   │ 热钱包余额 < 阈值                                │
   │   → 从温钱包转 (多签审批)                         │
   │                                                  │
   │ 温钱包余额 < 阈值                                │
   │   → 从冷钱包转 (多签 + 多人审批 + 24h 延迟)        │
   │                                                  │
   │ 冷钱包: 只在充值和紧急情况操作                      │
   └──────────────────────────────────────────────────┘

3. 多签方案
   - 3/5 多签: 5 个签名人中 3 人签名才能动钱
   - 签名人: CEO, CTO, CFO, 风控负责人, 合规负责人
   - 大额转账: 需要更多签名 + 时间锁延迟

4. 安全措施
   - 每日提现限额 (热钱包总额限制)
   - 地址白名单 (只能提现到已审核地址)
   - 异常地址检测 (Chainalysis API)
   - 链上交易模拟 (先 simulate 再广播)
   - 所有提现操作记录操作人 + 审核人 + 原因
```

---

### B4. 跨链桥/多链支持

**题目：**
平台需要支持 ETH、BSC、TRON、Polygon 等多条链的充值和提现。每条链的技术栈不同（地址格式、合约标准、确认数不同），如何架构？

**考察点：**
- 多链抽象设计
- 适配器模式
- 链差异化处理

**参考答案：**

```
┌─────────────────────────────────────────────────────────────┐
│                区块链适配层 (BlockchainAdapter)                │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                   ChainFactory                        │   │
│  │   InitializingBean → 按 ChainType 注册各链实现        │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐   │
│  │ ETH      │ │ BSC      │ │ TRON     │ │ Polygon      │   │
│  │ Adapter  │ │ Adapter  │ │ Adapter  │ │ Adapter      │   │
│  │ Web3j    │ │ Web3j    │ │ TronWeb  │ │ Web3j + Matic│   │
│  │ ERC20    │ │ BEP20    │ │ TRC20    │ │ PoS/Polygon  │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘   │
│             │          │          │          │              │
│        JSON-RPC   JSON-RPC   gRPC/HTTP   JSON-RPC           │
└─────────────────────────────────────────────────────────────┘

统一接口定义:

interface ChainAdapter {
    String getChainName();
    String generateAddress();           // 生成充值地址
    BigDecimal getBalance(String address); // 查询余额
    String sendTransaction(String to, BigDecimal amount, String privateKey);
    TransactionReceipt getReceipt(String txHash);
    int getRequiredConfirmations();     // 各链确认数不同
    boolean isAddressValid(String address); // 地址校验
    String getExplorerUrl(String txHash); // 浏览器链接
}

各链差异:
┌──────────┬────────────┬──────────────┬──────────────────┐
│ 链        │ 地址格式      │ 合约标准        │ 确认数              │
├──────────┼────────────┼──────────────┼──────────────────┤
│ ETH      │ 0x...40位   │ ERC20        │ 12                │
│ BSC      │ 0x...40位   │ BEP20        │ 15                │
│ TRON     │ T...34位    │ TRC20        │ 19                │
│ Polygon  │ 0x...40位   │ ERC20        │ 64                │
└──────────┴────────────┴──────────────┴──────────────────┘
```

---

### B5. 链上Gas管理策略

**题目：**
以太坊网络拥堵时，gas price 飙升，交易可能几小时 pending。如何设计 gas 管理策略保证提现不被卡住又不浪费手续费？

**考察点：**
- Gas 机制理解
- 动态调价策略
- Replace by Fee (RBF)

**参考答案：**

```
1. Gas Price 分级
   ┌────────────┬─────────────────────┬─────────────────┐
   │ 优先级      │ Gas Price 策略        │ 适用场景           │
   ├────────────┼─────────────────────┼─────────────────┤
   │ 紧急       │ 当前 base + 50%      │ 大额提现、用户催办   │
   │ 正常       │ 当前 base + 20%      │ 日常提现           │
   │ 经济       │ 当前 base + 5%       │ 内部归集、非紧急    │
   │ 最低       │ 历史 30 分钟最低价    │ 测试/小额           │
   └────────────┴─────────────────────┴─────────────────┘

2. Replace by Fee (RBF) 策略
   // 如果交易 pending 超过 N 块
   // 创建一笔新交易: nonce 相同, gas 更高, to 是自己
   // 矿工会优先打包 gas 高的交易

   async function replaceByFee(pendingTx, newGasPrice) {
       const tx = {
           nonce: pendingTx.nonce,     // 相同 nonce
           to: pendingTx.from,         // 转给自己
           value: '0x0',               // 0 金额
           gasPrice: newGasPrice,      // 更高的 gas
           gasLimit: 21000,
       };
       return await wallet.sendTransaction(tx);
   }

3. Gas 预测
   - 根据历史数据预测未来 5 分钟 gas 走势
   - 低峰期 (凌晨) 批量发送
   - 监控 mempool pending 量，pending 多就等
```

---

## 面试辅助索引

| 方向 | 编号 | 题目 | 考察点 | 面试轮次 |
|------|------|------|--------|---------|
| Java | J1 | JVM GC 问题排查 | 内存模型、调优 | 初面 |
| Java | J2 | 账户余额并发安全 | 锁、乐观锁 | 初面/二面 |
| Java | J3 | 支付幂等设计 | 幂等键、防重 | 初面 |
| Java | J4 | Spring 事务陷阱 | 事务传播、自调用 | 初面 |
| Java | J5 | MyBatis 批量性能优化 | Batch、分片 | 初面 |
| Node.js | N1 | Node.js 在支付定位 | 技术选型 | 交叉面 |
| Node.js | N2 | Webhook 顺序投递 | 异步流程、退避 | 二面 |
| Node.js | N3 | Node.js 内存泄漏 | 排查手段 | 初面 |
| Node.js | N4 | 支付回调健壮设计 | 签名、幂等、MQ | 二面 |
| 区块链 | B1 | 链上充值确认 | 确认数、重组、入账 | 二面 |
| 区块链 | B2 | 链上提现流程 | 风控、审核、广播 | 二面 |
| 区块链 | B3 | 热钱包/冷钱包管理 | 安全、多签 | 三面 |
| 区块链 | B4 | 多链支持架构 | 适配器、多链差异 | 二面 |
| 区块链 | B5 | Gas 管理策略 | RBF、动态调价 | 二面 |

---

**建议准备顺序：**
1. **先：** J2(并发) + J3(幂等) + 之前那3道VCC题 → PingPong面试核心
2. **再：** B1(充值) + B2(提现) + B3(钱包) → 如果有加密货币岗位
3. **有余力：** J1/J4/J5 + N1-N4 → 拓宽覆盖面
