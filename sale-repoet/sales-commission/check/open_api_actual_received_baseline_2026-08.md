# OpenAPI 实收与毛利基线（2026-08）

- Created Time: 2026-09-17 16:45:53
- Updated Time: 2026-09-17 17:19:50
- 账户：`9a6e4d51-d5cf-471f-8c13-9922c1213638`
- 结算月：`2026-08-01`
- 销售：`269ce892-8728-4954-bb05-613163dbd142`
- 部门：`1740319923059597313`
- 物化视图刷新时间：`2026-09-17 16:48:54.05538+08`

## 规则待实现口径

销售毛利以实际收到的钱统计。

- API 月费、API 一次性手续费：不参与渠道毛利分摊，直接按对应提成费率计算。
- API 月结手续费：与 `real_time` 使用相同毛利提成规则。
- 毛利池：`real_time + API月结手续费 - COGS - 返现`。
- 毛利池小于等于 0：`real_time` 和 API 月结手续费均不计毛利/返佣。
- 毛利池大于 0：按产品示例采用**反向收入占比**拆分毛利：
  - `real_time` 毛利 = 毛利池 × API 月结手续费收入 / (`real_time` 收入 + API 月结手续费收入)
  - API 月结手续费毛利 = 毛利池 × `real_time` 收入 / (`real_time` 收入 + API 月结手续费收入)
- 页面仍需将 `real_time` 与 API 账单收入分别展示。

示例：`real_time = 200`、API 月结手续费 = `100`、成本 = `150`、返现 = `100` 时，毛利池为 `50`：

```text
real_time 毛利       = 50 × 100 / 300 = 16.67
API 月结手续费毛利  = 50 × 200 / 300 = 33.33
```

### OpenAPI 实收分类

当前实收源为 `dws.dws_metrics_sales_revenue_monthly` 的 `open_api.month_revenue`：

| 源表条件 | 业务分类 | 计佣方式 |
|---|---|---|
| `provider` 非空（如 BB、BZ） | API 月结手续费 | 与同账号、同渠道的 `real_time` 进入共同毛利池，按上述反向收入占比分摊 GP |
| `provider` 为空 | 非渠道 API 收入 | 不参与渠道毛利池，需按 API 月费或 API 一次性手续费的实际收费规则计佣 |
| `metric_code = month_receivable` | API 月账单应收 | 仅作 `future_payout` 展示，不参与当期实收毛利池 |

当前源表的无渠道 `month_revenue` 没有收费类型字段，无法区分：

- API 月费：按活跃天数的实际收费规则（当前规则为 0-365 天 10%、366-1095 天 0%）；
- API 一次性手续费：按实际收费 15%。

因此，在数据侧提供 `api_monthly_fee` / `api_one_time_fee` 的 `metric_code` 或等价收费类型字段前，不能自动对无渠道实收选择 10% 或 15%。如需临时上线，必须明确约定无渠道 `month_revenue` 的默认归类。

### 视图改造原则

1. API 月结手续费需要使用新 `item = api_monthly_settlement_fee`，不再匹配当前 `api_monthly_fee` 的实收 10% 规则。
2. 渠道毛利池按 `settlement_month + root_account_id + provider + sale_id + department_id` 聚合。
3. 毛利池为负或零时，`real_time` 与 API 月结手续费的 GP 均归零。
4. 页面仍保留 `real_time` 和 API 月结手续费两条展示记录，仅 GP/返佣来自同一个渠道毛利池的反向占比拆分。

## 源表实收基线

查询：

```sql
SELECT r.*
FROM dws.dws_metrics_sales_revenue_monthly r
WHERE r.product = 'open_api'
  AND r.metric_code <> 'month_receivable'
  AND r.root_account_id = '9a6e4d51-d5cf-471f-8c13-9922c1213638';
```

| settlement_month | report_date | metric_code | provider | income_value |
|---|---|---|---|---:|
| 2026-08-01 | 2026-07-01 | month_revenue | BB | 932.9220 |
| 2026-08-01 | 2026-07-01 | month_revenue | BZ | 0.2500 |
| 2026-08-01 | 2026-07-01 | month_revenue | 无渠道 | 4686.7010 |

## 当前物化视图结果基线

| product | provider | item | source_type | commission_stage | effective_revenue | cogs | gp | estimated_commission |
|---|---|---|---|---|---:|---:|---:|---:|
| crypto | 无渠道 | 无 | real_time_processing_fee | current_payout | 0.0000 | 774.0000 | 0.0000 | 0.0000 |
| open_api | 无渠道 | api_monthly_fee | api_monthly_billing | future_payout | 36455.1700 | 0.0000 | 36455.1700 | 3645.5170 |
| open_api | 无渠道 | api_monthly_fee | billing_decline_fee | current_payout | 4686.7010 | 0.0000 | 4686.7010 | 468.6701 |
| open_api | BB | api_monthly_fee | billing_decline_fee | current_payout | 932.9220 | 0.0000 | 932.9220 | 93.2922 |
| open_api | BZ | api_monthly_fee | billing_decline_fee | current_payout | 0.2500 | 0.0000 | 0.2500 | 0.0250 |
| qbit_card | 无渠道 | 无 | real_time_processing_fee | current_payout | 8900.8000 | 0.0000 | 8900.8000 | 1068.0960 |
| qbit_card | BB | 无 | real_time_processing_fee | current_payout | 12653.8938 | 26080.2689 | 0.0000 | 0.0000 |
| qbit_card | BZ | 无 | real_time_processing_fee | current_payout | 802.8800 | 6100.7414 | 0.0000 | 0.0000 |
| qbit_card | IQ | 无 | real_time_processing_fee | current_payout | 0.0000 | 0.0000 | 0.0000 | 0.0000 |
| qbit_card | PC | 无 | real_time_processing_fee | current_payout | 0.0000 | 0.0000 | 0.0000 | 0.0000 |

## 后续对比重点

后续实现 API 毛利拆分后，使用本账户、结算月与上表对比：

1. `open_api / api_monthly_settlement_fee / billing_decline_fee` 是否按渠道归入 API 月结手续费毛利池。
2. `open_api / api_monthly_billing / future_payout` 是否仍独立按实际费用返佣，不参与毛利池。
3. `real_time + API月结手续费 - COGS - 返现` 的毛利是否在渠道维度正确分摊；毛利小于等于零时，两部分均为零。
