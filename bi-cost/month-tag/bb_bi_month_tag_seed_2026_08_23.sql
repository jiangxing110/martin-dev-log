-- BB 月度 Cashback rate 种子数据
-- Updated Time: 2026-09-08 12:30:00
-- 说明:
-- 1. tag 使用 BB_CASH_RATE，供 BB CDC / batch 按 report_month 读取。
-- 2. 2026-01 ~ 2026-07 使用 BI 提供的月度 cashback rate。
-- 3. 2026-07 使用 0.02061664，2026-08 使用 0.02059184，均按实际渠道返现反推。
-- 4. 2099-01-01 为 fallback 配置，默认 rate 为 0.02059391，避免月份没有 rate 时返回 NULL。

BEGIN;

WITH soft_delete_scope AS (
    SELECT detail
    FROM (
        VALUES
            ('2026-01'),
            ('2026-02'),
            ('2026-03'),
            ('2026-04'),
            ('2026-05'),
            ('2026-06'),
            ('2026-07'),
            ('2026-08'),
            ('DEFAULT_FALLBACK')
    ) AS s(detail)
)
UPDATE "ods"."ods_bi_month_tag" old_tag
SET
    "delete_time" = NOW(),
    "update_time" = NOW(),
    "remarks" = COALESCE(old_tag."remarks", '') || ' | soft deleted by bb_bi_month_tag_seed_2026_08_23'
FROM soft_delete_scope s
WHERE old_tag."provider" = 'BB'
  AND old_tag."product_line" = 'BB'
  AND old_tag."account_type" = 'fullCustomer'
  AND old_tag."tag" = 'BB_CASH_RATE'
  AND old_tag."detail" = s.detail
  AND old_tag."delete_time" IS NULL;

WITH seed_rows AS (
    SELECT
        -- 使用新的批次 ID，保证修正费率后重新执行时不会被旧 ID 跳过。
        (202608240000 + period_no)::bigint AS id,
        'BB_CASH_RATE' AS tag,
        statistics_time,
        rate AS amount,
        detail,
        remarks
    FROM (
        VALUES
            (1, '2026-01-01 00:00:00+08'::timestamptz, '2026-01', 0.02208669::numeric, 'BB 2026-01 monthly cashback rate seed'),
            (2, '2026-02-01 00:00:00+08'::timestamptz, '2026-02', 0.02204001::numeric, 'BB 2026-02 monthly cashback rate seed'),
            (3, '2026-03-01 00:00:00+08'::timestamptz, '2026-03', 0.02183684::numeric, 'BB 2026-03 monthly cashback rate seed'),
            (4, '2026-04-01 00:00:00+08'::timestamptz, '2026-04', 0.02161762::numeric, 'BB 2026-04 monthly cashback rate seed'),
            (5, '2026-05-01 00:00:00+08'::timestamptz, '2026-05', 0.02122117::numeric, 'BB 2026-05 monthly cashback rate seed'),
            (6, '2026-06-01 00:00:00+08'::timestamptz, '2026-06', 0.02085309::numeric, 'BB 2026-06 monthly cashback rate seed'),
            (7, '2026-07-01 00:00:00+08'::timestamptz, '2026-07', 0.02061664::numeric, 'BB 2026-07 monthly cashback rate seed; derived from actual cashback'),
            (8, '2026-08-01 00:00:00+08'::timestamptz, '2026-08', 0.02059184::numeric, 'BB 2026-08 monthly cashback rate seed; derived from actual cashback'),
            (99, '2099-01-01 00:00:00+08'::timestamptz, 'DEFAULT_FALLBACK', 0.02059391::numeric, 'BB fallback cashback rate seed')
    ) AS s(period_no, statistics_time, detail, rate, remarks)
)
INSERT INTO "ods"."ods_bi_month_tag"
    ("id", "create_time", "update_time", "delete_time", "version", "tag", "statistics_time", "amount", "remarks", "detail", "account_type", "provider", "product_line")
SELECT
    id,
    NOW(),
    NOW(),
    NULL::timestamptz,
    1,
    tag,
    statistics_time,
    amount,
    remarks,
    detail,
    'fullCustomer',
    'BB',
    'BB'
FROM seed_rows
WHERE NOT EXISTS (
    SELECT 1
    FROM "ods"."ods_bi_month_tag" existing
    WHERE existing."id" = seed_rows.id
);

COMMIT;
