-- QI 的 `ods_bi_month_tag` 月度 rate 种子数据
-- Updated Time: 2026-07-30 18:35:00
-- 说明:
-- 1. 2026-01 ~ 2026-06 为 BI 提供的新月度配置。
-- 2. 执行前先软删除旧 QI 月度配置，再插入新配置，避免旧 rate 混用。
-- 3. param_a -> QI_COST_SERVICE_RATE
-- 4. param_b -> QI_COST_ACS_REGULAR_RATE
-- 5. param_c -> QI_COST_ACS_VIP_RATE
-- 6. param_d -> QI_COST_VRM_RATE
-- 7. param_e -> CROSS，写入 QI_COST_HK_REGULAR_RATE / QI_COST_HK_VIP_RATE / QI_REBATE_INTERCHANGE_RATE / QI_REBATE_INCENTIVE_RATE
-- 8. param_f -> QI_COST_DCSF_RATE；没有 param_f 的月份显式写 0
-- 9. DEFAULT_FALLBACK 使用 2026-06 配置。
-- 10. 新插入 ID 使用 202607300000 段，避免旧数据软删除后主键冲突。

BEGIN;

WITH soft_delete_scope AS (
    SELECT *
    FROM (
        VALUES
            ('2026-01'),
            ('2026-02'),
            ('2026-03'),
            ('2026-04'),
            ('2026-05'),
            ('2026-06'),
            ('DEFAULT_FALLBACK')
    ) AS m(detail)
),
soft_delete_tags AS (
    SELECT *
    FROM (
        VALUES
            ('QI_COST_REIMBURSEMENT_RATE'),
            ('QI_COST_SERVICE_RATE'),
            ('QI_COST_ACS_REGULAR_RATE'),
            ('QI_COST_ACS_VIP_RATE'),
            ('QI_COST_VRM_RATE'),
            ('QI_COST_HK_REGULAR_RATE'),
            ('QI_COST_HK_VIP_RATE'),
            ('QI_COST_DCSF_RATE'),
            ('QI_REBATE_INTERCHANGE_RATE'),
            ('QI_REBATE_INCENTIVE_RATE')
    ) AS t(tag)
)
UPDATE "ods"."ods_bi_month_tag" old_tag
SET
    "delete_time" = NOW(),
    "update_time" = NOW(),
    "remarks" = COALESCE(old_tag."remarks", '') || ' | soft deleted by qi_bi_month_tag_seed_2026_01_06'
FROM soft_delete_scope s, soft_delete_tags t
WHERE old_tag."provider" = 'IQ'
  AND old_tag."product_line" = 'QI'
  AND old_tag."account_type" = 'fullCustomer'
  AND old_tag."detail" = s.detail
  AND old_tag."tag" = t.tag
  AND old_tag."delete_time" IS NULL;

