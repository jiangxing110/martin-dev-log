--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-02
-- Description:    销售毛利月度快照主表
-- Notes:
--   1. 结构参考 sale-repoet/sales-commission/table-scripts/dws_sales_commission_snapshot_p.sql。
--   2. 每月8号固化上个结算月；20号API月账单生成后沿用原snapshot_date幂等回写。
--   3. 金额保留正负号，不做归零、截断或非负约束。
--********************************************************************--

CREATE TABLE "dws"."dws_sales_gross_profit_snapshot_p" (
  "id" int8 NOT NULL,
  "snapshot_date" date NOT NULL,
  "settlement_month" date NOT NULL,
  "sale_id" varchar(64),
  "pref_rev" numeric(20,4) NOT NULL DEFAULT 0,
  "client_rebate" numeric(20,4) NOT NULL DEFAULT 0,
  "client_collection_rebate" numeric(20,4) NOT NULL DEFAULT 0,
  "gross_profit_rebate" numeric(20,4) NOT NULL DEFAULT 0,
  "rebate" numeric(20,4) NOT NULL DEFAULT 0,
  "pref_rev_effective" numeric(20,4) NOT NULL DEFAULT 0,
  "cost" numeric(20,4) NOT NULL DEFAULT 0,
  "pref_gp" numeric(20,4) NOT NULL DEFAULT 0,
  "cashflow_rev_sale" numeric(20,4) NOT NULL DEFAULT 0,
  "cashflow_rev_sale_effective" numeric(20,4) NOT NULL DEFAULT 0,
  "cashflow_gp_sale" numeric(20,4) NOT NULL DEFAULT 0,
  "version" int4 NOT NULL DEFAULT 1,
  "remarks" varchar(1000),
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_sales_gross_profit_snapshot_pkey" PRIMARY KEY ("id", "snapshot_date")
) PARTITION BY RANGE ("snapshot_date");

ALTER TABLE "dws"."dws_sales_gross_profit_snapshot_p" OWNER TO "flink_cdc_user";
COMMENT ON TABLE "dws"."dws_sales_gross_profit_snapshot_p" IS '销售毛利月度汇总快照，按结算月和销售固化';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_p"."snapshot_date" IS '快照日期；20号补入账单时仍使用本月8号日期';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_p"."settlement_month" IS '结算月份，月初日期';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_p"."sale_id" IS '销售ID；无销售归属时保留NULL';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_p"."rebate" IS '客户返现、代收返现和毛利返现的有符号合计';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_p"."pref_gp" IS '应收毛利=pref_rev-cost，可为负数';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_p"."cashflow_gp_sale" IS '销售维度毛利=cashflow_rev_sale-cost，可为负数';

CREATE INDEX "idx_sales_gross_profit_snapshot_query"
  ON "dws"."dws_sales_gross_profit_snapshot_p" USING btree ("settlement_month", "sale_id");

CREATE TABLE "dws"."dws_sales_gross_profit_snapshot_2026" PARTITION OF "dws"."dws_sales_gross_profit_snapshot_p"
  FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

CREATE TABLE "dws"."dws_sales_gross_profit_snapshot_2027" PARTITION OF "dws"."dws_sales_gross_profit_snapshot_p"
  FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');

CREATE TABLE "dws"."dws_sales_gross_profit_snapshot_2028" PARTITION OF "dws"."dws_sales_gross_profit_snapshot_p"
  FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');
