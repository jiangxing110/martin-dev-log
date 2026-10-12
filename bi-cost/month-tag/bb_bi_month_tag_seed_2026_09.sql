-- BB 的 `ods_bi_month_tag` 2026-09 月度 Cashback rate 种子数据
-- Created Time: 2026-10-12 00:00:00
-- Updated Time: 2026-10-12 00:00:00
-- 说明:
-- 1. 使用 BB_CASH_RATE，供 BB CDC / batch 按 report_month 读取。
-- 2. 本脚本仅维护 2026-09，不修改其他月份或 DEFAULT_FALLBACK。
-- 3. 固定 ID 已存在时重新激活，不存在时补插，可安全重复执行。

BEGIN;

CREATE TEMP TABLE tmp_bb_bi_month_tag_seed_2026_09 (
    id              bigint,
    statistics_time timestamptz,
    amount          numeric,
    detail          text,
    remarks         text
) ON COMMIT DROP
DISTRIBUTED BY (id);

INSERT INTO tmp_bb_bi_month_tag_seed_2026_09
    (id, statistics_time, amount, detail, remarks)
VALUES
    (202610120910, '2026-09-01 00:00:00+08'::timestamptz, 0.021067::numeric * 0.9940, '2026-09', 'BB 2026-09 monthly cashback rate seed; 0.021067 * 0.9940');

-- 软删除同月同范围内其他有效费率。
UPDATE "ods"."ods_bi_month_tag" old_tag
SET
    "delete_time" = NOW(),
    "update_time" = NOW(),
    "remarks" = COALESCE(old_tag."remarks", '') || ' | replaced by bb_bi_month_tag_seed_2026_09'
FROM tmp_bb_bi_month_tag_seed_2026_09 s
WHERE old_tag."provider" = 'BB'
  AND old_tag."product_line" = 'BB'
  AND old_tag."account_type" = 'fullCustomer'
  AND old_tag."tag" = 'BB_CASH_RATE'
  AND old_tag."detail" = s.detail
  AND old_tag."id" <> s.id
  AND old_tag."delete_time" IS NULL;

-- 固定 ID 已存在时更新并重新激活。
UPDATE "ods"."ods_bi_month_tag" existing
SET
    "update_time" = NOW(),
    "delete_time" = NULL,
    "version" = 1,
    "tag" = 'BB_CASH_RATE',
    "statistics_time" = s.statistics_time,
    "amount" = s.amount,
    "remarks" = s.remarks,
    "detail" = s.detail,
    "account_type" = 'fullCustomer',
    "provider" = 'BB',
    "product_line" = 'BB'
FROM tmp_bb_bi_month_tag_seed_2026_09 s
WHERE existing."id" = s.id;

-- 固定 ID 不存在时插入。
INSERT INTO "ods"."ods_bi_month_tag"
    ("id", "create_time", "update_time", "delete_time", "version", "tag", "statistics_time", "amount", "remarks", "detail", "account_type", "provider", "product_line")
SELECT
    s.id,
    NOW(),
    NOW(),
    NULL::timestamptz,
    1,
    'BB_CASH_RATE',
    s.statistics_time,
    s.amount,
    s.remarks,
    s.detail,
    'fullCustomer',
    'BB',
    'BB'
FROM tmp_bb_bi_month_tag_seed_2026_09 s
WHERE NOT EXISTS (
    SELECT 1
    FROM "ods"."ods_bi_month_tag" existing
    WHERE existing."id" = s.id
);

COMMIT;

-- 执行后核对有效费率。
SELECT
    "tag",
    "statistics_time",
    "amount",
    "detail",
    "remarks"
FROM "ods"."ods_bi_month_tag"
WHERE "provider" = 'BB'
  AND "product_line" = 'BB'
  AND "account_type" = 'fullCustomer'
  AND "tag" = 'BB_CASH_RATE'
  AND "detail" = '2026-09'
  AND "delete_time" IS NULL;
