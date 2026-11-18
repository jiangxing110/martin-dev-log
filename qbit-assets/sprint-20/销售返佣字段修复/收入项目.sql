WITH params AS (
    SELECT DATE '2026-09-01' AS start_date,
           DATE '2026-10-01' AS end_date_exclusive
),
-- 日汇总层：三项手续费收入按月、归属键拆开。
fee_by_month AS (
    SELECT
        date_trunc('month', d.create_date::timestamp)::date AS settlement_month,
        d.root_account_id,
        NULLIF(TRIM(d.provider_st), '') AS provider,
        NULLIF(TRIM(d.sale_id), '') AS sale_id,
        NULLIF(TRIM(d.am_id), '') AS am_id,
        SUM(d.income_value) FILTER (WHERE d.metric_code = 'deposit_fee') AS deposit_fee,
        SUM(d.income_value) FILTER (WHERE d.metric_code = 'payment_fee') AS payment_fee,
        SUM(d.income_value) FILTER (WHERE d.metric_code = 'fx_income') AS fx_income,
        SUM(d.income_value)::numeric(20,3) AS global_account_income,
        0::numeric AS client_rebate_deduction
    FROM dwm.dwm_global_account_sales_revenue_daily d
    CROSS JOIN params p
    WHERE d.create_date >= p.start_date
      AND d.create_date < p.end_date_exclusive
      AND d.metric_code IN ('deposit_fee', 'payment_fee', 'fx_income')
      AND NULLIF(TRIM(d.root_account_id), '') IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5
),
-- 归因明细层：客户返现按同一归属键汇总，转三位小数后取负。
rebate_by_month AS (
    SELECT
        date_trunc('month', r.create_date::timestamp)::date AS settlement_month,
        r.root_account_id,
        NULLIF(TRIM(r.provider), '') AS provider,
        NULLIF(TRIM(r.sale_id), '') AS sale_id,
        NULLIF(TRIM(r.am_id), '') AS am_id,
        0::numeric AS deposit_fee,
        0::numeric AS payment_fee,
        0::numeric AS fx_income,
        0::numeric AS global_account_income,
        -SUM(r.income_value)::numeric(20,3) AS client_rebate_deduction
    FROM dwm.dwm_client_rebate_sales_attribution_detail r
    CROSS JOIN params p
    WHERE r.create_date >= p.start_date
      AND r.create_date < p.end_date_exclusive
      AND r.product = 'global_account'
      AND r.metric_code = 'global_account_client_rebates'
      AND NULLIF(TRIM(r.root_account_id), '') IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5
),
components AS (
    SELECT * FROM fee_by_month
    UNION ALL
    SELECT * FROM rebate_by_month
)
SELECT
    settlement_month,
    root_account_id,
    provider,
    sale_id,
    am_id,
    COALESCE(SUM(deposit_fee), 0) AS deposit_fee,
    COALESCE(SUM(payment_fee), 0) AS payment_fee,
    COALESCE(SUM(fx_income), 0) AS fx_income,
    SUM(global_account_income)::numeric(20,3) AS global_account_income,
    SUM(client_rebate_deduction)::numeric(20,3) AS client_rebate_deduction,
    SUM(global_account_income + client_rebate_deduction)::numeric(20,3) AS main
FROM components
GROUP BY settlement_month, root_account_id, provider, sale_id, am_id
ORDER BY settlement_month, root_account_id, provider, sale_id, am_id;
统计全球账户的收入 global_account_income

