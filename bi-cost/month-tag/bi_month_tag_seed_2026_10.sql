-- BB 与 QI 的 ods_bi_month_tag 2026-10 月度配置
-- Created Time: 2026-11-06 00:00:00
-- Updated Time: 2026-11-06 00:00:00
-- 说明:
-- 1. 配置 BB_CASH_RATE 和 QI 月度成本 / 返现系数，共 11 条。
-- 2. 销售口径的 QI 返现 tag 使用 1.0000；客户毛利口径单独应用 param_e=1.0848。
-- 3. 成本及返现金额仅用于报表核对，不写入费率 tag。
-- 4. 执行前先运行下方固定 ID 冲突检查，确认没有无关记录占用这些 ID。
-- 5. 本脚本仅维护 2026-10，不修改其他月份或 DEFAULT_FALLBACK。

-- 执行前核对固定 ID 是否已被无关配置占用；预期返回 0 行。
WITH seed_ids(id) AS (
    VALUES
        (202611060901::bigint), (202611060902::bigint),
        (202611060903::bigint), (202611060904::bigint),
        (202611060905::bigint), (202611060906::bigint),
        (202611060907::bigint), (202611060908::bigint),
        (202611060909::bigint), (202611060910::bigint),
        (202611060911::bigint)
)
SELECT t.id, t.provider, t.product_line, t.account_type, t.tag, t.detail
FROM ods.ods_bi_month_tag t
JOIN seed_ids s ON s.id = t.id
WHERE NOT (
      (t.id = 202611060901 AND t.provider = 'BB' AND t.product_line = 'BB' AND t.account_type = 'fullCustomer' AND t.tag = 'BB_CASH_RATE' AND t.detail = '2026-10')
      OR (t.id = 202611060902 AND t.provider = 'IQ' AND t.product_line = 'QI' AND t.account_type = 'fullCustomer' AND t.tag = 'QI_COST_REIMBURSEMENT_RATE' AND t.detail = '2026-10')
      OR (t.id = 202611060903 AND t.provider = 'IQ' AND t.product_line = 'QI' AND t.account_type = 'fullCustomer' AND t.tag = 'QI_COST_SERVICE_RATE' AND t.detail = '2026-10')
      OR (t.id = 202611060904 AND t.provider = 'IQ' AND t.product_line = 'QI' AND t.account_type = 'fullCustomer' AND t.tag = 'QI_COST_ACS_REGULAR_RATE' AND t.detail = '2026-10')
      OR (t.id = 202611060905 AND t.provider = 'IQ' AND t.product_line = 'QI' AND t.account_type = 'fullCustomer' AND t.tag = 'QI_COST_ACS_VIP_RATE' AND t.detail = '2026-10')
      OR (t.id = 202611060906 AND t.provider = 'IQ' AND t.product_line = 'QI' AND t.account_type = 'fullCustomer' AND t.tag = 'QI_COST_VRM_RATE' AND t.detail = '2026-10')
      OR (t.id = 202611060907 AND t.provider = 'IQ' AND t.product_line = 'QI' AND t.account_type = 'fullCustomer' AND t.tag = 'QI_COST_HK_REGULAR_RATE' AND t.detail = '2026-10')
      OR (t.id = 202611060908 AND t.provider = 'IQ' AND t.product_line = 'QI' AND t.account_type = 'fullCustomer' AND t.tag = 'QI_COST_HK_VIP_RATE' AND t.detail = '2026-10')
      OR (t.id = 202611060909 AND t.provider = 'IQ' AND t.product_line = 'QI' AND t.account_type = 'fullCustomer' AND t.tag = 'QI_COST_DCSF_RATE' AND t.detail = '2026-10')
      OR (t.id = 202611060910 AND t.provider = 'IQ' AND t.product_line = 'QI' AND t.account_type = 'fullCustomer' AND t.tag = 'QI_REBATE_INTERCHANGE_RATE' AND t.detail = '2026-10')
      OR (t.id = 202611060911 AND t.provider = 'IQ' AND t.product_line = 'QI' AND t.account_type = 'fullCustomer' AND t.tag = 'QI_REBATE_INCENTIVE_RATE' AND t.detail = '2026-10')
  );

BEGIN;

CREATE TEMP TABLE tmp_bi_month_tag_seed_2026_10 (
    id              bigint,
    provider        text,
    product_line    text,
    account_type    text,
    tag             text,
    statistics_time timestamptz,
    amount          numeric,
    detail          text,
    remarks         text
) ON COMMIT DROP
DISTRIBUTED BY (id);

INSERT INTO tmp_bi_month_tag_seed_2026_10
    (id, provider, product_line, account_type, tag, statistics_time, amount, detail, remarks)
