WITH account_root_relation AS (
    SELECT account_id, root_id
    FROM ods.ods_api_account_relation
    WHERE delete_time IS NULL
),

cost_detail AS (
    -- 渠道成本
    SELECT
        c.source_month AS settlement_month,
        COALESCE(aar.root_id, c.account_id) AS root_account_id,
        c.provider,
        '渠道成本' AS cost_source,
        c.cost_type,
        SUM(COALESCE(c.cost_amount, 0)) AS cogs
    FROM dwm.dwm_finance_channel_cost_p c
    LEFT JOIN account_root_relation aar
        ON aar.account_id = c.account_id
    WHERE c.delete_time IS NULL
      AND c.source_month = DATE '2026-08-01'
      AND c.product_line = 'GLOBAL_ACCOUNT'
    GROUP BY
        c.source_month,
        COALESCE(aar.root_id, c.account_id),
        c.provider,
        c.cost_type

    UNION ALL

    -- 线下付款手续费 fee_cost
    SELECT
        DATE_TRUNC('month', ptr.submit_time)::date AS settlement_month,
        COALESCE(aar.root_id, ptr.account_id) AS root_account_id,
        'OFFLINE' AS provider,
        '线下付款手续费' AS cost_source,
        NULL AS cost_type,
        SUM(
            COALESCE(
                NULLIF(
                    (regexp_match(
                        ptr.extra,
                        '"fee_cost"[[:space:]]*:[[:space:]]*"?([-+]?[0-9]+([.][0-9]+)?)"?'
                    ))[1],
                    ''
                )::numeric,
                0
            )
        ) AS cogs
    FROM ods.ods_payment_transaction_record ptr
    LEFT JOIN account_root_relation aar
        ON aar.account_id = ptr.account_id
    WHERE ptr.delete_time IS NULL
      AND ptr.status = 'Closed'
      AND DATE_TRUNC('month', ptr.submit_time)::date = DATE '2026-08-01'
    GROUP BY
        DATE_TRUNC('month', ptr.submit_time)::date,
        COALESCE(aar.root_id, ptr.account_id)

    UNION ALL

    -- 线下退款成本
    SELECT
        DATE_TRUNC('month', t.statistics_time)::date AS settlement_month,
        COALESCE(aar.root_id, t.account_id) AS root_account_id,
        'OFFLINE_REFUND' AS provider,
        '线下退款成本' AS cost_source,
        t.tag AS cost_type,
        SUM(COALESCE(t.amount, 0)) AS cogs
    FROM ods.ods_bi_month_tag t
    LEFT JOIN account_root_relation aar
        ON aar.account_id = t.account_id
    WHERE t.delete_time IS NULL
      AND t.account_id IS NOT NULL
      AND t.tag = 'OFFLINE_REFUND'
      AND t.product_line = 'GLOBAL_ACCOUNT'
      AND DATE_TRUNC('month', t.statistics_time)::date = DATE '2026-08-01'
    GROUP BY
        DATE_TRUNC('month', t.statistics_time)::date,
        COALESCE(aar.root_id, t.account_id),
        t.tag
)

SELECT
    settlement_month,
    root_account_id,
    provider,
    cost_source,
    cost_type,
    cogs
FROM cost_detail
WHERE cogs <> 0
ORDER BY cogs DESC;