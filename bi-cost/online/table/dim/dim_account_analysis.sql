--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-28
-- Description:    客户分析维表 dim_account_analysis
-- 作业元信息：
--   作业类型：DDL建表/视图脚本
--   运行方式：非运行作业
--   运行参数：无
--   源库变更响应：不涉及源库变更同步；用于创建 ADBPG 目标表和索引。
--********************************************************************--

CREATE TABLE "dim"."dim_account_analysis" (
  "account_id" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "verified_name" varchar(255) COLLATE "pg_catalog"."default",
  "account_category" varchar(64) COLLATE "pg_catalog"."default",
  "status" varchar(64) COLLATE "pg_catalog"."default",
  "system_type" varchar(64) COLLATE "pg_catalog"."default",
  "business_mode" varchar(128) COLLATE "pg_catalog"."default",
  "access_type" varchar(128) COLLATE "pg_catalog"."default",
  "mor_type" varchar(128) COLLATE "pg_catalog"."default",
  "mor_type_extra" text COLLATE "pg_catalog"."default",
  "account_risk_level" varchar(64) COLLATE "pg_catalog"."default",
  "referral_user_id" varchar(64) COLLATE "pg_catalog"."default",
  "card_active_time" timestamp(6),
  "global_active_time" timestamp(6),
  "crypto_active_time" timestamp(6),
  "api_active_time" timestamp(6),
  "treasury_active_time" timestamp(6),
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dim_account_analysis_pkey" PRIMARY KEY ("account_id")
);

ALTER TABLE "dim"."dim_account_analysis"
  OWNER TO "qbit_admin";

COMMENT ON TABLE "dim"."dim_account_analysis" IS '客户分析维表，按最上层客户沉淀基础属性、扩展属性、风险等级和业务激活时间';
COMMENT ON COLUMN "dim"."dim_account_analysis"."account_id" IS '客户ID，来源 dim_account.id';
COMMENT ON COLUMN "dim"."dim_account_analysis"."verified_name" IS '客户名称，来源 dim_account.verified_name';
COMMENT ON COLUMN "dim"."dim_account_analysis"."account_category" IS '客户类型，来源 dim_account.type';
COMMENT ON COLUMN "dim"."dim_account_analysis"."status" IS '客户状态，来源 dim_account.status';
COMMENT ON COLUMN "dim"."dim_account_analysis"."system_type" IS '客户系统类型，来源 accountExtend.systemType / dim_account.system_type';
COMMENT ON COLUMN "dim"."dim_account_analysis"."business_mode" IS '业务模式，来源 caas_open_api_extend.business_mode';
COMMENT ON COLUMN "dim"."dim_account_analysis"."access_type" IS '对接模式，来源 caas_open_api_extend.access_type';
COMMENT ON COLUMN "dim"."dim_account_analysis"."mor_type" IS 'MOR类别，来源 caas_open_api_extend.mor_type';
COMMENT ON COLUMN "dim"."dim_account_analysis"."mor_type_extra" IS 'MOR类别扩展字段，来源 caas_open_api_extend.mor_type_extra';
COMMENT ON COLUMN "dim"."dim_account_analysis"."account_risk_level" IS '客户风险等级，来源 cddRiskRating.accountRiskLevel';
COMMENT ON COLUMN "dim"."dim_account_analysis"."referral_user_id" IS '邀请码归属用户ID，来源 public.account.referralCodeId 关联 public.referralCode.userId；直邀/非直邀在佣金快照计算时按当期销售关系判断';
COMMENT ON COLUMN "dim"."dim_account_analysis"."card_active_time" IS '客户量子卡激活时间：卡钱包入金累计首次超过5000的交易时间';
COMMENT ON COLUMN "dim"."dim_account_analysis"."global_active_time" IS '客户全球账户激活时间：transfer 最早交易时间';
COMMENT ON COLUMN "dim"."dim_account_analysis"."crypto_active_time" IS '客户加密资产激活时间：sell/Closed/hidden=false 累计USD首次超过200000的交易时间';
COMMENT ON COLUMN "dim"."dim_account_analysis"."api_active_time" IS '客户API上线时间，来源 openApiClientConfig.online_time';
COMMENT ON COLUMN "dim"."dim_account_analysis"."treasury_active_time" IS '客户粒子理财激活时间，来源 fund_orders 首次 complete purchase';
COMMENT ON COLUMN "dim"."dim_account_analysis"."create_time" IS '维表记录创建时间';
COMMENT ON COLUMN "dim"."dim_account_analysis"."update_time" IS '维表记录更新时间';
COMMENT ON COLUMN "dim"."dim_account_analysis"."delete_time" IS '逻辑删除时间';

CREATE INDEX "idx_dim_account_analysis_status_type" ON "dim"."dim_account_analysis" USING btree (
  "account_category" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "status" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "system_type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dim_account_analysis_active_times" ON "dim"."dim_account_analysis" USING btree (
  "card_active_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST,
  "global_active_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST,
  "crypto_active_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST,
  "api_active_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST,
  "treasury_active_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dim_account_analysis_referral" ON "dim"."dim_account_analysis" USING btree (
  "referral_user_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);
