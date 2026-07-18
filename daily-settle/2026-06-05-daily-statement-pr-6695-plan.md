# 日账单 PR 6695 改进实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 收紧日账单导出与重生成链路的契约，修复重生成任务、Distributor 导出和 Excel 版式/公式偏移问题，让普通户导出和 Distributor 批处理的语义清晰且可测试。

**Architecture:** 把“单文件导出”和“批处理 ZIP 导出”拆成明确的业务契约，保留 `exportXlsx(...)` 作为普通户单文件导出入口，把 Distributor 的批量 ZIP 行为限定在 Job / 批处理链路里。重生成链路先抢占执行权再创建任务，避免孤儿 `task_progress` 记录；Distributor 导出改成失败可见、可追踪，不再静默吞掉 master 级异常。Excel 模板填充与公式追加按实际写入行数计算，避免版式错位。

**Tech Stack:** Java 17, Spring Boot 3.0.2, MyBatis-Plus, PostgreSQL 15, Redis / Redisson, RocketMQ, EasyExcel, Apache POI, JUnit 5.

---

### Task 1: 锁定日账单导出契约，分清单文件与批处理 ZIP

**Files:**
- Modify: `qbit-core/src/main/java/com/qbit/openapi/v3/statement/service/DailyStatementService.java`
- Modify: `qbit-core/src/main/java/com/qbit/openapi/v3/statement/service/impl/DailyStatementServiceImpl.java`
- Modify: `qbit-core/src/main/java/com/qbit/openapi/v3/statement/controller/DailyStatementController.java`
- Modify: `qbit-core/src/main/java/com/qbit/job/settle/DailySettleJob.java`
- Test: `qbit-core/src/test/java/com/qbit/job/DailyStatementJobTest.java`

- [ ] **Step 1: 为导出契约写回归测试**

```java
@Test
void exportXlsx_shouldReturnSingleFileUrl_forOpenApiExport() {
    String fileUrl = dailyStatementService.exportXlsx("5ce9647c-d3b3-488c-a595-20a273554039", "2026-06-05", null);
    assertThat(fileUrl).endsWith(".xlsx");
}

@Test
void processDailySettle_shouldReturnZipPackage_forJobExport() {
    String fileUrl = dailySettleJob.processDailySettle("2026-06-02", "451fb6b9-54b7-4e6b-b690-cbe4f77670ed");
    assertThat(fileUrl).endsWith(".zip");
}
```

- [ ] **Step 2: 把控制器和 Job 的职责边界写清楚**

```java
@GetMapping("/xlsx")
@Operation(summary = "导出单个日账单文件（普通户单文件 XLSX）", operationId = "exportXlsx")
public ApiResult<String> exportXlsx(@ParameterObject @Valid StatementExportReqDTO dto) {
    return ApiResult.ok(dailyStatementService.exportXlsx(dto.getAccountId(), dto.getDate(), null));
}
```

```java
public String processDailySettle(String settleDate, String accountId) {
    // 批处理链路保持 ZIP 语义，内部可以包含多个 xlsx
}
```

- [ ] **Step 3: 将 Distributor 的 ZIP 输出限制在批处理链路**

```java
// exportXlsx 只返回单个账单文件，不在这里做 ZIP 容器化
if (ApiAccessTypeEnum.DISTRIBUTOR.equals(accessType)) {
    return buildDistributorSingleFile(accountId, date);
}
```

- [ ] **Step 4: 跑导出契约回归用例**

Run:

```bash
cd qbit-core && mvn test -Dtest=DailyStatementJobTest -DskipTests=false
```

Expected:

- 普通户 `exportXlsx(...)` 返回单个账单文件 URL
- Job 链路返回 ZIP
- 控制器文案与实际输出一致

---

### Task 2: 修复 regenerate 任务创建顺序，避免孤儿任务

**Files:**
- Modify: `qbit-core/src/main/java/com/qbit/openapi/v3/statement/service/impl/DailyStatementServiceImpl.java`
- Modify: `qbit-core/src/main/java/com/qbit/mq/statement/DailyStatementRegenerateConsumer.java`
- Modify: `qbit-core/src/main/java/com/qbit/mq/statement/DailyStatementRegenerateMsg.java`
- Test: `qbit-core/src/test/java/com/qbit/openapi/v3/statement/service/impl/DailyStatementServiceImplTest.java`

- [ ] **Step 1: 写重复请求不应新增任务的测试**

```java
@Test
void regenerate_shouldReuseExistingTaskBeforeCreatingNewProgress() {
    String taskId1 = dailyStatementService.regenerate("5ce9647c-d3b3-488c-a595-20a273554039", "2026-06-05");
    String taskId2 = dailyStatementService.regenerate("5ce9647c-d3b3-488c-a595-20a273554039", "2026-06-05");
    assertThat(taskId2).isEqualTo(taskId1);
}
```

- [ ] **Step 2: 把 running lock 前置，确保进度记录只在真正占位成功后创建**

```java
private String regenerate(String accountId, String date) {
    RegenerateContext context = buildRegenerateContext(rootId, accountId, date);
    String existingTaskId = findExistingRegenerateTaskId(context);
    if (StringUtil.isNotBlank(existingTaskId)) {
        return existingTaskId;
    }
    acquireRegenerateLimits(context);
    String runningTaskId = tryLockRunningTask(context);
    String taskId = createRegenerateTask(accountId);
    cacheRootTask(context, taskId);
    sendRegenerateMessage(context, taskId);
}
```

- [ ] **Step 3: 消费端补齐释放逻辑的幂等性**

