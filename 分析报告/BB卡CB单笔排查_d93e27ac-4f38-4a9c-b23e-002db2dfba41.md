# BB 卡 CB 单笔交易排查报告

**交易 ID：** `d93e27ac-4f38-4a9c-b23e-002db2dfba41`  
**账户 ID：** `e83b6e59-cd6b-4f77-9c0e-388ec2486bc4`  
**分析日期：** 2026-11-09

## 1. 排查结论

这笔交易的卡交易创建时间落在账户的月结区间内，但 `api_client_transaction` 记录是在账户切换到 Realtime 后创建的。实际 CB fee 为 **0.43 USD**，与 API 记录创建时生效的普通 markup 费率 **2%** 精确吻合：

```text
21.32 × 2% = 0.4264
ROUND_UP 到美分 = 0.43 USD
```

这笔交易发生时的月结费率按查询结果为 markup **1.5%** 加 CB base **1%**，估算应为：

```text
21.32 × (1.5% + 1%) = 0.533
ROUND_UP 到美分 = 0.54 USD
```

因此，`0.43` 很可能是用 API 记录创建时的 Realtime 配置和普通费率算出的，而不是按交易发生时的月结配置计算。它不是“月结就不应收 CB fee”；疑点在于月结状态和费率使用了哪个时间点。

## 2. 交易信息

| 字段 | 值 |
| --- | --- |
| Provider | `BlueBancCard` |
| BIN | `537100` |
| 卡交易状态 | `Closed` |
| 交易币种 | `USD` |
| 交易金额 / 结算金额 | `21.32 USD` |
| 商户国家 | `LU`（卢森堡，非美国） |
| API 实际 `crossBorderFee` | `0.43 USD` |
| API 实际 `settlementFee` | `0 USD` |

卡交易的 `specialSourceData` 中 CB 相关元数据为 0，不等同于 API 侧实际收取的 CB fee。API 侧费率计算使用 `accountFee` 中的 markup 和 CB base 费率。

## 3. 时间线

以下统一显示北京时间：

| 事件 | 时间 | 依据 |
| --- | --- | --- |
| 卡交易创建 | 2026-06-02 08:31:28.339 | `qbit_card_transaction.createTime` |
| 月结配置结束（结束时间不包含） | 2026-06-02 14:05:34.176 | 账户 `operationLog` 的下一条配置日志 |
| 2% 普通 markup 开始生效 | 2026-06-03 21:09:14.243 | `accountFee.startTime` |
| 卡交易完成 | 2026-06-04 10:25:56.482 | `api_client_transaction.complete_time` |
| API 交易记录创建 | 2026-06-05 06:05:43.435 | `api_client_transaction.create_time` |

因此卡交易发生时间位于月结区间：

```text
[2025-10-11 20:23:23.864, 2026-06-02 14:05:34.176)
```

API 交易记录创建时，月结区间已经结束，账户已切为 Realtime。

## 4. 费率对比

费率输出显示账户是顶层 `ApiClient`，`parentAccountId` 为 NullUUID，`tenantId` 为空；不存在其他父账户或 tenant 费率层级。

| 取值时间 / 类型 | Markup | CB base | 合计 | 21.32 USD 对应费用 |
| --- | ---: | ---: | ---: | ---: |
| 卡交易时的 `_Caas` 月结费率 | 1.5%（账户费率） | 1.0%（BlueBanc 全局费率；账户的 1.35% 记录已于 2026-01-31 16:00 UTC 结束） | 2.5% | **0.54 USD** |
| API 记录创建时的普通费率 | 2.0%（账户 + BIN 537100，6 月 3 日开始生效） | 0%（账户 + BlueBanc + BIN 537100） | 2.0% | **0.43 USD** |
| 卡交易时的普通费率（仅作对照） | 1.5%（账户 + BIN 537100） | 0%（账户 + BlueBanc + BIN 537100） | 1.5% | **0.32 USD** |

费率计算逻辑：

```text
crossBorderFee = ROUND_UP(amount × (markupRate + crossBorderFeeBaseRate), 2 位小数)
```

该交易为 USD，所以 FX markup 分支关闭；商户国家为 LU，所以 CB 分支适用。`settlementFee` 是单独的费用类型，与这次 CB 计算无关。

## 5. 与代码逻辑的对应

Node 的 `blueBancCardFee()` 把 `op.time` 传给普通 markup 与 CB base 的费率查询。Asset 的 `AccountFeeServiceImpl.getBestAccountFee()` 将费率查询时间传入 `getCaasMonthFee()`；但 `getCaasMonthFee()` 判断 Monthly / Realtime 时读取的是 `OpenApiClientConfig` 当前的 `statementType`，而不是该交易时间点对应的历史配置。

这意味着：如果计算时当前配置已是 Realtime，即使传入时间对应的交易发生在月结区间内，代码仍可能选 `Default` 普通费率类型。此次结果中的 **0.43** 与 API 记录创建时生效的普通 2% markup 完全吻合，与交易时间对应的月结费率估算 **0.54** 不同。

相关代码位置：

- Node：`src/modules/account-fee/account-fee.controller.ts` 的 `blueBancCardFee()`。
- Asset：`qbit-core/src/main/java/com/qbit/core/service/impl/account/AccountFeeServiceImpl.java` 的 `getCaasMonthFee()` 和 `getBestAccountFee()`。

## 6. 结论与证据边界

1. **已确认：** 卡交易创建时间在月结区间内；API 记录创建时间在月结结束后。
2. **已确认：** API 实际 CB fee 为 `0.43`；API 记录创建时间生效的普通费率 `2% + 0%` 可计算出 `0.43`。
3. **按查询费率估算：** 交易时月结费率 `1.5% + 1%` 对应 `0.54`。
4. **高可信判断：** 该费用与使用 API 记录创建时普通费率的结果吻合，符合“历史月结交易按后续 Realtime 配置 / 普通费率处理”的问题模式。
5. **证据限制：** 仅凭数据库费率与交易行，不能证明 Node 请求中的 `op.time` 实际值；若需完全确认调用链，应查看这次费率请求日志或 Asset 调用参数，确认它传的是卡交易时间还是 API 记录创建时间。

本案例说明，**2026-02-11 之后的交易不应一概认为 fee 为 0**。应按交易时间匹配当时的月结状态及费率；交易发生时为月结并不代表费率为零。
