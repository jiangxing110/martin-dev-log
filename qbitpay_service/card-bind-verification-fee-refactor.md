# qbitpay_service 绑卡验证费(BZ/QI)改造逻辑梳理

生成时间：2026-08-11

## 1. PR 来源关系

- PR #10050 是主体改造：
  - 远端 ref：`refs/pull/10050/head`
  - 提交：`8ededa36fd0cc36d2f06867c78a1c13d46650d4d`
  - 标题：`绑卡验证费(https://axss9gjoff.feishu.cn/wiki/CX5nwjhcriTMCikVylpckrO1nqb)`
  - 主要作用：引入 `thirdPartyTradeType: CardBindAuth`，并在 I2C/BZ、QI 授权链路中把该类交易标记为绑卡验证交易，后续收费从普通授权费切换为绑卡验证费。

- PR #10060 是后续补丁：
  - 当前 `develop` HEAD：`5eeb06e2642a07cbb7e1a673e517df591b5fedde`
  - 标题：`fix (#10060)`
  - 主要作用：允许 QI 的 `transactionType === 'na' && thirdPartyTradeType === 'CardBindAuth'` 通过交易类型检查，否则 QI 绑卡授权可能被 `checkThirdPartyTransactionType` 提前放过/跳过后续建单与计费链路。

- 当前分支状态：
  - 当前分支是 `develop`。
  - `#10060` 已在当前 `develop`。
  - `#10050` 的提交 SHA 本身不在当前 `develop` 祖先链上；`git cherry` 仍显示 `+ 8ededa...`。但其核心实现内容在当前代码中已经能看到，可能是通过其它分支/提交形态合入或手工合并过。

## 2. 原始需求要点

### BZ 卡段绑卡逻辑

原始查询：

```sql
SELECT * from public.i2c_iso_message
where pos_condition_code='62' and mti ='0100'
```

原始判断参数：

- `pos_condition_code = '62'`：Account Verification w/o Auth / product eligibility inquiry without authorization
- `mti = '0100'`：授权交易
- 我方控制成功/失败：
  - 当前卡内余额为负：绑卡失败
  - 余额 >= 0：正常成功

### QI 卡段绑卡逻辑

原始查询：

```sql
select response_code, * from vcc_authorization_advice_request
where processing_code like '38%'
```

原始判断参数：

- `processing_code` 前两位为 `38`：AccountVerification
- `response_code = '000'`：绑卡授权成功
- 其它 `response_code`：失败
- BPC 使用 STIP 模式代为审批，审批结果通过 `0120` 消息发送至我方。

### 默认报价

收费项：Card verification fee ($/verification)

- QI：
  - US Domestic：0
  - International：0
- BZ：
  - US Domestic：0.1
  - International：0.1

收费口径：交易类型 = 绑卡验证，且状态 = 成功，按笔数收费。

## 3. 当前代码中的统一内部标识

当前实现没有直接在收费逻辑里使用 SQL 条件作为主判断，而是引入统一内部业务码：

```ts
BusinessCodeEnum.CONSUMPTION_VERIFICATION_TRANSACTION
```

触发来源主要是：

```ts
op.raw?.thirdPartyTradeType === 'CardBindAuth'
```

也就是说，当前代码将上游/入参中的 `thirdPartyTradeType = CardBindAuth` 映射为“绑卡验证交易”，再通过 `specialSourceData.code` 传递到后续收费逻辑。

涉及字段扩展：

- `src/modules/qbit-card/qbit-card/third-party/i2c/i2c.dto.ts`
  - `Authorization.thirdPartyTradeType: 'CardBindAuth' | null`
- `src/modules/qbit-card/qbit-card/third-party/qbit-issuing/qbit-issuing.dto.ts`
  - `Authorization.thirdPartyTradeType: 'CardBindAuth' | null`

## 4. BZ/I2C 授权侧改造逻辑

涉及文件：

- `src/modules/qbit-card/qbit-card/third-party/i2c/i2c-authorization.service.ts`

