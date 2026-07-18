# Qbit 对账体系 (Reconciliation System)

> 基于 `qbit-core` (Spring Boot) 代码库分析。
> 对账体系涵盖日账单、客户结算单、加密资产/理财对账、卡结算、外部渠道结算、实时结算、清退销户。
> 最后更新: 2025-06-12

---

## 1. 架构概览

### 1.1 整体拓扑

```
┌────────────────────────────────────────────────────────────────────┐
│                        对账体系总览                                   │
│                                                                    │
│  定时任务 (XXL-Job)          实时(MQ)          手动(Admin API)       │
│  ┌──────────────────┐   ┌──────────────┐   ┌───────────────────┐  │
│  │ DailySettleJob   │   │ Realtime-    │   │ ManualSettle-     │  │
│  │ CustomerSettleJob│   │ Settlement   │   │ Controller        │  │
│  │ BalanceSnapshot  │   │ Listener     │   │ SettleFileCtrl    │  │
│  │ SettlementRecord │   └──────────────┘   │ DailyStatement-   │  │
│  │ crypto/bb/i2c/sl │                      │ AdminController   │  │
│  └────────┬─────────┘                      └───────────────────┘  │
│           │                                                       │
│           ▼                                                       │
│  ┌──────────────────────────────────────────────────────────┐     │
│  │                   对账/结算核心                              │     │
│  │                                                          │     │
│  │  日账单           客户结算             渠道结算              │     │
│  │  StatementHandler  QbitStatement      SettlementHandler   │     │
│  │  HandlerRegistry   Service            Factory             │     │
│  │  BalanceSnapshot   CustomerSettleType  BbSettleService    │     │
│  │  DailyStatement    QbitCoreSettleFile  I2cSettleService   │     │
│  │  Service           Service             SlSettleService    │     │
│  │                                                          │     │
│  │  加密资产对账        理财对账            清退销户              │     │
│  │  StatementFactory  FundReconcili-     ClearService        │     │
│  │  (Circle/OKX)      ationService       ClearExecution-    │     │
│  │  CryptoAssetV2-                       Service             │     │
│  │  Reconciliation-                                          │     │
│  │  Service                                                   │     │
│  └──────────────────────────────────────────────────────────┘     │
│                                                                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────────────┐  │
│  │ 日账单    │ │客户结算单  │ │渠道结算   │ │ 账单/扣款           │  │
│  │ XLSX+OSS  │ │XLSX+OSS   │ │交易记录   │ │ MonthBill         │  │
│  │ Balance-  │ │SettleFile │ │Settlement │ │ ApiClientBill     │  │
│  │ Snapshot  │ │表         │ │表        │ │ DebitBill         │  │
│  └──────────┘ └──────────┘ └──────────┘ └────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

### 1.2 对账类型

| 类型 | 触发方式 | 输出 | 说明 |
|------|----------|------|------|
| OpenAPI V3 日账单 | DailySettleJob (每日 D-1) | XLSX+ZIP → OSS | StatementHandler 策略模式，每产品线独立实现 |
| 客户结算单 | CustomerSettleJob (每月 1 号) | XLSX → OSS | 按币种区分，4 种结算类型 |
| 加密资产对账 | StatementFactory | 对账结果 | Circle/OKX 本地 vs 三方交易对账 |
| 卡结算 | SettlementHandlerFactory | Settlement 表 | QbitCard 结算处理责任链 |
| 外部渠道结算 | BB/I2C/SL 定时任务 | 结算记录 | 卡组/渠道侧对账与手续费计算 |
| 实时结算 | MQ RealtimeSettlementListener | Settlement 表 | 交易完成后实时触发 |
| 理财对账 | Admin API | 对账明细 | 粒子理财资金端对账 |
| 清退销户 | ClearProcessJob | Clear 流程 | 账户注销前资产清算 |

### 1.3 核心实体

| 表 | 说明 |
|----|------|
| `daily_statement_file` | 日账单文件记录 (OSS URL、状态) |
| `daily_statement_transaction` | 日账单交易明细 |
| `balance_snapshot` | 余额快照 (月初) |
| `qbit_core_settle_file` | 客户结算文件 (对账单文件) |
| `qbit_card_settlement` | 量子卡结算记录 |
| `payment_settlement_record` | 出金结算记录 |
| `fund_settlement` | 理财结算记录 |

---

## 2. 日账单系统 (Daily Statement)

### 2.1 StatementHandler 策略模式

**StatementHandler** — 日账单策略接口，每个产品线一个实现:

```java
public interface StatementHandler {
    String getAccountType();                          // 产品线标识
    List<BalanceSummaryVO> getBalanceSummary(...);    // 余额汇总
    List<DailyTransactionVO> pageTransactions(...);   // 交易流水
    boolean hasTransactions(...);                     // 是否有交易
    String getWalletType();                           // 钱包类型
    List<BalanceSnapshot> buildBalanceSnapshots(...); // 构建余额快照
}
```

**StatementHandlerRegistry:** Spring 启动时自动收集所有 Handler Bean，按 `accountType` 注册到 Map。

### 2.2 Handler 实现

| Handler | 产品线 | 说明 |
|---------|--------|------|
| `BusinessAccountHandler` | Business Account | 业务账户出入金 |
| `CryptoAssetHandler` | Crypto Asset | 加密资产账户 |
| `PrepaidCardHandler` | Prepaid Card | 预付卡 |
| `InfinityAccountHandler` | Infinity Account | Infinity 账户 |
| `BudgetCardHandler` | Budget Card | 预算卡 |

### 2.3 日账单生成流程

```
DailySettleJob (每日凌晨 D-1)
    │
    ├── 1. Redisson 分布式锁
    ├── 2. 查询活跃账户列表 (分页 500/批)
    ├── 3. 对每个账户:
    │       └── StatementHandlerRegistry.getHandler(accountType)
    │            ├── getBalanceSummary (余额汇总)
    │            ├── pageTransactions (交易流水)
    │            └── EasyExcel 填充模板 → XLSX
    ├── 4. DailyStatementZipBuilder 打包 ZIP
    ├── 5. 上传 OSS → 记录 daily_statement_file
    └── 6. 清理过期占位
