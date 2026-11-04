# BB 卡 CB Fee 与 Settlement Fee 排查报告

**报告日期：** 2026-11-04（Asia/Shanghai）  
**范围：** BlueBanc（BB）API 月结交易；重点解释 `crossBorderFee`（CB Fee）及 `settlementFee` 为什么可能有值或为 0。  
**证据来源：** 本地仓库提交历史与当前代码、对话中提供的账户配置/操作日志/交易样例。没有直接连接生产数据库，因此本文不虚报受影响客户总数；文末 SQL 用于在目标数据库筛出候选客户。

## 结论摘要

1. **CB Fee 与 Settlement Fee 是两条独立的计算链路。** CB 费率由 BB 月结账单逻辑组合 markup 与 cross-border base rate；Settlement Fee 由 settlement fee 查询逻辑按固定费/百分比费率读取。某笔交易 CB 非 0、Settlement 为 0 并不矛盾。
2. **费率按哪一类读取，取决于月结路由。** Realtime 使用普通费率；Monthly 的异步月结应读取 `_Caas` 费率；月结“当前交易”分支会返回 0 费率。因此看到 0，可能是月结当前交易规则、普通费率配置为 0、对应 CaaS 费率缺失/为 0、交易本身不满足收费条件，或时间/结算类型判断不正确。要结合具体分支和生效配置判断。
3. **2026-02-11 提交 `2ad75bccf9` 的 BB CB 费率查询漏传交易时间。** 后续查询可能按费率查询默认时间选择记录，不能可靠地按交易发生时的费率版本取值。该提交本身的日期不等于生产部署日期，需用发布记录确认实际受影响时间段。
4. **账户结算类型曾按当前配置判断，无法还原历史交易当时的 Monthly 状态。** 如果账户后来切换成 Realtime，旧交易在月结计算时可能被路由到普通费率。2026-11-03 提交 `27e27732a2` 已增加按交易时间查操作日志还原 statement type，并给 BB CB 的 markup/base rate 查询传入交易时间。
5. **现有样例能解释为何 CB 有值而 Settlement 为 0，但正 CB 本身不能证明走了月结 CaaS 费率。** 例如 e6 账户一笔 USD 60、香港商户交易的 CB 为 0.90；普通路径 1.5% 与 CaaS 路径 0.5% + 1.0% 都会算出 0.90。该账户当时普通 Settlement 费率为 0，因此普通路径的 Settlement Fee 为 0；提供的 CaaS 默认 Settlement 费率则非 0。必须结合当次运行时读取的费率类型和账户历史状态判断是否漏收。

## 代码与提交记录

### 2026-02-11：BB 月结费率调整提交

提交 `2ad75bccf9335680e3ceb76bc0ef4a2c03c717b7`（`【测试中】月结账单—账户费率调整 (#9456)`）将 BB 逻辑改为分别读取 `QuantumCardMarkUpFeePercentage` 和 `QuantumCardCrossBorderFeeBaseRate`。当时这两个 BB CB 费率查询没有传入交易时间；其它部分的 fee 查询则有传时间。结果是 CB 的费率版本可能取当前/默认查询时间，而不是交易时间对应的有效费率。

### 2026-11-03：修复提交

提交 `27e27732a2f1725d4b1839c3884073641bf1443f`（`bb cb bug`）做了两项修复：

- BB CB 的 markup 与 cross-border base rate 查询都传入交易时间。
- `getCaasMonthFee()` 在有有效交易时间时，查询该时间之前最新的 API 客户操作日志，以还原当时的 `statementType`；没有匹配日志时回退当前配置。

当前代码的主要位置：

- `src/modules/account-fee/account-fee.controller.ts`：`blueBancCardFee()`；CB 只在非美国商户分支计算，USD 不走 FX markup 分支。
- `src/modules/account-fee/account-fee.service.ts`：`getCaasMonthFee()` 和 `getApiClientStatementTypeAtTime()`。
- `src/modules/account-fee/account-fee-v2.service.ts`：`getQuantumCardSettleFee()`，按月结路由选择普通或 `_Caas` 的 settlement fee 费率。

> 这里确认的是仓库提交历史，不代表生产环境已在同日部署。请用实际发布记录确定修复上线时间。

## 计算分支说明

### BB CB Fee

当前 BB CB 逻辑先判断商户国家：商户国家后两位是 `US` 时不收 CB，`crossBorderFee` 保持 0。其它国家会读取：

`CB费率 = QuantumCardMarkUpFeePercentage + QuantumCardCrossBorderFeeBaseRate`

`crossBorderFee = amount × CB费率`，结果按两位小数向上取整。

两项费率都应按卡的 provider/BIN 和交易时间选有效记录。2026-02-11 到 2026-11-03 修复前，BB CB 两项查询未显式传交易时间，这是时间敏感费率读取风险。

### Settlement Fee

Settlement 逻辑区分固定费与百分比费率，并使用交易时间读取费率。对于 Monthly：

