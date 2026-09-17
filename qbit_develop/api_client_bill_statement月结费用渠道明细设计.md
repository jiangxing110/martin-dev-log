# `api_client_bill_statement` 月结费用渠道明细设计

> 文档更新时间：2026-09-17  
> 依据：`qbit-assets/qbit-core` 当前源码

## 1. 结论摘要

`api_client_bill_statement` 通过两个字段区分费用记录的层级：

| 字段 | 含义 |
|---|---|
| `is_sum = true` | 账户级费用汇总行，通常 `provider = null` |
| `is_sum = false` | 渠道级费用明细行，`provider` 保存渠道编码 |

一般情况下，存在渠道明细的费用会同时生成“账户汇总 + 渠道明细”；无法按渠道拆分的费用只生成账户汇总。

## 2. 有渠道明细的费用类型

以下 `type` 在月结费用计算中会按渠道生成 `is_sum = false` 的明细，同时通常保留一条 `is_sum = true` 的汇总：

| `type` | 费用名称 | 渠道明细中的扩展信息 |
|---|---|---|
| `settlementFee` | 结算手续费 | 消费金额 |
| `topUpFee` | 月结充值手续费 | 净消费金额 |
| `cardCreationFee` | 开卡费 | 开卡数量 |
| `cardProductionFee` | 制卡费 | 制卡数量 |
| `postageFee` | 邮寄费 | 包裹数量 |
| `authFee` | 授权费 | 授权费分段 |
| `verificationFee` | 绑卡费 | 消费金额 |
| `crossBorderFee` | 跨境手续费 | 跨境笔数、跨境金额 |
| `fxFee` | 汇兑费用 | 消费金额 |
| `applePayAuthFee` | Apple Pay 服务费 | Apple Pay 交易金额 |
| `atmWithdrawalFee` | ATM 取现手续费 | 取现金额 |
| `refundFee` | 退款手续费 | 退款金额 |
| `refundClientFee` | 客户退款手续费 | 退款金额 |
| `reversalFee` | 撤销手续费 | 大于 5 USD 的撤销笔数 |
| `declineFee` | 交易失败/拒付手续费 | 拒付笔数、拒付费率等拒付信息 |
| `monthlyCardFee` | 活跃卡月费 | 活跃卡数量 |

渠道明细的生成逻辑集中在 `ApiClientTransactionServiceImpl.buildExtendData`：先按账户和渠道查询交易费用，再补充开卡数、包裹数、活跃卡数等统计信息，最后将明细设置为 `is_sum = false`。

## 3. 只有账户汇总的费用类型

以下费用被归入 `NO_DIFFERENCES_PROVIDER`，业务设计上不区分支付渠道，通常只保留 `provider = null` 的汇总行：

| `type` | 费用名称 |
|---|---|
| `inactiveCardManagementFee` | 非活跃卡管理费 |
| `monthlyCommitment` | 月低消费用 |
| `disputeFee` | 争议手续费 |
| `additionalFee` | 额外手续费 |
| `apiSubscription` | 接口订阅费 |
| `complianceDueDiligence` | CDD 费用 |
| `apiIntegration` | 接口服务费 |
| `identityVerification` | 身份验证费用 |
| `kycPmVerification` | 身份托管验证费用 |
| `revenueAdjustment` | 营收补差 |
| `minimumVolumeCommitmentFee` | 最低交易量承诺费用（MVC） |

这些费用通常来自账户配置、外部身份验证统计、营收补差或账单主表计算结果，不依赖卡交易渠道。

## 4. 特殊情况

### 4.1 `additionalFee` 有费用项明细，但不是渠道明细

`additionalFee` 会生成：

1. 一条账户级总额记录；
2. 多条 `is_sum = false` 的费用项记录。

这些明细的 `provider` 实际保存的是自定义费用名称 `itemName`，不是支付渠道。因此它属于“费用项明细”，不属于“渠道明细”。

### 4.2 `monthlyCardFee` 既有汇总也有渠道明细

活跃卡月费会按照渠道统计活跃卡数量并计算渠道费用，同时再汇总成账户总额。部分无渠道交易数据但存在渠道卡片统计的场景，也会补生成渠道记录和总额记录。

