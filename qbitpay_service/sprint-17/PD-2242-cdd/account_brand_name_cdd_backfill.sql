-- PD-2242 / PD-1999：历史 CDD KYC/KYB 品牌名回填。
--
-- 只读取历史记录中明确的 brandNames/brandNameDba/brandName 字段，
-- 不把 businessName（公司法定名称）当成品牌名。
-- 脚本可重复执行：当前有效记录按 account_id + normalized_name 幂等写入。

WITH kyc_brand AS (
    SELECT
        kyc."accountId"::VARCHAR AS account_id,
        'KYC' AS source_type,
        'KYC:' || kyc.id::VARCHAR AS source_id,
        btrim(brand_name) AS brand_name
    FROM "cddKyc" kyc
    JOIN "cddKycBusinessDetail" detail ON detail."kycId" = kyc.id
    CROSS JOIN LATERAL jsonb_array_elements_text(
        CASE
            WHEN jsonb_typeof(to_jsonb(detail)->'brandNames') = 'array'
                THEN to_jsonb(detail)->'brandNames'
            WHEN jsonb_typeof(to_jsonb(detail)->'brandNameDba') = 'array'
                THEN to_jsonb(detail)->'brandNameDba'
            ELSE '[]'::JSONB
        END
    ) AS names(brand_name)
    WHERE kyc."isLatest" = TRUE
      AND detail."deleteTime" IS NULL
      AND kyc."deleteTime" IS NULL
      AND btrim(brand_name) <> ''
), kyb_brand AS (
    SELECT
        kyb."accountId"::VARCHAR AS account_id,
        'KYB' AS source_type,
        'KYB:' || kyb.id::VARCHAR AS source_id,
        btrim(name_item.brand_name) AS brand_name
    FROM "cddKyb" kyb
    JOIN "cddKybDetail" detail ON detail."kybId" = kyb.id
    CROSS JOIN LATERAL (
        SELECT jsonb_array_elements_text(detail.value::JSONB) AS brand_name
        WHERE detail.value ~ '^\s*\['
        UNION ALL
        SELECT detail.value AS brand_name
        WHERE detail.value !~ '^\s*\['
    ) name_item
    WHERE kyb."isLatest" = TRUE
      AND detail."deleteTime" IS NULL
      AND kyb."deleteTime" IS NULL
      AND detail.key IN ('brandNames', 'brandNameDba', 'brandName')
      AND btrim(name_item.brand_name) <> ''
), source AS (
    SELECT account_id, source_type, source_id, brand_name FROM kyc_brand
    UNION ALL
    SELECT account_id, source_type, source_id, brand_name FROM kyb_brand
), normalized AS (
    SELECT DISTINCT
        account_id,
        source_type,
        source_id,
        brand_name,
        lower(btrim(brand_name)) AS normalized_name
    FROM source
)
INSERT INTO account_brand_name (
    id, account_id, brand_name, normalized_name, source_type, source_id,
    create_time, update_time, version
)
SELECT
    (
        1000000000000000000
        + ('x' || substr(md5(source_type || ':' || source_id || ':' || account_id || ':' || normalized_name), 1, 15))::BIT(60)::BIGINT
    ),
    account_id,
    brand_name,
    normalized_name,
    source_type,
    source_id,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    0
FROM normalized
ON CONFLICT (account_id, normalized_name) WHERE delete_time IS NULL DO NOTHING;

-- 回填后检查仍超过 10 个品牌的账户。
SELECT account_id, COUNT(*) AS brand_count
FROM account_brand_name
WHERE delete_time IS NULL
GROUP BY account_id
HAVING COUNT(*) > 10
ORDER BY brand_count DESC, account_id;