```

### 2.4 日账单模板

XLSX 包含:

| Sheet | 内容 |
|-------|------|
| 资金明细 | 期初余额、收支明细(逐笔)、期末余额 |
| 多币种 | 各币种出入金小计 |
| 费用 | 手续费明细 |

- EasyExcel 模板填充 + `FillConfig(WriteDirectionEnum.VERTICAL)`
- `StatementFormulaWriter` 自动写入 SUM/期初/期末公式
- `BalanceSummaryUSDVO` 所有币种统一折算 USD

### 2.5 余额快照 (BalanceSnapshot)

**BalanceSnapshotJob:** 每月 1 号通过反向推导记录月初余额。

反向推导公式:
```
月初余额 = 上月末实时余额 - 当月收入 + 当月支出
```

**实现:** `BalanceSnapshotService.snapshot()` 对各 Handler 调用 `buildBalanceSnapshots()`。

### 2.6 日账单重生成

```java
dailyStatementService.regenerate(accountId, date)
```

Redis 信号量控制 (`Semaphore`):
- 单请求人: 最多 1 个并发任务
- 全局: 最多 10 个并发任务

异步处理: 创建 TaskProgress → 发送 MQ → 异步重新生成。

### 2.7 OpenAPI V3 接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `open-api/v3/statements/xlsx` | GET | 导出账单 ZIP |
| `open-api/v3/statements/{accountId}/{date}/regenerate` | POST | 异步重生日账单 |

### 2.8 Admin 接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `api/admin/statements/daily/regenerate` | POST | Admin 异步重生日账单 |

---

## 3. 客户结算单 (Customer Settlement)

### 3.1 CustomerSettleJob

```java
@XxlJob("customer_settle_distinguish_currency")
```

每月一号凌晨触发，生成对账 Excel，区分币种:

1. 分页查询存活账户 (limit 1000)
2. 对每个账户生成结算文件:
   - 查询该账户对账周期内所有交易
   - 按 `CustomerSettleType` 分类生成不同格式 Excel
3. 上传 OSS → 记录 `qbit_core_settle_file`
4. 发送结算通知
5. 记录操作审计日志

### 3.2 CustomerSettleType

| 类型 | 说明 |
|------|------|
| `Collection_Fee_Statement` | 代收对账单 |
| `Merchant_Capital_Statement` | 商户资金对账单 |
| `Detailed_Business_Statement` | 业务明细对账单 |
| `Child_Account_Business_Statement` | 子账户业务明细对账单 |

### 3.3 商户/Admin 对账文件接口

| 接口 | 说明 |
|------|------|
| `api/core/settleFile` (GET, 商户) | 对账文件列表 |
| `api/admin/core/settleFile/page` (POST, Admin) | 对账文件分页 |
| `api/admin/core/settleFile/get-account-business-status` (GET) | 动态获取 accountId 开通业务 |

---

## 4. 加密资产对账 (Crypto Reconciliation)

### 4.1 StatementFactory

```java
StatementFactory.settlement(date)
    → 遍历所有 StatementStrategy Bean 执行 settlement(startTime, endTime)
