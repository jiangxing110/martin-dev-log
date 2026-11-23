# Open API 月账单应收/实收拆行设计

## 目标

详情页和详情导出能按 provider 识别 Open API 月账单应收与实收，避免两种金额合并在同一客户/产品/provider 行后无法分别核对。

## 当前口径

- Open API 应收来源：`dws_metrics_sales_revenue_monthly` 的 `product = 'open_api'`、`metric_code = 'month_receivable'`，按结算月首日归属。
- Open API 实收来源：`dws_sales_metric_daily` 的 `metric_code = 'api_client_bill_monthly_fee_received_amount'`，保留 provider；作为实收基数。
- `Cashflow_Rev_sale` 仍从实收基数扣除月结 KYC、实体卡手续费、最低承诺三项。
- `Cashflow_Rev` 使用新实收指标原值。其它实时收入、返现、成本以及三类毛利规则维持现行口径，包括 `physical_card_gp`。

## 方案

1. **拆成两列金额**：详情仍是一客户/产品/provider 一行，增加应收和实收两列。缺点是用户已要求应收/实收拆成多行，且同一行继续混合不同账单阶段。
2. **数据层类型字段 + product 后缀展示（采用）**：V1 视图和明细快照增加内部字段 `api_bill_type`；API 应收行取 `RECEIVABLE`，实收行取 `RECEIVED`，其它来源行为空。Batch 传递该字段。详情接口和详情导出不暴露该字段，而按它把 `product` 显示为 `open_api_receivable` 或 `open_api_received`；其它行继续使用原产品值。按销售、根账户、展示 product、provider 聚合。

## 影响范围

- V1 估算物化视图输出内部 `api_bill_type`：应收行使用 `metric_code = 'month_receivable'`，实收行使用 `metric_code = 'api_client_bill_monthly_fee_received_amount'`，其它来源行类型为空。
- 明细快照表增加 `api_bill_type` 列；明细快照 Batch 增加对应 source、view、sink 列并原样传递。汇总快照表和 Batch 不变。
- 详情 Mapper 按 `api_bill_type` 将展示 product 改为 `open_api_receivable` / `open_api_received` 并按展示 product 分组。类型列不进入详情 VO 或导出 BO。
- 详情分页和详情导出使用相同分组与 product 值；汇总列表、汇总导出仍使用原 product 及聚合口径。
- 接口文档说明类型值；11 个业务指标的既有公式不变。

## 注意事项

Open API 月账单应收来源只有结算月粒度，继续按月初日期筛选；查询区间不含月初时不会包含该月应收。实收按日指标的 `report_date` 筛选。金额保留正负号，不归零。
