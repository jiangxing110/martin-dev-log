--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-09-02
-- Description:    合伙人客户业务线毛利返佣结果表
-- Notes: 粒度为合伙人+客户+业务线+结算月，每月快照后计算写入。
--********************************************************************--

CREATE TABLE "public"."partner_gross_margin_commission_p" (
  "id" int8 NOT NULL,
  "snapshot_date" date NOT NULL,
  "settlement_month" date NOT NULL,
  "partner_id" varchar(64) NOT NULL,
  "account_id" varchar(64) NOT NULL,
  "product_line_type" varchar(32) NOT NULL,
  "gross_profit" numeric(20,4) NOT NULL DEFAULT 0,
  "commission_before_floor" numeric(20,4) NOT NULL DEFAULT 0,
  "commission_amount" numeric(20,4) NOT NULL DEFAULT 0,
  "config_id" int8,
  "config_effective_time" timestamptz(6),
  "config_expiration_time" timestamptz(6),
  "version" int4 NOT NULL DEFAULT 1,
  "remarks" varchar(1000),
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "partner_gross_margin_commission_pkey" PRIMARY KEY ("id", "snapshot_date")
) PARTITION BY RANGE ("snapshot_date");


COMMENT ON TABLE "public"."partner_gross_margin_commission_p" IS '合伙人客户业务线毛利返佣结果，按月快照固化';
COMMENT ON COLUMN "public"."partner_gross_margin_commission_p"."gross_profit" IS '客户业务线月度毛利，可为负';
COMMENT ON COLUMN "public"."partner_gross_margin_commission_p"."commission_before_floor" IS '按阶梯计算的原始返佣金额，负毛利时为0';
COMMENT ON COLUMN "public"."partner_gross_margin_commission_p"."commission_amount" IS '最终返佣金额，MAX(commission_before_floor, 0)';

CREATE INDEX "idx_partner_gross_margin_commission_query"
  ON "public"."partner_gross_margin_commission_p" (settlement_month, partner_id, account_id, product_line_type);

CREATE TABLE "public"."partner_gross_margin_commission_2026"
  PARTITION OF "public"."partner_gross_margin_commission_p"
  FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
