# BB 卡 CB 月结交易排查导出开发方案

## 1. 目标

在 Assets 项目提供可手动运行的分页导出 Service 与测试，支持排查 BB 卡月结 CB 手续费，并导出可用交易 ID 对照 API 交易记录和卡交易记录的数据文件。本次不增加后台 Controller。

## 2. 导出类型

### 2.1 CB 交易对账导出

生成一份 XLSX，按交易 ID 对照 API 侧记录和卡交易侧记录，建议分为两个 sheet：

- `API交易记录`：`transaction_id`、`root_id`、`api_client_transaction.account_id`、`create_time`、`complete_time`、原始 `fees`、`provider`、单独解析出的 `crossBorderFee`。
- `卡交易记录`：对应的 `qbit_card_transaction` 记录，包含 `id`、`transactionCurrency`、`transactionAmount`、`specialSourceData.country`、`status`、`createTime`。

两个 sheet 用相同的 `transaction_id` 对照。导出候选范围为：

- 固定当前确认的 10 个 API 客户账户。
- `api_client_transaction.create_time >= 2026-02-11 00:00:00+00` 且 `< 2026-10-01 00:00:00+00`。
- provider 前缀为 `BlueBancCard`，API 记录未软删除。
- 卡交易 `status = 'Closed'`、币种为 USD、商户国家/地区不是美国。
- 交易发生时账户处于 Monthly 月结周期；周期由 root 账户 `operationLog` 中的 statementType 配置日志确定，按卡交易 `q.createTime` 匹配。
- `fees` 中 `crossBorderFee` 缺失或金额为 0。

### 2.2 按账户与月份拆分的交易导出

生成多个 XLSX：每个 API 账户一个文件，每个文件按月创建 sheet；当前范围预计每个文件包含 2026-02 至 2026-09 的月 sheet（2 月为部分月份，10 月 1 日起不纳入）。

- 文件名包含账户 ID，例如 `BB-CB-<accountId>.xlsx`。
- sheet 名使用 `YYYY-MM`。
- 月份归属按 `api_client_transaction.complete_time` 计算；整体查询时间范围仍按 `api_client_transaction.create_time` 过滤。
- 每月 sheet 导出该账户在相同候选条件下的交易，字段包含 API 记录和卡交易侧可对照字段。

## 3. 账户 rootId

从 `public.account` 按 `parentAccountId` 递归得到每个目标交易账户对应的 rootId。月结日志按 rootId 关联。关联不同表的账户 ID、交易 ID 时，将两侧统一转换为 text，避免 UUID 与 varchar 直接比较导致 SQL 类型错误。

## 4. 实现方式

- 新增专用 MyBatis Mapper 与 XML，承载筛选、rootId 计算、月结周期识别、CB fee 解析及分页查询。
- 新增 Service，以固定页大小分页查询；EasyExcel 逐页写入 XLSX，避免将全部交易一次性加载到内存。
- 测试直接注入 Service，运行后在 `qbit-core/target/exports` 生成对账文件和账户月度文件；不走异步通知或后台 API。
- 使用稳定排序和去重，确保分页结果不重复、不遗漏。评估在数据量较大时采用游标分页，避免深 offset 查询变慢。

## 5. 验收标准

1. 指定测试可生成对账 XLSX，API 与卡交易 sheet 能按 transaction ID 一一核对。
2. 指定测试可为每个账户生成独立 XLSX，且每个月有对应 sheet。
3. 每个 sheet 中的交易均满足时间、月结、Closed、BB、USD、非美国及 CB 缺失/为 0 条件。
4. 导出保留 API `account_id` 和对应 `root_id`，并包含 API 原始 fees、CB fee、完成时间和卡交易状态等字段。
5. 分页文件可正常打开；空结果时仍生成带表头的文件。

## 6. 验证与已知限制

- 编译、MyBatis XML 格式与 diff 检查需通过。
- 数据库集成测试需连接项目 `dw` 数据源；当前开发环境运行测试时 `dw` 连接超时，尚未生成 XLSX，也尚未验证 SQL 的数据库执行结果。
- 如 `fees` 数组中出现多个 `crossBorderFee` 条目，目前取其中一个；正常数据预期每笔交易只有一个该类型条目。

## 7. 当前代码进度

已在 Assets 分支增加单文件分页查询、导出 Service 和手动导出测试，并补充 API 完成时间、原始 fees、卡交易 status 字段。待扩展为 API/卡交易双 sheet 对账文件，以及每账户一个文件、每月一个 sheet 的导出；待 `dw` 数据库可用后运行集成测试确认。
