# OpenAPI 月结手续费渠道毛利池设计

## 摘要

有渠道的 `open_api.month_revenue` 归为 API 月结手续费，与同账号、同渠道、同销售/部门的 `real_time_processing_fee` 共用毛利池；正毛利按产品确认的反向收入占比拆分，负毛利两类明细均归零。无渠道 OpenAPI 实收不进入该池。

## 数据流

1. `provider` 非空的 OpenAPI 实收映射为 `item = api_monthly_settlement_fee`。
2. 现有收入和成本分摊完成后，以 `settlement_month + root_account_id + provider + sale_id + department_id` 聚合渠道毛利池。
3. 池内 `real_time` 与 API 月结手续费分别获得反向收入占比的 GP；页面保留原始明细行。
4. 无渠道 OpenAPI 继续使用实际收费规则；`month_receivable` 保持未来发薪。

## 约束

- 当前无渠道 `month_revenue` 无法区分 API 月费与一次性手续费，不在本次毛利池逻辑中强制分类。
- API 月结手续费新增 GP 规则，按与普通 `real_time` 一致的 0-180 / 181-365 / 366-1095 天梯度配置。
- 不改 CDC、batch 和快照表结构；物化视图输出字段保持不变。
