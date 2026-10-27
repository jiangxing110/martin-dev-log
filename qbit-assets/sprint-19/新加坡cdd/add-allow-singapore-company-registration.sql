ALTER TABLE "accountExtend"
  ADD COLUMN IF NOT EXISTS "allowSingaporeCompanyRegistration" boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN "accountExtend"."allowSingaporeCompanyRegistration" IS '是否允许新加坡公司主体开户';
