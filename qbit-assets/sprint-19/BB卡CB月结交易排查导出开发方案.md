# BB 卡 CB 月结交易排查导出开发方案

## 1. 目标

为当前 10 个 API 客户导出同一批 BB 卡月结 CB 待排查交易，提供两种 Excel 组织方式：一份全量工作簿，以及每客户一份、按完成月份分 sheet 的工作簿。首轮两种形式由一次分页查询同时生成，保证交易集合一致，并保留交易 ID 供 Excel 关联及后续复查。

流程分两轮：修复前生成基线；修复后，以首轮全量工作簿中的 `transaction_id` 为固定清单重新查询，并再次生成全量工作簿和客户/月工作簿，供 Excel 按 ID 对比修复前后字段。两轮文件分开保存。导出工具不执行费率修复，也不自动计算差异。

任务入口参照现有 XXL-JOB 用法，提供可由调度器参数或 Spring Boot 测试直接调用的 Job 方法。

## 2. 目标账户与筛选范围

### 2.1 默认目标账户

未传自定义账户时，默认查询以下 10 个 `api_client_transaction.account_id`；传入账户列表后仅查询指定 ID，不自动扩展其其他子账户。客户工作簿按最终生效的账户 ID 分组。

| # | account_id |
|---:|---|
| 1 | `a54fda9d-cce8-4525-b153-dbc0f45a0c6c` |
| 2 | `9a6e4d51-d5cf-471f-8c13-9922c1213638` |
| 3 | `80be1f90-8f3a-4014-875a-6f71ea40551e` |
| 4 | `b04da43a-0be5-44ae-a5c2-b8e8fdbeecd7` |
| 5 | `e6f7db49-c103-455e-930a-acdc22f64889` |
| 6 | `4a3bb457-d294-4ddd-8f1c-bde22b59d3fb` |
| 7 | `ff22382b-df2e-4a76-b92e-bc32e3b8b089` |
| 8 | `e83b6e59-cd6b-4f77-9c0e-388ec2486bc4` |
| 9 | `f67cd913-4d76-47bf-b6f6-02c7531a2a69` |
| 10 | `2e48629c-9216-4841-8d38-6594e3975251` |

### 2.2 可自定义的查询参数

参考 `ApiClientTransactionJob` 使用 JSON 参数映射到 `QueryFilterDTO` 的方式，两种导出共用同一组参数：

- `accountIds`：可选账户 ID 列表；未传时使用本方案列出的 10 个默认账户。
- `startDate`、`endDate`：可选时间范围，作用于 `api_client_transaction.create_time`，左闭右开 `[startDate, endDate)`。
- 未传时间时使用默认范围 `[2026-02-11 00:00:00+00, 2026-10-01 00:00:00+00)`。不沿用同步 Job 的前一天/上月默认值，因为本次默认任务是历史排查。
- 全量 XLSX 和客户/月 XLSX 必须使用同一份参数对象、同一条分页查询结果流；不能为两种文件分别解析或应用参数。

参数示例：

```json
{
  "accountIds": ["9a6e4d51-d5cf-471f-8c13-9922c1213638"],
  "startDate": "2026-08-01 00:00:00+00",
  "endDate": "2026-09-01 00:00:00+00"
}
```

修复后复查另接受首轮全量 XLSX 导出的 `transactionIds` 列表。提供该列表时，它固定复查交易集合；不重新应用首轮 CB=0 条件或首轮创建时间范围。

新增专用导出参数 DTO，字段为 `accountIds`、`startDate`、`endDate`、`transactionIds`。不直接扩展通用 `QueryFilterDTO`，避免把导出专属的 ID 复查参数加到其他业务筛选对象中。

### 2.3 已确认的交易条件

- API 记录创建时间：`api_client_transaction.create_time >= startDate` 且 `< endDate`；未传时使用默认范围 `[2026-02-11 00:00:00+00, 2026-10-01 00:00:00+00)`。
- Provider 前缀为 `BlueBancCard`，API 记录未软删除。
- 卡交易状态为 `Closed`，`transactionCurrency = 'USD'`，商户国家不是美国。
- 月结资格使用卡交易 `q.createTime`，与对应 root 账户的 `operationLog` 中 `Monthly` 配置生效区间匹配。
- 交易 `root_id` 从 `public.account.parentAccountId` 递归计算；账户及交易 ID 跨表关联时统一转换为文本，避免 UUID/varchar 类型不匹配。
- `fees` 中明确存在 `crossBorderFee` 且金额为 0 才纳入；完全没有该 fee 项的交易按“没有的不管”排除。
- 对同一 `transaction_id` 只保留最新 API 记录后，再判断 CB fee 条件，防止较早记录影响候选结果。

### 2.4 同一交易多条 API 记录的处理

- 首轮基线：先按自定义 `create_time` 范围过滤 API 记录，再按 `transaction_id` 取范围内最新的一条，最后判断 CB fee 是否为 0。
- 修复后复查：不应用首轮日期范围；按首轮 ID 清单，从全历史 API 记录中取每个 ID 最新的一条。

## 3. 导出字段

| 来源 | 字段 | 说明 |
|---|---|---|
| 关联 | `transaction_id` | 卡交易 `q.id`，与 API `transaction_id` 对应 |
| 关联 | `transaction_display_id` | 来自关联的 `Transaction.transactionDisplayId`；不是账户的 `displayId` |
| API | `account_id`、`root_id` | API 客户账户及其 root 账户 |
| API | `create_time`、`complete_time`、`complete_month` | `complete_month` 根据 API `complete_time` 按 UTC 月份生成 |
| API | `fees`、`provider`、`crossBorderFee` | 保留原始费用 JSON、渠道及单独解析的 CB 金额 |
| 卡交易 | `transactionCurrency`、`transactionAmount` | 卡交易币种和金额 |
| 卡交易 | `specialSourceData`、`country` | 同时保留原始 JSON 和其中解析出的商户国家 |
| 卡交易 | `status` | 卡交易状态 |