WITH seed_rows AS (
    SELECT
        (202607300000 + period_no * 100 + rule_no)::bigint AS id,
        tag,
        statistics_time,
        amount,
        detail,
        remarks
    FROM (
        VALUES
            -- period_no, rule_no, tag, statistics_time, amount, detail, remarks
            -- 2026-01
            (1, 1, 'QI_COST_SERVICE_RATE',        '2026-01-01 00:00:00+08'::timestamptz, 1.0084::numeric, '2026-01', 'QI monthly rate seed'),
            (1, 2, 'QI_COST_ACS_REGULAR_RATE',    '2026-01-01 00:00:00+08'::timestamptz, 0.9852::numeric, '2026-01', 'QI monthly rate seed'),
            (1, 3, 'QI_COST_ACS_VIP_RATE',        '2026-01-01 00:00:00+08'::timestamptz, 1.1146::numeric, '2026-01', 'QI monthly rate seed'),
            (1, 4, 'QI_COST_VRM_RATE',            '2026-01-01 00:00:00+08'::timestamptz, 1.2239::numeric, '2026-01', 'QI monthly rate seed'),
            (1, 5, 'QI_COST_HK_REGULAR_RATE',     '2026-01-01 00:00:00+08'::timestamptz, 0.9952::numeric, '2026-01', 'QI monthly rate seed'),
            (1, 6, 'QI_COST_HK_VIP_RATE',         '2026-01-01 00:00:00+08'::timestamptz, 0.9952::numeric, '2026-01', 'QI monthly rate seed'),
            (1, 7, 'QI_COST_DCSF_RATE',           '2026-01-01 00:00:00+08'::timestamptz, 0::numeric,      '2026-01', 'QI monthly rate seed'),
            (1, 8, 'QI_REBATE_INTERCHANGE_RATE',  '2026-01-01 00:00:00+08'::timestamptz, 0.9952::numeric, '2026-01', 'QI monthly rate seed'),
            (1, 9, 'QI_REBATE_INCENTIVE_RATE',    '2026-01-01 00:00:00+08'::timestamptz, 0.9952::numeric, '2026-01', 'QI monthly rate seed'),

            -- 2026-02
            (2, 1, 'QI_COST_SERVICE_RATE',        '2026-02-01 00:00:00+08'::timestamptz, 1.0159::numeric, '2026-02', 'QI monthly rate seed'),
            (2, 2, 'QI_COST_ACS_REGULAR_RATE',    '2026-02-01 00:00:00+08'::timestamptz, 0.9858::numeric, '2026-02', 'QI monthly rate seed'),
            (2, 3, 'QI_COST_ACS_VIP_RATE',        '2026-02-01 00:00:00+08'::timestamptz, 1.1556::numeric, '2026-02', 'QI monthly rate seed'),
            (2, 4, 'QI_COST_VRM_RATE',            '2026-02-01 00:00:00+08'::timestamptz, 1.1967::numeric, '2026-02', 'QI monthly rate seed'),
            (2, 5, 'QI_COST_HK_REGULAR_RATE',     '2026-02-01 00:00:00+08'::timestamptz, 1.0041::numeric, '2026-02', 'QI monthly rate seed'),
            (2, 6, 'QI_COST_HK_VIP_RATE',         '2026-02-01 00:00:00+08'::timestamptz, 1.0041::numeric, '2026-02', 'QI monthly rate seed'),
            (2, 7, 'QI_COST_DCSF_RATE',           '2026-02-01 00:00:00+08'::timestamptz, 0::numeric,      '2026-02', 'QI monthly rate seed'),
            (2, 8, 'QI_REBATE_INTERCHANGE_RATE',  '2026-02-01 00:00:00+08'::timestamptz, 1.0041::numeric, '2026-02', 'QI monthly rate seed'),
            (2, 9, 'QI_REBATE_INCENTIVE_RATE',    '2026-02-01 00:00:00+08'::timestamptz, 1.0041::numeric, '2026-02', 'QI monthly rate seed'),

            -- 2026-03
            (3, 1, 'QI_COST_SERVICE_RATE',        '2026-03-01 00:00:00+08'::timestamptz, 1.0023::numeric, '2026-03', 'QI monthly rate seed'),
            (3, 2, 'QI_COST_ACS_REGULAR_RATE',    '2026-03-01 00:00:00+08'::timestamptz, 0.9770::numeric, '2026-03', 'QI monthly rate seed'),
            (3, 3, 'QI_COST_ACS_VIP_RATE',        '2026-03-01 00:00:00+08'::timestamptz, 1.1284::numeric, '2026-03', 'QI monthly rate seed'),
            (3, 4, 'QI_COST_VRM_RATE',            '2026-03-01 00:00:00+08'::timestamptz, 1.1548::numeric, '2026-03', 'QI monthly rate seed'),
            (3, 5, 'QI_COST_HK_REGULAR_RATE',     '2026-03-01 00:00:00+08'::timestamptz, 0.9952::numeric, '2026-03', 'QI monthly rate seed'),
            (3, 6, 'QI_COST_HK_VIP_RATE',         '2026-03-01 00:00:00+08'::timestamptz, 0.9952::numeric, '2026-03', 'QI monthly rate seed'),
            (3, 7, 'QI_COST_DCSF_RATE',           '2026-03-01 00:00:00+08'::timestamptz, 0::numeric,      '2026-03', 'QI monthly rate seed'),
            (3, 8, 'QI_REBATE_INTERCHANGE_RATE',  '2026-03-01 00:00:00+08'::timestamptz, 0.9952::numeric, '2026-03', 'QI monthly rate seed'),
            (3, 9, 'QI_REBATE_INCENTIVE_RATE',    '2026-03-01 00:00:00+08'::timestamptz, 0.9952::numeric, '2026-03', 'QI monthly rate seed'),

            -- 2026-04
            (4, 1, 'QI_COST_SERVICE_RATE',        '2026-04-01 00:00:00+08'::timestamptz, 0.9963::numeric, '2026-04', 'QI monthly rate seed'),
            (4, 2, 'QI_COST_ACS_REGULAR_RATE',    '2026-04-01 00:00:00+08'::timestamptz, 0.9835::numeric, '2026-04', 'QI monthly rate seed'),
            (4, 3, 'QI_COST_ACS_VIP_RATE',        '2026-04-01 00:00:00+08'::timestamptz, 1.1170::numeric, '2026-04', 'QI monthly rate seed'),
            (4, 4, 'QI_COST_VRM_RATE',            '2026-04-01 00:00:00+08'::timestamptz, 1.2048::numeric, '2026-04', 'QI monthly rate seed'),
            (4, 5, 'QI_COST_HK_REGULAR_RATE',     '2026-04-01 00:00:00+08'::timestamptz, 0.9957::numeric, '2026-04', 'QI monthly rate seed'),
            (4, 6, 'QI_COST_HK_VIP_RATE',         '2026-04-01 00:00:00+08'::timestamptz, 0.9957::numeric, '2026-04', 'QI monthly rate seed'),
            (4, 7, 'QI_COST_DCSF_RATE',           '2026-04-01 00:00:00+08'::timestamptz, 1.2014::numeric, '2026-04', 'QI monthly rate seed'),
            (4, 8, 'QI_REBATE_INTERCHANGE_RATE',  '2026-04-01 00:00:00+08'::timestamptz, 0.9957::numeric, '2026-04', 'QI monthly rate seed'),
            (4, 9, 'QI_REBATE_INCENTIVE_RATE',    '2026-04-01 00:00:00+08'::timestamptz, 0.9957::numeric, '2026-04', 'QI monthly rate seed'),

            -- 2026-05
            (5, 1, 'QI_COST_SERVICE_RATE',        '2026-05-01 00:00:00+08'::timestamptz, 0.9808::numeric, '2026-05', 'QI monthly rate seed'),
            (5, 2, 'QI_COST_ACS_REGULAR_RATE',    '2026-05-01 00:00:00+08'::timestamptz, 0.9525::numeric, '2026-05', 'QI monthly rate seed'),
            (5, 3, 'QI_COST_ACS_VIP_RATE',        '2026-05-01 00:00:00+08'::timestamptz, 1.1040::numeric, '2026-05', 'QI monthly rate seed'),
            (5, 4, 'QI_COST_VRM_RATE',            '2026-05-01 00:00:00+08'::timestamptz, 1.1785::numeric, '2026-05', 'QI monthly rate seed'),
            (5, 5, 'QI_COST_HK_REGULAR_RATE',     '2026-05-01 00:00:00+08'::timestamptz, 0.9928::numeric, '2026-05', 'QI monthly rate seed'),
            (5, 6, 'QI_COST_HK_VIP_RATE',         '2026-05-01 00:00:00+08'::timestamptz, 0.9928::numeric, '2026-05', 'QI monthly rate seed'),
            (5, 7, 'QI_COST_DCSF_RATE',           '2026-05-01 00:00:00+08'::timestamptz, 1.0563::numeric, '2026-05', 'QI monthly rate seed'),
            (5, 8, 'QI_REBATE_INTERCHANGE_RATE',  '2026-05-01 00:00:00+08'::timestamptz, 0.9928::numeric, '2026-05', 'QI monthly rate seed'),
            (5, 9, 'QI_REBATE_INCENTIVE_RATE',    '2026-05-01 00:00:00+08'::timestamptz, 0.9928::numeric, '2026-05', 'QI monthly rate seed'),

            -- 2026-06
            (6, 1, 'QI_COST_SERVICE_RATE',        '2026-06-01 00:00:00+08'::timestamptz, 0.9749::numeric, '2026-06', 'QI monthly rate seed'),
            (6, 2, 'QI_COST_ACS_REGULAR_RATE',    '2026-06-01 00:00:00+08'::timestamptz, 0.9019::numeric, '2026-06', 'QI monthly rate seed'),
            (6, 3, 'QI_COST_ACS_VIP_RATE',        '2026-06-01 00:00:00+08'::timestamptz, 1.0636::numeric, '2026-06', 'QI monthly rate seed'),
            (6, 4, 'QI_COST_VRM_RATE',            '2026-06-01 00:00:00+08'::timestamptz, 1.3434::numeric, '2026-06', 'QI monthly rate seed'),
            (6, 5, 'QI_COST_HK_REGULAR_RATE',     '2026-06-01 00:00:00+08'::timestamptz, 0.9904::numeric, '2026-06', 'QI monthly rate seed'),
            (6, 6, 'QI_COST_HK_VIP_RATE',         '2026-06-01 00:00:00+08'::timestamptz, 0.9904::numeric, '2026-06', 'QI monthly rate seed'),
            (6, 7, 'QI_COST_DCSF_RATE',           '2026-06-01 00:00:00+08'::timestamptz, 1.1263::numeric, '2026-06', 'QI monthly rate seed'),
            (6, 8, 'QI_REBATE_INTERCHANGE_RATE',  '2026-06-01 00:00:00+08'::timestamptz, 0.9904::numeric, '2026-06', 'QI monthly rate seed'),
            (6, 9, 'QI_REBATE_INCENTIVE_RATE',    '2026-06-01 00:00:00+08'::timestamptz, 0.9904::numeric, '2026-06', 'QI monthly rate seed'),

            -- 兜底配置，使用 2026-06 rate
            (99, 1, 'QI_COST_SERVICE_RATE',       '2099-01-01 00:00:00+08'::timestamptz, 0.9749::numeric, 'DEFAULT_FALLBACK', 'QI fallback rate'),
            (99, 2, 'QI_COST_ACS_REGULAR_RATE',   '2099-01-01 00:00:00+08'::timestamptz, 0.9019::numeric, 'DEFAULT_FALLBACK', 'QI fallback rate'),
            (99, 3, 'QI_COST_ACS_VIP_RATE',       '2099-01-01 00:00:00+08'::timestamptz, 1.0636::numeric, 'DEFAULT_FALLBACK', 'QI fallback rate'),
            (99, 4, 'QI_COST_VRM_RATE',           '2099-01-01 00:00:00+08'::timestamptz, 1.3434::numeric, 'DEFAULT_FALLBACK', 'QI fallback rate'),
            (99, 5, 'QI_COST_HK_REGULAR_RATE',    '2099-01-01 00:00:00+08'::timestamptz, 0.9904::numeric, 'DEFAULT_FALLBACK', 'QI fallback rate'),
            (99, 6, 'QI_COST_HK_VIP_RATE',        '2099-01-01 00:00:00+08'::timestamptz, 0.9904::numeric, 'DEFAULT_FALLBACK', 'QI fallback rate'),
            (99, 7, 'QI_COST_DCSF_RATE',          '2099-01-01 00:00:00+08'::timestamptz, 1.1263::numeric, 'DEFAULT_FALLBACK', 'QI fallback rate'),
            (99, 8, 'QI_REBATE_INTERCHANGE_RATE', '2099-01-01 00:00:00+08'::timestamptz, 0.9904::numeric, 'DEFAULT_FALLBACK', 'QI fallback rate'),
            (99, 9, 'QI_REBATE_INCENTIVE_RATE',   '2099-01-01 00:00:00+08'::timestamptz, 0.9904::numeric, 'DEFAULT_FALLBACK', 'QI fallback rate')
    ) AS s(period_no, rule_no, tag, statistics_time, amount, detail, remarks)
)
INSERT INTO "ods"."ods_bi_month_tag"
    ("id", "create_time", "update_time", "delete_time", "version", "tag", "statistics_time", "amount", "remarks", "detail", "account_type", "provider", "product_line")
SELECT
    id,
    NOW() AS create_time,
    NOW() AS update_time,
    NULL::timestamptz AS delete_time,
    1 AS version,
    tag,
    statistics_time,
    amount,
    remarks,
    detail,
    'fullCustomer' AS account_type,
    'IQ' AS provider,
    'QI' AS product_line
FROM seed_rows
WHERE NOT EXISTS (
    SELECT 1
    FROM "ods"."ods_bi_month_tag" existing
    WHERE existing."id" = seed_rows.id
);

COMMIT;
