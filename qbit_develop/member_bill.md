# 月结账单、返现账单与轧差处理说明：API 客户 / 直客

> 梳理日期：2026-10-15  
> 依据：`qbit-assets` 当前代码。XXL-JOB 实际调度时间以运行环境配置为准。

## 1. 核心概念

月度轧差把同一账户、同一 `billMonth` 下的月结账单和返现账单放在一起结算。计算方式为：

```text
轧差净额 N = 月结应收金额 B - 返现金额 R
```

- `N > 0`：返现抵减月结应收后仍有欠款，生成 `NettingDebit`，扣除剩余金额。
- `N = 0`：月结应收和返现正好抵消，生成 `NettingEqual`，两边都记偏移并结清。
- `N < 0`：返现金额超过月结应收，生成 `NettingRebate`，返还超出部分 `R - B`。

账单配对键是 `accountId + billMonth`。返现单的创建时间本身不是配对条件；但创建时间会影响某些直客手动返现最终被分到哪个 `billMonth`。即时转账或状态为 `NO_NEED` 的返现不进入 Rebate 账单，也就不参加账单轧差。

## 2. API 客户月结账单：每一步的作用

1. **确定账期。** 定时任务 `quantum_card_api_customer_bill` 默认取 GMT+8 上一个自然月。账期决定本次汇总哪些费用，以及月结账单的 `billMonth`。
2. **筛选 API 客户。** 找出该账期符合条件的 API 客户，并排除该账户该月已经生成过月结账单的情形，避免重复出单。
3. **准备计费配置。** 计算适用优惠和折扣，并按批次处理账户（代码每批最多 100 个），控制单次聚合规模。
4. **汇总费用。** 同时兼容历史 API 费用来源 `api_client_transaction` 和新费率来源 `account_fee_transaction`，再整理 provider 费用汇总/明细、营收补差、身份验证等账单项目。
5. **计算附加项目。** 根据账户配置计算低消/MVC、拒付罚款及其他附加费，得到该账户本月应收金额。
6. **保存月结单。** 逐账户事务写入 `MonthlyStatement` 主记录和费用明细。单个账户处理失败会记录失败信息并继续处理其他账户。
7. **设置账单状态。** 总应收大于 0 时账单为 `Pending`；总应收小于等于 0 时为 `FREE`。`FREE` 表示没有待收金额，不代表该账期不存在账单记录。
8. **复核并生成文件。** API 月结单需要后台复核，复核完成后 `checkStatus=Done`；生成账单明细 ZIP，并在通知流程中生成或取得 PDF。
9. **通知及后续结算。** 发送月结通知。API 普通线上扣款使用独立的 API 扣款查询；进入轧差的账单则等待同账户、同 `billMonth` 的返现单一起计算，不能把 Rebate 当作普通 API 月结扣款记录。

## 3. 直客月结账单：每一步的作用

1. **确定账期。** 定时任务 `quantum_card_direct_customer_bill` 未传月份时取上一个自然月；传入月份时用于指定月份的补账。指定账期允许补生成过去月份的账单。
2. **筛选直客账户。** 取符合条件的直客账户，排除该账期属于 API 客户的账户，并排除已经有该月账单的账户，避免类型串账和重复出单。
3. **汇总直客费用。** 汇总新费率流水 `account_fee_transaction`；并行汇总 RS 营收补差和活跃卡月费。直客账单不读取 `api_client_transaction` 的历史 API 费用。
4. **整理账单明细。** 归一 provider 汇总行和明细行，确保费用按账单项目落入月结单明细。
5. **写入月结账单。** 保存 `MonthlyStatement` 和费用明细，并固化 `customerType=DIRECT`，后续扣款/返现分支据此识别直客。
6. **设置金额状态。** 总应收大于 0 时为 `Pending`；小于等于 0 时为 `FREE`。
7. **自动复核。** 直客月结单生成时会自动设 `checkStatus=Done`，不走 API 月结单的人工复核步骤。
8. **生成文件并通知。** 非 `FREE` 账单生成 PDF 和 ZIP；`FREE` 账单跳过文件生成。之后发送月结通知。
9. **等待轧差结算。** 直客月结单不进入普通 API 自动扣款查询。结算时与同账户、同 `billMonth` 的返现账单配对，再按净额走扣款、抵消或返现分支。

## 4. 返现账单：从返现记录到 Rebate 的处理步骤

