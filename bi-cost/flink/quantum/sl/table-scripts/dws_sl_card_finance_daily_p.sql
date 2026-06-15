CREATE TABLE "public"."dws_sl_card_finance_daily_p" (
  "id" int8 NOT NULL,
  "report_date" date NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "rebate_base" numeric(20,4) DEFAULT 0,
  "rebate_amt" numeric(20,4) DEFAULT 0,
  "cost_fixed_fee" numeric(20,4) DEFAULT 0,
  CONSTRAINT "dws_sl_daily_pkey" PRIMARY KEY ("id", "report_date")
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
);

ALTER TABLE "public"."dws_sl_card_finance_daily_p" OWNER TO "qbit_admin";

COMMENT ON TABLE "public"."dws_sl_card_finance_daily_p" IS 'SL渠道财务汇总日表-按年分区';
COMMENT ON COLUMN "public"."dws_sl_card_finance_daily_p"."id" IS '主键: 业务指纹';
COMMENT ON COLUMN "public"."dws_sl_card_finance_daily_p"."report_date" IS '统计日期-分区键';
COMMENT ON COLUMN "public"."dws_sl_card_finance_daily_p"."account_id" IS '账户ID';
COMMENT ON COLUMN "public"."dws_sl_card_finance_daily_p"."version" IS '乐观锁版本';
COMMENT ON COLUMN "public"."dws_sl_card_finance_daily_p"."remarks" IS '备注';
COMMENT ON COLUMN "public"."dws_sl_card_finance_daily_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "public"."dws_sl_card_finance_daily_p"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "public"."dws_sl_card_finance_daily_p"."delete_time" IS '逻辑删除时间';
COMMENT ON COLUMN "public"."dws_sl_card_finance_daily_p"."sale_id" IS '销售ID';
COMMENT ON COLUMN "public"."dws_sl_card_finance_daily_p"."am_id" IS 'AM ID';
COMMENT ON COLUMN "public"."dws_sl_card_finance_daily_p"."rebate_base" IS '可分摊净消费基数';
COMMENT ON COLUMN "public"."dws_sl_card_finance_daily_p"."rebate_amt" IS '净消费金额';
COMMENT ON COLUMN "public"."dws_sl_card_finance_daily_p"."cost_fixed_fee" IS 'SL固定渠道成本分摊金额';

CREATE TABLE "public"."dws_sl_card_finance_daily_p_2026" PARTITION OF "public"."dws_sl_card_finance_daily_p"
FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
