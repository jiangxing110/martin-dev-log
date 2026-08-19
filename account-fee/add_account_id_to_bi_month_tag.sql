-- 添加account_id字段到bi_month_tag表
ALTER TABLE "bi_month_tag" ADD COLUMN IF NOT EXISTS "account_id" VARCHAR(50);

-- 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS "idx_bi_month_tag_account_id" ON "bi_month_tag"("account_id");

-- 添加注释
COMMENT ON COLUMN "bi_month_tag"."account_id" IS '客户ID，关联account表的id字段';