1. **确认返现已完成。** 返现状态需要达到 `Closed`。未关闭的返现记录不进入返现账单。
2. **判断结算路径。** 审核业务结合客户类型、返现来源、项目、金额和时间截止规则，决定走“返现账单”还是“即时转账/跳过账单”。即时转账或 `NO_NEED` 不生成用于轧差的 Rebate。
3. **标记账单处理状态。** 走账单路径的返现记录进入 `GENERATING` 等账单处理状态，方便事件处理器或历史补生成任务筛选。
4. **选择账单生成入口。** 一种入口是在返现状态关闭后触发 `CashBackBonusListener`，按账户和目标账期收集返现；另一种入口是 XXL-JOB `create_rebate_bill` / `re_create_rebate_bill` 对历史返现补生成。历史任务筛选 `Closed` 且 `bill_status` 为 `GENERATING` 或 `GENERATED` 的记录。
5. **确定返现账期。** 历史补生成通常按 `CashBackBonus.month` 分组并作为目标 `billMonth`，所以任务在 10 月执行并不自动把 8 月记录改成 10 月。特定直客手动事件路径会按创建时间推导月份，详见第 7 节。
6. **生成返现快照。** 按账户和目标月份组织返现明细，只保留符合条件的 Closed 记录，构造返现账单初始化数据。快照记录返现 ID、来源交易、状态、钱包类型、金额、项目和月份。
7. **创建或更新 Rebate。** 创建新的返现账单，或按对应更新规则把新明细加入已有账单。金额从 `bill_history_config` 的快照金额汇总，不是从月结账单费用明细计算。直客分支会合并已有快照和新增返现后重新生成明细。
8. **固化客户类型和状态。** 返现账单客户类型在创建时保存为 `API` 或 `DIRECT`；状态为 `Pending`，复核状态为 `Done`。
9. **生成返现明细文件并回写状态。** 按项目生成对应详情文件，并将关联返现记录的 `bill_status` 推进到 `GENERATED` / `DETAIL_GENERATED` 等后续状态。
10. **等待轧差。** 返现单只有在账户和 `billMonth` 都与月结单匹配、且满足轧差筛选状态时，才会抵减该月的应收金额。

支持月结返现处理的项目包括加密资产交易返现、量子卡开卡返现、量子账户返现及部分 RS 返现项目。RS 返现母单金额已包含子单金额；子单仅作为明细标记，金额置零，避免重复计入返现总额。

## 5. API 与直客返现的差异

| 处理点 | API 客户 | 直客 |
| --- | --- | --- |
| 返现账单客户类型 | 创建时固化为 `API` | 创建时固化为 `DIRECT` |
| 返现账单复核 | `Pending`，`checkStatus=Done` | `Pending`，`checkStatus=Done` |
| 截止规则关注点 | 指定 API 手动返现项目按 `bonus.month` 计算次月 20 日截止点 | 手动返现按创建时间；指定定时返现项目按审核完成时间判断 20 日节点 |
| 手动返现账期 | 通常按返现记录所属月份；超期的特定记录可能转即时路径 | 指定项目的手动账单返现按创建时间推导目标账期，截止后可能转即时路径 |
| 已有返现账单增加明细 | 按既有返现快照处理逻辑更新 | 直客分支会合并已有快照与新增返现，再重新生成明细 |

## 6. 月结账单与返现账单如何轧差：每一步的作用

1. **确定处理范围。** 轧差任务/扣款入口确定本次要处理的账户和账期。金额和账期必须能落到具体的 `accountId + billMonth`。
2. **查询候选账单。** 从 `api_client_bill` 读取最新、未删除且未结清的账单，并按账户和账期分组。只有返现单、没有对应月结单的组不会建立轧差单。
3. **等待账单复核完成。** 检查组内月结单和返现单的 `checkStatus`。未全部为 `Done` 时先跳过，待复核完成后再运行，避免用未确认金额结算。
4. **创建或复用轧差单。** 没有已有轧差单时创建 `Pending` 单并记录关联月结 `billId` / 返现 `rebateId`。已有单时复用当前状态；特定直客 `Pending` 轧差单会重新读取同组账单并刷新待处理金额。已经部分或全部结清的记录不会由这条逻辑自动重开。
5. **计算净额。** 汇总月结应收 `B`，汇总返现快照金额 `R`，计算 `N=B-R`。这是返现抵扣月结费用的核心步骤；比较的是最终账期，不是单据创建月份。
6. **净额为零时抵消。** 创建 `NettingEqual`，分别记录月结应收偏移和返现偏移，然后把轧差单及关联账单置为 `Settled`。
7. **净额大于零时扣款。** 创建 `NettingDebit`。API 客户走 API 多钱包扣款路径；直客走 Qbit Card USD 钱包路径，代码允许直客余额扣至负数。全额成功后结清；部分成功记为 `PartSettled` 并保留剩余金额；失败时保留未结状态，记录并通知/重试。
8. **净额小于零时返还超额。** 创建 `NettingRebate`，返还金额为 `R-B`。通常使用 QBWallet；InfinityLaunch 使用 VirtualUSD。成功时写返现流水、结清轧差单及关联账单并发送成功通知；账户冻结、钱包缺失或执行失败时保留失败记录并通知处理。
9. **后续重试只处理未结部分。** 部分扣款和失败返现保留状态及金额，供后续重试或人工处理；不能把已结算账单误认为尚未处理。

