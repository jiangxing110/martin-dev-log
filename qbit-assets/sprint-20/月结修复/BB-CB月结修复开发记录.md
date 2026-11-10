# BB / CB 月结修复开发记录

- 日期：2026-11-10（北京时间）
- 项目：`qbit-assets`
- 分支：`jx/26/sprint-20/caas-fee`
- 范围：Java 月结手续费任务的费率时间选择、历史 fees 基线恢复、指定单一手续费类型重算。

## 目标与处理流程

这次改动继续使用 `sync_caas_month_tx` 定时任务，新增两个可显式选择的处理模式：

1. **恢复基线**：从 OSS XLSX 的“修复前API fees”恢复 `api_client_transaction.fees`。
2. **单项重算**：仍以同一份 XLSX 的交易 ID 为范围，确认数据库费用与基线一致后，按 `ApiClientFeeEnum` 指定一个费项重新计算；合并时保留其他费项及原费用对象的扩展字段。

普通定时任务仍按卡交易 `completeTime` 过滤同步窗口。手续费费率查询和月结区间判断共用以下有效时间规则：卡交易 `createTime` 在北京时间 2026-10-01 00:00 前，使用 `completeTime`；从该切换点开始（含）使用 `createTime`。

历史 `settlementFee` 由于公式有变更，本次仅从修复前文件恢复，不纳入重算白名单。当前单项重算支持 `crossBorderFee`、`fxFee`、`applePayAuthFee`、`atmWithdrawalFee`。保护范围不限于 `settlementFee`：只重算 CB 或 FX 时，费用数组中的其他项（包括另一项 CB/FX、Settlement、ATM、Apple Pay）均保留修复前原值。

## 文件改动清单

| 文件 | 改动 |
| --- | --- |
| `qbit-core/src/main/java/com/qbit/common_all/api/client/bill/service/ApiClientFeeTimeSelector.java` | 新增统一有效时间选择器；按卡交易创建时间的北京时间切换点选择完成时间或创建时间，供月结判断与费率查询共用。 |
| `qbit-core/src/main/java/com/qbit/common_all/api/client/bill/service/ApiClientTransactionFactory.java` | 增加带修复上下文的同步重载，把固定交易范围和单项费类型传到具体交易服务。 |
| `qbit-core/src/main/java/com/qbit/common_all/api/client/bill/service/ApiMonthBillTransactionService.java` | 增加修复模式默认入口；未实现该能力的交易服务明确抛出不支持异常，避免静默误处理。 |
| `qbit-core/src/main/java/com/qbit/common_all/api/client/bill/service/impl/ApiClientQbitCardTransactionServiceImpl.java` | 在卡交易月结处理及费率计算中统一使用有效时间；正常任务仍按完成时间窗口查询。修复模式改按 XLSX 交易 ID 查询、不受普通日期窗口限制；从目标费项校验处理分组，按该分组计算后只合并目标费用，不整组 upsert。 |
| `qbit-core/src/main/java/com/qbit/common_all/api/client/bill/service/impl/ApiClientTransactionFactoryImpl.java` | 实现修复上下文的路由，按现有手续费类别选择对应交易服务。 |
| `qbit-core/src/main/java/com/qbit/job/synchronization/ApiClientTransactionJob.java` | 将 `sync_caas_month_tx` 参数解析为新任务 DTO；增加 `executeWithParam`，供定时任务和 SpringBootTest 以相同入口执行；无日期参数时保留原来的默认日期窗口。 |
| `qbit-core/src/main/java/com/qbit/openapi/domain/dto/ApiClientTransactionBaselineRowDTO.java` | 新增 XLSX 行映射，读取交易 ID、API 账户 ID、root_id、API 创建时间、provider 和修复前 fees。 |
| `qbit-core/src/main/java/com/qbit/openapi/domain/dto/ApiClientTransactionFeeRepairContext.java` | 新增经基线校验后的修复上下文，固定交易 ID、root 账户、原 fees、唯一目标费项和 dry-run 状态；提供读取唯一目标枚举的方法。 |
| `qbit-core/src/main/java/com/qbit/openapi/domain/dto/ApiClientTransactionJobParam.java` | 新增任务模式、OSS 文件路径、单个 `ApiClientFeeEnum feeType` 和 `dryRun` 参数；默认预览，不写库。 |
| `qbit-core/src/main/java/com/qbit/openapi/domain/dto/ApiClientTransactionRawFeesDTO.java` | 新增 API 交易原始费用查询 DTO，保留数据库中的 fees JSON 文本用于基线对比和并发保护。 |
| `qbit-core/src/main/java/com/qbit/openapi/domain/enums/ApiClientTransactionJobMode.java` | 新增 `NORMAL`、`RESTORE_BASELINE`、`REPAIR_FEES` 三种任务模式。 |
| `qbit-core/src/main/java/com/qbit/openapi/domain/enums/ApiClientFeeEnum.java` | 增加由费项元数据查找其交易处理分组的方法；任务根据目标 `ApiClientFeeEnum` 动态选择分组，不在修复调用处固定 `CONSUMPTION_COLLECT`。 |
| `qbit-core/src/main/java/com/qbit/openapi/mapper/ApiClientTransactionMapper.java` | 增加按账户和卡交易 ID 批量读取原始 fees 的查询；增加以预期旧 fees 为条件的更新，避免并发覆盖。 |
| `qbit-core/src/main/java/com/qbit/openapi/service/ApiClientFeeJsonMerger.java` | 新增费用 JSON 合并器：只替换指定费项，保留其他费用、字段和扩展信息；目标费项本次未产出时写 0，避免旧金额残留。CB/FX 单项修复仍按共享的大小比较规则计算。 |
| `qbit-core/src/main/java/com/qbit/openapi/service/ApiClientTransactionFeeBaselineService.java` | 新增 OSS XLSX 读取、行校验、分块定位 API 交易、恢复基线和重算前校验。恢复只更新 `fees`，使用旧值比较保护；重算前要求数据库 fees 与 XLSX 基线一致。`dryRun` 缺省或为 null 时均只预览，只有显式 false 才写库。 |
| `qbit-core/src/main/java/com/qbit/openapi/service/ApiClientTransactionService.java` | 增加月结任务模式分发服务接口。 |
| `qbit-core/src/main/java/com/qbit/openapi/service/impl/ApiClientTransactionServiceImpl.java` | 实现三种模式分发。修复时从 XLSX 固定账户和交易范围，批量获取月结区间，并根据目标费项动态选择交易处理分组；普通同步路径维持原流程。 |
| `qbit-core/src/test/java/com/qbit/job/ApiClientTransactionFeeRepairJobTest.java` | 新增两个按任务入口执行的 SpringBootTest：恢复修复前基线、重算一个指定枚举费项。使用 OSS key / 费项 / dry-run 系统属性；默认预览，未提供 OSS key 时跳过。 |