### 4.3 `declineFee` 的汇总标识需要注意

拒付费用会按渠道生成 `is_sum = false` 明细；但部分补充总拒付费用的代码路径没有显式设置 `is_sum = true`，可能出现汇总记录 `is_sum = null` 的情况。查询汇总时不能只根据 `provider is null` 判断，建议同时核对 `is_sum`。

### 4.4 已实时收取的费用只有汇总行

以下已实收费用由账户收入统计直接生成，`provider` 为空，当前设计只有汇总记录：

`settlementFeeClosed`、`cardCreationFeeClosed`、`authFeeClosed`、`applePayAuthFeeClosed`、`topUpFeeClosed`、`physicalCardFeeClosed`、`atmWithdrawalFeeClosed`。

这些费用在计算月结账单应收总额时会被 `closedFees` 排除。

## 5. 不进入客户月结账单的系统费用

以下类型虽然定义在 `ApiClientFeeEnum` 中，但当前月结流程会通过 `RS_SCHEME_FEE_TYPES` 过滤，不写入客户的 `api_client_bill_statement`，只用于 RS 成本核算：

- `issuerCardServiceIntFee`
- `issuerCardServiceDomFee`
- `visaRiskManagerIntFee`
- `visaRiskManagerDomFee`
- `issuerTransactionAuthIntFee`
- `issuerTransactionAuthDomFee`
- `issuerTransactionSettlementIntFee`
- `issuerTransactionSettlementDomFee`
- `schemeVerificationIntFee`
- `schemeVerificationDomFee`
- `schemeRefundFee`
- `schemeReversalFee`
- `schemeSignatureFee`

## 6. 数据生成链路

```text
api_client_transaction.fees
        |
        +-- getApiClientMonthFees：按账户、type 汇总 -> is_sum=true
        |
        +-- getMonthProvider：按账户、provider、type 汇总
                                      |
                                      +-> buildExtendData -> is_sum=false
        |
        +-- 身份验证、KYC-PM、营收补差等账户级费用
        |
        +-- ApiClientBillStatementTemp / ApiClientBillStatement
```

核心查询：

- `OdsApiClientTransactionMapper.xml#getApiClientMonthFees`：生成账户级费用汇总。
- `OdsApiClientTransactionMapper.xml#getMonthProvider`：生成按渠道费用数据。
- `ApiClientTransactionServiceImpl#getApiClientMonthlySettlementFee`：合并汇总、渠道和扩展统计。
- `ApiClientBillServiceImpl#createApiClientBillStatement`：将月结费用转换为 `api_client_bill_statement`。

## 7. 查询建议

查询账户月结费用总额时使用：

```sql
WHERE delete_time IS NULL
  AND bill_id = :billId
  AND is_sum = TRUE
```

查询渠道明细时使用：

```sql
WHERE delete_time IS NULL
  AND bill_id = :billId
  AND is_sum = FALSE
  AND provider IS NOT NULL
```

`additionalFee` 如果需要展示自定义费用项，应单独按 `type = 'additionalFee' AND is_sum = false` 查询，并将 `provider` 当作费用项名称处理，不能当作渠道名称展示。

## 8. 代码依据

- `qbit-core/src/main/java/com/qbit/openapi/domain/enums/ApiClientFeeEnum.java`
  - 费用类型定义
  - `NO_DIFFERENCES_PROVIDER`
  - `closedFees`
- `qbit-core/src/main/java/com/qbit/openapi/service/impl/ApiClientTransactionServiceImpl.java`
  - 月结费用汇总与渠道明细生成
  - `buildExtendData`
  - `RS_SCHEME_FEE_TYPES`
- `qbit-core/src/main/java/com/qbit/common_all/api/client/bill/service/impl/ApiClientBillServiceImpl.java`
  - `api_client_bill_statement` 写入逻辑
- `qbit-core/src/main/resources/mapper/ods/OdsApiClientTransactionMapper.xml`
  - `getApiClientMonthFees`
  - `getMonthProvider`