```

各 Strategy 独立处理，一个异常不阻断其他。

### 4.2 StatementStrategy 实现

| 实现类 | 说明 |
|--------|------|
| `CircleDepositStatementStrategyImpl` | Circle 充值对账 |
| `CirclePayOutStatementStrategyImpl` | Circle 出金对账 |
| `CircleWithdrawalStatementStrategyImpl` | Circle 提现对账 |
| `OkxWithdrawalStatementStrategyImpl` | OKX 提现对账 |

**AbstractCircleStatementStrategyImpl:**
1. `buildParams()` 构建 Circle API 查询参数
2. 分页调用 Circle API (每页 50 条)
3. 比对本地交易 (`CryptoAssetsTransfer`/`CryptoAssetsTransaction`) vs Circle 三方交易
4. 不平账单发钉钉/企微通知

### 4.3 Admin Crypto 对账接口

| 接口 | 说明 |
|------|------|
| `api/admin/internal/reconciliation/crypto-asset/reconciliations` | 对账汇总 |
| `api/admin/internal/reconciliation/crypto-asset/reconciliations-details` | 对账明细 |
| `api/admin/internal/reconciliation/crypto-asset/blockchain-refund-details` | 链上退款明细 |

### 4.4 Merchant Crypto 对账

`CryptoAssetV2ReconciliationService`:
- `reconciliation()` — 加密资产钱包对账
- `reconciliationDetails()` — 对账明细
- `blockchainRefundDetails()` — 链上退款明细

---

## 5. 量子卡结算 (Card Settlement)

### 5.1 SettlementHandlerFactory

结算处理器工厂，按责任链模式执行:

```java
List<SettlementHandler> handlers = factory.getHandler(settlement, cardInfo, channel);
handlers.forEach(h -> h.handle(cardInfo, settlement));
```

### 5.2 SettlementHandler

| 方法 | 说明 |
|------|------|
| `getOrder()` | 处理器顺序 |
| `getChannel()` | 卡渠道 |
| `support(cardInfo, settlement)` | 是否支持该结算 |
| `handle(cardInfo, settlement)` | 执行结算 (返回 false 中断后续) |

### 5.3 结算生命周期

```
交易完成
    │
    ├── RealtimeSettlementListener (MQ 实时结算)
    │       └── BbSettleService.processSettlement()
    │
    ├── SettleJob (定时结算)
    │       └── QbitCardSettlementService.batchSettle()
    │
    └── SettlementHandlerFactory (结算处理链)
            ├── CrossBorderTransactionService (跨境交易处理)
            ├── SettlementAccountFeeService (费用计算)
            ├── RiskDelayCheckService (风控延迟检查)
            ├── CryptoBalanceTransactionSyncService (加密同步)
            └── SettleAgencyService (代付结算)
