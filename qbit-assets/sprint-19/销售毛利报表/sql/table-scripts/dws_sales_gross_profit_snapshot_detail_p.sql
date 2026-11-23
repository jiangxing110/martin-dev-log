--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-02
-- Updated Time:   2026-11-23 17:07:30
-- Description:    销售毛利日粒度快照明细表
-- Notes:
--   1. 结构参考 sale-repoet/sales-commission/table-scripts/dws_sales_commission_snapshot_detail_p.sql。
--   2. 明细粒度：快照版本日、业务日、结算月、销售、客户、产品、渠道和来源类型。
--   3. 金额保留正负号，不做归零、截断或非负约束。
--********************************************************************--

DROP TABLE IF EXISTS "dws"."dws_sales_gross_profit_snapshot_detail_p";

CREATE TABLE "dws"."dws_sales_gross_profit_snapshot_detail_p" (
  "id" int8 NOT NULL,
  "snapshot_date" date NOT NULL,
  "report_date" date NOT NULL,
  "settlement_month" date NOT NULL,
  "report_month" date NOT NULL,
  "sale_id" varchar(64) NOT NULL CHECK (BTRIM("sale_id") <> ''),
  "root_account_id" varchar(64) NOT NULL,
  "product" varchar(64) NOT NULL,
  "provider" varchar(255),
  "metric_code" varchar(128),
  "source_type" varchar(64) NOT NULL,
  "api_bill_type" varchar(16),
  "pref_rev" numeric(20,4) NOT NULL DEFAULT 0,
  "client_rebate" numeric(20,4) NOT NULL DEFAULT 0,
  "client_collection_rebate" numeric(20,4) NOT NULL DEFAULT 0,
  "gross_profit_rebate" numeric(20,4) NOT NULL DEFAULT 0,
  "rebate" numeric(20,4) NOT NULL DEFAULT 0,
  "pref_rev_effective" numeric(20,4) NOT NULL DEFAULT 0,
  "cost" numeric(20,4) NOT NULL DEFAULT 0,
  "pref_gp" numeric(20,4) NOT NULL DEFAULT 0,
  "cashflow_rev" numeric(20,4) NOT NULL DEFAULT 0,
  "cashflow_rev_effective" numeric(20,4) NOT NULL DEFAULT 0,
  "cashflow_gp" numeric(20,4) NOT NULL DEFAULT 0,
  "cashflow_rev_sale" numeric(20,4) NOT NULL DEFAULT 0,
  "cashflow_rev_sale_effective" numeric(20,4) NOT NULL DEFAULT 0,
  "cashflow_gp_sale" numeric(20,4) NOT NULL DEFAULT 0,
  "version" int4 NOT NULL DEFAULT 1,
  "remarks" varchar(1000),
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_sales_gross_profit_snapshot_detail_pkey" PRIMARY KEY ("id", "snapshot_date")
) PARTITION BY RANGE ("snapshot_date");

ALTER TABLE "dws"."dws_sales_gross_profit_snapshot_detail_p" OWNER TO "flink_cdc_user";
COMMENT ON TABLE "dws"."dws_sales_gross_profit_snapshot_detail_p" IS '销售毛利日粒度快照明细，保存收入、返现、成本和毛利来源';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_detail_p"."snapshot_date" IS '快照版本日期；不代表业务发生日或每日运行频率';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_detail_p"."report_date" IS '业务发生日期；日期区间查询按此字段过滤';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_detail_p"."settlement_month" IS '报表归属月份，由 report_date 所属月确定';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_detail_p"."sale_id" IS '销售ID；无销售归属的数据不写入快照';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_detail_p"."api_bill_type" IS 'Open API月账单类型：RECEIVABLE应收、RECEIVED实收，其他来源为空';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_detail_p"."provider" IS '渠道/服务商；NULL单独保留';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_detail_p"."cashflow_rev" IS '整体实收收入：实时收入及历史月账单实收';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_detail_p"."cashflow_rev_effective" IS '整体实收有效收入=cashflow_rev-rebate，可为负数';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_detail_p"."cashflow_gp" IS '整体实收毛利=cashflow_rev_effective-cost+physical_card_gp，可为负数';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_detail_p"."gross_profit_rebate" IS '兼容字段；毛利返现已并入client_rebate，本字段当前为0';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_detail_p"."pref_gp" IS '应收毛利=pref_rev_effective-cost+physical_card_gp，可为负数';
COMMENT ON COLUMN "dws"."dws_sales_gross_profit_snapshot_detail_p"."cashflow_gp_sale" IS '销售维度毛利=cashflow_rev_sale_effective-cost+physical_card_gp，可为负数';

CREATE INDEX "idx_sales_gross_profit_snapshot_detail_query"
  ON "dws"."dws_sales_gross_profit_snapshot_detail_p" USING btree ("report_date", "sale_id", "root_account_id");
CREATE INDEX "idx_sales_gross_profit_snapshot_detail_product"
  ON "dws"."dws_sales_gross_profit_snapshot_detail_p" USING btree ("report_date", "sale_id", "product", "api_bill_type");

CREATE TABLE "dws"."dws_sales_gross_profit_snapshot_detail_2026" PARTITION OF "dws"."dws_sales_gross_profit_snapshot_detail_p" FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

CREATE TABLE "dws"."dws_sales_gross_profit_snapshot_detail_2027" PARTITION OF "dws"."dws_sales_gross_profit_snapshot_detail_p" FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');

CREATE TABLE "dws"."dws_sales_gross_profit_snapshot_detail_2028" PARTITION OF "dws"."dws_sales_gross_profit_snapshot_detail_p" FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');
