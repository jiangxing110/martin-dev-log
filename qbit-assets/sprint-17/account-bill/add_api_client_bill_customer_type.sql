-- 账单生成时的客户类型快照。
ALTER TABLE IF EXISTS "api_client_bill"
    ADD COLUMN IF NOT EXISTS "customer_type" varchar(64);

COMMENT ON COLUMN "api_client_bill"."customer_type"
    IS '账单生成时的客户类型：API/API客户，DIRECT/直客';


SELECT
    b."id" AS bill_id,
    b."type" AS bill_type,
    b."account_id",
    a."type" AS account_type,
    b."bill_month"
FROM "api_client_bill" b
JOIN "account" a
    ON a."id"::varchar = b."account_id"::varchar
WHERE 1=1
  AND b."delete_time" IS NULL
ORDER BY b."create_time";

UPDATE "api_client_bill" b
SET "customer_type" = CASE
    WHEN a."type" IN ('ApiClient', 'ApiClientCustomer')
        THEN 'API'
    ELSE 'DIRECT'
END
FROM "account" a
WHERE a."id"::varchar = b."account_id"::varchar
  AND b."customer_type" IS NULL
  AND b."delete_time" IS NULL
  AND b."type" IN ('MonthlyStatement', 'Rebate');