## 7. 特殊时间节点和账期归属判断

时间节点会决定一条返现是进入账单轧差、即时转账，还是不进入返现账单。判断前先确认返现客户类型、返现来源/项目和使用的入口，再应用对应时间规则；不能把所有返现都套同一个 20 日规则。

### 7.1 直客手动返现：每月 20 日 00:00 切换

- 代码按 `CashBackBonus.createTime` 的上海时区日期判断，日号小于 20 才在账单返现截止前。
- 创建日期为当月 1–19 日的指定直客手动返现，可走返现账单路径；`getManualRebateBillMonth(createTime)` 通常把账期归到创建月份的上一个月。例如 10 月 1–19 日创建，对应目标账期通常为 9 月。
- 从 20 日 00:00 起，不再走这个手动返现账单路径；符合条件的记录走即时转账 / `NO_NEED`，因此不会生成用于轧差的返现账单。
- 这里看的是返现创建时间。若 10 月才新建一条手动返现，不能只因业务描述写着“8 月返现”就认定它属于 8 月账期；应查看最终 `Rebate.billMonth` 和快照。

### 7.2 直客指定定时返现：看审核完成时间

- 指定返现项目按 `approvalTime` 判断，而不是只看记录创建时间。
- 审核时间早于当月 20 日 00:00 的记录可以继续走账单返现后置处理。
- 审核时间到达或晚于当月 20 日 00:00 的指定项目会被设为 `NO_NEED`，不进入返现账单轧差。

### 7.3 API 手动返现：按返现月份计算次月 20 日

- 对应 API 手动返现项目用 `bonus.month` 计算 `M+1 月 20 日 00:00` 截止点。
- 代码以 `now.isAfter(deadline)` 判断超时，因此严格晚于截止点才算超时；恰好等于 `20 日 00:00` 时 `isAfter` 为 false，仍未判定超时。
- 未超过时可保留账单/轧差路径；超时后的指定情形可能改走即时转账。具体仍受来源、金额、项目和客户类型条件限制。

### 7.4 月结复核相关节点：次月 20 日 10:00

- `BILL_CHECK_DEADLINE` 配置为账单月 `M+1` 月 20 日 10:00。
- 需要注意方法名和实际判断方向不一致：`isCheckDeadlineExceeded()` 实际返回 `now.isBefore(deadline)`，调用方在返回 true 时发送 webhook。按当前代码，webhook 判断发生在 deadline 之前；不能只根据方法名理解为“超过截止时间才发送”。

### 7.5 轧差结算窗口：源码注释与日期运算可能相差一天

- `initApiClientNettingBill()` 先把 `billMonth` 加一个月并取当月 1 日零点，再调用 `offsetDay(..., 20)` 作为窗口开始时间；结束时间为开始时间再加一个月。
- 按 Hutool“加 20 天”的运算，`billMonth=2026-08` 得到的窗口是 `2026-09-21 00:00` 至 `2026-10-21 00:00`。源码注释描述为“20 号凌晨”，可能与实际日期计算相差一天。
- 判断某张轧差单实际覆盖时间时，应以数据库 `start_time`、`end_time` 或运行时计算值为准。

### 7.6 提醒账单的日历触发点

- `dealBillMonth()` 在当前月 20 日后第 7 天触发时，提醒上一个自然月账单。
- 在上月 20 日后第 14、21、28 天触发且仍早于本月 20 日时，提醒上上个自然月账单。
- 例如 10 月 27 日对应提醒 9 月账单；10 月 4、11、18 日对应提醒 8 月账单。
- 普通 API 扣款通知还有独立的硬编码截止判断；轧差通知调用相同账期推导，但自身没有该停止判断。

## 8. 场景示例：10 月处理 8 月返现

假设账户 A 的 8 月月结应收 `B=120 USD`，10 月补生成返现单，返现快照 `R=35 USD`：

