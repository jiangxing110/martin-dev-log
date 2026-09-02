# 合伙人月度佣金数仓同步契约

## 1. 目标与边界

江星负责将月度佣金主表和明细同步到 Partner PostgreSQL；Partner 服务负责查询、状态机、审批、日志和交易账单。

数仓只允许写入：

```text
partner_monthly_commission
partner_monthly_commission_detail
```

数仓禁止写入：

```text
partner_commission_approval_round
partner_commission_operation_log
partner_commission_transaction_bill
```

本期不使用同步 API、消息队列或数据库触发器。

## 2. 主表同步契约

表：`partner_monthly_commission`

业务唯一键：

```text
partner_account_id + settlement_month
```

`settlement_month` 必须是自然月首日。插入时不传 `id`，由 PostgreSQL Identity 生成。

数仓可写业务字段：

| 字段 | 必填 | 说明 |
|---|---:|---|
| `partner_account_id` | 是 | 合伙人 Account ID |
| `settlement_month` | 是 | 月份首日 |
| `currency` | 是 | 本期为 USD |
| `referred_customer_count` | 是 | 推介客户数 |
| `gross_profit_commission` | 是 | 毛利分佣金额 |
| `base_markup_commission` | 是 | 底价加价金额 |
| `elastic_markup_commission` | 是 | 弹性加价金额 |
| `total_commission_amount` | 是 | 三种模式金额合计 |
| `source_batch_no` | 是 | 数仓批次号 |
| `source_updated_time` | 是 | 数仓结果生成时间 |

数仓不得更新：

```text
id
status
current_audit_level
latest_approval_round_id
version
remarks
create_time
delete_time
```

新记录依赖数据库默认值进入 `PENDING_SUBMISSION`。已有记录只有状态为 `PENDING_SUBMISSION` 时允许覆盖业务字段。

## 3. 明细同步契约

表：`partner_monthly_commission_detail`

明细唯一键：

```text
monthly_commission_id + source_detail_id
```

插入时不传 `id`，由 PostgreSQL Identity 生成。

公共字段：

```text
monthly_commission_id
source_detail_id
partner_account_id
customer_account_id
customer_name
business_type
fee_type
commission_mode
currency
card_bin
card_scheme
tier_lower_bound
tier_upper_bound
commission_amount
effective_date
detail_status
source_batch_no
remarks
```

模式字段：

| 分佣模式 | 必填字段 | 其他模式字段 |
|---|---|---|
| `BasePriceMarkup` | `interlace_base_rate`、`partner_markup_rate`、`customer_final_rate`、`commission_amount` | 写 `NULL` |
| `GrossProfitShare` | `gross_profit_contribution_amount`、`commission_share_rate`、`commission_amount` | 写 `NULL` |
| `FlexibleMarkup` | `customer_final_rate`、`commission_share_rate`、`commission_amount` | 写 `NULL` |

不适用字段必须写 `NULL`，不能写 `0`。费率和金额使用 Decimal，不使用浮点数。

字段与原型、Excel 的完整映射见：

```text
/Users/huangmingbo/workspace/code/qbit/docs/partner-monthly-commission-field-mapping.md
```

## 4. 单张账单事务

每张“合伙人 + 月份”账单独立事务处理：

1. 按业务唯一键查询主表并执行 `FOR UPDATE`。
2. 主表不存在时插入业务字段并通过 `RETURNING id` 获取月账单 ID。
3. 主表存在且状态为 `PENDING_SUBMISSION` 时更新业务字段。
4. 主表存在但状态不是 `PENDING_SUBMISSION` 时整张账单跳过，不修改主表或明细。
5. 将该月账单当前有效明细的 `delete_time` 更新为当前时间。
6. 使用月账单 ID 插入本批次全部新明细。
7. 完成账单级数量和金额校验后提交事务。
8. 任一步失败，主表和明细全部回滚。

并发创建同一业务唯一键时，以数据库唯一索引为最终保障；发生唯一键冲突后重新读取并按状态规则处理。

## 5. 幂等与重跑

- `source_batch_no` 标识本次同步批次。
- `source_detail_id` 在同一月账单内必须稳定且唯一。
- 相同业务月份重跑时覆盖当前待提交账单，不做金额累加。
- 同一批次重复执行后，主表一条、有效明细数量和金额必须保持不变。
- 部分明细失败时不能提交主表或部分明细。
- 已进入审核、待付款、已取消或已结算的账单不得被重跑覆盖。

## 6. 对账规则

每个批次至少输出以下对账结果：

| 维度 | 对账内容 |
|---|---|
| 合伙人 + 月份 + 币种 | 主表数量 |
| 合伙人 + 月份 | 推介客户数 |
| 合伙人 + 月份 + 分佣模式 | 明细佣金合计 |
| 合伙人 + 月份 | 三种模式金额与总金额 |
| 合伙人 + 月份 | 明细数量 |
| 批次 | 成功、跳过、失败账单数 |

必须满足：

```text
SUM(明细 commission_amount，按 GrossProfitShare) = gross_profit_commission
SUM(明细 commission_amount，按 BasePriceMarkup) = base_markup_commission
SUM(明细 commission_amount，按 FlexibleMarkup) = elastic_markup_commission
三种模式金额之和 = total_commission_amount
```

无法归属合伙人、未知分佣模式、明细重复、金额不一致均记为失败，不能静默丢弃。

## 7. 权限与告警

建议为数仓使用独立 PostgreSQL 账号：

- 允许插入主表业务字段。
- 允许在状态为 `PENDING_SUBMISSION` 时更新主表业务字段。
- 允许查询主表状态。
- 允许插入明细和更新明细 `delete_time`。
- 禁止写审批、日志和交易账单表。
- 禁止更新主表流程字段。

告警必须包含：

```text
partner_account_id
settlement_month
monthly_commission_id
current_status
source_batch_no
failure_reason
```

## 8. 验收清单

- [ ] 首批主表和明细同步成功。
- [ ] 相同批次重跑结果不变。
- [ ] 非待提交账单被跳过并产生告警。
- [ ] 单条明细失败时整张账单回滚。
- [ ] 三种模式金额和总金额对账一致。
- [ ] 数仓账号无法更新流程字段和其他三张表。
