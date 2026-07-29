--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-29
-- Description:    销售佣金发薪快照明细表
-- Notes:
--   1. 每月8号从预估结果表固化生成。
--   2. current_payout 明细参与快照主表汇总，future_payout 仅用于未来发薪展示。
--********************************************************************--

CREATE TABLE "dws"."dws_sales_commission_snapshot_detail_p" (
  "id" int8 NOT NULL,
  "snapshot_date" date NOT NULL,
  "settlement_month" date NOT NULL,
  "root_account_id" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "product" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "provider" varchar(255) COLLATE "pg_catalog"."default",
  "item" varchar(64) COLLATE "pg_catalog"."default",
  "source_type" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "commission_stage" varchar(32) COLLATE "pg_catalog"."default" NOT NULL,
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "operation_manager_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "department_id" varchar(64) COLLATE "pg_catalog"."default",
  "invite_type" varchar(32) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'all',
  "activity_month" date,
  "collection_month" date,
  "payable_settlement_month" date,
  "effective_revenue" numeric(20,4) NOT NULL DEFAULT 0,
  "cogs" numeric(20,4) NOT NULL DEFAULT 0,
  "gp" numeric(20,4) NOT NULL DEFAULT 0,
  "commission_base" numeric(20,4) NOT NULL DEFAULT 0,
  "commission_rate" numeric(10,6) NOT NULL DEFAULT 0,
  "commission_amount" numeric(20,4) NOT NULL DEFAULT 0,
  "active_days" int4,
  "rule_code" varchar(64) COLLATE "pg_catalog"."default",
  "version" int4 DEFAULT 1,
  "remarks" varchar(1000) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_sales_commission_snapshot_detail_pkey" PRIMARY KEY ("id", "snapshot_date")
)
PARTITION BY RANGE (
  "snapshot_date" "pg_catalog"."date_ops"
);

ALTER TABLE "dws"."dws_sales_commission_snapshot_detail_p"
  OWNER TO "flink_cdc_user";

COMMENT ON TABLE "dws"."dws_sales_commission_snapshot_detail_p" IS '销售佣金发薪快照明细表，保存8号固化的佣金组成';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."id" IS '唯一标识，按快照、客户、产品、销售、来源等生成';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."snapshot_date" IS '快照生成日期，通常为每月8号，分区键';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."settlement_month" IS '结算月份，月初日期';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."root_account_id" IS '顶层客户ID';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."product" IS '产品线编码';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."provider" IS '服务商/渠道编码';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."item" IS '收费项编码';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."source_type" IS '页面回款来源类型';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."commission_stage" IS '佣金阶段：current_payout/future_payout';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."sale_id" IS '销售ID';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."operation_manager_id" IS '运营经理ID';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."am_id" IS 'AM ID';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."department_id" IS '销售所属部门ID';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."invite_type" IS '直邀类型：all/direct/non_direct，快照生成时计算后固化';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."activity_month" IS '业务活动月份';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."collection_month" IS '回款月份';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."payable_settlement_month" IS '发薪归属结算月份';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."effective_revenue" IS '有效收入';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."cogs" IS '成本';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."gp" IS '毛利';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."commission_base" IS '计佣基数';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."commission_rate" IS '命中佣金率';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."commission_amount" IS '佣金金额';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."active_days" IS '产品活跃天数';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."rule_code" IS '命中的返佣规则编码';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."version" IS '版本号';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."remarks" IS '备注';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "dws"."dws_sales_commission_snapshot_detail_p"."delete_time" IS '逻辑删除时间';

CREATE INDEX "idx_sales_commission_snapshot_detail_query" ON "dws"."dws_sales_commission_snapshot_detail_p" USING btree (
  "settlement_month" "pg_catalog"."date_ops" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "commission_stage" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE TABLE "dws"."dws_sales_commission_snapshot_detail_2026" PARTITION OF "dws"."dws_sales_commission_snapshot_detail_p"
FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
