-- 为 ODS 月度标签表增加客户维度字段
ALTER TABLE "ods"."ods_bi_month_tag"
    ADD COLUMN IF NOT EXISTS "account_id" VARCHAR(50);

CREATE INDEX IF NOT EXISTS "idx_ods_bi_month_tag_account_id"
    ON "ods"."ods_bi_month_tag" ("account_id");

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."account_id"
    IS '客户ID，关联account表的id字段';
