# Web3 合伙人返佣逻辑说明

基于当前 `qbit-assets` 代码梳理，适用范围为 `QbitInternational` 海外版 Web3 合伙人。

## 一、整体流程

```text
客户产生业务订单
    ↓
创建合伙人原始返佣订单
    ↓ 每月统计上月客户毛利
按业务类型汇总毛利
    ↓
按合伙人阶梯费率计算
    ↓
生成月度返佣订单
    ↓
更新原始订单的毛利与分摊返佣信息
```

## 二、返佣范围与有效期

- 合伙人账户通过 `account.type = Channel` 识别。
- Web3 月结算筛选 `systemType = QbitInternational`。
- 月度结算只统计状态为 `Closed` 且未删除的原始返佣订单。
- 客户开户时间超过一年后，原则上不再产生有效返佣。
- 海外 Web3 月度结算流水起始时间当前硬编码为 `2024-02-01 00:00:00`。

## 三、参与结算的业务类型

| 业务类型 | 枚举值 | 月度毛利来源 |
|---|---|---|
| 加密资产交易 | `Crypto_Assets` | 交易手续费 + 加价收入 - 交易成本 |
| 全球账户开户 | `Global_Account_Charging` | 开户费收入 - 各地区开户成本 |
| 量子账户充值 | `Partner_QbitCard_Recharge` | 充值手续费收入 × 90% |
| 全球账户入金 | `Partner_Inbound_fee_Settlement` | 入金手续费 - CC/L2/CL/DBS 等通道成本 |

实现位置：

- `PartnerOrderServiceImpl.sendMonthCommission`
- `resources/mapper/PartnerOrderMapper.xml.selectMonthCommission`

## 四、原始返佣订单生成

以加密资产交易为例，客户产生手续费后，根据客户绑定的邀请码找到合伙人，创建 `Crypto_Assets` 原始返佣订单。

核心计算公式：

```text
原始返佣金额 = 客户手续费 × 10% × 币种兑换 USD 汇率
```

创建条件：

- 客户必须是 `QbitInternational` 海外版账户；
- 手续费为空或为 0 时不创建合伙人订单；
- 必须存在有效 `referralCode`；
- 交易时间必须在客户开户一年内。

## 五、月度毛利与返佣计算

每月任务 `partner_commission_Job` 统计上一个自然月。`sendMonthCommission` 会按合伙人和业务类型聚合客户，再调用销售统计服务取得月度毛利。

### 5.1 默认费率

没有配置阶梯费率时：

```text
最终返佣 = 月度毛利 × 10%
```

### 5.2 阶梯费率

如果账户配置了对应 `AccountFeeType` 的阶梯费率，则按区间累进计算。

代码中的示例：

```text
3000 × 10% + 6000 × 12% + 6000 × 14% + 2800 × 16% = 2308
```

阶梯配置按业务类型分别读取：

- `ASSETS_ACCOUNT_TRADING`
- `GLOBAL_ACCOUNT_OPEN`
- `GLOBAL_ACCOUNT_DEPOSIT`
- `QBIT_CARD_ACCOUNT_DEPOSIT`

## 六、月度返佣订单与原始订单更新

- 每种业务每月生成一笔 `Month_*` 月度返佣订单。
- 同一合伙人、同一业务类型、同一月份已有记录时，复用原记录 ID 并更新，避免重复新增。
- 原始业务订单的 `amount` 不直接改写。
- 重新计算的 `newOrderProfit`、`newOrderAmount` 会写入原订单的 `rawData`。
- 月度返佣订单状态为 `Closed`，并设置 `merchantShow = true`、`systemType = QbitInternational`。

月度返佣枚举：

- `Month_Assets_Account_Trading`
- `Month_Global_Account_Open`
- `Month_Global_Account_Deposit`
- `Month_QbitCard_Account_Deposit`

## 七、超期返佣抵扣

当客户开户超过一年后仍存在返佣订单，`overdue_rebates_deducted_job` 会执行超期处理：

1. 统计客户开户一年后产生的有效返佣金额；
2. 优先从合伙人当前返佣余额中生成 `Overdue_rebates_deducted` 扣减订单；
3. 余额不足时，按提现订单的 `transactionTime` 倒序，从提现金额、手续费和税费中抵扣；
4. 提现订单的 `rawData` 记录 `overdueAmount` 和 `allOverdueAmount`。

## 八、当前实现中的注意事项

### 8.1 负毛利判断可能失效

`buildCommissionOrder` 中会逐段修改传入的 `incomes`，最后再判断 `incomes` 是否小于 0，实际负数判断可能失效。

### 8.2 `rawData.feeRate` 可能与实际阶梯费率不一致

即使实际使用了阶梯费率，`rawData` 中仍然写入默认值 `0.1`。如果前端或报表展示该字段，可能与实际计算结果不一致。

### 8.3 任务执行时间依赖 XXL-Job

代码只定义了 XXL-Job handler，实际执行时间需要到 XXL-Job 控制台确认。

### 8.4 结算起始时间硬编码

海外 Web3 结算起始时间写死为 `2024-02-01 00:00:00`。如果调整历史结算口径，需要同步评估余额、月度返佣和超期抵扣数据。

## 九、关键代码位置

| 模块 | 文件与方法 |
|---|---|
| 月度任务入口 | `qbit-core/src/main/java/com/qbit/job/partner/PartnerCommissionJob.java` · `handler` |
| 月度毛利汇总 | `PartnerOrderServiceImpl.java` · `sendMonthCommission` |
| 阶梯返佣计算 | `PartnerOrderServiceImpl.java` · `buildCommissionOrder` |
| 原始订单生成 | `PartnerOrderServiceImpl.java` · `createPartnerOrder` |
| 月度订单查询 | `resources/mapper/PartnerOrderMapper.xml` · `selectMonthCommission` |
| 超期订单查询 | `resources/mapper/PartnerOrderMapper.xml` · `getOverdueRebateOrder` |
