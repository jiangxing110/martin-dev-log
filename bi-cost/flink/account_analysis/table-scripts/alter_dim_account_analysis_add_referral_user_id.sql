--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-29
-- Description:    dim_account_analysis 增加邀请码归属用户字段
-- 作业元信息：
--   作业类型：DDL变更脚本
--   运行方式：非运行作业，目标库执行一次
--   运行参数：无
--   源库变更响应：不涉及源库变更同步。
--********************************************************************--

ALTER TABLE "dim"."dim_account_analysis"
  ADD COLUMN IF NOT EXISTS "referral_user_id" varchar(64) COLLATE "pg_catalog"."default";

COMMENT ON COLUMN "dim"."dim_account_analysis"."referral_user_id" IS '邀请码归属用户ID，来源 public.account.referralCodeId 关联 public.referralCode.userId；直邀/非直邀在佣金快照计算时按当期销售关系判断';

CREATE INDEX IF NOT EXISTS "idx_dim_account_analysis_referral" ON "dim"."dim_account_analysis" USING btree (
  "referral_user_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);
