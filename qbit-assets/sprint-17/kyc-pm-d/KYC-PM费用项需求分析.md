# KYC-PM 费用项需求分析

## 1. 分析结论

本需求的目标不是单纯给 `idv_channel_request_record` 增加一个字段，而是建立一条可审计的 KYC 计费链路：

```text
客户调用 KYC / Cardholder / 实体卡 URL
        ↓
按现有唯一性规则决定是否形成一次计费事件
        ↓
idv_channel_request_record.checkType
        ↓
按客户、自然月、checkType 分类统计次数
        ↓
分别读取 KYC Verification Fee / KYC-PM Verification Fee
        ↓
生成月结账单费用项
```

账单侧最终需要支持：

```text
月度 KYC 费用
= THIRD_PARTY 次数 × KYC Verification Fee
  + SELF_CHECK 次数 × KYC-PM Verification Fee
```

默认的 KYC-PM 费率为 `0.85 USD/次`。正常 KYC 客户仍按原 KYC Verification Fee 计费；只有已开通 KYC-PM 模式的客户，其客户提交行为才按 SELF_CHECK 费率计费。

## 2. 需求范围拆解

| 领域 | 必须完成的事情 | 账单侧关注点 |
|---|---|---|
| 记录模型 | `idv_channel_request_record` 增加 `"checkType"` | 账单查询必须能区分两种计费类型 |
| 记录生产 | KYC-PM 客户的有效客户提交行为写入 SELF_CHECK | 必须和现有唯一性/幂等规则保持一致 |
| 抽查 | KYC-PM 后续自动抽查调用三方，但不新增统计记录 | 不能把抽查次数计入客户 KYC 费用 |
| 历史数据 | 旧数据按 THIRD_PARTY 解释 | 查询应兼容 NULL，最好通过迁移回填 |
| 费率配置 | 新老账户费率都增加 KYC-PM 费用项，默认 0.85 USD/次 | 需要新增可配置的费率类型，并纳入账户级/默认账户级兜底 |
| 月结账单 | 按自然月统计两种 checkType，并分别计价 | 需要明确是展示为两行还是合并为一行 |
| 账单展示 | 费用名称、英文名称、说明、PDF/接口返回保持一致 | 费用枚举、VO、模板、汇总查询要同步 |

## 3. 当前代码实现摸底

### 3.1 现有身份验证月结逻辑

当前月账单入口在：

- `qbit-core/src/main/java/com/qbit/openapi/service/impl/ApiClientTransactionServiceImpl.java`

现有逻辑大致是：

1. `getApiClientMonthlySettlementFee` 异步查询各类月账单数据。
2. 通过 `identityVerificationMap(filter)` 查询身份验证次数趋势。
3. 通过 `AccountFeeService.identityVerificationFee(..., KYC_INTERFACE_CALL_FEE_CAAS)` 获取账户费率。
4. 次数乘以单价，向下保留 2 位小数。
5. 以 `ApiClientFeeEnum.IDENTITY_VERIFICATION` 作为月账单费用项输出。

当前身份验证统计 SQL 在：

- `qbit-core/src/main/resources/mapper/ApiInterfaceLog.xml`

查询条件目前包括：

- `delete_time IS NULL`
- `request_status = 'Success'`
- `request_channel IN ('sumsub', 'plaid')`
- `type != 'CDD'`
- 按 `request_time` 的月份、账户关系的 `root_id` 聚合

因此，现有逻辑只有一个身份验证次数和一个身份验证费率，无法直接实现本需求的双费率公式。

### 3.2 现有费用项结构

相关枚举：

- `qbit-core/src/main/java/com/qbit/openapi/domain/enums/ApiClientFeeEnum.java`
- `qbit-core/src/main/java/com/qbit/openapi/domain/enums/ApiClientMonthFeeEnum.java`
- `qbit-core/src/main/java/com/qbit/common/enums/AccountFeeType.java`

现有 `IDENTITY_VERIFICATION` 已被归入：

- 默认月账单费用项集合；
- 不区分渠道的费用项集合；
- “实时产生、月结收取”的费用项集合。

这说明新费用应继续沿用现有“月账单费用项”的架构，而不是另起一套账单流程。

### 3.3 现有账单落库和展示

月账单明细表相关逻辑：