以上新增和修改的关键入口、参数、恢复/重算步骤及费用合并规则均补充了 Javadoc 或行内注释。

## 任务参数示例

先预览恢复工作簿中的原始 fees：

```json
{
  "operationMode": "RESTORE_BASELINE",
  "restoreOssKey": "exports/all-transactions-before.xlsx",
  "dryRun": true
}
```

再预览单独重算 `crossBorderFee`：

```json
{
  "operationMode": "REPAIR_FEES",
  "restoreOssKey": "exports/all-transactions-before.xlsx",
  "feeType": "crossBorderFee",
  "dryRun": true
}
```

确认预览结果后，显式把 `dryRun` 改为 `false` 才会写入。单项修复要求数据库当前 fees 已与同一工作簿中的修复前 fees 匹配；不匹配时任务中止，避免在未恢复基线的数据上继续重算。

SpringBootTest 入口使用系统属性：

- `qbit.api.fee.baseline.oss-key`：OSS 工作簿对象路径或 HTTPS OSS 链接。
- `qbit.api.fee.repair.type`：费项 API 值，缺省 `crossBorderFee`。
- `qbit.api.fee.baseline.dry-run`：缺省 `true`；只有显式 `false` 才写库。

## 静态核对

- 当前分支：`jx/26/sprint-20/caas-fee`。
- `git diff --check`：通过。
- 按要求未编译、未运行测试；因此本记录不声明构建或测试通过。
- 本次记录覆盖的是 `qbit-assets` Java 改动；Node 项目不在这次文件清单内。



2163-1676=

https://qbit-develop.oss-accelerate.aliyuncs.com/open-api/4c5ee705-1db8-4729-8954-2bcb866b6fdd/1794282460531/all-transactions-before.xlsx



NORMAL	按原有定时任务逻辑正常同步手续费；未填模式时默认走这个	按普通任务的账户和日期参数筛选
RESTORE_BASELINE	把 XLSX 中的完整 fees 覆盖回数据库，不重新计算	XLSX 中的交易
REPAIR_FEES	重新计算目标费项，只替换这些费项；其他项保留数据库当前值	目前必须由 restoreOssKey 中的交易 ID 指定
这个的情况下

