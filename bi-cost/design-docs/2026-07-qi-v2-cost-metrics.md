# QI V2 成本指标计算逻辑

## 摘要

QI DWS v2 只记录两类核心信息：

- 成本/返现计费基数。
- 基数对应的月度 rate。

最终金额不落 DWS，由下游按 `base * rate` 计算。这样表结构保持轻量，也避免旧表里 `*_rate` 实际存基数的语义混乱。

参考文件：

- `bi_month/QI客户毛利2026-06.sql`
- `flink/quantum-v2/qi/table-scripts/dwm_qi_card_transaction_detail_v2_p.sql`
- `flink/quantum-v2/qi/table-scripts/dws_qi_card_finance_daily_v2_p.sql`
- `flink/quantum-v2/qi/batch/dwm_online_qi_card_transaction_detail_v2-batch-sql.sql`
- `flink/quantum-v2/qi/batch/dws_online_qi_card_finance_daily_v2-batch-sql.sql`
- `flink/quantum-v2/qi/cdc/dws_online_qi_card_finance_daily_v2-cdc-sql.sql`

## DWS 粒度

| 字段 | 说明 |
|---|---|
| `report_date` | 报表日期，来源交易日期 |
| `account_id` | 账号 |
| `sale_id` | 销售 |
| `am_id` | AM |

状态流转通过 DWS 删除重算保证一致性。比如 `Pending -> Failed` 后，CDC 找到影响月份，删除该月份 DWS，再从 DWM 当前状态重新聚合。

## DWM 字段设计原因

| DWM 字段 | 为什么需要 |
|---|---|
| `id` | 对应 `qbit_card_transaction.id`，用于 upsert 和硬删除对账 |
| `transaction_id` | 关联 `quantum_card_transaction_extend.transaction_id` |
| `account_id` | DWS 汇总维度 |
| `account_type` / `account_category` / `system_type` | 下游 total/gross 维度 |
| `status` | 状态机核心字段，DWS 按 `Closed/Pending` 过滤 |
| `transaction_time` | 报表日期和分区基准 |
| `billing_amount` | 所有成本/返现基数的金额来源 |
| `is_hk_region` | 区分非港和香港口径 |
| `business_type` | 区分 `Consumption`、`Reversal`、`Credit` |
| `has_special_code` | ACS VIP、VRM 需要排除特殊码 |
| `source_update_time` | CDC 默认昨天变化扫描 |
| `source_delete_time` | 软删除变化扫描 |
| `sale_id` / `am_id` | DWS 汇总维度 |

## DWS 字段

QI DWS v2 业务字段为 15 个：

| 类型 | 字段 |
|---|---|
| 成本基数 | `cost_reimbursement_base_amt`、`cost_service_base_amt`、`cost_acs_regular_base_amt`、`cost_acs_vip_base_amt`、`cost_vrm_base_amt` |
| 返现基数 | `rebate_interchange_base_amt`、`rebate_incentive_base_amt` |
| 成本 rate | `cost_reimbursement_rate`、`cost_service_rate`、`cost_acs_regular_rate`、`cost_acs_vip_rate`、`cost_vrm_rate` |
| 返现 rate | `rebate_interchange_rate`、`rebate_incentive_rate` |
| 固定成本 | `cost_fixed_fee` |

## Rate 来源

Rate 从 `ods_bi_month_tag` 按月份取，不使用 `ods_account_fee`。

| DWS 字段 | tag |
|---|---|
| `cost_reimbursement_rate` | `QI_COST_REIMBURSEMENT_RATE` |
| `cost_service_rate` | `QI_COST_SERVICE_RATE` |
| `cost_acs_regular_rate` | `QI_COST_ACS_REGULAR_RATE` |
| `cost_acs_vip_rate` | `QI_COST_ACS_VIP_RATE` |
| `cost_vrm_rate` | `QI_COST_VRM_RATE` |
| `rebate_interchange_rate` | `QI_REBATE_INTERCHANGE_RATE` |
| `rebate_incentive_rate` | `QI_REBATE_INCENTIVE_RATE` |