- `qbit-core/src/main/resources/mapper/quantum/card/ApiClientBillStatementMapper.xml`

当前汇总查询已经对 `identityVerification` 做了单独聚合，并输出 `identityVerificationFee`。新增费用后，需要同步确认：

- 账单明细是否存储费用类型枚举值；
- 汇总 VO 是否需要新增字段；
- 管理端/开放接口是否依赖固定字段；
- PDF 模板是否存在身份验证费用的固定文案或字段。

## 4. 账单侧建议方案

### 4.1 费用类型设计

建议保留现有 `identityVerification` 作为 KYC Verification Fee，新增独立费用类型表示 KYC-PM Verification Fee，例如：

- `identityVerification`：KYC Verification Fee，统计 `THIRD_PARTY`；
- `kycPmVerification`：KYC-PM Verification Fee，统计 `SELF_CHECK`。

具体枚举值应以账户费率合集中的既有命名为准，不能在代码中自行创造与费率后台不一致的名称。

建议不要把两种金额强行合并成一个不可拆分的账单行。拆成两行的好处是：

- 客户能够看出普通三方校验和 KYC-PM 自检分别发生了多少次；
- 费率调整和账单复核更容易；
- 可与 `checkType` 一一对应，方便审计和排查。

如果产品明确要求前台只展示一个“身份托管验证费”总额，则内部仍建议保留两种费用的计算结果，展示层再提供合计，避免丢失核对依据。

### 4.2 计费查询设计

建议将现有 `identityVerificationTrends` 改造成或新增一个按 `accountId + month + checkType` 聚合的查询，SQL 形态应接近：

```sql
SELECT
    root_id AS account_id,
    TO_CHAR(request_time, 'YYYY-MM-01') AS month,
    COALESCE(checkType, 'THIRD_PARTY') AS check_type,
    COUNT(*) AS count
FROM idv_channel_request_record
WHERE delete_time IS NULL
  AND request_status = 'Success'
  AND request_channel IN ('sumsub', 'plaid')
  AND type != 'CDD'
  AND request_time >= :month_start
  AND request_time < :next_month_start
GROUP BY root_id, month, COALESCE(checkType, 'THIRD_PARTY')
```

关键点：

1. 历史 `checkType IS NULL` 必须按 THIRD_PARTY 处理。
2. 自然月应使用左闭右开区间 `[月初, 下月月初)`，避免 `<= 月末 23:59:59` 的边界问题。
3. 账单统计必须明确使用 `request_time` 还是 `create_time`。需求写的是上送/校验发生时间，建议使用 `request_time`，并与现有身份验证趋势保持一致。
4. 查询应直接按账户关系的根账户口径聚合，避免 Service 层二次聚合造成客户账单错位。
5. 若使用 MyBatis-Plus 枚举映射，SQL 中应使用数据库真实存储值 `THIRD_PARTY` / `SELF_CHECK`。

### 4.3 费率读取设计

现有费率读取使用 `AccountFeeService.identityVerificationFee`，并支持客户账户费率找不到时回退默认账户。

建议：

- 普通 KYC 继续读取现有 KYC Verification Fee 对应的 `AccountFeeType`；
- KYC-PM 新增独立 `AccountFeeType`，纳入新老账户费率和默认账户费率列表；
- 新费率的单位、固定值限制、有效期和精度沿用账户费率合集定义；
- 默认费率 `0.85` 不建议硬编码在账单 Service 中，应通过默认账户费率配置落库；
- 费率为空时要有明确处理策略，不能出现 `accountFees.get(key)` 空指针导致整个月账单生成失败。

### 4.4 月账单组装设计

在 `getApiClientMonthlySettlementFee` 中建议把当前单个 `identityVerificationMap` 改成两类金额，或改成按费用类型组织的结果：

```text
accountId + month
  ├─ THIRD_PARTY count × KYC Verification Fee
  └─ SELF_CHECK  count × KYC-PM Verification Fee
```

组装时需同步处理：

- 有次数时输出对应费用金额；
- 无次数时是否输出 0 元占位费用项，保持当前账单结构一致；
- 两种费用是否都标记 `isSum = true`；
- 费用项是否进入 `DEFAULT_TYPE`，避免被残余费用逻辑补出重复行；
- `closedFees`、`realTimeButMonthlyFees` 和 `NO_DIFFERENCES_PROVIDER` 是否需要加入新费用项；
- 账单总额计算不能将该费用误认为实时已收费用。

