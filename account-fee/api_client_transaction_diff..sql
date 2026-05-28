SELECT * FROM qbit_card_transaction 
WHERE "accountId"='2fd1d1f0-684b-4a9d-a36a-c6c7558aeda0'
and "businessType" not in ('TransferIn','TransferOut','Fee_Consumption','Declined_Fee','System_Fee')
and status='Closed' and "deleteTime" is null

WITH api_fee_sum AS (
    SELECT
        act.transaction_id,
        act.account_id,
        SUM((fee_item ->> 'amount')::numeric) AS api_fee_total,
        jsonb_agg(
            jsonb_build_object(
                'type', fee_item ->> 'type',
                'amount', (fee_item ->> 'amount')::numeric
            )
            ORDER BY fee_item ->> 'type'
        ) AS api_fee_detail
    FROM api_client_transaction act
    CROSS JOIN LATERAL jsonb_array_elements(act.fees::jsonb) AS fee_item
    WHERE act.delete_time IS NULL
    GROUP BY act.transaction_id, act.account_id
)
SELECT
    qct.id AS transaction_id,
    qct."businessType" AS business_type,
    qct.provider,
    qct.fee AS qct_fee_total,
    COALESCE(a.api_fee_total, 0) AS api_fee_total,
    qct.fee - COALESCE(a.api_fee_total, 0) AS diff,
    qct."specialSourceData"::jsonb AS special_source_data,
    a.api_fee_detail
FROM qbit_card_transaction qct
LEFT JOIN api_fee_sum a ON a.transaction_id::UUID = qct.id
WHERE qct."accountId" = '2fd1d1f0-684b-4a9d-a36a-c6c7558aeda0'
  AND qct.status = 'Closed'
	AND qct."businessType"  in ('Consumption')
  AND qct."deleteTime" IS NULL
ORDER BY qct."businessType", qct.id;