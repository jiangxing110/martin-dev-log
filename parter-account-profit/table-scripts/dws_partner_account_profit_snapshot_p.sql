--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-09-02
-- Description:    合伙人客户毛利月度快照主表
-- Notes: 每月21号按合伙人、客户、产品固化上个月毛利汇总。
--********************************************************************--

CREATE TABLE "dws"."dws_partner_account_profit_snapshot_p" (
  "id" int8 NOT NULL,
  "snapshot_date" date NOT NULL,
  "settlement_month" date NOT NULL,
  "root_account_referral_id" varchar(64),
  "root_account_id" varchar(64) NOT NULL,
  "product" varchar(64) NOT NULL,
  "total_effective_revenue" numeric(20,4) NOT NULL DEFAULT 0,
  "total_cogs" numeric(20,4) NOT NULL DEFAULT 0,
  "total_gp" numeric(20,4) NOT NULL DEFAULT 0,
  "version" int4 NOT NULL DEFAULT 1,
  "remarks" varchar(1000),
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_partner_account_profit_snapshot_pkey" PRIMARY KEY ("id", "snapshot_date")
) PARTITION BY RANGE ("snapshot_date");

ALTER TABLE "dws"."dws_partner_account_profit_snapshot_p" OWNER TO "flink_cdc_user";

COMMENT ON TABLE "dws"."dws_partner_account_profit_snapshot_p" IS '合伙人客户毛利月度快照主表，按合伙人、root客户、产品汇总';
COMMENT ON COLUMN "dws"."dws_partner_account_profit_snapshot_p"."total_gp" IS '客户产品月度毛利，可为负，不做下限处理';

CREATE INDEX "idx_partner_profit_snapshot_query"
  ON "dws"."dws_partner_account_profit_snapshot_p" (settlement_month, root_account_referral_id, root_account_id, product);

CREATE TABLE "dws"."dws_partner_account_profit_snapshot_2026"
  PARTITION OF "dws"."dws_partner_account_profit_snapshot_p"
  FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
