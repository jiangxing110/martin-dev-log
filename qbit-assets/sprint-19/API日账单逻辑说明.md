# API 日账单逻辑说明

> 本文根据当前代码梳理 API V3 日账单的生成、查询和重生成流程。钱包快照构建/落库流程不在本文范围内；这里仅说明日账单 API 实际调用的余额汇总和流水查询接口，不展开快照机制。

## 1. 范围与入口

日账单核心代码位于 `qbit-core` 的 `com.qbit.openapi.v3.statement` 包，主要由控制器、门面服务、产品 Handler、Mapper 和 Excel/ZIP 工具组成。

| 用途 | 接口/任务 | 说明 |
| --- | --- | --- |
| 下载已生成账单 | `GET /open-api/v3/statements/xlsx?accountId={accountId}&date={yyyy-MM-dd}` | 同步返回 ZIP 文件 URL；接口名为 xlsx，但返回包为 ZIP |
| 异步重新生成 | `POST /open-api/v3/statements/{accountId}/{date}/regenerate` | 返回 `task_id` 和 `status=processing`，由 MQ 消费端执行重生成 |
| 后台重生成 | `POST /api/admin/statements/daily/regenerate?accountId={accountId}&date={yyyy-MM-dd}` | 复用同一重生成服务和 MQ 流程 |
| 自动生成 | XXL-JOB `daily_settle` | 未指定账户时扫描有交易的账户；可通过任务参数指定日期/账户 |

OpenAPI 两个入口标记为 `@NoAuth(NoAuth.OPENAPI)`，账户访问范围在服务层通过当前登录账户校验。Admin 入口由后台身份和权限体系保护。

## 2. 日期与权限校验

导出和重生成均校验 `date`：

1. 日期格式须能解析为 `yyyy-MM-dd`。
2. 账单日期不能早于 `2026-05-01`。
3. 账单日期必须早于当天，不能查询当天或未来日期。
4. 账单日期距当天不能超过 90 天。
5. 用户发起的导出/重生成会校验 `accountId` 是否在当前登录根账户允许访问的范围内。

是否存在当天交易以数仓 `Transaction.transactionTime` 查询为准，使用 `[当日 00:00:00, 次日 00:00:00)` 半开区间，并覆盖对应 API 根账户及其子账户范围。无交易时请求失败，不生成空账单。

## 3. 数据处理与产品路由

### 3.1 Handler 选择

`StatementHandlerRegistry` 在 Spring 启动时收集产品 Handler，按账户产品状态挑选参与账单的 Handler：

| 产品状态 | 账单 Handler |
| --- | --- |
| 量子账户状态为 `Active` | `InfinityAccount`、`PrepaidCard`、`BudgetCard` |
| 全球账户状态为 `Active` | `BusinessAccount` |
| 加密理财状态为 `Active` | `CryptoAsset` |

普通账户无可用 Handler 时不生成账单。Distributor 账户会进入专门流程：查询其直接关联的 master 账户，为每个 master 账户分别汇总数据并生成 XLSX，最后合并到一个 ZIP。

### 3.2 余额汇总与交易流水

普通账户由 `DailyStatementServiceImpl.processTargetAccount` 对账户下所有 Handler 并行调用：

1. 调用 `getBalanceSummary(accountId, date, null)` 汇总产品余额。
2. 调用 `pageTransactions(accountId, date)` 获取账单日流水。
3. 汇总各 Handler 返回的余额行和流水行。
4. 任一并行查询异常会使该次账单处理失败；余额或流水为空时该账户不会生成账单。

Mapper/Handler 按产品交易表和产品规则查询与转换流水。交易类型统一映射为 `DailyStatementTxType`，并标记资金方向：`CREDIT` 表示余额增加，`DEBIT` 表示余额减少。余额行包含币种、账户类型、入金、出金、冻结、解冻、期初余额和期末余额。各产品余额计算口径以对应 Handler 的实现为准。

### 3.3 XLSX 与 ZIP

生成使用模板 `templates/dailySettleTemp.xlsx`，包含两张工作表：

- **余额汇总**：每个账户类型/币种一行，另追加 USD 汇总行。非 USD 金额通过汇率服务换算后汇总。
- **交易流水**：输出交易 ID、账户信息、创建/完成时间、账户类型、交易类型、对手方、币种、资金方向、金额、手续费、状态和描述等字段。