1. 如果返现记录的 `month=2026-08`，通过 `create_rebate_bill` / `re_create_rebate_bill` 历史补生成，任务按返现记录月份分组并写入 `billMonth=2026-08`。
2. 轧差按账户 A 和 `billMonth=2026-08` 找到月结单和返现单，计算 `120-35=85 USD`。
3. 净额为正，生成 `NettingDebit`，待扣 85 USD。前提是相关账单满足最新、未结清、复核完成等筛选条件。
4. 如果最终返现单的 `billMonth=2026-09`，则不能抵减 8 月月结单。
5. 如果 8 月轧差已经 `Settled` 或 `PartSettled`，不会因新增返现而由直客 Pending 刷新逻辑自动重开。

若是 10 月新发起的直客手动返现，则先按创建时间判断：10 月 1–19 日的指定项目通常归属 9 月；10 月 20 日 00:00 起符合条件的项目可能转即时路径。不要把“业务上想抵 8 月”当作系统账期；以最终 `Rebate.billMonth`、`bill_history_config` 和轧差状态为准。

## 9. 当前代码中的普通 API 扣款时间开关

普通 API 自动扣款在 `ApiClientDebitRecordServiceImpl.debit()` 中有硬编码截止时间 `2026-03-20 23:59:59`；月结扣款提醒 `noticeCustomerToDebit()` 有 `2026-04-21 23:59:59` 截止判断。按本文件梳理日期 2026-10-15，这两个普通扣款/提醒方法会提前返回。轧差入口是独立任务/服务，需要结合 XXL-JOB 实际调度配置判断是否执行。

## 10. 排查某张返现是否抵减指定月份

建议按以下顺序核对，避免只看返现创建时间得出结论：

1. 查 `CashBackBonus`：确认 `status` 是否 `Closed`、`bill_status` 是否进入账单生成状态、记录的 `month`、创建时间、审核时间、客户类型、返现来源和项目。
2. 查最终 `Rebate`：确认 `customerType`、`billMonth`、`status`、`checkStatus`，确认目标账期是否真的是月结账单所属月份。
3. 查 `bill_history_config`：核对返现快照金额、`cashBackId` 和明细，确认汇总金额 `R` 与预期相符；留意 RS 子单金额置零规则。
4. 查同账户同 `billMonth` 的 `MonthlyStatement`：核对账单是否存在、金额 `B`、是否最新、是否已删除、是否已结清、复核是否 `Done`。
5. 查对应 `api_client_netting_bill`：确认是否创建轧差单、净额类型和金额、关联账单 ID、结算状态及失败原因。
6. 如果 10 月处理 8 月数据，确认走的是历史月份补生成入口还是 10 月新建的直客手动事件路径；前者通常按返现 `month`，后者可能由创建时间重新推导账期。

## 11. 关键代码位置

| 流程 | 文件 |
| --- | --- |
| API、直客月结和返现 XXL-JOB | `qbit-core/src/main/java/com/qbit/job/qbitcard/ApiCustomerJob.java` |
| 月结账单生成、通知、返现账单创建和汇总 | `qbit-core/src/main/java/com/qbit/common_all/api/client/bill/service/impl/ApiClientBillServiceImpl.java` |
| API 月结费用聚合 | `qbit-core/src/main/java/com/qbit/openapi/service/impl/ApiClientTransactionServiceImpl.java` |
| 返现审核、即时/账单路径判断 | `qbit-core/src/main/java/com/qbit/common_all/funding/service/impl/CashBackBonusServiceImpl.java` |
| 返现状态事件、账期推导、返现账单后置处理 | `qbit-core/src/main/java/com/qbit/common_all/funding/listener/CashBackBonusListener.java` |
| 定时/历史返现记录筛选 | `qbit-core/src/main/resources/mapper/slave/CashBackBonusSlaveMapper.xml` |
| 轧差初始化、配对、金额分类 | `qbit-core/src/main/java/com/qbit/common_all/api/client/bill/service/impl/ApiClientNettingBillServiceImpl.java` |
| 轧差扣款、返现、金额偏移和账单状态更新 | `qbit-core/src/main/java/com/qbit/common_all/api/client/bill/service/impl/ApiClientDebitRecordServiceImpl.java` |
| 返现与复核截止日、手动返现账期推导 | `qbit-core/src/main/java/com/qbit/common/utils/DateUtil.java` |
| 自动 API 扣款筛选、轧差账单查询 | `qbit-core/src/main/resources/mapper/quantum/card/ApiClientBillMapper.xml` |
