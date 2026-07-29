--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-29
-- Description:    销售佣金发薪快照主表
-- Notes:
--   1. 每月8号固化上个月 settlement_month 的佣金汇总。
--   2. 8号后页面钱包区查询本表和明细表，不再查询预估结果表。
--********************************************************************--

CREATE TABLE "dws"."dws_sales_commission_snapshot_p" (
  "id" int8 NOT NULL,
  "snapshot_date" date NOT NULL,
  "settlement_month" date NOT NULL,
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "operation_manager_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "total_effective_revenue" numeric(20,4) NOT NULL DEFAULT 0,
  "total_cogs" numeric(20,4) NOT NULL DEFAULT 0,
  "total_gp" numeric(20,4) NOT NULL DEFAULT 0,
  "total_commission" numeric(20,4) NOT NULL DEFAULT 0,
  "version" int4 DEFAULT 1,
  "remarks" varchar(1000) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_sales_commission_snapshot_pkey" PRIMARY KEY ("id", "snapshot_date")
)
PARTITION BY RANGE (
  "snapshot_date" "pg_catalog"."date_ops"
);

ALTER TABLE "dws"."dws_sales_commission_snapshot_p"
  OWNER TO "flink_cdc_user";

COMMENT ON TABLE "dws"."dws_sales_commission_snapshot_p" IS '销售佣金发薪快照主表，每月8号按销售/AM固化汇总';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_p"."id" IS '唯一标识，按snapshot_date、settlement_month、sale_id、am_id生成';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_p"."snapshot_date" IS '快照生成日期，通常为每月8号，分区键';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_p"."settlement_month" IS '结算月份，月初日期';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_p"."sale_id" IS '销售ID';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_p"."operation_manager_id" IS '运营经理ID';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_p"."am_id" IS 'AM ID';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_p"."total_effective_revenue" IS '当前发薪明细有效收入合计';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_p"."total_cogs" IS '当前发薪明细成本合计';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_p"."total_gp" IS '当前发薪明细毛利合计';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_p"."total_commission" IS '当前发薪明细佣金合计';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_p"."version" IS '版本号';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_p"."remarks" IS '备注';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_p"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_p"."delete_time" IS '逻辑删除时间';

CREATE INDEX "idx_sales_commission_snapshot_query" ON "dws"."dws_sales_commission_snapshot_p" USING btree (
  "settlement_month" "pg_catalog"."date_ops" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE TABLE "dws"."dws_sales_commission_snapshot_2026" PARTITION OF "dws"."dws_sales_commission_snapshot_p"
FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
