# BB 卡 Settlement Fee 0.40 USD 计算分析报告

**报告日期：** 2026-11-04（Asia/Shanghai）  
**交易 ID：** `d074581e-d5e1-4072-89fd-e2a6baebd1a1`  
**分析范围：** 根据提供的 Java SDK 日志、TypeScript 服务日志和当前 `qbitpay_service` 代码，追踪本笔交易的 `settlementFee = 0.40 USD` 来源。

## 结论摘要

本笔交易的清算费由固定费和百分比费相加：

```text
固定费             0.20 USD
百分比费           10 USD × 0.02 = 0.20 USD
Settlement Fee     0.20 + 0.20 = 0.40 USD
```

日志显示金额为 `10 USD`；固定费查询返回 `0.2`，百分比费查询返回 `0.02`，Java 服务随后记录 `SETTLEMENT_FEE = 0.40 USD`。同一记录中的 `CROSS_BORDER_FEE = 0 USD`，不计入本次 0.40 的组成。

## 交易与费率查询条件

| 字段 | 值 |
|---|---|
| 交易 ID | `d074581e-d5e1-4072-89fd-e2a6baebd1a1` |
| Account ID | `69e3818f-4b12-4f31-9642-091641e4f092` |
| 交易时间 | `2026-11-03 19:57:15` |
| 交易类型 | `Domestic` |
| 金额 / 币种 | `10 USD` |
| Provider | `BlueBanc`（卡数据中的 provider 为 `BlueBancCardRecharge`，查询使用归一化 provider `BlueBanc`） |
| BIN 前六位 | `537100` |
| 固定费类型 | `QuantumCardSettlementFeeDom_Caas` |
| 百分比费类型 | `QuantumCardSettlementFeeDomRate_Caas` |

两个请求都传入 `feeType=QuantumCardSettlementFeeDom`、`type=Domestic`、`amount=10`。`isQiRate=false` 时服务选择固定费枚举；`isQiRate=true` 时选择百分比费枚举。月结异步分支再给费率类型追加 `_Caas` 后缀。

## 日志证据

1. 固定费请求的参数包含 `amount=10`、`type=Domestic`、`isQiRate=false`；SDK 返回 `data=0.2`。
2. 百分比费请求的参数包含同一金额和交易类型、`isQiRate=true`；SDK 返回 `data=0.02`。
3. Java 账单服务记录：`SETTLEMENT_FEE amount=0.40 USD`；持久化的 fees JSON 也记录 `settlementFee=0.4`、`crossBorderFee=0`。

日志来源：用户提供的附件 `已粘贴的文本.txt`（Java SDK 与 MyBatis 日志）及另一份 `已粘贴的文本.txt`（TypeORM accountFee 查询日志）。

## Fee 查询 SQL

以下是第二份附件中记录的 PostgreSQL 参数化查询结构。两个查询都按有效时间、账户、provider、BIN、创建/删除时间筛选，并优先选择当前账户配置，再回退全局账户配置。

### 固定费：`QuantumCardSettlementFeeDom_Caas`

固定费查询另按金额档位匹配：`10 >= low AND (10 < high OR high IS NULL)`。

```sql
SELECT t.*
FROM (
  SELECT DISTINCT ON ("accountId", "feeType", "provider", "providerField") *
  FROM "accountFee" "AccountFee"
  WHERE "AccountFee"."startTime" <= $1
    AND "AccountFee"."endTime" >= $2
    AND "AccountFee"."accountId" IN ($3, $4)
    AND "feeType" = $5
    AND ("provider" = $6 OR "provider" IS NULL)
    AND ("providerField" = $7 OR "providerField" IS NULL)
    AND "createTime" <= $8
    AND (
      "deleteTime" IS NULL
      OR ("deleteTime" IS NOT NULL AND $9 < "deleteTime")
    )
    AND $10 >= low
    AND ((high IS NOT NULL AND $11 < high) OR high IS NULL)
  ORDER BY
    "feeType" ASC,
    "accountId" DESC,
    "provider" ASC,
    "providerField" ASC,
    "createTime" DESC
) t
ORDER BY
  "feeType" ASC,
  CASE "accountId"
    WHEN '69e3818f-4b12-4f31-9642-091641e4f092' THEN 1
    WHEN '00000000-0000-0000-0000-000000000000' THEN 2
    ELSE 999
  END ASC,
  "provider" ASC,
  "providerField" ASC,
  "createTime" DESC;
```