单账户 XLSX 文件名为 `daily-statement-{accountId}-{date}.xlsx`。普通账户 ZIP 内含一份 XLSX；Distributor ZIP 内含各 master 账户的独立 XLSX。生成的 ZIP 上传到文件存储，随后以账户 ID、账单日期和 `DAILY` 类型插入或更新 `DailyStatementFile` 记录，状态写为 `completed`，并返回文件 URL。

## 4. 用户下载流程

`GET /open-api/v3/statements/xlsx` 执行顺序：

1. 校验日期及账户访问权限。
2. 查询账户和日期对应的 `DailyStatementFile`。
3. 若已存在非空文件 URL，直接返回该 URL，不重新查询和生成文件。
4. 若没有已生成文件，检查该账户范围当天是否有交易；无交易返回业务错误。
5. 有交易但文件尚未生成时，仍返回“请异步重新生成”的业务错误；下载接口本身不会触发重生成。

因此下载接口适用于取回已生成文件。历史缺失文件应调用重生成接口。

## 5. 异步重生成流程

OpenAPI/Admin 重生成入口调用 `DailyStatementServiceImpl.regenerate`：

1. 校验当前账户访问范围、日期和是否存在交易。
2. 按 `rootId + accountId + date` 查找可复用任务；相同请求若已有任务，返回已有 `task_id`。
3. 使用 Redis 占位和计数进行并发限制：同一根账户同时最多 1 个重生成任务，全局同时最多 10 个；相关 Redis 占位默认 120 分钟过期。
4. 创建任务进度记录，写入任务/执行 Key，并发送 `DAILY_STATEMENT_REGENERATE` MQ 消息。
5. MQ 消费端调用 `exportZip(accountId, date, taskId)`，重新查询 Handler 数据、生成 XLSX/ZIP、上传并更新文件记录。
6. 消费成功后将任务标记完成；异常时标记失败并记录失败原因；无论成功失败，都会清理当前任务持有的 Redis Key 并释放计数。

重生成过程会更新阶段进度（准备、数据查询、XLSX、ZIP、上传）。接口当前返回的是任务 ID 和初始 `processing` 状态；任务进度查询需使用系统已有的任务进度能力。

## 6. 自动生成流程

XXL-JOB 任务名为 `daily_settle`，默认处理前一天，可通过任务参数覆盖日期或指定单个账户。任务通过 Redisson 日期锁避免同一日期并发执行。

全量模式下，任务从数仓按批次（每批最多 500 个账户）扫描有账单日交易的 API 母户/普通账户；账户通过活跃状态、产品 Handler 和 Distributor 判断后交给账户线程池处理。默认账户并发数为 4（可由任务实现中的配置逻辑调整）。同一账单日账户的处理结果写入 `qbit:assets:daily-settle:processed:{date}`，集合有效期 7 天，用于避免重复处理；成功生成或判定无 Handler 后写入，失败账户可在任务重跑时再次尝试。

自动任务和手动重生成最终都生成同结构的 ZIP，并调用同一日账单文件记录服务。

## 7. 关键代码索引

| 逻辑 | 代码位置 |
| --- | --- |
| OpenAPI 下载/重生成入口 | `qbit-core/src/main/java/com/qbit/openapi/v3/statement/controller/DailyStatementController.java` |
| Admin 重生成入口 | `qbit-core/src/main/java/com/qbit/admin/statement/controller/DailyStatementAdminController.java` |
| 导出、数据编排、Redis 配额 | `qbit-core/src/main/java/com/qbit/openapi/v3/statement/service/impl/DailyStatementServiceImpl.java` |
| Handler 注册/账户产品路由 | `qbit-core/src/main/java/com/qbit/openapi/v3/statement/service/StatementHandlerRegistry.java`、`DailyStatementServiceImpl.resolveHandlersForAccount` |
| 交易查询/账户范围/自动扫描 | `qbit-core/src/main/java/com/qbit/openapi/v3/statement/mapper/DailyStatementTransactionMapper.java` |
| 自动日账单任务 | `qbit-core/src/main/java/com/qbit/job/settle/DailySettleJob.java` |
| 重生成 MQ 消费 | `qbit-core/src/main/java/com/qbit/mq/statement/DailyStatementRegenerateConsumer.java` |
| ZIP 构建 | `qbit-core/src/main/java/com/qbit/openapi/v3/statement/util/DailyStatementZipBuilder.java` |

## 8. 当前口径说明

本文不描述钱包快照的构建、批量写入、快照调度或快照回补。日账单说明仅覆盖当前导出链路中 Handler 提供的余额汇总结果与交易流水，不将钱包快照机制视为本次日账单流程的步骤。

## 9. 各产品期初与期末余额计算

