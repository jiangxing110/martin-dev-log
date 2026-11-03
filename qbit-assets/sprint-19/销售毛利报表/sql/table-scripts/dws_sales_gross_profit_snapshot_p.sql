--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-02
-- Updated Time:   2026-11-03 11:54:00
-- Description:    销售毛利日粒度汇总快照主表
-- Notes:
--   1. 结构参考 sale-repoet/sales-commission/table-scripts/dws_sales_commission_snapshot_p.sql。
--   2. 数据行按 report_date + sale_id 汇总；快照仍每月8号固化、20号沿用原snapshot_date幂等回写。
--   3. 金额保留正负号，不做归零、截断或非负约束。
--********************************************************************--

DROP TABLE IF EXISTS "dws"."dws_sales_gross_profit_snapshot_p";

CREATE TABLE "dws"."dws_sales_gross_profit_snapshot_p" (
  "id" int8 NOT NULL,
  "snapshot_date" date NOT NULL,
  "report_date" date NOT NULL,
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
COMMENT ON TABLE "dws"."dws_sales_gross_profit_snapshot_p" IS '销售毛利日粒度汇总快照，按业务日期和销售归集';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_p"."snapshot_date" IS '快照版本日期；每月8号固化，20号回刷时沿用本月8号日期';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_p"."report_date" IS '业务发生日期；日期区间查询按此字段过滤';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_p"."settlement_month" IS '报表归属月份，由 report_date 所属月确定；用于月度汇总和快照范围';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_p"."sale_id" IS '销售ID；无销售归属时保留NULL';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_p"."rebate" IS '客户返现、代收返现和毛利返现的有符号合计';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_p"."gross_profit_rebate" IS '兼容字段；毛利返现已并入client_rebate，本字段当前为0';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_p"."pref_gp" IS '应收毛利=pref_rev-cost，可为负数';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_p"."cashflow_gp_sale" IS '销售维度毛利=cashflow_rev_sale-cost，可为负数';

CREATE INDEX "idx_sales_gross_profit_snapshot_query"
  ON "dws"."dws_sales_gross_profit_snapshot_p" USING btree ("report_date", "sale_id", "settlement_month");

CREATE TABLE "dws"."dws_sales_gross_profit_snapshot_2026" PARTITION OF "dws"."dws_sales_gross_profit_snapshot_p" FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

CREATE TABLE "dws"."dws_sales_gross_profit_snapshot_2027" PARTITION OF "dws"."dws_sales_gross_profit_snapshot_p" FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');

CREATE TABLE "dws"."dws_sales_gross_profit_snapshot_2028" PARTITION OF "dws"."dws_sales_gross_profit_snapshot_p" FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');