- 当前月结交易分支 `ApiMonthlyCurrent` 返回 0 费率；
- 异步月结分支 `ApiMonthlyAsync` 将费率类型加 `_Caas`，读取 CaaS 月结费率；
- Realtime/默认分支读取普通费率。

所以，`settlementFee = 0` 不能只凭字段本身判断是 bug。首先要确认该交易在计算时是否进入 `ApiMonthlyCurrent`、`ApiMonthlyAsync` 或 `Default`，再核对匹配的费率记录（含账户、provider、BIN、时间范围和费率类型）。

## 已提供样例的判断

### 账户 `e6f7db49-c103-455e-930a-acdc22f64889`

已提供的日志显示：

- `Monthly` 配置操作时间：2026-08-17 04:56:17 UTC；
- 切换到 `Realtime` 的操作时间：2026-10-20 06:20:26 UTC；
- 交易 `f68347e8-c06e-4b92-8bc5-d08fe7911a63` 时间：约 2026-10-20 05:33:11 UTC，落在上述 Monthly 区间；
- API fee 记录生成时间：2026-10-22 22:44:48 UTC，晚于切换到 Realtime；
- 商户国家 HK，金额 USD 60，CB Fee USD 0.90，Settlement Fee USD 0。

对话中提供的 e6 账户普通 BB Settlement 固定费与百分比费率均为 0；CaaS 默认 Settlement 固定费为 0.20、百分比费率为 2%。因此若旧逻辑在 fee 生成时只看当前配置，切换后的 `Realtime` 可能使 Settlement 查普通费率并得到 0。若按交易时间还原成 Monthly 且该笔走异步月结，则应进一步检查命中的 `_Caas` 费率和实际金额计算。

CB USD 0.90 等于 60 × 1.5%。但普通配置的 markup 1.5%，以及 CaaS 配置的 markup 0.5% + CB base 1.0%，都可能得出 1.5%；单看 0.90 无法识别当时实际走的是哪条费率路径。

### 账户 `9a6e4d51-d5cf-471f-8c13-9922c1213638`

三笔 2026-08-19 至 2026-08-20 交易的 CB 分别为 0.23、0.05、0.15；交易日志显示当时是 Monthly，而随后在 fee 记录生成前账户切换为 Realtime。金额分别对应约 1.7% 的普通 markup。此现象与旧逻辑按 fee 生成时的当前 Realtime 配置读取普通费率相符，但仅凭 fee 数值还不足以证明具体执行路径。

### 其它已见到的 0 值

- 美国商户的 CB 为 0：符合代码的国家判断。
- 非美国交易的 CB 为 0：还需核对 CB 两项有效费率是否为 0、是否命中 CaaS/普通分支、币种/金额及交易记录是否完整。
- Settlement 为 0：检查当前月结分支、普通 Settlement 费率、CaaS Settlement 费率以及结算类型的历史还原结果。

## 受影响客户范围与建议 SQL

目前能确认的是**受影响候选**，不是已确认漏收客户。按你的排查范围，仅筛选 2026-02-11 之后、交易时为 Monthly、BB、USD、非美国商户的交易，并按账户汇总 CB Fee 为 0 的候选交易；FX 不纳入这轮判断。执行前请确认数据库表名/字段名与 JSON 类型；下面使用此前对话中出现的 PostgreSQL 表和字段。

```sql
WITH bb_tx AS (
  SELECT
    ac.account_id,
    ac.transaction_id,
    ac.create_time AS fee_created_at,
    ac.complete_time,
    ac.fees::jsonb AS fees,
    q."transactionTime" AS transaction_time,
    q."specialSourceData"::jsonb AS special_source_data,
    q."transactionAmount" AS transaction_amount,
    q."transactionCurrency" AS transaction_currency,
    q."cardId" AS card_id
  FROM public.api_client_transaction ac
  JOIN public.qbit_card_transaction q
    ON q.id::text = ac.transaction_id::text
  WHERE ac.provider = 'BlueBancCardRecharge'
    AND ac.create_time >= TIMESTAMPTZ '2026-02-11 00:00:00+00'
    AND ac.delete_time IS NULL
), fee_values AS (
  SELECT
    b.*,
    COALESCE((
      SELECT (f->>'amount')::numeric
      FROM jsonb_array_elements(b.fees) f
      WHERE f->>'type' = 'crossBorderFee'
      LIMIT 1
    ), 0) AS cb_fee,
    COALESCE((
      SELECT (f->>'amount')::numeric
      FROM jsonb_array_elements(b.fees) f
      WHERE f->>'type' = 'settlementFee'
      LIMIT 1
    ), 0) AS settlement_fee,
    upper(right(COALESCE(b.special_source_data->>'country', ''), 2)) AS merchant_country
  FROM bb_tx b
), classified AS (
  SELECT
    f.*,
    ol.statement_type_at_tx
  FROM fee_values f
  LEFT JOIN LATERAL (
    SELECT
      l.data->'params'->'operationContent'->>'statementType' AS statement_type_at_tx
    FROM public."operationLog" l
    WHERE l."recordId"::text = f.account_id::text
      AND l."operationAccountType" = 'ApiClient'
      AND l."businessType" = 'OpenApiAdmin'
      AND l."deleteTime" IS NULL
      AND l.data->>'operationType' IN (
        'OPEN_API_CLIENT_CREATION', 'UPDATE_CONFIG', 'UPDATE_DISCOUNT_CONFIG'
      )
      AND l.data->'params'->'operationContent'->>'statementType' IS NOT NULL
      AND l."createTime" <= f.transaction_time
    ORDER BY l."createTime" DESC
    LIMIT 1
  ) ol ON true
)
SELECT
  account_id,
  COUNT(*) AS candidate_transactions,
  COUNT(*) FILTER (WHERE cb_fee = 0) AS zero_cb_transactions,
  COUNT(*) FILTER (WHERE settlement_fee = 0) AS zero_settlement_transactions,
  MIN(transaction_time) AS first_transaction_time,
  MAX(transaction_time) AS last_transaction_time
FROM classified
WHERE transaction_time >= TIMESTAMPTZ '2026-02-11 00:00:00+00'
  AND upper(transaction_currency) = 'USD'
  AND statement_type_at_tx = 'Monthly'
  AND merchant_country <> 'US'
  AND cb_fee = 0
GROUP BY account_id
ORDER BY candidate_transactions DESC;
```

