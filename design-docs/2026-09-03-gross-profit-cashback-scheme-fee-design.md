# 毛利返现 Scheme Fee 调整设计方案

> 设计日期：2026-09-03
> 适用系统：Qbit Assets / qbit-core
> 文档状态：待业务评审

## 1. 背景与目标

Scheme Fee 是我方在渠道侧产生的成本。Revenue Sharing 毛利返现的计算已经从渠道返现总额中扣除 Scheme Fee，因此如果在交易发生时再次向客户收取 Scheme Fee，会形成重复收费。

本次调整目标：

1. 对账期内生效 RS 毛利返现配置的客户及其子客户，将 Scheme Fee 从实时收取调整为月结收取。
2. 已经是月结模式的客户保持现有行为不变。
3. RS 客户的其他费用继续按照原有实时/月结配置处理，不因 Scheme Fee 的特殊规则整体切换客户账单模式。
4. Scheme Fee 的原始写入、毛利返现公式、营收补差逻辑和客户毛利返现配置保持不变。

## 2. 已确认的业务口径

### 2.1 RS 配置的生效判断

“设置过 Scheme 返现”按账单月份判断，不按当前配置追溯历史月份。账单月份内存在生效配置时，才对该月份交易启用特殊月结规则。

生效条件：

```text
feeType in (
    QUANTUM_CARD_QI_RS_PROFIT_CASH_BACK,
    QUANTUM_CARD_BZ_RS_PROFIT_CASH_BACK
)
AND startTime <= billMonthEnd
AND endTime >= billMonthStart
```

### 2.2 客户范围

以客户根账户为判断主体，覆盖根账户及 `api_account_relation.root_id` 下的全部子客户。RS 配置应从根账户或现有客户配置继承关系中判定，不对单笔交易新增配置字段。

### 2.3 费用分类

特殊月结规则只适用于 Scheme Fee，不适用于普通消费费用。

消费交易中的普通费用包括：

- `settlementFee`
- `fxFee`
- `crossBorderFee`
- `applePayAuthFee`
- `atmWithdrawalFee`

授权费、绑卡验证费、退款费、撤销费、交易失败费、开卡费、制卡费和邮寄费等也不因 RS 配置改变账单模式。

### 2.4 账单结果示例

RS 客户原本为实时模式时，一笔消费交易应拆分为：

```text
实时费用：消费相关普通费用
月结费用：issuer card service、issuer transaction auth、issuer transaction settlement、
          Visa risk manager、scheme verification，以及对应退款/撤销 Scheme Fee
```

实际包含哪些 Scheme Fee 仍由已有渠道、交易类型和费率配置决定。

## 3. 现状分析

### 3.1 交易月结同步

现有入口为：

```text
ApiClientTransactionJob
    -> ApiClientTransactionService
    -> ApiClientTransactionFactory
    -> ApiClientQbitCardTransactionServiceImpl.syncApiTransactions
```

`ApiClientQbitCardTransactionServiceImpl` 当前通过 `operationLogService.isMonthPayment(...)` 判断客户是否整体按月结处理。`SYSTEM_FEE_COLLECT` 会根据渠道从交易扩展数据和 Java 费率能力重新生成 Scheme Fee，并通过 `mergeSchemeFees(...)` 保留已有非 Scheme Fee、替换已有 Scheme Fee。

现有 `ApiClientMonthFeeEnum` 已包含多类 Scheme Fee；因此本次优先复用已有月结交易、账单聚合和幂等更新机制，不新增账单表或费用表。

### 3.2 毛利返现计算

`CashBackJob` 已通过 `QuantumAccountTransferService.getRsSchemeFee(...)` 查询 Scheme Fee，并在毛利返现计算中从渠道返现基数中扣除。该链路符合新的业务口径，本次不调整。

### 3.3 重要现状约束

当前同步流程的“是否月结”判断位于交易级流程，而需求是“仅 Scheme Fee 月结”。如果直接在通用同步流程中放宽 RS 客户条件，会导致普通消费费用、退款费等错误进入月结账单。因此本次采用独立 Job 隔离 Scheme Fee 月结范围。

## 4. 推荐方案

### 4.1 方案概述

新增专门的 `RevenueSharingSchemeFeeJob`，只负责 RS 客户及其子客户的 Scheme Fee 月结同步；现有 `ApiClientTransactionJob` 保持原有客户整体账单模式逻辑不变。

新 Job 复用现有 `ApiClientQbitCardTransactionServiceImpl` 中的 Scheme Fee 计算、费用合并和幂等写入能力，不复制整套账单同步实现。

```text
普通费用同步：仍按 isMonthPayment 判断
Scheme Fee 同步：
    原本月结客户 -> 保持原逻辑
    原本实时且账期内生效 RS 配置 -> 由新 Job 进入月结
    非 RS 客户 -> 不由新 Job 处理
```

建议新增独立的查询/策略能力，例如：

```java
boolean hasActiveRevenueSharingConfig(String rootAccountId, YearMonth billMonth);
```