WITH params AS (
    SELECT DATE '2026-09-01' AS start_date,
           DATE '2026-10-01' AS end_date_exclusive
),
source_rows AS (
    SELECT create_date AS business_date, root_account_id,
           provider_st AS provider, sale_id, am_id, metric_code,
           'main_fee' AS component, income_value
    FROM dwm.dwm_qbit_card_main_fee_sales_detail

    UNION ALL

    SELECT create_date, root_account_id,
           provider_st, sale_id, am_id, metric_code,
           'virtual_card_create_fee', income_value
    FROM dwm.dwm_qbit_virtual_card_create_fee_sales_detail

    UNION ALL

    SELECT create_month, root_account_id,
           provider_st, sale_id, am_id, 'qbit_account_recharge_fee',
           'recharge_fee', income_value
    FROM dwm.dwm_qbit_card_recharge_fee_channel_monthly_share

    UNION ALL

    SELECT create_date, root_account_id,
           provider_st, sale_id, am_id, metric_code,
           'pc_channel_rebate', income_value
    FROM dwm.dwm_qbit_card_cash_back_file_up_sales_detail
    WHERE product = 'qbit_card'
      AND metric_code = 'qbit_card_cash_back_file_up_amount'

    UNION ALL

    SELECT create_date, root_account_id,
           provider, sale_id, am_id, metric_code,
           'client_rebate', income_value
    FROM dwm.dwm_client_rebate_sales_attribution_detail
    WHERE product = 'qbit_card'
      AND metric_code = 'qbit_card_client_rebates'
),
monthly_components AS (
    SELECT
        date_trunc('month', s.business_date::timestamp)::date AS settlement_month,
        s.root_account_id,
        NULLIF(TRIM(s.provider), '') AS provider,
        NULLIF(TRIM(s.sale_id), '') AS sale_id,
        NULLIF(TRIM(s.am_id), '') AS am_id,
        s.metric_code,
        s.component,
        SUM(s.income_value)::numeric(20,3) AS amount
    FROM source_rows s
    CROSS JOIN params p
    WHERE s.business_date >= p.start_date
      AND s.business_date < p.end_date_exclusive
      AND NULLIF(TRIM(s.root_account_id), '') IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5, 6, 7
)
SELECT
    settlement_month,
    root_account_id,
    provider,
    sale_id,
    am_id,
    COALESCE(SUM(amount) FILTER (WHERE component = 'main_fee'), 0)
        AS main_fee,
    COALESCE(SUM(amount) FILTER (WHERE component = 'virtual_card_create_fee'), 0)
        AS virtual_card_create_fee,
    COALESCE(SUM(amount) FILTER (WHERE component = 'recharge_fee'), 0)
        AS recharge_fee,
    COALESCE(SUM(amount) FILTER (WHERE component = 'pc_channel_rebate'), 0)
        AS pc_channel_rebate,
    -COALESCE(SUM(amount) FILTER (WHERE component = 'client_rebate'), 0)
        AS client_rebate_deduction,
    SUM(CASE WHEN component = 'client_rebate' THEN -amount ELSE amount END)
        ::numeric(20,3) AS main
FROM monthly_components
GROUP BY 1, 2, 3, 4, 5
ORDER BY 1, 2, 3, 4, 5;
量子卡收入:main_fee+virtual_card_create_fee +recharge_fee+pc_channel_rebate

WITH params AS (
    SELECT DATE '2026-09-01' AS start_date,
           DATE '2026-10-01' AS end_date_exclusive
),
-- 承兑手续费：取日汇总，月表收入编码为 crypto_connect_income。
fee_by_month AS (
    SELECT
        date_trunc('month', d.create_date::timestamp)::date AS settlement_month,
        d.root_account_id,
        NULL::text AS provider,
        NULLIF(TRIM(d.sale_id), '') AS sale_id,
        NULLIF(TRIM(d.am_id), '') AS am_id,
        SUM(d.income_value)::numeric(20,3) AS crypto_connect_income,
        0::numeric AS client_rebate_deduction
    FROM dwm.dwm_crypto_connect_sales_revenue_daily d
    CROSS JOIN params p
    WHERE d.create_date >= p.start_date
      AND d.create_date < p.end_date_exclusive
      AND d.metric_code = 'assets_acceptance_fee'
      AND NULLIF(TRIM(d.root_account_id), '') IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5
),
-- 客户返现：取归因 Detail，分组汇总转三位后取负。
rebate_by_month AS (
    SELECT
        date_trunc('month', r.create_date::timestamp)::date AS settlement_month,
        r.root_account_id,
        NULLIF(TRIM(r.provider), '') AS provider,
        NULLIF(TRIM(r.sale_id), '') AS sale_id,
        NULLIF(TRIM(r.am_id), '') AS am_id,
        0::numeric AS crypto_connect_income,
        -(SUM(r.income_value)::numeric(20,3)) AS client_rebate_deduction
    FROM dwm.dwm_client_rebate_sales_attribution_detail r
    CROSS JOIN params p
    WHERE r.create_date >= p.start_date
      AND r.create_date < p.end_date_exclusive
      AND r.product = 'crypto_connect'
      AND r.metric_code = 'crypto_connect_client_rebates'
      AND NULLIF(TRIM(r.root_account_id), '') IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5
),
components AS (
    SELECT * FROM fee_by_month
    UNION ALL
    SELECT * FROM rebate_by_month
)
SELECT
    settlement_month,
    root_account_id,
    provider,
    sale_id,
    am_id,
    SUM(crypto_connect_income)::numeric(20,3) AS crypto_connect_income,
    SUM(client_rebate_deduction)::numeric(20,3) AS client_rebate_deduction,
    (
        SUM(crypto_connect_income) + SUM(client_rebate_deduction)
    )::numeric(20,3) AS main