### SQL 结果如何解释

- 该 SQL 仅筛选 USD + 非美国商户的 BB 交易，以隔离 CB 分支；结果是**需要逐笔核实的候选账户**，不能直接当作漏收名单。零费也可能来自应收为 0 的规则、月结当前交易分支或无有效 CaaS 配置。
- SQL 按交易时间还原 Monthly，因此有机会找出“交易时 Monthly、后来切成 Realtime”的交易；若日志 JSON 路径、枚举值或字段名在目标环境不同，需要按实际日志查询调整。
- `2026-02-11` 是提交日期，不一定是生产生效日期；应将起始时间替换为 BB 相关版本在生产的实际上线时间。
- 确认漏收还要对每笔候选核对当日命中的 `QuantumCardMarkUpFeePercentage_Caas`、`QuantumCardCrossBorderFeeBaseRate_Caas`、Settlement 的固定费/百分比 `_Caas` 配置，以及该交易是否属于 async 月结。

## 建议逐笔排查顺序

1. 用 `transaction_id` 查 `qbit_card_transaction`：确认交易时间、商户国家、币种、金额、卡 provider/BIN。
2. 查该账户操作日志在**交易时间**之前的最后一条有效 statement type，确认交易当时是否 Monthly。
3. 查交易时有效的账号、provider、BIN 费率记录，分别列出普通费率和 `_Caas` 月结费率及其起止时间。
4. 确认月结分支应为当前交易还是异步交易，并按代码公式重算 CB 和 Settlement。
5. 对照 `api_client_transaction.fees`。只有“应进入 async CaaS、当时有效费率非零、实际记录为 0”才可确认为疑似漏收；之后再按上线时间和客户配置统计影响面。

## 限制

- 目前没有直接查询业务数据库，受影响账户数/交易数尚未计算。
- 提供的 SQL 按现有对话中看到的 schema 写成；执行若报字段/枚举差异，请以目标环境真实 DDL 和一条操作日志 JSON 为准。
- 本文说明代码意图及样例一致性，不等同于从应用运行日志证明某条交易实际走过的分支。

## CB 与 FX 的交易条件矩阵（用于隔离问题）

当前 `blueBancCardFee()` 的两个开关分别由商户国家和币种决定：美国商户关闭 CB；USD 交易关闭 FX markup。两项逻辑彼此独立：

| 商户国家 | 交易/清算币种 | CB 分支 | FX markup 分支 | 排查用途 |
|---|---|---:|---:|---|
| 非美国 | USD | 开 | 关 | **纯 CB 样例，最适合先隔离 BB CB 问题** |
| 美国 | 非 USD | 关 | 开 | 纯 FX 样例，可作为对照 |
| 非美国 | 非 USD | 开 | 开 | CB 与 FX 都可能收费；需分开看 `crossBorderFee`、`fxMarkupFee`，不能用总费用判断 CB |
| 美国 | USD | 关 | 关 | 两个分支均不收费 |

这里的“分支开启”只表示代码会查询费率并计算，不保证最终金额大于 0：匹配费率为 0、月结当前交易规则、或有效费率不存在时，费用仍可能为 0。

因此，如果目的是先判断 CB 月结是否异常，优先筛选 USD 且商户国家非 US 的 BB 交易，再单独核对 `crossBorderFee` 和交易时间对应的月结费率；之后再用非 USD、非 US 样例检查 CB 与 FX 同时启用时两项输出是否分别正确。
