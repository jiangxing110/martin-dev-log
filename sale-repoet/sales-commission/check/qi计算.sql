WITH qi_detail AS (
    SELECT
        DATE_TRUNC('month', q.report_date)::date AS settlement_month,
        q.report_date,
        q.account_id,

        q.cost_reimbursement_base_amt,
        q.cost_reimbursement_rate,
        q.cost_service_base_amt,
        q.cost_service_rate,
        q.cost_acs_regular_base_amt,
        q.cost_acs_regular_rate,
        q.cost_acs_vip_base_amt,
        q.cost_acs_vip_rate,
        q.cost_vrm_base_amt,
        q.cost_vrm_rate,
        q.cost_hk_regular_base_amt,
        q.cost_hk_regular_rate,
        q.cost_hk_vip_base_amt,
        q.cost_hk_vip_rate,
        q.cost_dcsf_base_amt,
        q.cost_dcsf_rate,
        q.cost_fixed_fee,

        q.rebate_interchange_base_amt,
        q.rebate_interchange_rate,
        q.rebate_incentive_base_amt,
        q.rebate_incentive_rate

    FROM dws.dws_qi_card_finance_daily_v2_p q
    LEFT JOIN public.api_account_relation aar
        ON aar.account_id::varchar = q.account_id::varchar
       AND aar.delete_time IS NULL
    WHERE q.delete_time IS NULL
      AND q.report_date >= DATE '2026-08-01'
      AND q.report_date < DATE '2026-09-01'
      AND COALESCE(
            aar.root_id::varchar,
            q.account_id::varchar
          ) = '69794135-965c-4670-b712-64e43c69195d'
),
qi_items AS (
    SELECT
        q.settlement_month,
        x.item_type,
        x.base_amount,
        x.rate,
        x.amount
    FROM qi_detail q
    CROSS JOIN LATERAL (
        VALUES
            (
                'reimbursement_cost',
                q.cost_reimbursement_base_amt::numeric,
                q.cost_reimbursement_rate::numeric,
                COALESCE(q.cost_reimbursement_base_amt, 0)
                    * COALESCE(q.cost_reimbursement_rate, 1)
            ),
            (
                'service_cost',
                q.cost_service_base_amt::numeric,
                q.cost_service_rate::numeric,
                COALESCE(q.cost_service_base_amt, 0)
                    * COALESCE(q.cost_service_rate, 1)
            ),
            (
                'acs_regular_cost',
                q.cost_acs_regular_base_amt::numeric,
                q.cost_acs_regular_rate::numeric,
                COALESCE(q.cost_acs_regular_base_amt, 0)
                    * COALESCE(q.cost_acs_regular_rate, 1)
            ),
            (
                'acs_vip_cost',
                q.cost_acs_vip_base_amt::numeric,
                q.cost_acs_vip_rate::numeric,
                COALESCE(q.cost_acs_vip_base_amt, 0)
                    * COALESCE(q.cost_acs_vip_rate, 1)
            ),
            (
                'vrm_cost',
                q.cost_vrm_base_amt::numeric,
                q.cost_vrm_rate::numeric,
                COALESCE(q.cost_vrm_base_amt, 0)
                    * COALESCE(q.cost_vrm_rate, 1)
            ),
            (
                'hk_regular_cost',
                q.cost_hk_regular_base_amt::numeric,
                q.cost_hk_regular_rate::numeric,
                COALESCE(q.cost_hk_regular_base_amt, 0)
                    * COALESCE(q.cost_hk_regular_rate, 1)
            ),
            (
                'hk_vip_cost',
                q.cost_hk_vip_base_amt::numeric,
                q.cost_hk_vip_rate::numeric,
                COALESCE(q.cost_hk_vip_base_amt, 0)
                    * COALESCE(q.cost_hk_vip_rate, 1)
            ),
            (
                'dcsf_cost',
                q.cost_dcsf_base_amt::numeric,
                q.cost_dcsf_rate::numeric,
                COALESCE(q.cost_dcsf_base_amt, 0)
                    * COALESCE(q.cost_dcsf_rate, 1)
            ),
            (
                'fixed_fee',
                NULL::numeric,
                NULL::numeric,
                COALESCE(q.cost_fixed_fee, 0)
            ),
            (
                'interchange_rebate',
                q.rebate_interchange_base_amt::numeric,
                q.rebate_interchange_rate::numeric,
                COALESCE(q.rebate_interchange_base_amt, 0)
            ),
            (
                'incentive_rebate',
                q.rebate_incentive_base_amt::numeric,
                q.rebate_incentive_rate::numeric,
                COALESCE(q.rebate_incentive_base_amt, 0)
                    * COALESCE(q.rebate_incentive_rate, 1)
            )
    ) AS x(item_type, base_amount, rate, amount)
),
monthly_total AS (
    SELECT
        settlement_month,
        SUM(
            CASE
                WHEN item_type LIKE '%_cost'
                  OR item_type = 'fixed_fee'
                THEN amount
                ELSE 0
            END
        )::numeric(20,4) AS total_cost,
        SUM(
            CASE
                WHEN item_type IN (
                    'interchange_rebate',
                    'incentive_rebate'
                )
                THEN amount
                ELSE 0
            END
        )::numeric(20,4) AS total_rebate
    FROM qi_items
    GROUP BY settlement_month
)
SELECT
    i.settlement_month,
    i.item_type,
    SUM(COALESCE(i.base_amount, 0))::numeric(20,4) AS base_amount,
    AVG(i.rate)::numeric(20,6) AS rate,
    SUM(i.amount)::numeric(20,4) AS amount,
    t.total_cost,
    t.total_rebate
FROM qi_items i
LEFT JOIN monthly_total t
    ON t.settlement_month = i.settlement_month
GROUP BY
    i.settlement_month,
    i.item_type,
    t.total_cost,
    t.total_rebate
HAVING SUM(i.amount) <> 0
ORDER BY
    i.settlement_month,
    CASE i.item_type
        WHEN 'reimbursement_cost' THEN 1
        WHEN 'service_cost' THEN 2
        WHEN 'acs_regular_cost' THEN 3
        WHEN 'acs_vip_cost' THEN 4
        WHEN 'vrm_cost' THEN 5
        WHEN 'hk_regular_cost' THEN 6
        WHEN 'hk_vip_cost' THEN 7
        WHEN 'dcsf_cost' THEN 8
        WHEN 'fixed_fee' THEN 9
        WHEN 'interchange_rebate' THEN 10
        WHEN 'incentive_rebate' THEN 11
        ELSE 99
    END;