-- QI 的 `ods_bi_month_tag` 2026-08 月度 rate 种子数据
-- Created Time: 2026-08-10 15:27:46
-- Updated Time: 2026-09-07 18:35:12
-- 说明:
-- 1. 仅维护 2026-08，不修改 2026-01 ~ 2026-06 和 DEFAULT_FALLBACK。
-- 2. 执行前软删除八月同范围内的其他有效配置。
-- 3. 使用独立 UPDATE/INSERT 语句，兼容 Greenplum writable CTE 限制。
-- 4. 固定 ID 已存在时重新激活，不存在时补插，可安全重复执行。

BEGIN;

CREATE TEMP TABLE tmp_qi_bi_month_tag_seed_2026_08 (
    id              bigint,
    tag             text,
    statistics_time timestamptz,
    amount          numeric,
    detail          text,
    remarks         text
) ON COMMIT DROP
DISTRIBUTED BY (id);

INSERT INTO tmp_qi_bi_month_tag_seed_2026_08
    (id, tag, statistics_time, amount, detail, remarks)
VALUES
    (202609070801, 'QI_COST_SERVICE_RATE',       '2026-08-01 00:00:00+08'::timestamptz, 1.0087, '2026-08', 'QI 2026-08 monthly rate seed'),
    (202609070802, 'QI_COST_ACS_REGULAR_RATE',   '2026-08-01 00:00:00+08'::timestamptz, 0.9220, '2026-08', 'QI 2026-08 monthly rate seed'),
    (202609070803, 'QI_COST_ACS_VIP_RATE',       '2026-08-01 00:00:00+08'::timestamptz, 1.1044, '2026-08', 'QI 2026-08 monthly rate seed'),
    (202609070804, 'QI_COST_VRM_RATE',           '2026-08-01 00:00:00+08'::timestamptz, 1.0743, '2026-08', 'QI 2026-08 monthly rate seed'),
    (202609070805, 'QI_COST_HK_REGULAR_RATE',    '2026-08-01 00:00:00+08'::timestamptz, 1.0526, '2026-08', 'QI 2026-08 monthly rate seed'),
    (202609070806, 'QI_COST_HK_VIP_RATE',        '2026-08-01 00:00:00+08'::timestamptz, 1.0526, '2026-08', 'QI 2026-08 monthly rate seed'),
    (202609070807, 'QI_COST_DCSF_RATE',          '2026-08-01 00:00:00+08'::timestamptz, 0.9163, '2026-08', 'QI 2026-08 monthly rate seed'),
    (202609070808, 'QI_REBATE_INTERCHANGE_RATE', '2026-08-01 00:00:00+08'::timestamptz, 1.0526, '2026-08', 'QI 2026-08 monthly rate seed'),
    (202609070809, 'QI_REBATE_INCENTIVE_RATE',   '2026-08-01 00:00:00+08'::timestamptz, 1.0526, '2026-08', 'QI 2026-08 monthly rate seed');

-- 软删除同一月份、同一 tag 下由其他脚本写入的有效旧配置。
UPDATE "ods"."ods_bi_month_tag" old_tag
SET
    "delete_time" = NOW(),
    "update_time" = NOW(),
    "remarks" = COALESCE(old_tag."remarks", '') || ' | replaced by qi_bi_month_tag_seed_2026_08'
FROM tmp_qi_bi_month_tag_seed_2026_08 s
WHERE old_tag."provider" = 'IQ'
  AND old_tag."product_line" = 'QI'
  AND old_tag."account_type" = 'fullCustomer'
  AND old_tag."detail" = '2026-08'
  AND old_tag."tag" = s.tag
  AND old_tag."id" <> s.id
  AND old_tag."delete_time" IS NULL;

-- 固定 ID 已存在时更新并重新激活。
UPDATE "ods"."ods_bi_month_tag" existing
SET
    "update_time" = NOW(),
    "delete_time" = NULL,
    "version" = 1,
    "tag" = s.tag,
    "statistics_time" = s.statistics_time,
    "amount" = s.amount,
    "remarks" = s.remarks,
    "detail" = s.detail,
    "account_type" = 'fullCustomer',
    "provider" = 'IQ',
    "product_line" = 'QI'
FROM tmp_qi_bi_month_tag_seed_2026_08 s
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
    s.tag,
    s.statistics_time,
    s.amount,
    s.remarks,
    s.detail,
    'fullCustomer',
    'IQ',
    'QI'
FROM tmp_qi_bi_month_tag_seed_2026_08 s
WHERE NOT EXISTS (
    SELECT 1
    FROM "ods"."ods_bi_month_tag" existing
    WHERE existing."id" = s.id
);

COMMIT;

-- 执行后应返回 9 行，且每个 tag 仅有一条有效配置。
SELECT
    "tag",
    "statistics_time",
    "amount",
    "detail",
    "remarks"
FROM "ods"."ods_bi_month_tag"
WHERE "provider" = 'IQ'
  AND "product_line" = 'QI'
  AND "account_type" = 'fullCustomer'
  AND "detail" = '2026-08'
  AND "delete_time" IS NULL
ORDER BY "tag";
