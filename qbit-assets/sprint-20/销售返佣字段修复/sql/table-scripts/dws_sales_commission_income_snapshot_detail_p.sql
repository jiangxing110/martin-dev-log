--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-18
-- Updated Time:   2026-11-18 11:03:00
-- Description:    销售绩效实际收入快照明细表
-- Notes:
--   1. 每月8号由销售佣金快照 batch 与佣金主表、佣金明细表同批写入。
--   2. 粒度为快照日、活动月、账单月、客户、产品、渠道、收入项目、销售和AM。
--   3. 不保存成本、毛利、佣金率或佣金金额；收入与佣金计算分表。
--   4. 本 DDL 首次执行；脚本不删除或重建已有数据表。
--********************************************************************--

CREATE TABLE "dws"."dws_sales_commission_income_snapshot_detail_p" (
  "id" int8 NOT NULL,
  "snapshot_date" date NOT NULL,
  "activity_month" date NOT NULL,
  "bill_month" date,
  "root_account_id" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "product" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "provider" varchar(255) COLLATE "pg_catalog"."default",
  "income_type" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "income_amount" numeric(20,4) NOT NULL DEFAULT 0,
  "version" int4 NOT NULL DEFAULT 1,
  "remarks" varchar(1000) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_sales_commission_income_snapshot_detail_pkey"
    PRIMARY KEY ("id", "snapshot_date")
)
PARTITION BY RANGE ("snapshot_date");

ALTER TABLE "dws"."dws_sales_commission_income_snapshot_detail_p"
  OWNER TO "flink_cdc_user";

COMMENT ON TABLE "dws"."dws_sales_commission_income_snapshot_detail_p"
  IS '销售绩效实际收入快照明细；保存8号固化的客户收入组成';
COMMENT ON COLUMN "dws"."dws_sales_commission_income_snapshot_detail_p"."id"
  IS '收入明细唯一标识，由快照日和收入维度确定性生成';
COMMENT ON COLUMN "dws"."dws_sales_commission_income_snapshot_detail_p"."snapshot_date"
  IS '收入快照生成日期及分区键，通常为每月8号';
COMMENT ON COLUMN "dws"."dws_sales_commission_income_snapshot_detail_p"."activity_month"
  IS '活动/实收月份，按月粒度记录为该月1号（YYYY-MM-01）；BB/QI渠道返现按report_date汇总到该月';
COMMENT ON COLUMN "dws"."dws_sales_commission_income_snapshot_detail_p"."bill_month"
  IS '账单所属月份；OpenAPI保留原账单月，非账单收入为空';
COMMENT ON COLUMN "dws"."dws_sales_commission_income_snapshot_detail_p"."root_account_id"
  IS '顶层客户ID；BB/QI由来源account_id通过api_account_relation映射root_id，无映射时保留来源account_id';
COMMENT ON COLUMN "dws"."dws_sales_commission_income_snapshot_detail_p"."product"
  IS '产品线编码';
COMMENT ON COLUMN "dws"."dws_sales_commission_income_snapshot_detail_p"."provider"
  IS '渠道/服务商编码，可为空';
COMMENT ON COLUMN "dws"."dws_sales_commission_income_snapshot_detail_p"."income_type"
  IS '收入项目编码，如global_account_income、month_revenue或渠道返现';
COMMENT ON COLUMN "dws"."dws_sales_commission_income_snapshot_detail_p"."sale_id"
  IS '收入发生时来源记录中的销售ID';
COMMENT ON COLUMN "dws"."dws_sales_commission_income_snapshot_detail_p"."am_id"
  IS '收入发生时来源记录中的AM ID';
COMMENT ON COLUMN "dws"."dws_sales_commission_income_snapshot_detail_p"."income_amount"
  IS '该客户、产品、渠道和收入项目对应的实际收入金额，保留正负号';
COMMENT ON COLUMN "dws"."dws_sales_commission_income_snapshot_detail_p"."version"
  IS '记录版本号';
COMMENT ON COLUMN "dws"."dws_sales_commission_income_snapshot_detail_p"."remarks"
  IS '快照来源说明';
COMMENT ON COLUMN "dws"."dws_sales_commission_income_snapshot_detail_p"."create_time"
  IS '记录创建时间';
COMMENT ON COLUMN "dws"."dws_sales_commission_income_snapshot_detail_p"."update_time"
  IS '记录更新时间';
COMMENT ON COLUMN "dws"."dws_sales_commission_income_snapshot_detail_p"."delete_time"
  IS '逻辑删除时间';

CREATE INDEX "idx_sales_commission_income_snapshot_month_sale"
  ON "dws"."dws_sales_commission_income_snapshot_detail_p"
  USING btree ("activity_month", "sale_id", "am_id");
CREATE INDEX "idx_sales_commission_income_snapshot_account"
  ON "dws"."dws_sales_commission_income_snapshot_detail_p"
  USING btree ("activity_month", "root_account_id", "product", "provider");

CREATE TABLE "dws"."dws_sales_commission_income_snapshot_detail_2026"
  PARTITION OF "dws"."dws_sales_commission_income_snapshot_detail_p"
  FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE "dws"."dws_sales_commission_income_snapshot_detail_2027"
  PARTITION OF "dws"."dws_sales_commission_income_snapshot_detail_p"
  FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE "dws"."dws_sales_commission_income_snapshot_detail_2028"
  PARTITION OF "dws"."dws_sales_commission_income_snapshot_detail_p"
  FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');