`q.createTime` 仅用于月结周期判断，不作为 Excel 列。`complete_time` 与 `complete_month` 都是独立字段；若 `complete_time` 为空，保留交易，月度版归入“未完成”sheet，`complete_month` 为空。

## 4. 两种导出文件

### 4.1 全量版

- 生成一个全量 XLSX，只包含一个 `交易明细` sheet。
- 每个 `transaction_id` 一行，将 API 账户/root、API 时间和费用字段，与卡交易及交易 display ID 字段放在同一行。
- API `transaction_id` 与卡交易 `q.id` 在查询阶段关联；交易 display ID 来自 `Transaction.transactionDisplayId`。
- 产物建议放在 `qbit-core/target/exports/`。

### 4.2 按客户/月拆分版

- 每个最终生效的账户生成一个 XLSX，文件名包含账户 ID，例如 `BB-CB-<accountId>.xlsx`。
- 每个文件按 `complete_month` 建立 `YYYY-MM` sheet。
- 每个 sheet 每笔交易一行，合并展示上表 API 与卡交易字段，保留 transaction ID 供 Excel 匹配。
- 只导出与全量版相同的候选交易，不扩展为账户所有月结交易。
- 空月份保留带表头的 sheet；完成时间为空的记录放入“未完成”sheet。

### 4.3 修复后复查

- 从首轮全量工作簿提取 `transaction_id` 清单，按这些 ID 查询当前最新 API 与卡交易记录。
- 复查轮仅由 ID 清单限定交易集合；不再应用首轮 `crossBorderFee = 0` 条件、`ac.create_time` 初始时间范围或其他候选筛选，以免已修复的交易被排除。
- 复查轮再次生成两种格式：一个全量 `交易明细` 工作簿，以及每个账户一份、按当前 `complete_month` 分 sheet 的工作簿。
- 修复前后使用相同列和列头，分别放入 `before-repair/` 与 `after-repair/` 目录，便于 Excel 按 `transaction_id` 匹配。建议文件名为 `BB-CB-all.xlsx` 和 `BB-CB-<accountId>.xlsx`。

## 5. 实现方案（已选）

使用一个 MyBatis Mapper 查询和一条分页结果流。Service 每取一页，只查询一次：将行写入全量工作簿，并同时按 `account_id`、`complete_month` 分发到对应客户文件和 sheet。这样两种交付形式使用完全相同的交易集合，避免重复扫描数据库或筛选条件漂移。

具体实现：

1. 专用 MyBatis Mapper/XML：计算 root、解析 root 的 Monthly 日志周期、关联 API/卡交易/Transaction display ID，返回导出共用行。
2. 按固定页大小查询，使用稳定排序（账户、完成月份、交易 ID）；同一交易先定最新 API 行，再应用 CB 条件。
3. Service 同时持有全量工作簿和目标客户工作簿的 writer；按页写出，不把全部交易载入内存。
4. 新增 `ApiClientBbCbTransactionExportJob` Spring 组件及 XXL-JOB handler；handler 从 `XxlJobHelper.getJobParam()` 读取 JSON，再委托给独立的参数化执行方法。
5. 新增 `@SpringBootTest`：注入导出 Job 并像 `ApiClientTransactionJobTest` 一样直接调用；另可传 JSON 参数覆盖账户、时间或复查 transactionIds。Job 在非 XXL 执行上下文中收到空参数时使用默认账户和日期。
6. 不新增后台 Controller。导出执行逻辑与 Job 参数解析分开，便于测试直接调用，也避免测试依赖正在运行的 XXL 调度器。

备选方案：先生成全量 Excel 后读取并拆客户文件，会增加一次文件读写和转换；两类文件分别执行 SQL 虽实现直观，但会重复查库且可能生成不同交易集合。故采用单次查询、同步分发。

## 6. 验收标准

1. 首轮和复查轮各生成一个全量工作簿及每个最终生效账户各一个客户工作簿；不传账户参数时每轮为 10 个客户文件。
2. 全量版只有一个明细 sheet，每笔交易一行，合并 API 与卡交易字段，包含 `transaction_id` 和 `transaction_display_id`。
3. 两类导出的交易 ID 集合完全相同。
4. 客户月度文件只包含对应账户的候选交易，按 API `complete_time` 的 UTC 月份分 sheet。
5. SQL 使用正确的时间口径：API 创建时间过滤范围、卡交易创建时间判断月结、API 完成时间生成完成月份。
6. Java/测试源码可编译，Mapper XML 可解析，SQL 回归测试通过；数据库可连接时实际生成 XLSX 并核对 sheet、表头和交易数。

## 7. 当前工作区和实施前置条件

- Assets 分支：`jx/26/sprint-19/fix-dev-BB-CB-Caas`。
- 上一轮新增的导出 Java/XML 源文件当前不在 `src` 下，只有 `target` 中的编译产物；实施时需要按本方案恢复或重建源文件。
- 当前工作区有两处 Partner 相关未提交修改，不属于本任务，实施时必须保留。
- 之前 Spring 集成测试因 `dw` 数据源连接超时未能生成 XLSX；实际数据库查询验收需要该数据源可连通。



