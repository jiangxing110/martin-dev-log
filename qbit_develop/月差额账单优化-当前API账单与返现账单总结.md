# 月差额账单优化：当前 API 与返现账单总结

> 盘点分支：`jx/26/sprint-16/PD-1934/api-bill`
>
> 盘点日期：2026-09-05
>
> 本文只总结当前项目实现与本次需求的影响面，不包含代码改动方案的最终定稿。

## 一、需求范围

本次月差额账单优化涉及以下能力：

1. 月账单下载及账单明细中，隐藏金额为 0 的费用项。
2. 月差额计算纳入“毛利返现”（Revenue Sharing / Profit Cashback），并同步调整返现账单和返现明细。
3. Admin 客户账单查询返回账单更新时间，便于定位账单变更导致的差额订单重算。
4. 相关上下文还提出月账单增加 Active Card Details 明细页，以及直客并入差额后不再发送原直客邮件、改由差额邮件发送，并支持中英文；这两项属于关联范围，当前文档一并记录。

## 二、账单领域模型

### 2.1 API 客户月账单

主表为 `api_client_bill`，实体为：

`qbit-core/src/main/java/com/qbit/openapi/domain/entity/ApiClientBill.java`

关键字段：

| 字段 | 含义 |
| --- | --- |
| `id` | 账单 ID |
| `account_id` | API 客户账户 ID |
| `bill_month` | 账单月份 |
| `type` | `MonthlyStatement` 月账单，`Rebate` 返现账单 |
| `bill_history_config` | 账单生成时保存的历史配置；返现账单中保存返现明细汇总配置 |
| `is_latest` | 同一客户同一月份的最新账单标记 |
| `check_status` | 账单复核状态 |
| `create_time` | 账单创建时间 |
| `update_time` | 账单更新时间 |

月账单费用明细在 `api_client_bill_statement`，对应实体/VO 中的 `amount`、`adjust_amount`、`type`、`is_sum`、`provider` 等字段。计算金额时普遍使用：

`COALESCE(adjust_amount, amount)`

其中 `adjust_amount` 是调账后的有效金额。

### 2.2 返现数据模型

返现业务数据主表为 `cash_back_bonuses`，实体为：

`qbit-core/src/main/java/com/qbit/common_all/funding/domain/entity/CashBackBonus.java`

关键字段包括：`account_id`、`month`、`project`、`cash_back_amount`、`income`、`profit`、`cost`、`status`、`parent_id`。

当前返现项目枚举为：

`qbit-core/src/main/java/com/qbit/common_all/funding/enums/CashBackBonusProject.java`

已经存在毛利返现项目：

| 枚举 | value | 说明 |
| --- | --- | --- |
| `QUANTUM_CARD_QI_RS_PROFIT_CASH_BACK` | `QuantumCardQIRSProfitCashBack` | QI 卡 RS 毛利返现 |
| `QUANTUM_CARD_BZ_RS_PROFIT_CASH_BACK` | `QuantumCardBZRSProfitCashBack` | BZ 卡 RS 毛利返现 |

这两个项目已经被放入 `QUANTUM_ACCOUNT_CASH_BACK` 的子项目集合及 `QUANTUM_ACCOUNT_BASE_COLLECTION`，说明底层返现统计模型已有数据定义；当前主要缺口在账单导出/返现账单装配和客户展示链路是否完整覆盖。

另有 `collection_fee_settlement` 代收返现结算快照，使用 `MonthlyRebateStatementDTO` 查询，属于 OpenAPI V3 月代收返现账单，不应与 API 客户 `api_client_bill` 的 `Rebate` 账单混淆。

### 2.3 差额账单

差额表为 `api_client_netting_bill`，实体为：

`qbit-core/src/main/java/com/qbit/openapi/domain/entity/ApiClientNettingBill.java`

关键字段：

| 字段 | 含义 |
| --- | --- |
| `bill_id` | 月账单 ID |
| `rebate_id` | 返现账单 ID |
| `bill_amount` | 轧差时月账单金额 |
| `rebate_amount` | 轧差时返现金额 |
| `amount` | 最终需要付款或返现的差额 |
| `type` | `NettingDebit` 扣款、`NettingRebate` 返现、`NettingEqual` 相等结清 |
| `old_type` | 差额类型变更前的类型 |
| `deal_amount` | 已处理金额 |
| `status` | 差额处理状态 |

当前差额金额规则：

- 月账单金额 > 返现金额：`NettingDebit`，差额为月账单金额减返现金额。
- 返现金额 > 月账单金额：`NettingRebate`，差额为返现金额减月账单金额。
- 两者相等：`NettingEqual`。

返现总额在部分链路中从 `api_client_bill.bill_history_config` 中解析 `InitRebateCashbackInfo.amount` 后求和；因此毛利返现要参与差额，必须确保它进入返现账单配置/总额，同时明细导出也能识别对应项目。

## 三、当前 API 清单

### 3.1 Admin API 客户账单