```java
@Override
public Action consume(Message message, ConsumeContext consumeContext) {
    try {
        dailyStatementService.exportXlsx(msg.getAccountId(), msg.getDate(), msg.getTaskId());
        taskProgressService.updateData(completeDTO);
    } catch (Exception e) {
        taskProgressService.updateData(failDTO);
    } finally {
        releaseRegenerateLimit(msg);
    }
}
```

- [ ] **Step 4: 跑重生成回归测试**

Run:

```bash
cd qbit-core && mvn test -Dtest=DailyStatementServiceImplTest -DskipTests=false
```

Expected:

- 同一账单重复触发不会新增孤儿任务
- 失败时 Redis 占位和计数能释放
- 消费端完成后能正确清理运行 key

---

### Task 3: 让 Distributor 导出失败可见，并降低内存压力

**Files:**
- Modify: `qbit-core/src/main/java/com/qbit/openapi/v3/statement/service/impl/DailyStatementServiceImpl.java`
- Modify: `qbit-core/src/main/java/com/qbit/openapi/v3/statement/service/handler/*`
- Test: `qbit-core/src/test/java/com/qbit/openapi/v3/statement/service/impl/DailyStatementServiceImplTest.java`

- [ ] **Step 1: 写 master 失败必须让整单失败的测试**

```java
@Test
void exportXlsxForDistributor_shouldFailWhenAnyMasterFails() {
    assertThatThrownBy(() -> dailyStatementService.exportXlsx("451fb6b9-54b7-4e6b-b690-cbe4f77670ed", "2026-06-02", "12306"))
            .hasMessageContaining("账单生成失败");
}
```

- [ ] **Step 2: 把 master 级异常从静默吞掉改成可追踪失败**

```java
private MasterResult processMasterAccount(AccountRelation rel, String date) {
    try {
        // 查询、构建、生成
    } catch (Exception e) {
        log.error("Distributor 子账户处理异常: masterId={}, date={}", masterId, date, e);
        throw ExceptionCodeFactory.businessCode(ExceptionConstant.COMMON_EXCEPTION_400, "Distributor 子账户账单生成失败");
    }
}
```

- [ ] **Step 3: 改成边生成边写 ZIP，避免先攒满内存**

```java
try (ZipOutputStream zos = new ZipOutputStream(zipBaos)) {
    for (AccountRelation rel : masterRelations) {
        MasterResult result = processMasterAccount(rel, date);
        zos.putNextEntry(new ZipEntry(result.filename()));
        zos.write(result.xlsx());
        zos.closeEntry();
    }
}
```

- [ ] **Step 4: 跑 Distributor 导出回归**

Run:

```bash
cd qbit-core && mvn test -Dtest=DailyStatementServiceImplTest -DskipTests=false
```

Expected:

- 任一 master 失败时整单失败
- ZIP 里不会出现缺页但成功返回的情况
- 大客户导出不会一次性把所有 xlsx 长时间压在内存里

---

### Task 4: 修正 Excel 公式偏移和日期边界校验

**Files:**
- Modify: `qbit-core/src/main/java/com/qbit/openapi/v3/statement/service/impl/DailyStatementServiceImpl.java`
- Modify: `qbit-core/src/main/java/com/qbit/openapi/v3/statement/util/StatementFormulaWriter.java`
- Modify: `qbit-core/src/main/java/com/qbit/openapi/v3/statement/domain/dto/StatementExportReqDTO.java`
- Modify: `qbit-core/src/main/java/com/qbit/openapi/v3/statement/controller/DailyStatementController.java`
- Test: `qbit-core/src/test/java/com/qbit/openapi/v3/statement/service/impl/DailyStatementServiceImplTest.java`

- [ ] **Step 1: 写 Excel 公式起始行的回归测试**

```java
@Test
void appendBalanceFormulas_shouldRespectUsdSummaryRow() {
    byte[] result = StatementFormulaWriter.appendBalanceFormulas(filledBytes, balanceSummaries.size() + 1);
    assertThat(result).isNotNull();
}
```

- [ ] **Step 2: 让公式 writer 使用真实写入行数**

```java
byte[] filledBytes = stream.toByteArray();
return StatementFormulaWriter.appendBalanceFormulas(filledBytes, balanceSummaries.size() + 1);
```

- [ ] **Step 3: 在 DTO / Controller 边界补充日期格式和范围校验**

```java
@NotBlank(message = "date is required")
@Schema(description = "账单日期 yyyy-MM-dd，且必须早于今天", example = "2026-05-14", requiredMode = Schema.RequiredMode.REQUIRED)
private String date;
```

```java
@GetMapping("/xlsx")
public ApiResult<String> exportXlsx(@ParameterObject @Valid StatementExportReqDTO dto) {
    return ApiResult.ok(dailyStatementService.exportXlsx(dto.getAccountId(), dto.getDate(), null));
}
```

- [ ] **Step 4: 跑日期与模板回归测试**

Run:

```bash
cd qbit-core && mvn test -Dtest=DailyStatementServiceImplTest -DskipTests=false
```

Expected:

- 今天、未来日期、过期历史日期都会被拦截
- Excel 中 USD 汇总行与后续公式说明区位置正确
- 模板不再出现错位或覆盖

---

## 实施顺序建议

1. 先修 `regenerate()` 的任务占位顺序
2. 再修 Distributor 的失败可见和流式 ZIP
3. 再修 Excel 公式偏移
4. 最后收紧 DTO / Controller 边界校验和文案

## 验收标准

- 普通户 `exportXlsx(...)` 的输出契约稳定，路径和返回值清晰
- `DailySettleJob.processDailySettle(...)` 保持 ZIP 批处理语义
- 重生成重复请求不会产生孤儿 `task_progress`
- Distributor 导出不会静默返回缺页文件
- Excel 公式说明区不会错位
- 日期边界校验在控制器层和服务层都能稳定命中