FROM components
GROUP BY settlement_month, root_account_id, provider, sale_id, am_id
ORDER BY settlement_month, root_account_id, provider, sale_id, am_id;
加密收入:crypto_connect_income




WITH params AS (
    SELECT DATE '2026-08-01' AS start_date,
           DATE '2026-09-01' AS end_date_exclusive
),
offline_api_detail AS (
    SELECT
        d.settlement_month,
        d.root_account_id,
        d.provider,
        d.sale_id,
        d.am_id,
        d.metric_value
    FROM dwm.dwm_bi_month_tag_sales_attribution_detail d
    CROSS JOIN params p
    WHERE d.settlement_month >= p.start_date
      AND d.settlement_month < p.end_date_exclusive
      AND d.product = 'bi_month_tag'
      AND d.metric_code = 'offline_api_income_amount'
)
SELECT
    settlement_month AS report_date,
    settlement_month,
    root_account_id,
    'bi_month_tag' AS product,
    'offline_api_income_amount' AS metric_code,
    provider,
    sale_id,
    am_id,
    ROUND(SUM(metric_value), 3)::numeric(20,3) AS income_value,
    'base_metric' AS type_desc,
    COUNT(*) AS source_record_count
FROM offline_api_detail
GROUP BY settlement_month, root_account_id, provider, sale_id, am_id
ORDER BY settlement_month, root_account_id, provider, sale_id, am_id;
线下收入:income_value

WITH params AS (
    SELECT DATE '2026-10-01' AS start_date,
           DATE '2026-11-01' AS end_date_exclusive
),
contributions AS (
    SELECT
        f.create_date,
        f.root_account_id,
        NULLIF(TRIM(f.provider_st), '') AS provider,
        NULLIF(TRIM(f.sale_id), '') AS sale_id,
        NULLIF(TRIM(f.am_id), '') AS am_id,
        f.income_value::numeric AS card_creation_fee,
        0::numeric AS cost_card_quantity
    FROM dwm.dwm_qbit_card_wallet_fee_sales_detail f
    CROSS JOIN params p
    WHERE f.create_date >= p.start_date
      AND f.create_date < p.end_date_exclusive
      AND f.product = 'qbit_card'
      AND f.metric_code = 'card_creation_fee_amount'

    UNION ALL

    SELECT
        d.create_date,
        d.root_account_id,
        NULLIF(TRIM(d.provider_st), ''),
        NULLIF(TRIM(d.sale_id), ''),
        NULLIF(TRIM(d.am_id), ''),
        0::numeric,
        CASE d.metric_code
            WHEN 'active_physical_card_count' THEN d.card_quantity::numeric
            WHEN 'physical_card_other_created_count' THEN -d.card_quantity::numeric
        END
    FROM dwm.dwm_qbit_physical_card_created_daily d
    CROSS JOIN params p
    WHERE d.create_date >= p.start_date
      AND d.create_date < p.end_date_exclusive
      AND d.product = 'qbit_card'
      AND d.metric_code IN (
          'active_physical_card_count',
          'physical_card_other_created_count'
      )
),
monthly AS (
    SELECT
        date_trunc('month', create_date::timestamp)::date AS settlement_month,
        root_account_id,
        provider,
        sale_id,
        am_id,
        SUM(card_creation_fee) AS card_creation_fee,
        SUM(cost_card_quantity) AS cost_card_quantity
    FROM contributions
    GROUP BY 1, 2, 3, 4, 5
)
SELECT
    settlement_month,
    root_account_id,
    provider,
    sale_id,
    am_id,
    card_creation_fee,
    cost_card_quantity,
    4 * cost_card_quantity AS card_creation_cost,
    ROUND((card_creation_fee - 4 * cost_card_quantity) * 0.15, 3)
        AS physical_card_gp
FROM monthly
ORDER BY settlement_month, root_account_id, provider, sale_id, am_id;
实体卡fee:card_creation_fee


