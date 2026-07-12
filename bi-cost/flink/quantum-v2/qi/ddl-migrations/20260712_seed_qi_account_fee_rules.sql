--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-12
-- Description:    QI 渠道 account_fee 默认规则插入模板
-- Notes:
--   1. 使用确定性 UUID 生成 id，保证脚本可重复执行
--   2. 这里按 2026 年 1 月到 6 月逐月生成默认规则，每个月独立一个时间窗
--   3. 同时补一条 2022-01-01 ~ 2099-01-01 的全局兜底规则
--   4. 仅为固定 QI 账户 accountId 生成数据
--********************************************************************--

WITH months AS (
    SELECT
        generate_series(DATE '2026-01-01', DATE '2026-06-01', INTERVAL '1 month')::date AS dt
),
target_accounts AS (
    SELECT
        '00000000-0000-0000-0000-000000000000'::uuid AS account_id
),
base_rules AS (
    SELECT *
    FROM (
        VALUES
            ('QI_COST_REIMBURSEMENT', NULL, 0.9946, 'Amount', 'Single', NULL, NULL, NULL, 'MasterAccount', NULL, NULL),
            ('QI_COST_SERVICE', NULL, 0.00095798, 'Amount', 'Tiered', 0, 5, NULL, 'MasterAccount', NULL, NULL),
            ('QI_COST_SERVICE', NULL, 0.00146218, 'Amount', 'Tiered', 5, 10, NULL, 'MasterAccount', NULL, NULL),
            ('QI_COST_SERVICE', NULL, 0.00221848, 'Amount', 'Tiered', 10, 50, NULL, 'MasterAccount', NULL, NULL),
            ('QI_COST_SERVICE', NULL, 0.00373108, 'Amount', 'Tiered', 50, 250, NULL, 'MasterAccount', NULL, NULL),
            ('QI_COST_SERVICE', NULL, 0.00448738, 'Amount', 'Tiered', 250, NULL, NULL, 'MasterAccount', NULL, NULL),
            ('QI_COST_ACS_REGULAR', NULL, 0.009852, 'Count', 'Tiered', 0, 5, NULL, 'MasterAccount', NULL, NULL),
            ('QI_COST_ACS_REGULAR', NULL, 0.054186, 'Count', 'Tiered', 5, 10, NULL, 'MasterAccount', NULL, NULL),
            ('QI_COST_ACS_REGULAR', NULL, 0.078816, 'Count', 'Tiered', 10, 50, NULL, 'MasterAccount', NULL, NULL),
            ('QI_COST_ACS_REGULAR', NULL, 0.118224, 'Count', 'Tiered', 50, 250, NULL, 'MasterAccount', NULL, NULL),
            ('QI_COST_ACS_REGULAR', NULL, 0.137928, 'Count', 'Tiered', 250, NULL, NULL, 'MasterAccount', NULL, NULL),
            ('QI_COST_ACS_VIP', NULL, 0.044584, 'Count', 'Tiered', 0, 5, NULL, 'MasterAccount', NULL, NULL),
            ('QI_COST_ACS_VIP', NULL, 0.245212, 'Count', 'Tiered', 5, 10, NULL, 'MasterAccount', NULL, NULL),
            ('QI_COST_ACS_VIP', NULL, 0.284223, 'Count', 'Tiered', 10, 50, NULL, 'MasterAccount', NULL, NULL),
            ('QI_COST_ACS_VIP', NULL, 0.535008, 'Count', 'Tiered', 50, 250, NULL, 'MasterAccount', NULL, NULL),
            ('QI_COST_ACS_VIP', NULL, 0.624176, 'Count', 'Tiered', 250, NULL, NULL, 'MasterAccount', NULL, NULL),
            ('QI_COST_VRM', NULL, 1.2239, 'Count', 'Single', NULL, NULL, NULL, 'MasterAccount', NULL, NULL),
            ('QI_REBATE_INTERCHANGE', NULL, 0.019892, 'Amount', 'Single', NULL, NULL, NULL, 'MasterAccount', NULL, NULL),
            ('QI_REBATE_INCENTIVE', NULL, 0.01173628, 'Amount', 'Single', NULL, NULL, NULL, 'MasterAccount', NULL, NULL)
    ) AS t(
        fee_type,
        remarks,
        rate,
        math_type,
        type,
        low,
        high,
        threshold,
        child_fee_type,
        provider,
        provider_field
    )
),
monthly_rows AS (
    SELECT
        (
            substr(md5(CONCAT(a.account_id, ':', r.fee_type, ':', TO_CHAR(m.dt, 'YYYY-MM'))), 1, 8) || '-' ||
            substr(md5(CONCAT(a.account_id, ':', r.fee_type, ':', TO_CHAR(m.dt, 'YYYY-MM'))), 9, 4) || '-' ||
            substr(md5(CONCAT(a.account_id, ':', r.fee_type, ':', TO_CHAR(m.dt, 'YYYY-MM'))), 13, 4) || '-' ||
            substr(md5(CONCAT(a.account_id, ':', r.fee_type, ':', TO_CHAR(m.dt, 'YYYY-MM'))), 17, 4) || '-' ||
            substr(md5(CONCAT(a.account_id, ':', r.fee_type, ':', TO_CHAR(m.dt, 'YYYY-MM'))), 21, 12)
        )::uuid AS id,
        m.dt,
        CONCAT(r.remarks, ' ', TO_CHAR(m.dt, 'YYYY-MM')) AS remarks,
        NOW() AS create_time,
        NOW() AS update_time,
        NULL::timestamptz AS delete_time,
        1 AS version,
        a.account_id,
        r.fee_type,
        r.rate::double precision,
        r.math_type,
        CAST(m.dt AS TIMESTAMP(6)) AS start_time,
        CAST((m.dt + INTERVAL '1 month') AS TIMESTAMP(6)) AS end_time,
        r.type,
        r.low::double precision,
        r.high::double precision,
        NULL::double precision AS threshold,
        r.child_fee_type,
        NULL AS raw,
        r.provider,
        r.provider_field,
        TRUE AS enable,
        0::numeric(20,4) AS collection_rate
    FROM target_accounts a
    CROSS JOIN months m
    CROSS JOIN base_rules r
),
fallback_rows AS (
    SELECT
        (
            substr(md5(CONCAT(a.account_id, ':', r.fee_type, ':', 'DEFAULT')), 1, 8) || '-' ||
            substr(md5(CONCAT(a.account_id, ':', r.fee_type, ':', 'DEFAULT')), 9, 4) || '-' ||
            substr(md5(CONCAT(a.account_id, ':', r.fee_type, ':', 'DEFAULT')), 13, 4) || '-' ||
            substr(md5(CONCAT(a.account_id, ':', r.fee_type, ':', 'DEFAULT')), 17, 4) || '-' ||
            substr(md5(CONCAT(a.account_id, ':', r.fee_type, ':', 'DEFAULT')), 21, 12)
        )::uuid AS id,
        DATE '2022-01-01' AS dt,
        CONCAT(r.remarks, ' DEFAULT') AS remarks,
        NOW() AS create_time,
        NOW() AS update_time,
        NULL::timestamptz AS delete_time,
        1 AS version,
        a.account_id,
        r.fee_type,
        r.rate::double precision,
        r.math_type,
        TIMESTAMP '2022-01-01 00:00:00' AS start_time,
        TIMESTAMP '2099-01-01 00:00:00' AS end_time,
        r.type,
        r.low::double precision,
        r.high::double precision,
        NULL::double precision AS threshold,
        r.child_fee_type,
        NULL AS raw,
        r.provider,
        r.provider_field,
        TRUE AS enable,
        0::numeric(20,4) AS collection_rate
    FROM target_accounts a
    CROSS JOIN base_rules r
),
all_rows AS (
    SELECT * FROM monthly_rows
    UNION ALL
    SELECT * FROM fallback_rows
)
INSERT INTO "ods"."ods_account_fee"
("id", "dt", "remarks", "create_time", "update_time", "delete_time", "version",
 "account_id", "fee_type", "rate", "math_type", "start_time", "end_time", "type",
 "low", "high", "threshold", "child_fee_type", "raw", "provider", "provider_field",
 "enable", "collection_rate")
SELECT ar.*
FROM all_rows ar
ON CONFLICT ("id", "dt") DO NOTHING;


type 

Tiered
Single