### 4.1 成功建单时打绑卡标识

在 `createPendingQbitCardTx` 中组装 `code`：

```ts
const code = [
  ...(op.isATM ? [BusinessCodeEnum.ATM_TX] : []),
  ...(op.isApplePay ? [BusinessCodeEnum.APPLE_TX] : []),
  ...(op.raw?.thirdPartyTradeType === 'CardBindAuth' ? [BusinessCodeEnum.CONSUMPTION_VERIFICATION_TRANSACTION] : []),
];
```

如果是 `CardBindAuth`，交易会在 `specialSourceData.code` 中带上 `CONSUMPTION_VERIFICATION_TRANSACTION`。

### 4.2 失败建单时也会打绑卡标识

在 `createFailedQbitCardTxAndTransaction` 中，如果原始交易是 `CardBindAuth`，同样会把 `CONSUMPTION_VERIFICATION_TRANSACTION` 加入失败交易的 `specialSourceData.code`。

### 4.3 收费时切换收费模板

在 `createConsumptionFeeTx` 中：

- 如果 `code` 包含 `CONSUMPTION_VERIFICATION_TRANSACTION`：
  - 使用 `FeeTemplateNameEnum.QuantumCardVerificationFee`
  - 备注写入 `绑卡验证手续费`
  - `specialSourceData` 写入 `{ bindCardVerificationFee: collectionFee }`

- 否则：
  - 使用 `FeeTemplateNameEnum.QuantumCardAuthorizationFee`
  - `specialSourceData` 写入 `{ authVerificationFee: collectionFee }`

### 4.4 Domestic / International 判断

绑卡验证费国家维度判断：

```ts
['US', 'USA', '840'].includes(originQbitCardTx.specialSourceData?.country?.toUpperCase())
  ? FeeTemplateTransactionCountryEnum.domestic
  : FeeTemplateTransactionCountryEnum.international
```

## 5. QI/Qbit Issuing 授权侧改造逻辑

涉及文件：

- `src/modules/qbit-card/qbit-card/third-party/qbit-issuing/qbit-issuing-authorization.service.ts`

### 5.1 成功建单时打绑卡标识

在 `createPendingQbitCardTx` 中，如果：

```ts
op.raw?.thirdPartyTradeType === 'CardBindAuth'
```

则加入：

```ts
BusinessCodeEnum.CONSUMPTION_VERIFICATION_TRANSACTION
```

### 5.2 失败建单时也会打绑卡标识

在 `createFailedQbitCardTxAndTransaction` 中，如果 `thirdPartyTradeType` 是 `CardBindAuth`，也会给失败交易加上绑卡验证业务码。

### 5.3 收费时切换收费模板

QI 的 `createConsumptionFeeTx` 与 I2C 类似：

- `CONSUMPTION_VERIFICATION_TRANSACTION`：使用 `QuantumCardVerificationFee`
- 普通授权交易：使用 `QuantumCardAuthorizationFee`

### 5.4 PR #10060 的补丁逻辑

`checkThirdPartyTransactionType` 原逻辑：

```ts
if (op.raw.transactionType !== 'authorization') {
  throw { id: op.raw.id, code: qbitIssuing.CodeEnum.CBSRC_000 };
}
```

这会导致 `transactionType = 'na'` 的 QI 绑卡授权不进入后续正常处理。

`#10060` 增加特例：

```ts
if (op.raw.transactionType === 'na' && op.raw.thirdPartyTradeType === 'CardBindAuth') {
  return;
}
```

效果：QI 的 `CardBindAuth` 即使 `transactionType` 是 `na`，也继续进入换汇、风控、建单、收费等处理流程。

## 6. 本次改造使用到的收费模板

### 客户侧绑卡验证费

枚举：

- `AccountFeeTypeEnum.QuantumCardVerificationFeeByDomestic`
- `AccountFeeTypeEnum.QuantumCardVerificationFeeByInternational`

费率模板：

- `FeeTemplateNameEnum.QuantumCardVerificationFee`
- Rate type：`fixed`
- Math type：`Count`

