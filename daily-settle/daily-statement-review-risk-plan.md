# 日账单导出与重生成 Review 改进计划

> 来源：qbit-assets PR 6695 日账单导出 / 重生成链路 review  
> 日期：2026-06-05

## 目标

让日账单导出统一以 ZIP 交付，并确保 Distributor 任一 master 失败时整单失败，同时补齐重生成链路的风险控制和代码结构优化。

当前口径：

- 普通户：ZIP 内包含 1 个 XLSX
- Distributor：ZIP 内包含多个 master XLSX
- 旧文件复用不是当前风险，因为功能尚未上线，没有历史存量数据

## Code Review Findings

### P0. Distributor 任一 master 失败没有整单失败

风险位置：

- `DailyStatementServiceImpl.processMasterAccount(...)`
- `DailyStatementServiceImpl.exportDistributorZip(...)`
- `DailySettleJob.generateDailyStatement(...)`
- `DailySettleJob.buildDistributorParentExcels(...)`

问题：

`processMasterAccount(...)` 和 `processDistributorParentAccount(...)` 现在会用 `null` 表达“无数据 / 无 handler / 查询异常 / 生成失败”。外层只收集非空结果，只要至少一个 XLSX 成功，就会继续打 ZIP 并标记 `completed`。

影响：

Distributor 账单可能静默缺 master 文件，用户拿到的是成功 ZIP，但内容不完整。财务账单场景里这是最高优先级风险。

建议：

- 区分“可跳过账户”和“失败账户”
- 查询异常、模板异常、打包异常、结果获取异常，都必须整单失败
- 只有业务明确允许的“无交易 / 无数据”才能跳过，并且要记录日志

### P1. `regenerate()` 先创建任务再抢 running key，可能产生孤儿任务

风险位置：

- `DailyStatementServiceImpl.regenerate(...)`
- `DailyStatementServiceImpl.createRegenerateTask(...)`
- `DailyStatementServiceImpl.tryLockRunningTask(...)`

问题：

当前先 `createRegenerateTask(...)`，再 `tryLockRunningTask(...)`。如果 running key 已存在，方法返回旧任务 ID，但刚创建的新 `task_progress` 不会被消费，也不会被清理。

影响：

高频重复请求下会产生无效任务记录，进度查询和运营排障都会被污染。

建议：

先抢 running key，再创建进度任务；或者在复用旧 taskId 时主动将新建任务标记失败/取消。推荐前者。

### P1. ZIP 生成仍然全量攒内存

风险位置：

- `DailyStatementServiceImpl.exportDistributorZip(...)`
- `DailySettleJob.generateDailyStatement(...)`

问题：

当前先把所有 XLSX `byte[]` 放入 `List<byte[]>`，再统一写入 ZIP。

影响：

Distributor master 多、交易量大时会同时持有多个 XLSX 和完整 ZIP，容易放大内存压力。

建议：

- 短期保留现状但增加数量、大小、耗时日志
- 中期改为边生成边写 `ZipOutputStream`

### P2. Controller 路径仍叫 `/xlsx`，但结果已经是 ZIP

风险位置：

- `DailyStatementController.exportXlsx(...)`

问题：

接口路径是 `/xlsx`，但当前对外契约已经是 ZIP。

影响：

前端、SDK、客户文档容易误解响应文件格式。

建议：

如果接口还没上线，直接改为 `/zip` 或 `/download`；如果已对接文档，可以保留路径但在 OpenAPI 文档和 README 中明确返回 ZIP。

### P2. `DailyStatementServiceImpl` 职责过重

问题：

一个类同时负责：

- 权限校验
- 日期校验
- 账户类型路由
- 余额交易聚合
- Excel 构建
- ZIP 打包
- OSS 上传
- 重生成限流
- MQ 发送
- 进度查询

影响：

后续修改容易互相影响，测试难以聚焦。

建议：

分阶段拆出：

- `DailyStatementZipBuilder`
- `DailyStatementExportCoordinator`
- `DailyStatementRegenerateCoordinator`
- `DailyStatementProgressReader`

## 改进计划

### Task 1. Distributor master 失败整单失败

目标：

只要任一 master / parent 发生查询失败、生成失败、模板失败、结果获取失败，就整单失败，不上传 ZIP，不写 `completed` 文件记录。

修改文件：

- `qbit-core/src/main/java/com/qbit/openapi/v3/statement/service/impl/DailyStatementServiceImpl.java`
- `qbit-core/src/main/java/com/qbit/job/settle/DailySettleJob.java`
- `qbit-core/src/test/java/com/qbit/job/DailyStatementJobTest.java`

建议步骤：

