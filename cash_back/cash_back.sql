ALTER TABLE "public"."cash_back_bonuses"
    ADD COLUMN IF NOT EXISTS "channel_rate" NUMERIC DEFAULT 1,
    ADD COLUMN IF NOT EXISTS "scheme_fee" NUMERIC DEFAULT 0;

COMMENT ON COLUMN "public"."cash_back_bonuses"."channel_rate" IS '渠道返现比例';
COMMENT ON COLUMN "public"."cash_back_bonuses"."scheme_fee" IS 'Scheme fee';

UPDATE "public"."cash_back_bonuses"
SET "channel_rate" = COALESCE("channel_rate", 1),
    "scheme_fee" = COALESCE("scheme_fee", 0)
WHERE "channel_rate" IS NULL
   OR "scheme_fee" IS NULL;



SELECT
    id,
    account_id,
    month,
    project,
    purchase_net_amount,
    channel_rate,
    scheme_fee,
    ratio,
    cash_back_amount AS actual_cash_back_amount,
    ROUND(((purchase_net_amount * channel_rate - scheme_fee) * ratio)::numeric, 2) AS expected_cash_back_amount,
    cash_back_amount - ROUND(((purchase_net_amount * channel_rate - scheme_fee) * ratio)::numeric, 2) AS diff_amount,
    CASE
        WHEN cash_back_amount = ROUND(((purchase_net_amount * channel_rate - scheme_fee) * ratio)::numeric, 2)
            THEN 'MATCH'
        ELSE 'DIFF'
    END AS check_result
FROM "public"."cash_back_bonuses"
WHERE delete_time IS NULL
ORDER BY create_time DESC;