这是本次 `#10050` 主体改造实际切换使用的收费模板：当交易被标记为 `CONSUMPTION_VERIFICATION_TRANSACTION` 后，消费手续费从普通授权费 `QuantumCardAuthorizationFee` 切换为绑卡验证费 `QuantumCardVerificationFee`。

## 7. 当前实现与原始需求的差异点

### 7.1 交易识别字段不同

原始需求：

- BZ：`pos_condition_code = '62'` 且 `mti = '0100'`
- QI：`processing_code like '38%'`，成功看 `response_code = '000'`

当前代码主识别：

- `thirdPartyTradeType === 'CardBindAuth'`

这说明当前实现依赖上游或入库映射层已经把原始交易条件转换成 `CardBindAuth`。如果上游没有稳定写入这个字段，则收费识别会偏离原始 SQL 口径。

### 7.2 成功才收费的约束不够显式

原始需求强调：

> 交易类型 = 绑卡验证，且状态 = 成功，按笔数收费。

当前 I2C/QI 授权服务在 `finally` 中会调用：

```ts
createDeclineFeeTxAndCreateConsumptionFeeTx(op.qbitCardTx)
```

而 `createConsumptionFeeTx` 自身没有判断原始交易状态必须成功。失败交易如果已经落了 `QbitCardTransaction` 且 `specialSourceData.code` 包含 `CONSUMPTION_VERIFICATION_TRANSACTION`，理论上也可能进入绑卡验证费创建逻辑。

这是当前代码相对原始需求最需要确认/修正的风险点。

### 7.3 QI 默认 0 费率依赖配置数据

原始报价里 QI Card verification fee 是 0。

当前代码会按 `QuantumCardVerificationFee` 模板取费率。如果 QI 的账号费率/模板没有明确配置为 0，或者模板 bin 维度没有覆盖 QI provider，则实际行为取决于 `accountFeeItemService.getCardFee` 的兜底逻辑和现有数据。

需要通过线上/测试库费率数据确认：

- QI provider 是否有 `QuantumCardVerificationFee` 对应费率项
- Domestic / International 是否都为 0
- BZ provider 是否都为 0.1

## 8. 建议核对清单

1. 对 BZ 样本交易确认：
   - `i2c_iso_message.pos_condition_code = '62'`
   - `mti = '0100'`
   - 入参或映射后 `thirdPartyTradeType = 'CardBindAuth'`
   - 成功交易生成 `Fee_Consumption`，备注为 `绑卡验证手续费`

2. 对 QI 样本交易确认：
   - `vcc_authorization_advice_request.processing_code like '38%'`
   - `response_code = '000'`
   - 入参或映射后 `thirdPartyTradeType = 'CardBindAuth'`
   - `transactionType = 'na'` 时仍能通过 `#10060` 的特例继续处理

3. 对失败交易确认：
   - BZ 失败绑卡是否生成绑卡验证手续费
   - QI 非 `000` 的绑卡 advice 是否生成绑卡验证手续费
   - 若失败也收费，则与原始需求不一致

4. 对费率配置确认：
   - BZ Domestic = 0.1
   - BZ International = 0.1
   - QI Domestic = 0
   - QI International = 0

## 9. 总结

本次改造的核心逻辑是：把 BZ/QI 的绑卡授权统一映射为 `thirdPartyTradeType = CardBindAuth`，再在交易 `specialSourceData.code` 中打上 `CONSUMPTION_VERIFICATION_TRANSACTION`，后续创建消费手续费时根据该业务码从普通授权费 `QuantumCardAuthorizationFee` 切换为绑卡验证费 `QuantumCardVerificationFee`。

`#10050` 是主体改造，`#10060` 是 QI `transactionType = na` 场景的补丁。当前最需要注意的是“成功才收费”这一条件在代码中没有被 `createConsumptionFeeTx` 显式兜住，需要通过数据流确认失败交易是否会进入收费创建，或在代码层补充状态判断。