```

### 5.4 QbitCardSettlement 主要字段

| 字段 | 说明 |
|------|------|
| `id` | 主键 |
| `card_id` | 卡片 ID |
| `transaction_id` | 交易 ID |
| `channel` | 卡渠道 |
| `type` | 结算类型 |
| `status` | 状态 |
| `amount` | 金额 |
| `fee` | 手续费 |
| `settlement_currency` | 结算币种 |
| `exchange_rate` | 汇率 |
| `settlement_time` | 结算时间 |

---

## 6. 外部渠道结算

### 6.1 BB (Commerce) 结算

**BbSettleService:** BB 卡组结算处理:

| 方法 | 说明 |
|------|------|
| `processSettlement()` | 结算处理 |
| `manualRefund()` | 手动退款 |
| `handleTransaction()` | 手动关闭交易 |
| `handleCreateTransaction()` | 手动创建交易 |

**Jobs:** `BbSettleJob`, `QbitCardSettlementWashJob`, `CvvFailAuthorizationJob`

### 6.2 I2C 结算

**I2cSettleService:** I2C 卡组结算:

| 说明 | |
|------|------|
| 粒度 | 按卡组 (card group) 结算 |
| 手续费 | 按交易类型区分费率 |
| 对账 | 本地 vs I2C 账单比对 |

### 6.3 SL 结算

**SlSettlementHandlerFactory:** SL 卡组结算处理器工厂:

| 说明 | |
|------|------|
| Handler 模式 | `SlSettlementHandler` 策略接口 |
| 费用计算 | 按产品编码区分费率 |
| 对账 | 本地 vs SL 账单比对 |

---

## 7. 实时结算 (Realtime Settlement)

### 7.1 RealtimeSettlementListener

```java
@MqMessageListener(topic = QBIT_QUEUE_TOPIC, tag = REALTIME_SETTLEMENT)
```

交易完成后发送 MQ 消息 → 异步触发 BB 渠道结算处理。

### 7.2 结算支持服务

| Service | 说明 |
|---------|------|
| `SettleAgencyService` | 代付结算 |
| `SettlementAccountFeeService` | 结算账户手续费计算 |
| `CryptoBalanceTransactionSyncService` | 加密资产余额同步 |
| `RiskDelayCheckService` | 风控延迟检查 |

---

## 8. 理财对账 (Fund Reconciliation)

### 8.1 FundReconciliationService

粒子理财资金端对账:

| 方法 | 说明 |
|------|------|
| `reconciliation()` | 对账汇总 (本地 vs 三方) |
| `reconciliationDetails()` | 对账明细 |

### 8.2 Admin 接口

| 接口 | 说明 |
|------|------|
| `api/admin/internal/reconciliation/fund/reconciliations` | 理财对账汇总 |
| `api/admin/internal/reconciliation/fund/reconciliations-details` | 理财对账明细 |

---

## 9. 清退销户 (Account Clear)

### 9.1 ClearService

账户注销前资产清算全流程:

| 方法 | 说明 |
|------|------|
| `clear()` | 启动清退 |
| `executeClear()` | 执行清算 |
| `finishClear()` | 完成清退 |
| `cancelClear()` | 取消清退 |
| `appeal()` | 申诉 |

### 9.2 ClearExecutionService

清退执行引擎:

| 步骤 | 说明 |
|------|------|
| 1. 业务状态判断 | ClearBusinessStatusJudgeService |
| 2. 余额划转 | ClearBalanceTransferService |
| 3. 处置处理 | ClearDisposal (各业务线实现) |
| 4. 通知 | AccountClearNoticeService |
| 5. 黑名单 | AccountClearBlacklistService |
| 6. 完成 | AccountClearFinishService |

### 9.3 Clear 定时任务

| Job | 说明 |
|-----|------|
| `AccountClearProcessJob` | 清退流程推进 |
| `AccountClearFinishJob` | 清退完成处理 |

---

## 10. 账单系统

### 10.1 API 客户账单

| 服务 | 说明 |
|------|------|
| `ApiClientBillService` | 客户账单主服务 |
| `ApiClientBillStatementService` | 账单对账单 |
| `ApiClientNettingBillService` | 净额结算账单 |
| `ApiClientDebitRecordService` | 扣款记录 |

### 10.2 月账单 (MonthBill)

| 组件 | 说明 |
|------|------|
| `MonthBillJob` | 月账单生成定时任务 |
| `MonthBillExportQueueService` | 导出队列管理 |
| `MonthBillExportTask` | 导出任务执行 |
| `MonthBillExportController` | Admin 月账单导出接口 |
| `DebitBillService` | 欠款/扣款账单 (量子卡) |

---

## 11. 定时任务汇总

| Job Handler | 说明 | 触发 |
|-------------|------|------|
| `daily_settle` | 日账单生成 (D-1) | 每日凌晨 |
| `balance_snapshot` | 余额快照 | 每月 1 号 |
| `customer_settle_distinguish_currency` | 客户结算单 | 每月 1 号凌晨 |
| `month_bill` | 月账单 | 每月 |
| `settlement_record` | 出金结算记录 | 按配置 |
| `crypto_assets_settle` | 加密资产结算 | 按配置 |
| `delay_settlement_label` | 延迟结算标签 | 按配置 |
| `bb_settle` | BB 结算 | 按配置 |
| `i2c_settle` | I2C 结算 | 按配置 |
| `sl_settle` | SL 结算 | 按配置 |
| `account_clear_process` | 清退流程推进 | 按配置 |
| `account_clear_finish` | 清退完成 | 按配置 |
| `cny_settle_quota` | 人民币结算额度 | 按配置 |
| `handle_settlement_expiration` | 结算过期处理 | 按配置 |

---

## 12. 路径速查

| 模块 | 路径 |
|------|------|
| 日账单 Controller (OpenAPI) | `qbit-core/.../openapi/v3/statement/controller/DailyStatementController.java` |
| 日账单 Controller (Admin) | `qbit-core/.../admin/statement/controller/DailyStatementAdminController.java` |
| 日账单 Service | `qbit-core/.../openapi/v3/statement/service/impl/DailyStatementServiceImpl.java` |
| 日账单 Job | `qbit-core/.../job/settle/DailySettleJob.java` |
| StatementHandler 接口 | `qbit-core/.../openapi/v3/statement/service/StatementHandler.java` |
| Handler 注册器 | `qbit-core/.../openapi/v3/statement/service/StatementHandlerRegistry.java` |
| 余额快照 Service | `qbit-core/.../openapi/v3/statement/service/BalanceSnapshotService.java` |
| 余额快照 Job | `qbit-core/.../job/settle/BalanceSnapshotJob.java` |
| 客户结算 Job | `qbit-core/.../job/settle/CustomerSettleJob.java` |
| 客户结算 Service | `qbit-core/.../core/service/QbitStatementService.java` |
| 客户结算类型枚举 | `qbit-core/.../common/enums/CustomerSettleType.java` |
| 结算文件 Service | `qbit-core/.../report/service/QbitCoreSettleFileService.java` |
| 结算文件 Controller (Admin) | `qbit-core/.../admin/settle/SettleFileController.java` |
| 结算文件 Controller (商户) | `qbit-core/.../merchant/QbitCoreSettleFileController.java` |
| 手动结算 Controller | `qbit-core/.../admin/settle/ManualSettleController.java` |
| 加密资产对账 Admin | `qbit-core/.../admin/reconciliation/controller/AdminCryptoAssetReconciliationController.java` |
| 加密资产对账 Service | `qbit-core/.../merchant/cryptoasset/v2/service/CryptoAssetV2ReconciliationService.java` |
| 理财对账 Admin | `qbit-core/.../admin/reconciliation/controller/AdminFundReconciliationController.java` |
| 理财对账 Service | `qbit-core/.../financing/v2/service/FundReconciliationService.java` |
| 对账工厂 (加密) | `qbit-core/.../common_all/statement/StatementFactory.java` |
| 对账策略接口 | `qbit-core/.../common_all/statement/StatementStrategy.java` |
| Circle 对账抽象 | `qbit-core/.../statement/impl/AbstractCircleStatementStrategyImpl.java` |
| Circle 充值对账 | `qbit-core/.../statement/impl/CircleDepositStatementStrategyImpl.java` |
| Circle 出金对账 | `qbit-core/.../statement/impl/CirclePayOutStatementStrategyImpl.java` |
| Circle 提现对账 | `qbit-core/.../statement/impl/CircleWithdrawalStatementStrategyImpl.java` |
| OKX 提现对账 | `qbit-core/.../statement/impl/OkxWithdrawalStatementStrategyImpl.java` |
| 卡结算处理器工厂 | `qbit-core/.../core/service/impl/transaction/settle/SettlementHandlerFactory.java` |
| 卡结算处理器接口 | `qbit-core/.../core/service/impl/transaction/settle/SettlementHandler.java` |
| 结算上下文 | `qbit-core/.../core/service/impl/transaction/settle/SettleContext.java` |
| 结算代付 Service | `qbit-core/.../core/service/impl/transaction/settle/support/SettleAgencyService.java` |
| 结算费用 Service | `qbit-core/.../core/service/impl/transaction/settle/support/SettlementAccountFeeService.java` |
| 实时结算监听器 | `qbit-core/.../openapi/listener/RealtimeSettlementListener.java` |
| BB 结算 Service | `qbit-core/.../thirdparty/external/bb/settle/BbSettleService.java` |
| BB 结算 Job | `qbit-core/.../thirdparty/external/bb/settle/BbSettleJob.java` |
| I2C 结算 Service | `qbit-core/.../thirdparty/external/i2c/settle/I2cSettleService.java` |
| I2C 结算 Job | `qbit-core/.../thirdparty/external/i2c/settle/I2cSettleJob.java` |
| SL 结算工厂 | `qbit-core/.../thirdparty/external/sl/settle/handler/SlSettlementHandlerFactory.java` |
| SL 结算 Service | `qbit-core/.../thirdparty/external/sl/settle/SlSettleService.java` |
| SL 结算 Job | `qbit-core/.../thirdparty/external/sl/settle/SlSettleJob.java` |
| 清退 Service | `qbit-core/.../core/clear/service/ClearService.java` |
| 清退执行引擎 | `qbit-core/.../core/clear/service/ClearExecutionService.java` |
| 清退流程 Job | `qbit-core/.../job/clear/AccountClearProcessJob.java` |
| 清退完成 Job | `qbit-core/.../job/clear/AccountClearFinishJob.java` |
| 出金结算 Job | `qbit-core/.../job/payout/SettlementRecordJob.java` |
| 出金结算 Service | `qbit-core/.../payout/service/PaymentSettlementService.java` |
| API 客户账单 Service | `qbit-core/.../api/client/bill/service/ApiClientBillService.java` |
| API 对账单 Service | `qbit-core/.../api/client/bill/service/ApiClientBillStatementService.java` |
| 净额结算 Service | `qbit-core/.../api/client/bill/service/ApiClientNettingBillService.java` |
| 月账单 Job | `qbit-core/.../job/settle/MonthBillJob.java` |
| 月账单导出 Job | `qbit-core/.../job/settle/MonthBillManualExportJob.java` |
| 欠款账单 Service | `qbit-core/.../core/service/quantum/arrearsrecover/DebitBillService.java` |
