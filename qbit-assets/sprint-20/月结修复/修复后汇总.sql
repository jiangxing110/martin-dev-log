WITH fee_rows AS (
    SELECT
        COALESCE(aar.root_id::text, tr.account_id::text) AS api_customer_id,
        CASE
            WHEN tr.provider ~ '^ThepennyincCard.*' THEN 'TP'
            WHEN tr.provider ~ '^NiumCard.*' THEN 'NM'
            WHEN tr.provider ~ '^ReapCard.*' THEN 'RP'
            WHEN tr.provider ~ '^QbitIssuingCard.*' THEN 'IQ'
            WHEN tr.provider ~ '^RainCard.*' THEN 'RC'
            WHEN tr.provider ~ '^BlueBancCard.*' THEN 'BB'
            WHEN tr.provider ~ '^Slash.*' THEN 'LS'
            WHEN tr.provider ~ '^CorpayCard.*' THEN 'PC'
            WHEN tr.provider ~ '^I2cCard.*' THEN 'BZ'
            WHEN tr.provider ~ '^OrendaCard.*' THEN 'RO'
            ELSE tr.provider
        END AS channel,
        date_trunc('month', tr.complete_time AT TIME ZONE 'UTC')::date AS fee_month,
        fee_item->>'type' AS fee_type,
        COALESCE(NULLIF(fee_item->>'amount', '')::numeric, 0) AS fee_amount
    FROM public.api_client_transaction tr
    LEFT JOIN public.api_account_relation aar
        ON aar.account_id = tr.account_id
    CROSS JOIN LATERAL jsonb_array_elements(
        COALESCE(tr.fees::jsonb, '[]'::jsonb)
    ) AS fee_items(fee_item)
    WHERE tr.delete_time IS NULL
      AND tr.status = 'Closed'
      AND tr.complete_time >= TIMESTAMPTZ '2026-02-01 00:00:00+00'
              AND tr.complete_time < TIMESTAMPTZ '2026-10-01 00:00:00+00'
      AND fee_item->>'type' <> 'declineFee'
)
SELECT
    api_customer_id,
    channel,
    fee_month,
    fee_type,
    ROUND(SUM(fee_amount), 2) AS fee_amount_usd
FROM fee_rows
GROUP BY api_customer_id, channel, fee_month, fee_type
ORDER BY fee_month, api_customer_id, channel, fee_type;