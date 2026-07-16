-- QI v2 ods_bi_month_tag monthly rate and fixed-fee seed data.
-- 1. 2026-01 ~ 2026-06 are monthly formal configurations.
-- 2. 2099-01 is the fallback configuration used when a month has no formal row.
-- 3. Base values are calculated in DWS; these rows only store the monthly rate.
-- 4. CHANNEL_COST is seeded as 0 and can be updated by Finance per month.

WITH period_rules AS (
    SELECT *
    FROM (
        VALUES
            (1, '2026-01-01 00:00:00+08'::timestamptz, '2026-01', 'QI v2 monthly rate seed'),
            (2, '2026-02-01 00:00:00+08'::timestamptz, '2026-02', 'QI v2 monthly rate seed'),
            (3, '2026-03-01 00:00:00+08'::timestamptz, '2026-03', 'QI v2 monthly rate seed'),
            (4, '2026-04-01 00:00:00+08'::timestamptz, '2026-04', 'QI v2 monthly rate seed'),
            (5, '2026-05-01 00:00:00+08'::timestamptz, '2026-05', 'QI v2 monthly rate seed'),
            (6, '2026-06-01 00:00:00+08'::timestamptz, '2026-06', 'QI v2 monthly rate seed'),
            (7, '2099-01-01 00:00:00+08'::timestamptz, 'DEFAULT_FALLBACK', 'QI v2 fallback rate seed')
    ) AS p(period_no, statistics_time, detail, remarks)
),
tag_rules AS (
    SELECT *
    FROM (
        VALUES
            (1, 'QI_COST_REIMBURSEMENT_RATE', 0.9904::numeric, 'QI', 'Reimbursement monthly rate'),
            (2, 'QI_COST_SERVICE_RATE', 0.9749::numeric, 'QI', 'Card Service monthly rate'),
            (3, 'QI_COST_ACS_REGULAR_RATE', 0.9019::numeric, 'QI', 'ACS regular monthly rate'),
            (4, 'QI_COST_ACS_VIP_RATE', 1.0636::numeric, 'QI', 'ACS VIP monthly rate'),
            (5, 'QI_COST_VRM_RATE', 1.3434::numeric, 'QI', 'VRM monthly rate'),
            (6, 'QI_REBATE_INTERCHANGE_RATE', 0.9904::numeric, 'QI', 'Visa Incentive monthly rate'),
            (7, 'QI_REBATE_INCENTIVE_RATE', 0.9904::numeric, 'QI', 'Visa Reimbursement monthly rate'),
            (8, 'CHANNEL_COST', 0::numeric, 'QUANTUM_CARD', 'Channel fixed cost')
    ) AS r(rule_no, tag, amount, product_line, tag_desc)
),
seed_rows AS (
    SELECT
        (202607150000 + p.period_no * 100 + r.rule_no)::bigint AS id,
        r.tag,
        p.statistics_time,
        r.amount,
        CASE
            WHEN r.tag = 'CHANNEL_COST' THEN p.remarks || ' - ' || r.tag_desc
            ELSE p.remarks
        END AS remarks,
        p.detail,
        'fullCustomer' AS account_type,
        'IQ' AS provider,
        r.product_line
    FROM period_rules p
    CROSS JOIN tag_rules r
)
INSERT INTO "ods"."ods_bi_month_tag"
    ("id", "create_time", "update_time", "delete_time", "version", "tag", "statistics_time", "amount", "remarks", "detail", "account_type", "provider", "product_line")
SELECT
    s.id,
    NOW() AS create_time,
    NOW() AS update_time,
    NULL::timestamptz AS delete_time,
    1 AS version,
    s.tag,
    s.statistics_time,
    s.amount,
    s.remarks,
    s.detail,
    s.account_type,
    s.provider,
    s.product_line
FROM seed_rows s
WHERE NOT EXISTS (
    SELECT 1
    FROM "ods"."ods_bi_month_tag" e
    WHERE e."id" = s.id
);