## 5. 与 PR #7494 / 底层实现的依赖核对

参考：<https://github.com/PalmDrive/qbit-assets/pull/7494>

本地仓库可见对应先行提交：`5515d68343`，提交内容为“新增收费项 KYC-PM——idv 落库”。该提交涉及：

- `IdvChannelRequestRecord` 增加 `checkType`；
- 新增 `IdvCheckTypeEnum`；
- Cardholder KYC 流程增加是否记录 IDV 请求的参数；
- 自动抽查分支绕过 `IdvChannelService`，直接调用三方 SDK；
- NoKYC/直通场景增加直接成功记录。

账单开发前需要重点确认以下问题：

### 5.1 `checkType` 写入语义存在风险

先行提交中 `IdvChannelService.idvBySumsub` 写入的是 `SELF_CHECK`。但该方法本身代表调用 Sumsub 的三方校验入口；按需求，真正送三方的校验应计入 THIRD_PARTY，客户自检提交才应计入 SELF_CHECK。

同时，NoKYC 直通场景的 `saveDirectSuccessRecord` 写入的是 THIRD_PARTY，而需求描述的是客户自有 KYC 结果上送，应核对该场景是否应计入 SELF_CHECK。

如果这些语义不修正，账单即使按 `checkType` 正确统计，金额也会被分配到错误费率。

### 5.2 覆盖范围可能不完整

需求明确包含：

- KYC 接口；
- cardholder 接口；
- 实体卡 URL 接口。

先行提交主要改动了 Cardholder 流程。需要确认 KYC 和实体卡 URL 的入口是否也已落 SELF_CHECK 记录，以及三类入口的唯一性规则是否一致。账单侧不能通过补统计逻辑来弥补底层漏记，否则会出现无法审计的“推算次数”。

### 5.3 自动抽查不应产生客户计费记录

自动抽查调用三方时应满足：

- 业务校验可以正常执行；
- 不新增 `idv_channel_request_record` 计费记录；
- 不影响原有 KYC 状态和回调；
- 失败重试不会产生计费记录。

建议在底层增加明确的测试断言：初始客户提交产生一条 SELF_CHECK；自动抽查执行前后记录数不变；正常非 KYC-PM 客户送三方产生 THIRD_PARTY。

## 6. 数据库和历史数据方案

建议新增数据库迁移脚本：

```sql
ALTER TABLE idv_channel_request_record
    ADD COLUMN IF NOT EXISTS "checkType" VARCHAR(32) DEFAULT 'THIRD_PARTY';

UPDATE idv_channel_request_record
SET "checkType" = 'THIRD_PARTY'
WHERE "checkType" IS NULL;
```

是否增加 `NOT NULL` 需要结合线上历史数据和写入兼容性决定。更稳妥的上线顺序是：先加字段和默认值，再回填历史数据，验证无 NULL 后再评估是否加非空约束。

需要确认：

- 生产表是否存在双引号驼峰字段规范；
- 数据库迁移脚本的实际执行目录和发布方式；
- 是否有 ODS/数仓同步需要同步字段；
- 是否需要给 `(account_id, request_time, checkType)` 或相关查询增加索引；
- `request_status`、`request_channel`、`type` 的现有索引是否足够支撑月初批量账单查询。

## 7. 任务拆分建议

### A. 底层记录链路

- 完成字段和枚举落库；
- 梳理 KYC、Cardholder、实体卡 URL 三个入口；
- 复用现有唯一性规则；
- 正确区分客户自检与真正三方校验；
- 自动抽查不落计费记录；
- 补充非 KYC-PM、KYC-PM 首次提交、重复提交、自动抽查测试。

### B. 账单统计

- Mapper 增加按 `checkType` 分类的月度统计；
- 兼容历史 NULL 按 THIRD_PARTY 统计；
- Service 读取两种费率并计算两种金额；
- 防止账户费率缺失导致账单任务整体失败；
- 处理自然月边界和时区口径。

### C. 费用配置

- 新增 KYC-PM 对应 `AccountFeeType`；
- 加入新老账户费率初始化/迁移；
- 默认账户配置 0.85 USD/次；
- 确认固定值校验、有效期和费率覆盖规则。