1. 新增私有异常或直接抛业务异常，明确“生成失败”语义
2. `processMasterAccount(...)` 捕获异常后改为 `throw`
3. `exportDistributorZip(...)` 捕获任一 future 异常后整单失败
4. `processDistributorParentAccount(...)` 查询/生成异常改为抛出
5. `buildDistributorParentExcels(...)` 中结果为空时明确区分“无数据”和“失败”
6. 增加测试：任一 master 失败时，不上传 ZIP，不写 completed

核心代码方向：

```java
} catch (Exception e) {
    log.error("Distributor master 账单生成失败: masterId={}, date={}", masterId, date, e);
    throw ExceptionCodeFactory.businessCode(ExceptionConstant.COMMON_EXCEPTION_400, "Distributor 账单生成失败");
}
```

### Task 2. 修复 regenerate 任务创建顺序

目标：

避免重复请求产生孤儿 `task_progress`。

修改文件：

- `qbit-core/src/main/java/com/qbit/openapi/v3/statement/service/impl/DailyStatementServiceImpl.java`
- `qbit-core/src/test/java/com/qbit/openapi/v3/statement/service/impl/DailyStatementServiceImplTest.java`

目标流程：

```text
校验 -> 查可复用任务 -> 申请配额 -> 抢 running key -> 创建 task_progress -> 写 root task key -> 发 MQ
```

建议步骤：

1. 将 running key 占位提前
2. 先写临时占位值 `PENDING`
3. 创建任务后将 running key 替换成真实 `taskId`
4. MQ 发送失败时清理 `PENDING` 或当前 `taskId`
5. 增加测试：重复请求不会新增无效任务记录

### Task 3. ZIP 打包与上传抽公共组件

目标：

减少 `DailyStatementServiceImpl` 和 `DailySettleJob` 的 ZIP 代码重复，统一文件名、路径、异常处理和日志。

建议新增：

- `DailyStatementZipBuilder`
- `DailyStatementZipEntry`

建议接口：

```java
public interface DailyStatementZipBuilder {

    byte[] buildSingle(String filename, byte[] xlsxBytes);

    byte[] build(List<DailyStatementZipEntry> entries);
}
```

使用方向：

```java
byte[] zipBytes = dailyStatementZipBuilder.buildSingle(
        "daily-statement-" + accountId + "-" + date + ".xlsx", xlsxBytes);
```

### Task 4. Controller 和文档契约收敛为 ZIP

目标：

避免 `/xlsx` 路径和 ZIP 结果不一致造成误解。

建议：

- 未上线：把 `/xlsx` 改为 `/zip` 或 `/download`
- 如果保留 `/xlsx`：OpenAPI 文档必须明确返回 ZIP
- DTO 日期说明补充“必须早于今天”
- SDK / API 文档同步修改文件格式说明

### Task 5. 数据量与运行风险控制

目标：

提升大客户数据量下的稳定性和可观测性。

建议：

1. 交易分页增加稳定排序：

```sql
ORDER BY "transactionTime" DESC, "id" DESC
```

2. 增加导出规模日志：

```java
log.info("日账单导出规模: accountId={}, date={}, balanceCount={}, transactionCount={}, zipBytes={}",
        accountId, date, balanceSummaries.size(), transactions.size(), zipBytes.length);
```

3. 重生成并发阈值配置化：

```java
@Value("${daily-statement.regenerate.max-root-count:1}")
private int maxRootRegenerateCount;

@Value("${daily-statement.regenerate.max-total-count:10}")
private int maxTotalRegenerateCount;
```

## 风险控制 Checklist

- [ ] Distributor 任一 master 失败时整单失败
- [ ] 不允许部分 ZIP 标记 `completed`
- [ ] 重生成任务先抢占运行权，再创建 `task_progress`
- [ ] MQ 发送失败必须清理 running key、root task key、root count、total count
- [ ] Consumer 完成或失败都必须释放 Redis 计数
- [ ] ZIP 上传路径必须以 `.zip` 结尾，不走 `ExportService.generatorFilepath(...)`
- [ ] 普通户 ZIP 内只有一个 XLSX
- [ ] Distributor ZIP 内可以有多个 XLSX
- [ ] Excel 公式追加行数包含 USD Total 汇总行
- [ ] 日期必须早于今天，且在允许的历史范围内
- [ ] 导出日志必须包含 accountId、date、文件数量、交易数量、耗时

## 推荐实施顺序

1. 先修 Distributor 任一 master 失败整单失败
2. 再修 `regenerate()` 任务创建顺序
3. 再抽 ZIP 构建公共组件
4. 再收敛接口路径和文档契约
5. 最后做数据量、排序、日志和配置化治理