具体类名可遵循现有 AccountFee/AccountService 领域边界，避免将 SQL 和配置判断堆在 Job 或交易账单服务中。

### 4.2 推荐流程

1. 新 Job 接收账期参数；未传参数时默认处理上一个完整账期。
2. 查询账期内生效 RS 配置的根账户，并获取其全部子客户。
3. 排除原本已经是月结模式的根账户，避免与原有 `SYSTEM_FEE_COLLECT` 同步重复处理。
4. 按账期查询这些客户已完成的消费、退款和撤销交易。
5. 复用现有渠道 Scheme Fee 计算逻辑生成费用明细。
6. 通过现有 `mergeSchemeFees(...)` 合并交易费用：保留普通费用，去除旧 Scheme Fee，再写入本次计算结果。
7. 使用现有 `insertOrUpdate` 保证同一交易重复同步时不产生重复费用。
8. 在账单锁定前执行，并记录账期、根账户范围、交易数量和失败交易信息。

伪代码：

```java
List<String> rootAccountIds = revenueSharingFeePolicy
        .listActiveRootAccountIds(billMonth);
List<String> transactionAccountIds = accountRelationService
        .listAccountIdsByRootAccountIds(rootAccountIds);
List<QbitCardTransaction> transactions = transactionQueryService
        .listClosedTransactions(transactionAccountIds, billMonth);

for (QbitCardTransaction transaction : transactions) {
    List<ApiClientFeeDTO> schemeFees = schemeFeeCalculator.calculate(transaction);
    schemeFeeBillWriter.mergeAndUpsert(transaction, schemeFees);
}
```

新 Job 不调用普通消费费、退款费等同步类型，只调用 Scheme Fee 专用处理能力，因此不会改变其他费用的账单模式。

### 4.3 方案比较

| 方案 | 优点 | 风险/不足 | 结论 |
|---|---|---|---|
| 修改现有通用同步流程 | 改动入口少 | 交易级月结判断容易把普通费用带入月结；影响现有客户范围 | 不采用 |
| 新增 RS Scheme Fee Job | 处理范围独立；执行账期明确；不改变通用账单规则 | 需要抽取现有 Scheme Fee 计算和交易合并能力 | 推荐 |
| 修改客户整体 statementType | 表面实现简单 | 当前不支持部分费率月结，会改变客户其他费用的收取时机 | 不采用 |

## 5. 费用处理矩阵

| 交易/费用同步类型 | 原本月结客户 | RS 实时客户 | 非 RS 实时客户 |
|---|---|---|---|
| 普通消费费用 | 月结 | 实时 | 实时 |
| Scheme Fee | 原有月结流程 | 新 Job 月结 | 沿用现有规则 |
| 退款/撤销普通费用 | 月结 | 沿用原规则 | 沿用原规则 |
| 退款/撤销 Scheme Fee | 月结 | 月结 | 沿用现有规则 |
| 毛利返现 Scheme Fee 成本 | 继续扣除 | 继续扣除 | 按现有逻辑 |

其中“沿用现有规则”表示本次不改变非 RS 客户的现有行为。若产品最终要求所有客户的 Scheme Fee 都统一改为月结，需要另行设计费用级账单模式能力，不应通过本次 RS 特殊逻辑扩展实现。

## 6. 代码改动范围建议

### 6.1 交易账单服务

修改：

```text
qbit-core/src/main/java/com/qbit/common_all/api/client/bill/service/impl/ApiClientQbitCardTransactionServiceImpl.java
```

职责：

- 抽取可复用的 Scheme Fee 计算、费用合并和幂等写入能力，供通用月结流程和新 Job 使用。
- 不在通用同步方法中加入 RS 客户放行条件。
- 保持 `systemFeeByProvider`、渠道费用计算和 `mergeSchemeFees` 的现有口径。
- 对批量交易尽量批量加载根账户和 RS 配置，避免每笔交易重复查询。

建议形成清晰的服务边界：

```java
List<ApiClientFeeDTO> calculateSchemeFees(QbitCardTransaction transaction);
void mergeAndUpsertSchemeFees(QbitCardTransaction transaction,
                              List<ApiClientFeeDTO> schemeFees);
```

方法的具体归属可以按现有 Service 结构确定，但新 Job 不应调用原类的私有方法，也不应复制 `syncApiTransactions` 的完整实现。

### 6.2 RS 配置查询能力

建议新增或扩展 AccountFee 领域查询服务/Mapper，职责仅为查询某根账户在指定账期是否存在生效 RS 配置。

查询必须：

- 过滤软删除数据。
- 限定两个 RS 毛利返现费率类型。
- 使用账期开始/结束时间判断有效区间。
- 支持批量传入 root account ID。
- 不将当前时间作为判断条件，避免历史账期受当前配置影响。

### 6.3 RS Scheme Fee Job