以下是各 Handler **实际写入 `BalanceSummaryVO.openingBalance` / `closingBalance` 的计算式**，按当前不走钱包快照的口径列出。所有公式均按产品及币种的余额范围分别计算。

记号：`Bnow` 为代码读取的当前余额；`Cday`、`Dday` 分别为账单日聚合入金、出金；`Cafter`、`Dafter` 为账单日结束时间起至查询时的入金、出金。对全球账户和加密资产，`Csince`、`Dsince` 是账单日开始时间起至查询时累计的入金、出金，`Cday = Csince - Cafter`，`Dday = Dsince - Dafter`。

### 9.1 量子账户（InfinityAccount）

`Bnow` 是 `balanceSlaveMapper.sumBalanceByAccountScopeAndWalletTypes` 按账户范围汇总量子账户钱包类型后返回的 `Balance.available`。账单日金额和账单日后金额来自 `qbitCardWalletTransaction` 的按时间聚合。

```text
期末余额 = Bnow - (Cafter - Dafter)
期初余额 = 期末余额 + Dday - Cday
```

聚合口径：

- `C`：状态为 `Closed` 且业务类型属于 CREDIT 集合时，金额为 `originAmount`。
- `D`：状态为 `Closed` 且业务类型属于 CREDIT 集合时计入 `fee`；状态为 `Closed` 或 `Pending` 且业务类型属于 DEBIT 集合时计入 `settleAmount + fee`。
- 交易类型集合由 `InfinityAccountHandler` 的映射表中 `Direction.CREDIT/DEBIT` 分类产生。交易需未软删除且处于 `Closed/Pending` 状态。

**参与余额计算的原始交易类型**（字段 `qbitCardWalletTransaction.businessType`）：

- 入金集合 `CREDIT_TYPES`：`Deposit`、`ReturnGroup`、`ReturnCard`、`TransferIn`、`SystemAdjustmentTransferIn`、`TransferInFromFinancing`、`QbitCryptoToQbitCardWallet`、`TransferInFromCryptoAssets`、`TransferInFromIPeakoin`、`TransferInFromQbitGlobal`、`TransferInFromMasterAccount`、`AccountDepositCNY`、`PreDeposit`、`FeeRefund`。
- 出金集合 `DEBIT_TYPES`：`CreateCardFee`、`RechargeGroup`、`RechargeCard`、`TransferOut`、`SystemAdjustmentTransferOut`、`TransferOutForVirtualUSD`、`TransferOutToFinancing`、`TransferOutToQbitGlobal`、`TransferOutToMasterAccount`、`QbitCardWalletToQbitCrypto`、`QuantumAccountMonthBillDebit`、`ClearFee`。

枚举中虽存在但未加入 `InfinityAccountHandler.TX_MAP` 的 `CreditFee`、`ClearOut`、`BuyVipPackage`、`AccountCharging` 不参与上述余额聚合。

### 9.2 储值卡（PrepaidCard）

`Bnow` 是 `balanceSlaveMapper.sumBalanceByAccountScopeAndWalletTypes` 按储值卡钱包类型汇总后的 `Balance.available`。交易来自独立卡交易表，并关联卡记录。

```text
期末余额 = Bnow - (Cafter - Dafter)
期初余额 = 期末余额 + Dday - Cday
```

聚合口径：

- `C`：状态为 `Closed` 且业务类型属于 CREDIT 集合时，金额为 `settleAmount`。
- `D`：状态为 `Closed` 且业务类型属于 CREDIT 集合时计入 `fee`；状态为 `Closed` 或 `Pending` 且业务类型属于 DEBIT 集合时计入 `settleAmount + fee`。
- 仅汇总可展示交易（`isShow=true`）且不属于预算卡组的卡交易（`groupId IS NULL`）；交易未软删除且状态为 `Closed/Pending`。

**参与余额计算的原始交易类型**（字段 `qbit_card_transaction.businessType`）：

- 入金集合 `CREDIT_TYPES`：`Credit`、`TransferIn`、`Refund`、`DeleteCardRefund`、`UnFrozen`、`Reversal`、`FeeRefund`。
- 出金集合 `DEBIT_TYPES`：`Consumption`、`TransferOut`、`Frozen`、`CardWithdraw`、`Fee_CreateCard`、`Fee_Credit`、`Fee_Consumption`、`Verification_Fee`、`Declined_Fee`、`System_Fee`。

### 9.3 预算卡（BudgetCard）

`Bnow` 是 `balanceSlaveMapper.sumBalanceByAccountScopeAndWalletTypes` 按 `GroupWallet` 类型汇总的 `Balance.available`。交易来自预算组交易表。