VALUES
    (202611060901, 'BB', 'BB', 'fullCustomer', 'BB_CASH_RATE',
     '2026-10-01 00:00:00+08'::timestamptz, 0.022698, '2026-10', 'BB 2026-10 monthly cashback rate; 2.2698%'),
    (202611060902, 'IQ', 'QI', 'fullCustomer', 'QI_COST_REIMBURSEMENT_RATE',
     '2026-10-01 00:00:00+08'::timestamptz, 1.0848, '2026-10', 'QI 2026-10 monthly rate seed; reimbursement / CROSS'),
    (202611060903, 'IQ', 'QI', 'fullCustomer', 'QI_COST_SERVICE_RATE',
     '2026-10-01 00:00:00+08'::timestamptz, 1.0122, '2026-10', 'QI 2026-10 monthly rate seed; param_a'),
    (202611060904, 'IQ', 'QI', 'fullCustomer', 'QI_COST_ACS_REGULAR_RATE',
     '2026-10-01 00:00:00+08'::timestamptz, 0.9079, '2026-10', 'QI 2026-10 monthly rate seed; param_b'),
    (202611060905, 'IQ', 'QI', 'fullCustomer', 'QI_COST_ACS_VIP_RATE',
     '2026-10-01 00:00:00+08'::timestamptz, 1.1059, '2026-10', 'QI 2026-10 monthly rate seed; param_c'),
    (202611060906, 'IQ', 'QI', 'fullCustomer', 'QI_COST_VRM_RATE',
     '2026-10-01 00:00:00+08'::timestamptz, 1.0131, '2026-10', 'QI 2026-10 monthly rate seed; param_d / VRM'),
    (202611060907, 'IQ', 'QI', 'fullCustomer', 'QI_COST_HK_REGULAR_RATE',
     '2026-10-01 00:00:00+08'::timestamptz, 1.0848, '2026-10', 'QI 2026-10 monthly rate seed; param_e / CROSS'),
    (202611060908, 'IQ', 'QI', 'fullCustomer', 'QI_COST_HK_VIP_RATE',
     '2026-10-01 00:00:00+08'::timestamptz, 1.0848, '2026-10', 'QI 2026-10 monthly rate seed; param_e / CROSS'),
    (202611060909, 'IQ', 'QI', 'fullCustomer', 'QI_COST_DCSF_RATE',
     '2026-10-01 00:00:00+08'::timestamptz, 0.9676, '2026-10', 'QI 2026-10 monthly rate seed; param_f / DCSF'),
    (202611060910, 'IQ', 'QI', 'fullCustomer', 'QI_REBATE_INTERCHANGE_RATE',
     '2026-10-01 00:00:00+08'::timestamptz, 1.0000, '2026-10', 'QI 2026-10 sales cashback rate; no parameter multiplier'),
    (202611060911, 'IQ', 'QI', 'fullCustomer', 'QI_REBATE_INCENTIVE_RATE',
     '2026-10-01 00:00:00+08'::timestamptz, 1.0000, '2026-10', 'QI 2026-10 monthly rebate rate seed');

-- 软删除同月份、同 provider/product_line/account_type/tag 下其他有效配置。
UPDATE ods.ods_bi_month_tag old_tag
SET
    delete_time = NOW(),
    update_time = NOW(),
    remarks = COALESCE(old_tag.remarks, '') || ' | replaced by bi_month_tag_seed_2026_10'
FROM tmp_bi_month_tag_seed_2026_10 s
WHERE old_tag.provider = s.provider
  AND old_tag.product_line = s.product_line
  AND old_tag.account_type = s.account_type
  AND old_tag.tag = s.tag
  AND old_tag.detail = s.detail
  AND old_tag.id <> s.id
  AND old_tag.delete_time IS NULL;

-- 固定 ID 已存在时更新并重新激活。
UPDATE ods.ods_bi_month_tag existing
SET
    update_time = NOW(),
    delete_time = NULL,
    version = 1,
    tag = s.tag,
    statistics_time = s.statistics_time,
    amount = s.amount,
    remarks = s.remarks,
    detail = s.detail,
    account_type = s.account_type,
    provider = s.provider,
    product_line = s.product_line
FROM tmp_bi_month_tag_seed_2026_10 s
WHERE existing.id = s.id;

-- 固定 ID 不存在时插入。
INSERT INTO ods.ods_bi_month_tag
    (id, create_time, update_time, delete_time, version, tag, statistics_time, amount, remarks, detail, account_type, provider, product_line)
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
    s.account_type,
    s.provider,
    s.product_line
FROM tmp_bi_month_tag_seed_2026_10 s
WHERE NOT EXISTS (
    SELECT 1
    FROM ods.ods_bi_month_tag existing
    WHERE existing.id = s.id
);

COMMIT;

-- 执行后应返回 BB 1 行、QI 10 行；检查有效配置及金额。
SELECT
    provider,
    product_line,
    account_type,
    tag,
    statistics_time,
    amount,
    detail,
    remarks
FROM ods.ods_bi_month_tag
WHERE detail = '2026-10'
  AND delete_time IS NULL
  AND (
      (provider = 'BB' AND product_line = 'BB' AND account_type = 'fullCustomer' AND tag = 'BB_CASH_RATE')
      OR (provider = 'IQ' AND product_line = 'QI' AND account_type = 'fullCustomer'
          AND tag IN (
              'QI_COST_REIMBURSEMENT_RATE',
              'QI_COST_SERVICE_RATE',
              'QI_COST_ACS_REGULAR_RATE',
              'QI_COST_ACS_VIP_RATE',
              'QI_COST_VRM_RATE',
              'QI_COST_HK_REGULAR_RATE',
              'QI_COST_HK_VIP_RATE',
              'QI_COST_DCSF_RATE',
              'QI_REBATE_INTERCHANGE_RATE',
              'QI_REBATE_INCENTIVE_RATE'
          ))
  )
ORDER BY provider, tag;
