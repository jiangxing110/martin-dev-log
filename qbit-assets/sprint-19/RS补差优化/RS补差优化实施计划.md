# RS 月账单服务 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 由独立服务统一维护 RS 返现补差月账单明细和汇总，供 API 与直客月账单共用。

**Architecture:** 在 `com.qbit.openapi.service` 增加单一具体类 `RevenueAdjustmentBillService`，复用现有 `CashBackBonusMapper#getRevenueAdjustments`。API 月结编排 `ApiClientTransactionServiceImpl` 与直客账单 `ApiClientBillServiceImpl.saveDirectBillBatch` 都直接调用该服务；保留 `ApiClientTransactionService#getRevenueAdjustmentMonthlyFees` 作为兼容委托。

**Tech Stack:** Java 17、Spring Boot 3.0.2、JUnit 5、Mockito、MyBatis-Plus。

**Spec:** `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/RS补差优化/RS补差优化设计方案.md`

## Global Constraints

- Java 17，Spring Boot 3.0.2。
- 新代码使用 `@RequiredArgsConstructor` 和 `private final` 构造器注入。
- 新增类必须有中文类注释和 `@author`；新增公开方法必须有中文 Javadoc。
- 金额使用 `BigDecimal`；金额比较使用 `compareTo()`。
- 不为单实现协作者新增接口；不使用 `BeanUtils.copyProperties()`、`import *`、空 `catch` 或吞异常。
- 不自动创建分支、commit、push、合并或 PR；不覆盖其他人的未提交改动。
- 不改变现有补差来源、计算口径、账单字段和 FREE/Pending 状态判定。

## Review Focus

- filter 为 null 或账户列表为空时不访问 Mapper；Task 1 测试覆盖。
- Mapper 返回 null/空列表时不生成虚假费用行；Task 1 测试覆盖。
- provider 明细金额含 null 时忽略该金额但保留明细；Task 1 测试覆盖。
- API 将统一服务返回的汇总行只计入总额一次，provider 明细仅用于展示；Task 2 检查调用与拼接路径。
- 直客账单生成直接调用统一服务，且原有总额/FREE 状态计算路径不变；Task 2 检查调用路径。

---

### Task 1: 新增 RS 月账单服务及规则测试

**Files:**
- Create: `qbit-core/src/main/java/com/qbit/openapi/service/RevenueAdjustmentBillService.java`
- Test: `qbit-core/src/test/java/com/qbit/openapi/service/RevenueAdjustmentBillServiceTest.java`
- Consume: `qbit-core/src/main/java/com/qbit/common_all/funding/mapper/CashBackBonusMapper.java`

**Interfaces:**
- Produces: concrete Spring service method `RevenueAdjustmentBillService#getMonthlyFees(QueryFilterDTO)`；返回 provider 明细行和每个命中账户的一条 `REVENUE_ADJUSTMENT` 汇总行，汇总行 `isSum=true`。

- [ ] **Step 1: Write unit tests first**
  - `returnsProviderDetailsAndAccountSum`：同账户三条 provider 明细金额为 `2.30`、`1.20` 和 null，断言三条明细保留，且有一条金额 `3.50`、`isSum=true` 的汇总行。
  - `returnsEmptyWithoutQueryForMissingAccountIds`：filter 为 null 或账户列表为空时返回空列表，Mapper 不调用。
  - `doesNotCreateSummaryWhenMapperReturnsNoRows`：Mapper 返回 null/空列表时不生成费用行。

- [ ] **Step 2: Implement the service**
  - `RevenueAdjustmentBillService` 注入 `CashBackBonusMapper`，集中负责查询、按账户组织明细、保留 provider 明细并生成命中账户的汇总行。
  - 空 filter/账户列表直接返回空列表；汇总时忽略 null 金额，使用 `BigDecimal.ZERO` 累加。
  - 不修改传入 filter，不改变 Mapper 查询和费用类型。

### Task 2: API 与直客账单接入统一服务

**Files:**
- Modify: `qbit-core/src/main/java/com/qbit/openapi/service/impl/ApiClientTransactionServiceImpl.java`
- Modify: `qbit-core/src/main/java/com/qbit/common_all/api/client/bill/service/impl/ApiClientBillServiceImpl.java`
- Test: `qbit-core/src/test/java/com/qbit/openapi/service/impl/ApiClientTransactionServiceImplRevenueAdjustmentTest.java`
- Test: `qbit-core/src/test/java/com/qbit/common_all/api/client/bill/service/ApiClientBillServiceImplRevenueAdjustmentTest.java`

**Interfaces:**
- Consumes: `RevenueAdjustmentBillService#getMonthlyFees(QueryFilterDTO)`。
- Preserves: `ApiClientTransactionService#getRevenueAdjustmentMonthlyFees(QueryFilterDTO)`，实现为对新 service 的兼容委托；API 和直客账单生成路径不经此委托方法。

- [ ] **Step 1: Write caller tests first**
  - `delegatesRevenueAdjustmentQueryToSharedBillService`：验证旧 API 交易服务方法把同一 filter 委托给新 service，并返回它的费用结果。
  - `directBillUsesSharedRevenueAdjustmentServiceAndCountsSummaryOnce`：验证直客账单直接调用新 service，补差汇总只计入一次。
  - `directBillWithoutRevenueAdjustmentRemainsFree`：验证无补差时直客账单仍按零总额进入 FREE 状态。

- [ ] **Step 2: Implement the shared wiring**
  - API 月结流程直接注入并调用 `RevenueAdjustmentBillService`；使用该服务返回的汇总行替代本地 RS 求和；provider 行只追加展示，避免重复计入总额。无补差行时保留 API 账单原有零值汇总行行为。
  - 保留 `ApiClientTransactionService` 公共兼容方法并改为委托新 service；删除旧的 `revenueAdjustmentMap` 和本地补差求和规则。
  - 直客月账单生成流程直接调用同一 `RevenueAdjustmentBillService`，不经 `ApiClientTransactionService` 获取 RS 费用。
  - 保持直客账单现有总额和 FREE/Pending 状态判定。

- [ ] **Step 3: Inspect the code and complete unified verification**
  - 检查 API 月结和直客账单生成调用点都直接使用 `RevenueAdjustmentBillService#getMonthlyFees`。
  - 检查 API 汇总行只计入一次、provider 明细仅用于展示，且直客零补差时沿用原 FREE 路径。
  - 按仓库要求，在全部实现和测试完成后统一运行：`mvn -pl qbit-core -am test -DskipTests=false -Dtest=ApiClientTransactionServiceImplRevenueAdjustmentTest,ApiClientBillServiceImplRevenueAdjustmentTest,RevenueAdjustmentBillServiceTest`。
  - 运行 `git diff --check` 并检查 diff/stat 与残留旧调用。
