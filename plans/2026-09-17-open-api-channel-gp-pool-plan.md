# OpenAPI Channel GP Pool Implementation Plan

**Goal:** 为有渠道的 OpenAPI 月结手续费实现与 real_time 共用的 effective_revenue 正向分摊毛利池。

1. 在物化视图收入层将有渠道 `month_revenue` 标识为 `api_monthly_settlement_fee`。
2. 在成本分摊后新增渠道毛利池，按账号、渠道、销售和部门汇总，并覆盖池内明细 GP。
3. 在规则维表增加 API 月结手续费 GP 梯度规则。
4. 使用已记录的 2026-08 基线校验负毛利归零和正毛利 effective_revenue 正向分摊。
