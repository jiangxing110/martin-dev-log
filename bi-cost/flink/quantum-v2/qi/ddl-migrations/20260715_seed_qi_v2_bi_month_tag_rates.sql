-- QI v2 ods_bi_month_tag monthly rate and fixed-fee seed data.
-- 1. 2026-01 ~ 2026-05 are monthly formal configurations.
-- 2. 2099-01 is the fallback configuration used when a month has no formal row, aligned to 2026-05 rates.
-- 3. Base values are calculated in DWS; these rows only store the monthly rate.
-- 4. Channel fixed costs are handled by separate fixed-fee scripts, not by this rate seed.

WITH period_rules AS (
    SELECT *
    FROM (
        VALUES
            (1, '2026-01-01 00:00:00+08'::timestamptz, '2026-01', 'QI v2 monthly rate seed'),
            (2, '2026-02-01 00:00:00+08'::timestamptz, '2026-02', 'QI v2 monthly rate seed'),
            (3, '2026-03-01 00:00:00+08'::timestamptz, '2026-03', 'QI v2 monthly rate seed'),
            (4, '2026-04-01 00:00:00+08'::timestamptz, '2026-04', 'QI v2 monthly rate seed'),
            (5, '2026-05-01 00:00:00+08'::timestamptz, '2026-05', 'QI v2 monthly rate seed'),
            (6, '2099-01-01 00:00:00+08'::timestamptz, 'DEFAULT_FALLBACK', 'QI v2 fallback rate seed')
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
            (8, 'QI_COST_HK_REGULAR_RATE', 1::numeric, 'QI', 'HK Regular monthly rate'),
            (9, 'QI_COST_HK_VIP_RATE', 1::numeric, 'QI', 'HK VIP monthly rate'),
            (10, 'QI_COST_DCSF_RATE', 1.1263::numeric, 'QI', 'DCSF monthly rate')
    ) AS r(rule_no, tag, amount, product_line, tag_desc)
),
month_rate_overrides AS (
    SELECT *
    FROM (
        VALUES
            ('2026-05', 'QI_COST_DCSF_RATE', 1.0563::numeric),
            ('2026-05', 'QI_REBATE_INTERCHANGE_RATE', 0.9945::numeric),
            ('2026-05', 'QI_REBATE_INCENTIVE_RATE', 0.9945::numeric),
            ('DEFAULT_FALLBACK', 'QI_COST_DCSF_RATE', 1.0563::numeric),
            ('DEFAULT_FALLBACK', 'QI_REBATE_INTERCHANGE_RATE', 0.9945::numeric),
            ('DEFAULT_FALLBACK', 'QI_REBATE_INCENTIVE_RATE', 0.9945::numeric)
    ) AS o(detail, tag, amount)
),
seed_rows AS (
    SELECT
        (202607150000 + p.period_no * 100 + r.rule_no)::bigint AS id,
        r.tag,
        p.statistics_time,
        COALESCE(o.amount, r.amount) AS amount,
        p.remarks,
        p.detail,
        'fullCustomer' AS account_type,
        'IQ' AS provider,
        r.product_line
    FROM period_rules p
    CROSS JOIN tag_rules r
    LEFT JOIN month_rate_overrides o
        ON o.detail = p.detail
       AND o.tag = r.tag
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

WITH month_rate_overrides AS (
    SELECT *
    FROM (
        VALUES
            ('2026-05', 'QI_COST_DCSF_RATE', 1.0563::numeric),
            ('2026-05', 'QI_REBATE_INTERCHANGE_RATE', 0.9945::numeric),
            ('2026-05', 'QI_REBATE_INCENTIVE_RATE', 0.9945::numeric),
            ('DEFAULT_FALLBACK', 'QI_COST_DCSF_RATE', 1.0563::numeric),
            ('DEFAULT_FALLBACK', 'QI_REBATE_INTERCHANGE_RATE', 0.9945::numeric),
            ('DEFAULT_FALLBACK', 'QI_REBATE_INCENTIVE_RATE', 0.9945::numeric)
    ) AS o(detail, tag, amount)
)
UPDATE "ods"."ods_bi_month_tag" t
SET
    "amount" = o.amount,
    "update_time" = NOW()
FROM month_rate_overrides o
WHERE t."provider" = 'IQ'
  AND t."detail" = o.detail
  AND t."tag" = o.tag
  AND t."delete_time" IS NULL;