WITH params AS (
    SELECT DATE '2026-09-01' AS start_date,
           DATE '2026-10-01' AS end_date_exclusive
),
allocation_codes(metric_code, include_in_revenue) AS (
    VALUES
        ('api_client_bill_monthly_fee_received_amount', TRUE),
        ('api_client_bill_monthly_fx_fee_received_amount', TRUE),
        ('api_client_bill_monthly_crypto_fee_received_amount', TRUE),
        ('api_client_bill_one_time_api_fee_received_amount', TRUE),
        ('api_client_bill_monthly_api_fee_received_amount', TRUE),
        ('api_client_bill_revenue_adjustment_received_amount', TRUE),
        ('api_client_bill_uncategorized_fee_received_amount', TRUE),
        ('api_client_bill_monthly_kyc_fee_received_amount', FALSE),
        ('api_client_bill_minimum_commitment_received_amount', FALSE),
        ('api_client_bill_physical_card_fee_received_amount', FALSE)
),
revenue_detail AS (
    SELECT
        d.state_date AS report_date,
        d.root_account_id,
        d.provider,
        NULLIF(TRIM(d.sale_id), '') AS sale_id,
        NULLIF(TRIM(d.am_id), '') AS am_id,
        d.metric_code,
        d.income_value,
        CASE
            WHEN d.source_detail_id ~ '^DEBIT_RECORD:[0-9]+:'
                THEN split_part(d.source_detail_id, ':', 2)::bigint
            WHEN d.metric_source_id ~ '^RECEIVED:[0-9]+:'
                THEN split_part(d.metric_source_id, ':', 2)::bigint
        END AS debit_event_id
    FROM dwm.dwm_open_api_monthly_revenue_attribution_detail d
    CROSS JOIN params p
    WHERE d.product = 'open_api'
      AND d.state_date >= p.start_date
      AND d.state_date < p.end_date_exclusive
),
bill_month_by_debit AS (
    SELECT
        ids.debit_event_id,
        CASE WHEN LEFT(TRIM(b.bill_month), 7) ~ '^[1-9][0-9]{3}-(0[1-9]|1[0-2])$'
             THEN (LEFT(TRIM(b.bill_month), 7) || '-01')::date
        END AS settlement_month
    FROM (SELECT DISTINCT debit_event_id FROM revenue_detail) ids
    LEFT JOIN public.api_client_debit_record debit ON debit.id = ids.debit_event_id
    LEFT JOIN public.api_client_bill b ON b.id = debit.bill_id
),
allocated_by_debit AS (
    -- 排除项仍计入已分摊总额，避免从残差漏回收入。
    SELECT d.debit_event_id, SUM(d.income_value)::numeric(38,6) AS allocated_amount
    FROM revenue_detail d
    JOIN allocation_codes c ON c.metric_code = d.metric_code
    GROUP BY d.debit_event_id
),
contributions AS (
    SELECT
        d.report_date, b.settlement_month, d.root_account_id,
        d.provider, d.sale_id, d.am_id,
        d.income_value AS included_fee_amount,
        0::numeric AS residual_amount
    FROM revenue_detail d
    JOIN allocation_codes c ON c.metric_code = d.metric_code
    LEFT JOIN bill_month_by_debit b ON b.debit_event_id = d.debit_event_id
    WHERE c.include_in_revenue

    UNION ALL

    SELECT
        d.report_date, b.settlement_month, d.root_account_id,
        NULL::text AS provider, d.sale_id, d.am_id,
        0::numeric,
        (d.income_value - COALESCE(a.allocated_amount, 0))::numeric(38,6)
    FROM revenue_detail d
    LEFT JOIN bill_month_by_debit b ON b.debit_event_id = d.debit_event_id
    LEFT JOIN allocated_by_debit a ON a.debit_event_id = d.debit_event_id
    WHERE d.metric_code = 'api_client_bill_actual_received_amount'
)
SELECT
    report_date,
    settlement_month,
    root_account_id,
    'open_api' AS product,
    'month_revenue' AS metric_code,
    provider,
    sale_id,
    am_id,
    SUM(included_fee_amount) AS included_fee_amount,
    SUM(residual_amount) AS residual_amount,
    SUM(included_fee_amount + residual_amount)::numeric(20,3) AS month_revenue
FROM contributions
WHERE root_account_id IS NOT NULL
GROUP BY report_date, settlement_month, root_account_id, provider, sale_id, am_id
ORDER BY report_date, settlement_month, root_account_id, provider, sale_id, am_id;
实时:month_revenue

统计全球账户的收入 global_account_income
量子卡收入:main_fee+virtual_card_create_fee +recharge_fee+pc_channel_rebate
加密收入:crypto_connect_income
线下收入:income_value
实体卡fee:card_creation_fee
实时:month_revenue