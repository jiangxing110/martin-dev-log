--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-11-25
-- Description:    销售绩效实际收入视图组成查询
-- Usage:
--   1. 修改 params 中的 activity_month 和 target_user_id。
--   2. target_user_id 按 sale_id OR am_id 匹配；设为 NULL 查询该月全部销售/AM。
--   3. 本脚本只读物化视图，不刷新或修改任何数据。
--   4. 第一条查询按收入类型汇总；第二条查询列出物化视图粒度的明细行。
--********************************************************************--

-- 收入口径提示：
--   global_account_income: 入金费、付款费、汇兑收入。
--   qbit_card: main_fee、virtual_card_create_fee、recharge_fee、pc_channel_rebate。
--   crypto_connect_income: 加密承兑收入。
--   offline_income: 线下 API 收入。
--   card_creation_fee: 实体卡制卡费收入。
--   month_revenue: OpenAPI 实际收款，按实际到账日期归属；不含 month_receivable 应收。
--   bb_channel_cashback: BB 渠道返现，取 cashback_income。
--   qi_channel_cashback: QI Interchange + Incentive 返现合计，只计 special_fee_type IS NULL。
--     该视图已将两项合并，不能从此视图进一步拆分 Interchange / Incentive。

-- 查询一：按月份、收入类型、产品、渠道及 OpenAPI 账单月份汇总。
WITH params AS (
    SELECT
        DATE '2026-11-01' AS activity_month,
        'edfc4d0a-2131-440f-87a3-f3781767fa7f'::varchar AS target_user_id
),
filtered_income AS (
    SELECT income.*
    FROM dws.mv_sales_commission_performance_income_recent income
    CROSS JOIN params
    WHERE income.activity_month = params.activity_month
      AND (
          params.target_user_id IS NULL
          OR income.sale_id = params.target_user_id
          OR income.am_id = params.target_user_id
      )
)
SELECT
    activity_month,
    income_type,
    CASE income_type
        WHEN 'global_account_income' THEN '全球账户收入'
        WHEN 'main_fee' THEN '量子卡主手续费'
        WHEN 'virtual_card_create_fee' THEN '虚拟卡开卡费'
        WHEN 'recharge_fee' THEN '量子卡充值费'
        WHEN 'pc_channel_rebate' THEN '量子卡渠道返现'
        WHEN 'crypto_connect_income' THEN '加密承兑收入'
        WHEN 'offline_income' THEN '线下收入'
        WHEN 'card_creation_fee' THEN '实体卡制卡费收入'
        WHEN 'month_revenue' THEN 'OpenAPI 实际收款'
        WHEN 'bb_channel_cashback' THEN 'BB 渠道返现'
        WHEN 'qi_channel_cashback' THEN 'QI 渠道返现'
        ELSE income_type
    END AS income_name,
    product,
    provider,
    bill_month,
    COUNT(*) AS view_row_count,
    COUNT(DISTINCT root_account_id) AS root_account_count,
    SUM(income_amount)::numeric(20, 4) AS income_amount
FROM filtered_income
GROUP BY activity_month, income_type, product, provider, bill_month
ORDER BY income_type, product, provider, bill_month;

-- 查询二：列出该收入视图的每条归属明细（视图粒度已按账户/产品/渠道/销售/AM 汇总）。
WITH params AS (
    SELECT
        DATE '2026-11-01' AS activity_month,
        'edfc4d0a-2131-440f-87a3-f3781767fa7f'::varchar AS target_user_id
),
filtered_income AS (
    SELECT income.*
    FROM dws.mv_sales_commission_performance_income_recent income
    CROSS JOIN params
    WHERE income.activity_month = params.activity_month
      AND (
          params.target_user_id IS NULL
          OR income.sale_id = params.target_user_id
          OR income.am_id = params.target_user_id
      )
)
SELECT
    id,
    activity_month,
    bill_month,
    root_account_id,
    product,
    provider,
    income_type,
    CASE income_type
        WHEN 'global_account_income' THEN '全球账户收入'
        WHEN 'main_fee' THEN '量子卡主手续费'
        WHEN 'virtual_card_create_fee' THEN '虚拟卡开卡费'
        WHEN 'recharge_fee' THEN '量子卡充值费'
        WHEN 'pc_channel_rebate' THEN '量子卡渠道返现'
        WHEN 'crypto_connect_income' THEN '加密承兑收入'
        WHEN 'offline_income' THEN '线下收入'
        WHEN 'card_creation_fee' THEN '实体卡制卡费收入'
        WHEN 'month_revenue' THEN 'OpenAPI 实际收款'
        WHEN 'bb_channel_cashback' THEN 'BB 渠道返现'
        WHEN 'qi_channel_cashback' THEN 'QI 渠道返现'
        ELSE income_type
    END AS income_name,
    sale_id,
    am_id,
    income_amount,
    refreshed_at
FROM filtered_income
ORDER BY income_type, provider, root_account_id, bill_month, sale_id, am_id;
