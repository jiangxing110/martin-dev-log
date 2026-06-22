CREATE OR REPLACE VIEW "dws"."vw_gross_profit_daily" AS
SELECT
    r.report_date,
    r.account_id,
    COALESCE(r.account_type, c.account_type) AS account_type,
    COALESCE(r.account_category, c.account_category) AS account_category,
    COALESCE(r.system_type, c.system_type) AS system_type,
    r.category,
    CAST(COALESCE(r.revenue_amount, 0) AS numeric(20,4)) AS revenue_amount,
    CAST(
        CASE r.category
            WHEN 'qbit_card' THEN COALESCE(c.quantum_cost, 0)
            WHEN 'global_account' THEN COALESCE(c.business_cost, 0)
            WHEN 'crypto_assets' THEN COALESCE(c.crypto_cost, 0)
            WHEN 'particle_financing' THEN 0
            WHEN 'company_registration' THEN 0
            WHEN 'offline_order' THEN 0
            ELSE 0
        END AS numeric(20,4)
    ) AS channel_cost_amount,
    CAST(
        COALESCE(r.revenue_amount, 0) -
        CASE r.category
            WHEN 'qbit_card' THEN COALESCE(c.quantum_cost, 0)
            WHEN 'global_account' THEN COALESCE(c.business_cost, 0)
            WHEN 'crypto_assets' THEN COALESCE(c.crypto_cost, 0)
            WHEN 'particle_financing' THEN 0
            WHEN 'company_registration' THEN 0
            WHEN 'offline_order' THEN 0
            ELSE 0
        END AS numeric(20,4)
    ) AS gross_profit_amount,
    CAST(
        CASE
            WHEN COALESCE(r.revenue_amount, 0) = 0 THEN 0
            ELSE (
                COALESCE(r.revenue_amount, 0) -
                CASE r.category
                    WHEN 'qbit_card' THEN COALESCE(c.quantum_cost, 0)
                    WHEN 'global_account' THEN COALESCE(c.business_cost, 0)
                    WHEN 'crypto_assets' THEN COALESCE(c.crypto_cost, 0)
                    WHEN 'particle_financing' THEN 0
                    WHEN 'company_registration' THEN 0
                    WHEN 'offline_order' THEN 0
                    ELSE 0
                END
            ) / COALESCE(r.revenue_amount, 0)
        END AS numeric(20,8)
    ) AS gross_margin
FROM "dws"."vw_profit_revenue_daily" r
LEFT JOIN "dws"."dws_total_channel_cost_daily_p" c
    ON c.report_date = r.report_date
   AND c.account_id = r.account_id
   AND c.delete_time IS NULL;