新增 `RevenueSharingSchemeFeeJob`，建议放在 `qbit-core/src/main/java/com/qbit/job/synchronization/` 下，并使用独立的 XXL-Job handler，例如 `revenueSharingSchemeFeeJob`。

Job 约束：

- 默认处理上月完整账期，支持通过 Job 参数指定 `startDate` 和 `endDate`。
- 执行时间必须早于月结账单锁定任务。
- 只处理账期内生效 RS 配置对应的根客户及子客户。
- 排除原本已是月结模式的客户，避免和现有 `SYSTEM_FEE_COLLECT` 重复。
- 失败交易记录业务 ID 和账期，支持按账期重跑。

`ApiClientTransactionJob` 原有调度入口保持不变。

### 6.4 毛利返现链路

以下文件和逻辑原则上不修改：

```text
CashBackJob.java
QuantumAccountTransferService.getRsSchemeFee(...)
OdsQbitCardTransactionMapper.xml 中 RS Scheme Fee 统计 SQL
```

如果验证发现 SQL 的 Scheme Fee 类型集合与账单同步使用的集合不一致，应只做集合口径校准，不改变返现公式。

## 7. 幂等、并发与历史数据

### 7.1 幂等

- 交易唯一标识继续使用 `transactionId`。
- 继续调用 `insertOrUpdate`。
- Scheme Fee 合并时先移除旧 Scheme Fee，再加入本次计算结果。
- 不使用追加式写入，防止 Job 重跑造成重复收费。

### 7.2 并发

新 Job 使用批量查询根账户、客户关系和交易，保留现有分页及异步计算方式。RS 配置结果应在本次账期执行中缓存或批量加载，避免并发线程对同一根账户重复查询。

### 7.3 历史账单

本次默认只影响上线后重新同步或尚未锁定的账单月份。已经完成扣款、锁定或对账的历史账单不自动反向修改，避免产生未授权的资金流水变更。

如业务要求修复历史重复收费，需要另行设计退款/营收补差/账单重算方案，并明确账单状态、扣款状态和审计要求。

## 8. 测试方案

### 8.1 Job 范围与策略判断测试

使用参数化测试覆盖：

- 原本月结客户：Scheme Fee 仍进入月结。
- 原本实时、根账户账期内有 QI RS 配置：新 Job 处理 Scheme Fee。
- 原本实时、根账户账期内有 BZ RS 配置：新 Job 处理 Scheme Fee。
- RS 配置只在账期外生效：不触发特殊月结。
- 子客户继承根账户 RS 配置：触发特殊月结。
- 非 RS 客户：不触发特殊月结。
- 原本月结客户不会被新 Job 重复处理。
- 普通消费费用不会被新 Job 处理。

### 8.2 交易费用合并测试

- 现有交易包含普通费用和旧 Scheme Fee，重同步后普通费用保留、Scheme Fee 替换。
- 现有交易只有普通费用，新增 Scheme Fee 后只追加 Scheme Fee。
- 交易无任何费用时不产生空账单交易。
- Job 重跑两次，Scheme Fee 金额和费用项数量保持一致。

### 8.3 费用类型测试

分别验证消费、退款、撤销和 System Fee 场景，确认：

- Scheme Fee 可按特殊规则月结。
- `settlementFee`、`fxFee`、`crossBorderFee`、Apple Pay、ATM 等普通费用不会被带入特殊月结。
- 毛利返现统计的 Scheme Fee 金额不因账单展示方式改变。

### 8.4 集成回归

至少执行：

```bash
cd qbit-core && mvn test -DskipTests=false -Dtest=RevenueSharingSchemeFeeJobTest,ApiClientTransactionJobTest
```

并补充针对交易账单服务和 RS 配置查询的测试。关键资金链路建议使用 Spring Boot 集成测试验证数据库查询、交易合并和账单聚合结果。

## 9. 风险与待确认事项

1. 本方案将本次改造范围限定为“RS 客户的 Scheme Fee 特殊月结”。非 RS 客户是否也要取消实时 Scheme Fee，需要产品明确；若是全量要求，应拆为独立设计。
2. 需要确认新 Job 使用账单锁定前的哪个具体执行窗口，并在 XXL-Job 中配置先后依赖。
3. 需要确认账单月份以 `completeTime` 还是现有账单流程使用的交易时间为准。建议统一沿用现有月结同步使用的时间字段，避免账期边界不一致。
4. 需要确认 RS 配置只从根账户读取，还是允许子客户独立配置覆盖根账户。当前推荐根账户统一判断，以满足“客户及其子客户”的需求。
5. 上线前需要核对已生成但未锁定的账单是否允许新 Job 重跑；已锁定账单不建议自动重算。

## 10. 结论

推荐新增独立的 `RevenueSharingSchemeFeeJob`，只处理 RS 客户及其子客户的 Scheme Fee 月结同步，不改变客户整体 `statementType`，也不改变普通费用、返现计算和营收补差逻辑。Job 内部复用现有 Scheme Fee 计算、费用合并和幂等写入能力，以避免修改通用账单同步流程造成费用串账。