Controller：

`qbit-core/src/main/java/com/qbit/admin/api/client/controller/QuantumCardApiCustomerController.java`

根路径：`api/admin/quantum/card/openapi/customer`

| 方法 | 路径 | 入参 | 返回 | 说明 |
| --- | --- | --- | --- | --- |
| POST | `/bill/list` | `QuantumCardApiCustomerBillDTO` | `Page<QuantumCardApiCustomerBillVO>` | Admin 客户月账单分页 |
| POST | `/bill/detail` | `ApiClientDetailDTO` | `ApiClientBillDetailVO` | 账单基本信息和费用明细 |
| POST | `/bill-statement/list` | `ApiBillStatementListDTO` | `List<ApiClientBillStatementVO>` | 账单明细列表 |
| POST | `/download/statement/pdf` | `DownloadApiBillPdfDTO` | 异步通知 | 月账单 PDF |
| POST | `/download/invoice/statement/pdf` | `DownloadApiBillPdfDTO` | 异步通知 | 根据账单类型生成 PDF |
| POST | `/download/statement/csv` | `DownloadApiBillPdfDTO` | 异步通知 | 账单明细 CSV |
| POST | `/download/statement/detail` | `DownloadApiBillPdfDTO` | 异步通知 | 明细压缩包 |
| POST | `/invoice/list` | `ApiClientInvoiceDTO` | `Page<ApiClientInvoiceVO>` | 发票/账单列表 |
| POST | `/netting/invoice/list` | `ApiClientNettingInvoiceDTO` | `Page<ApiClientNettingInvoiceVO>` | 差额账单列表 |
| POST | `/netting/invoice/details/list` | `ApiClientNettingInvoiceDetailsDTO` | `List<ApiClientInvoiceVO>` | 差额关联账单明细 |
| POST | `/rebate/debit` | `AdminRebateDTO` | 空 | Admin 发起返现 |
| POST | `/update/rebate/debit` | `AdminEditAndRebateDTO` | 空 | 更新金额并发起返现 |

Admin 月账单查询实现为 `QuantumCardApiCustomerServiceImpl.billList`，SQL 为：

`qbit-core/src/main/resources/mapper/quantum/card/ApiClientBillMapper.xml#billList`

查询仅取 `is_latest = true` 且 `type = 'MonthlyStatement'` 的账单。

### 3.2 内部/客户端月账单 API

Controller：

`qbit-core/src/main/java/com/qbit/admin/api/client/controller/InternalApiCustomerController.java`

根路径：`/qbit-assets`

| 方法 | 路径 | 入参 | 返回 | 说明 |
| --- | --- | --- | --- | --- |
| POST | `/monthly/fee/statement` | `MonthlyFeeStatementDTO` | `List<MonthlyFeeAndMonthlyStatementVO>` | 客户月收费账单 |
| POST | `/monthly/rebate/statement` | `MonthlyRebateStatementDTO` | `MonthlyRebateStatementPageVO` | 代收返现结算账单 |
| POST | `/download/statement` | `DownloadStatementDTO` | 文件 URL | 根据 `billType` 下载月账单或返现账单 |

实现为 `StatementServiceImpl`：

- 月收费账单从 `api_client_bill` 查询，并从 `api_client_bill_statement` 汇总总额。
- 月代收返现账单从 `collection_fee_settlement` 查询，仅返回 `SETTLED` 记录。
- 下载 `MonthlyStatement` 时读取/生成月账单 PDF；下载 `Rebate` 时读取已结算返现明细文件。

### 3.3 返现 Admin API

Controller：

`qbit-core/src/main/java/com/qbit/admin/funding/controller/AdminCashBackBonusController.java`

根路径：`/api/admin/account/cash-back-bonuses`

主要接口：新增返现、编辑/审核、分页查询、导出返现明细、下载返现明细 CSV、导出客户月度返现 Invoice。

返现 Invoice 生成最终调用 `CashBackBonusService.exportCashBackBonusesInvoiceV2`。API 客户返现账单 PDF 在 `ApiClientBillServiceImpl.generatorStatementPdf` 中按 `bill.type = Rebate` 转入该服务。

## 四、当前实现与需求的对应关系

### 4.1 隐藏 0 费用项

当前已存在部分过滤：

- `ApiClientBillStatementMapper.xml#apiBillStatementList` 查询条件包含 `amount > 0`，因此 Admin 账单明细列表已经不返回原始金额为 0 的明细。
- 汇总金额使用 `COALESCE(adjust_amount, amount)`，但当前 SQL 汇总不以金额大于 0 作为展示过滤。
- PDF 生成使用 `apiBillStatementIsSumList`，该查询当前没有统一的 `amount > 0` 条件；零费用项是否展示取决于后续模板数据处理。

结论：本项不能只改 Admin 明细 API，应统一检查月账单 PDF、CSV/压缩包、客户端账单明细和 Invoice 模板。过滤口径应以“最终有效金额（优先 `adjust_amount`，否则 `amount`）为 0”判断，并保留总额计算口径一致性。