参数对应：

| 占位符 | 值 |
|---|---|
| `$1`, `$2`, `$8`, `$9` | `2026-11-03 19:57:15` |
| `$3` | `69e3818f-4b12-4f31-9642-091641e4f092` |
| `$4` | `00000000-0000-0000-0000-000000000000` |
| `$5` | `QuantumCardSettlementFeeDom_Caas` |
| `$6` | `BlueBanc` |
| `$7` | `537100` |
| `$10`, `$11` | `10` |

### 百分比费：`QuantumCardSettlementFeeDomRate_Caas`

百分比费查询不带金额 low/high 档位条件；返回的 `0.02` 是费率，按 2% 乘交易金额计费。

```sql
SELECT t.*
FROM (
  SELECT DISTINCT ON ("accountId", "feeType", "provider", "providerField") *
  FROM "accountFee" "AccountFee"
  WHERE "AccountFee"."startTime" <= $1
    AND "AccountFee"."endTime" >= $2
    AND "AccountFee"."accountId" IN ($3, $4)
    AND "feeType" = $5
    AND ("provider" = $6 OR "provider" IS NULL)
    AND ("providerField" = $7 OR "providerField" IS NULL)
    AND "createTime" <= $8
    AND (
      "deleteTime" IS NULL
      OR ("deleteTime" IS NOT NULL AND $9 < "deleteTime")
    )
  ORDER BY
    "feeType" ASC,
    "accountId" DESC,
    "provider" ASC,
    "providerField" ASC,
    "createTime" DESC
) t
ORDER BY
  "feeType" ASC,
  CASE "accountId"
    WHEN '69e3818f-4b12-4f31-9642-091641e4f092' THEN 1
    WHEN '00000000-0000-0000-0000-000000000000' THEN 2
    ELSE 999
  END ASC,
  "provider" ASC,
  "providerField" ASC,
  "createTime" DESC;
```

参数对应与固定费查询相同，但 `$5` 是 `QuantumCardSettlementFeeDomRate_Caas`。百分比费配置类型在代码中映射为 `Percent`，固定费配置类型映射为 `Count`。

## 代码路径核对

- `src/modules/account-fee/account-fee.controller.ts`：收到 `QuantumCardSettlementFeeDom` 后，根据 `type` 选 Domestic/International，并把 `amount`、`isQiRate` 传给查询服务。
- `src/modules/account-fee/account-fee-v2.service.ts`：`isRate=false` 选择 `QuantumCardSettlementFeeDom`；`isRate=true` 选择 `QuantumCardSettlementFeeDomRate`。`ApiMonthlyAsync` 分支追加 `_Caas`，固定费再按金额范围匹配。
- `src/common/enum/account.enum.ts`：`QuantumCardSettlementFeeDomRate_Caas` 映射到 `Percent`，`QuantumCardSettlementFeeDom_Caas` 映射到 `Count`。
- `src/modules/qbit-card/qbit-card/third-party/blue-banc/blue-banc.settle.service.ts`：BlueBanc 清算逻辑分别读取固定 settlement fee 与 percentage fee，并将固定费和百分比产生的费用相加。

## 证据限制

附件中的 SQL 日志记录了查询语句和绑定参数，但没有展示 `accountFee` 查询结果行的完整字段值。`0.2` 和 `0.02` 由 SDK 返回日志确认；报告据此还原金额计算。由于 Java 汇总实现不在当前打开的 `qbitpay_service` 仓库中，`0.20 + 10 × 0.02` 是根据两次接口返回、金额和最终费用进行的数值核对。
