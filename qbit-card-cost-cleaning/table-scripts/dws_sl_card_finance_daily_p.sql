CREATE TABLE "public"."dws_sl_card_finance_daily_p" (
  "id" int8 NOT NULL,
  "report_date" date NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "rebate_base" numeric(20,4) DEFAULT 0,
  "rebate_amt" numeric(20,4) DEFAULT 0,
  "cost_fixed_fee" numeric(20,4) DEFAULT 0,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_sl_card_finance_daily_pkey" PRIMARY KEY ("id", "report_date")
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
);

ALTER TABLE "public"."dws_sl_card_finance_daily_p"
  OWNER TO "qbit_admin";

COMMENT ON TABLE "public"."dws_sl_card_finance_daily_p" IS 'SL渠道财务日汇总表';
COMMENT ON COLUMN "public"."dws_sl_card_finance_daily_p"."cost_fixed_fee" IS '固定渠道成本';

CREATE INDEX "idx_dws_sl_card_acc_sale_am" ON "public"."dws_sl_card_finance_daily_p" USING btree (
  "report_date" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" ASC NULLS LAST
);

ALTER TABLE "public"."dws_sl_card_finance_daily_p" ATTACH PARTITION "public"."dws_sl_card_finance_daily_2026" FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