### 4.2 毛利返现纳入返现账单和差额

当前已具备：

- `CashBackBonusProject` 中已有 QI/BZ RS 毛利返现枚举。
- 毛利返现已经列入量子账户返现父子项目集合。
- API 返现账单总额可从 `bill_history_config` 中解析多条 `InitRebateCashbackInfo` 并求和。
- 差额服务会读取 `Rebate` 账单总额，并写入 `api_client_netting_bill.rebate_amount` 后计算差额类型和金额。

需要重点核对/补齐：

1. 返现账单初始化时是否查询并写入 QI/BZ RS 毛利返现记录。
2. `InitRebateCashbackInfo` 是否携带毛利返现项目、金额、返现记录 ID 等字段，确保总额与明细可追溯。
3. `CashBackBonusService` 的 Invoice 汇总、PDF 模板、明细导出是否只处理消费返现、开卡返现、加密资产交易返现三类，是否需要新增第 4 个 sheet：`Infinity Card Revenue Sharing Rebate`。
4. 返现账单金额修改或重新生成后，是否同步更新差额订单的 `rebate_amount`、`amount`、`type`、`old_type`，并保留操作日志及幂等行为。
5. 直客返现账单与 API 客户轧差返现的邮件通知分支是否会重复发送；并确认差额成功/失败通知的中英文模板。

### 4.3 Admin 客户账单更新时间

当前分支已经具备该字段：

- `ApiClientBillMapper.xml#billList` 已查询 `acb.update_time`。
- `QuantumCardApiCustomerBillVO` 已有 `Date updateTime` 字段，并使用时间戳序列化。
- `ApiClientBillMonthBO` 也已有“更新时间”导出字段。

结论：如果前端实际未收到该字段，应优先核对接口实际返回、网关/前端 DTO 映射和缓存，而不是再次新增后端字段。需要区分：

- 账单更新时间：`api_client_bill.update_time`，适合 Admin 客户账单列表展示。
- 账单明细调账更新时间：`api_client_bill_statement.update_time`，当前明细 VO 已返回该字段。
- 差额订单更新时间：`api_client_netting_bill.update_time`，用于判断差额订单自身何时被重算/修改。

若业务要记录“账单变更导致差额订单时间修改过”，仅展示月账单更新时间可能不足，建议同时确认差额列表是否需要返回差额订单 `updateTime`，以及账单更新后是否一定触发差额重算并写操作日志。

## 五、建议的后续核对顺序

1. 先用一条包含 QI/BZ RS 毛利返现的真实账户月份，核对 `cash_back_bonuses`、`api_client_bill.bill_history_config`、返现 Invoice 明细和 `api_client_netting_bill` 四处金额。
2. 对同一账单分别验证 Admin 明细接口、客户端月账单接口、PDF、CSV/ZIP，确认 0 费用项过滤一致。
3. 修改已复核月账单后，验证差额订单金额、类型、更新时间、邮件分支和操作日志。
4. 最后检查前端使用的 Admin 账单列表响应是否确实读取 `updateTime`，并确认差额订单是否需要新增更新时间字段。

## 六、核心代码位置索引

| 能力 | 代码位置 |
| --- | --- |
| Admin API 客户账单入口 | `qbit-core/src/main/java/com/qbit/admin/api/client/controller/QuantumCardApiCustomerController.java` |
| 内部月账单/返现账单入口 | `qbit-core/src/main/java/com/qbit/admin/api/client/controller/InternalApiCustomerController.java` |
| Admin 账单查询实现 | `qbit-core/src/main/java/com/qbit/common_all/api/client/bill/service/impl/QuantumCardApiCustomerServiceImpl.java` |
| 月账单/返现账单服务 | `qbit-core/src/main/java/com/qbit/openapi/v3/statement/service/impl/StatementServiceImpl.java` |
| API 账单生成、PDF、差额前置数据 | `qbit-core/src/main/java/com/qbit/common_all/api/client/bill/service/impl/ApiClientBillServiceImpl.java` |
| 账单明细编辑与汇总 | `qbit-core/src/main/java/com/qbit/common_all/api/client/bill/service/impl/ApiClientBillStatementServiceImpl.java` |
| 差额账单计算 | `qbit-core/src/main/java/com/qbit/common_all/api/client/bill/service/impl/ApiClientNettingBillServiceImpl.java` |
| 返现账单/明细导出 | `qbit-core/src/main/java/com/qbit/common_all/funding/service/impl/CashBackBonusServiceImpl.java` |
| API 账单查询 SQL | `qbit-core/src/main/resources/mapper/quantum/card/ApiClientBillMapper.xml` |
| API 账单明细 SQL | `qbit-core/src/main/resources/mapper/quantum/card/ApiClientBillStatementMapper.xml` |
| 代收返现账单 SQL | `qbit-core/src/main/resources/mapper/CollectionFeeSettlementMapper.xml` |
