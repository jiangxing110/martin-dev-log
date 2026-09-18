-- PD-2242 / PD-1999：API 合规资料历史品牌名回填。
-- 由发布脚本在 account_brand_name 建表后执行；可重复执行。
INSERT INTO account_brand_name (
    id, account_id, brand_name, normalized_name, source_type, source_id,
    create_time, update_time, version
)
SELECT
    (1000000000000000000
        + ('x' || SUBSTR(MD5(source_type || ':' || source_id || ':' || account_id), 1, 15))::BIT(60)::BIGINT),
    account_id,
    brand_name,
    LOWER(BTRIM(brand_name)),
    source_type,
    source_id,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    0
FROM (
    SELECT account_id, product_name AS brand_name, 'API_COMPLIANCE' AS source_type,
           'CAAS:' || id::VARCHAR AS source_id
    FROM open_api_compliance_extend
    WHERE delete_time IS NULL AND product_name IS NOT NULL AND BTRIM(product_name) <> ''
    UNION ALL
    SELECT account_id, product_name AS brand_name, 'API_COMPLIANCE' AS source_type,
           'BAAS:' || id::VARCHAR AS source_id
    FROM baas_open_api_compliance_extend
    WHERE delete_time IS NULL AND product_name IS NOT NULL AND BTRIM(product_name) <> ''
) source
ON CONFLICT (account_id, normalized_name) WHERE delete_time IS NULL DO NOTHING;
