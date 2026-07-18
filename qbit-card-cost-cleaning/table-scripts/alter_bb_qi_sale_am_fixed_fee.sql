ALTER TABLE "public"."dws_bb_card_finance_daily_p"
  ADD COLUMN IF NOT EXISTS "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  ADD COLUMN IF NOT EXISTS "am_id" varchar(64) COLLATE "pg_catalog"."default",
  ADD COLUMN IF NOT EXISTS "cost_fixed_fee" numeric(20,4) DEFAULT 0;

ALTER TABLE "public"."dws_qi_card_finance_daily_p"
  ADD COLUMN IF NOT EXISTS "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  ADD COLUMN IF NOT EXISTS "am_id" varchar(64) COLLATE "pg_catalog"."default",
  ADD COLUMN IF NOT EXISTS "cost_fixed_fee" numeric(20,4) DEFAULT 0;

COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."sale_id" IS '销售ID';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."am_id" IS 'AM ID';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."cost_fixed_fee" IS '固定渠道成本';

COMMENT ON COLUMN "public"."dws_qi_card_finance_daily_p"."sale_id" IS '销售ID';
COMMENT ON COLUMN "public"."dws_qi_card_finance_daily_p"."am_id" IS 'AM ID';
COMMENT ON COLUMN "public"."dws_qi_card_finance_daily_p"."cost_fixed_fee" IS '固定渠道成本';