```text
期末余额 = Bnow - (Cafter - Dafter)
期初余额 = 期末余额 + Dday - Cday
```

交易金额口径与储值卡一致：Closed CREDIT 的 `settleAmount` 计入入金；Closed CREDIT 的 `fee` 计入出金；Closed/Pending DEBIT 的 `settleAmount + fee` 计入出金。交易未软删除且状态为 `Closed/Pending`。

**参与余额计算的原始交易类型**（字段 `qbit_card_group_transaction.businessType`）：

- 入金集合 `CREDIT_TYPES`：`TransferIn`、`FeeRefund`。
- 出金集合 `DEBIT_TYPES`：`TransferOut`、`CreateCardFee`。

量子账户、储值卡和预算卡的冻结/解冻金额由冻结记录另行统计，只填写 `totalFrozenAmount`、`totalUnfrozenAmount`，不参与以上期初、期末公式。上述 Handler 的余额交易聚合结果空值按零处理。

### 9.4 全球账户（BusinessAccount）

`Bnow` 是按币种从全球账户钱包类型余额中读取的当前 `totalAmount`。Historical 分支分别读取账单日开始以来与账单日结束以来的 Transfer 累计金额，代码具体计算为：

```text
期初余额 = Bnow + OutboundSinceDayStart - InboundSinceDayStart
期末余额 = Bnow + OutboundAfterDayEnd - InboundAfterDayEnd
Cday = InboundSinceDayStart - InboundAfterDayEnd
Dday = OutboundSinceDayStart - OutboundAfterDayEnd
```

SQL 金额口径为 `Inbound = originAmount - fee`，`Outbound = originAmount + fee`。仅统计未删除、`merchantShow=true`、业务类型符合方向且状态不属于 PaymentFailed、Rejected、Cancelled、UserCancelled、Refunding、RefundFailed 的 Transfer。各币种分别计算后按币种合并。代码有“账单日期为今天”的分支：此时 `closingBalance=Bnow`，`openingBalance=Bnow+OutboundDay-InboundDay`；OpenAPI 日期校验不允许查询今天。

**参与余额计算的原始交易类型**（字段 `transfer.businessType`）：入金集合只有 `Inbound`，出金集合只有 `Outbound`。流水明细中的 `businessTypeDetail` 不决定余额聚合类型。

### 9.5 加密资产（CryptoAsset）

先按加密资产钱包类型取得当前余额列表，再按每个 `balanceId` 读取当前 `available` 和交易变化，最后按币种加总。历史分支实际公式为：

```text
期初余额 = Bnow + OutflowSinceDayStart - InflowSinceDayStart
期末余额 = Bnow + OutflowAfterDayEnd - InflowAfterDayEnd
Cday = InflowSinceDayStart - InflowAfterDayEnd
Dday = OutflowSinceDayStart - OutflowAfterDayEnd
```

Outflow 类型为 `InstaPayOut`、`sell`、`out`、`collect_funds_out`；Inflow 类型为 `collect_funds_in`、`buy`、`InstaPayIn`、`in`、`refund`。金额取交易 `origin_amount`，不额外加减 fee。交易未删除、`hidden=false`，且状态不属于 Rejected、Cancel、Cancelled、Fail、Refunded。代码有“账单日期为今天”的分支：此时 `closingBalance=Bnow`，`openingBalance=Bnow+OutflowDay-InflowDay`；OpenAPI 日期校验不允许查询今天。

**参与余额计算的原始交易类型**（字段 `crypto_assets_transfers.action`）：

- 入金集合：`collect_funds_in`、`buy`、`InstaPayIn`、`in`、`refund`。
- 出金集合：`InstaPayOut`、`sell`、`out`、`collect_funds_out`。

`profit`、`adjustment_credit`、`adjustment_debit` 虽存在于加密资产交易类型枚举中，但不在余额查询 SQL 的类型集合内，不参与回推。

### 9.6 公式与导出字段的关系

以上 `Cday`、`Dday` 对应余额汇总 Sheet 的入金、出金金额；期初、期末列直接来自 Handler 写入的 `openingBalance`、`closingBalance`。实现中五类产品均遵循 `期末余额 = 期初余额 + Cday - Dday` 的代数关系，但各产品的当前余额来源、交易表字段、状态过滤和 fee 口径不同，不能将其中一类的明细聚合规则套用到其他产品。

实现代码仍保留有历史钱包快照时优先使用快照的分支；本文依照当前“钱包快照不走”的口径，只列无快照回推公式，不把快照流程作为运行步骤。