### D. 账单输出

- 新增或调整 `ApiClientFeeEnum`；
- 调整月账单默认费用项集合；
- 调整账单明细/汇总 VO；
- 调整 PDF/导出模板和多语言文案；
- 核对管理端、开放接口和账单下载是否依赖固定字段。

### E. 验收和数据核对

- 用人工构造数据验证两类次数和金额；
- 验证历史 NULL 数据按 THIRD_PARTY 计费；
- 验证同一自然月跨月边界；
- 验证零次数、缺费率、客户费率覆盖默认费率；
- 对比账单明细、账单总额、导出 PDF 三者一致；
- 抽查任务执行前后计费记录数不变。

## 8. 验收用例

| 场景 | 记录 | 预期计费 |
|---|---|---|
| 普通客户三方 KYC 成功 2 次 | 2 条 THIRD_PARTY | 2 × KYC Verification Fee |
| KYC-PM 客户提交 3 次 | 3 条 SELF_CHECK | 3 × 0.85 USD 或客户配置费率 |
| KYC-PM 客户自动抽查 1 次 | 不新增记录 | 不增加客户费用 |
| 历史记录 `checkType` 为空 4 次 | NULL | 按 4 条 THIRD_PARTY 计费 |
| 同月两种类型同时存在 | 两类记录 | 两项分别计价，合计正确 |
| 重复请求命中现有唯一性规则 | 不新增有效计费记录 | 不重复收费 |
| KYC、Cardholder、实体卡 URL | 各入口按规则落库 | 三类入口统计口径一致 |
| 账户无专属 KYC-PM 费率 | 无账户级配置 | 回退默认账户 0.85 |

## 9. 当前需要产品/业务确认的问题

1. 账单最终展示为两行（KYC Verification Fee、KYC-PM Verification Fee），还是展示一行合计并在明细中拆分？
2. “KYC、cardholder、实体卡 URL 接口”中的一次收费事件，具体沿用哪个现有唯一性条件？重复调用、资料更新、失败调用是否收费？
3. 普通客户的 `THIRD_PARTY` 是否只统计成功记录，还是“已发起三方调用”就收费？当前代码按 `request_status = Success` 统计，需要确认是否保持。
4. KYC-PM 客户切换模式前后，历史记录和切换当月分别按记录上的 `checkType` 计费，还是按当前客户配置回溯判断？建议按记录字段，不回溯。
5. 默认费率 0.85 是仅新费用项默认值，还是所有未配置客户都统一使用？
6. 是否需要在账单明细中展示次数和单价，而不只是最终金额？

## 10. 账单负责人最终交付边界

账单负责人主要交付：

- 两类 KYC 费用项的枚举和账单输出定义；
- 按账户、自然月、`checkType` 统计次数；
- 两种费率读取与金额计算；
- 历史数据兼容；
- 月账单明细、汇总、PDF/接口输出；
- 账单侧单元测试、集成测试和数据核对 SQL。

底层团队需要先保证：每一个应该收费的客户行为都准确落一条记录，并且 `checkType` 语义正确。账单侧不建议根据客户是否开通 KYC-PM 再自行推断记录类型，也不建议根据其他业务表反推漏记次数。

## 11. 参考代码位置

- `qbit-core/src/main/java/com/qbit/core/entity/IdvChannelRequestRecord.java`
- `qbit-core/src/main/java/com/qbit/core/enums/IdvCheckTypeEnum.java`
- `qbit-core/src/main/java/com/qbit/openapi/service/impl/IdvChannelService.java`
- `qbit-core/src/main/java/com/qbit/openapi/service/impl/ApiClientTransactionServiceImpl.java`
- `qbit-core/src/main/resources/mapper/ApiInterfaceLog.xml`
- `qbit-core/src/main/java/com/qbit/openapi/domain/enums/ApiClientFeeEnum.java`
- `qbit-core/src/main/java/com/qbit/openapi/domain/enums/ApiClientMonthFeeEnum.java`
- `qbit-core/src/main/java/com/qbit/common/enums/AccountFeeType.java`
- `qbit-core/src/main/java/com/qbit/core/service/impl/account/AccountFeeServiceImpl.java`
- `qbit-core/src/main/resources/mapper/quantum/card/ApiClientBillStatementMapper.xml`

