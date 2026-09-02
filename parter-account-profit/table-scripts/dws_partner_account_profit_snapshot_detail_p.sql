--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-09-02
-- Description:    合伙人客户毛利月度快照详情表
-- Notes: 每月21号固化上个月物化视图结果，负毛利原样保存。
--********************************************************************--

CREATE TABLE "dws"."dws_partner_account_profit_snapshot_detail_p" (
  "id" int8 NOT NULL,
  "snapshot_date" date NOT NULL,
  "report_date" date NOT NULL,
  "settlement_month" date NOT NULL,
  "root_account_id" varchar(64) NOT NULL,
  "root_account_referral_id" varchar(64),
  "product" varchar(64) NOT NULL,
  "source_product" varchar(64) NOT NULL,
  "provider" varchar(255),
  "item" varchar(64),
  "source_type" varchar(64) NOT NULL,
  "effective_revenue" numeric(20,4) NOT NULL DEFAULT 0,
  "cogs" numeric(20,4) NOT NULL DEFAULT 0,
  "gp" numeric(20,4) NOT NULL DEFAULT 0,
  "version" int4 NOT NULL DEFAULT 1,
  "remarks" varchar(1000),
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_partner_account_profit_snapshot_detail_pkey" PRIMARY KEY ("id", "snapshot_date")
) PARTITION BY RANGE ("snapshot_date");


COMMENT ON TABLE "dws"."dws_partner_account_profit_snapshot_detail_p" IS '合伙人客户毛利月度快照详情，保存渠道/费用项粒度的收入、成本和毛利';
COMMENT ON COLUMN "dws"."dws_partner_account_profit_snapshot_detail_p"."root_account_referral_id" IS '快照时客户邀请码归属的合伙人用户ID';
COMMENT ON COLUMN "dws"."dws_partner_account_profit_snapshot_detail_p"."source_product" IS '原始产品编码，用于区分open_api和qbit_card';
COMMENT ON COLUMN "dws"."dws_partner_account_profit_snapshot_detail_p"."gp" IS '毛利=effective_revenue-cogs，可为负';

CREATE INDEX "idx_partner_profit_snapshot_detail_query"
  ON "dws"."dws_partner_account_profit_snapshot_detail_p" (settlement_month, root_account_referral_id, root_account_id, product);

CREATE TABLE "dws"."dws_partner_account_profit_snapshot_detail_2026"
  PARTITION OF "dws"."dws_partner_account_profit_snapshot_detail_p"
  FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