脚本默认 rate 缺失时按 `1` 兜底。

## 指标口径

### Reimbursement 成本

| 项 | 口径 |
|---|---|
| 基数字段 | `cost_reimbursement_base_amt` |
| 基数公式 | 非港 `Consumption` 且 `status IN ('Closed','Pending')` 的 `billing_amount * 0.0135` |
| rate 字段 | `cost_reimbursement_rate` |
| 结果公式 | `cost_reimbursement_base_amt * cost_reimbursement_rate` |

### Card Service 成本

| 项 | 口径 |
|---|---|
| 基数字段 | `cost_service_base_amt` |
| 过滤条件 | 非港，`status IN ('Closed','Pending')`，`business_type IN ('Consumption','Reversal','Credit')` |
| 阶梯 | `<5:0.00095`，`<10:0.00145`，`<50:0.0022`，`<250:0.0037`，其他 `0.00445` |
| 正负 | `Consumption` 为正，`Reversal/Credit` 为负 |
| rate 字段 | `cost_service_rate` |
| 结果公式 | `cost_service_base_amt * cost_service_rate` |

### ACS 普通成本

| 项 | 口径 |
|---|---|
| 基数字段 | `cost_acs_regular_base_amt` |
| 过滤条件 | 非港，`Consumption`，`status IN ('Closed','Pending')` |
| 阶梯 | `<5:0.01`，`<10:0.055`，`<50:0.08`，`<250:0.12`，其他 `0.14` |
| rate 字段 | `cost_acs_regular_rate` |
| 结果公式 | `cost_acs_regular_base_amt * cost_acs_regular_rate` |

### ACS VIP 成本

| 项 | 口径 |
|---|---|
| 基数字段 | `cost_acs_vip_base_amt` |
| 过滤条件 | 非港，`Consumption`，`has_special_code = FALSE` |
| 阶梯 | `<5:0.04`，`<10:0.22`，`<50:0.255`，`<250:0.48`，其他 `0.56` |
| rate 字段 | `cost_acs_vip_rate` |
| 结果公式 | `cost_acs_vip_base_amt * cost_acs_vip_rate` |

### VRM 成本

| 项 | 口径 |
|---|---|
| 基数字段 | `cost_vrm_base_amt` |
| 过滤条件 | 非港，`Consumption`，`has_special_code = FALSE` |
| 基数公式 | 满足条件笔数 * `0.09` |
| rate 字段 | `cost_vrm_rate` |
| 结果公式 | `cost_vrm_base_amt * cost_vrm_rate` |

### Interchange 返现

| 项 | 口径 |
|---|---|
| 基数字段 | `rebate_interchange_base_amt` |
| 基数公式 | 非港 `Consumption` 且 `status IN ('Closed','Pending')` 的 `billing_amount * 0.02` |
| rate 字段 | `rebate_interchange_rate` |
| 结果公式 | `rebate_interchange_base_amt * rebate_interchange_rate` |

### Incentive 返现

| 项 | 口径 |
|---|---|
| 基数字段 | `rebate_incentive_base_amt` |
| 基数公式 | `Consumption` 且 `status IN ('Closed','Pending')` 的 `billing_amount * 0.0118` |
| rate 字段 | `rebate_incentive_rate` |
| 结果公式 | `rebate_incentive_base_amt * rebate_incentive_rate` |

## 固定成本

`cost_fixed_fee` 仍然单独落表，当前脚本按月 DWS 行数均摊：

```sql
cost_fixed_fee = month_fixed_fee / month_row_count
```

后续如果要贴近 BI 的净消费占比分摊，可以再把固定成本拆成独立回刷脚本。

## 验收口径

- DWS v2 表只保留 7 个基数、7 个 rate、1 个固定成本字段。
- DWS v2 不再落 `*_vol`、`*_count`、`*_amt` 结果字段。
- 修改 `ods_bi_month_tag` 后，CDC 能识别对应月份并重算 rate。
- 修改一笔交易 `Pending -> Failed` 后，CDC 能重算月份并剔除该笔基数。
