CREATE TABLE "public"."dwm_finance_channel_cost_p" (
  "id" int8 NOT NULL,
  "report_date" date NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "product_line" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "provider" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "cost_type" varchar(80) COLLATE "pg_catalog"."default" NOT NULL,
  "source_month" date NOT NULL,
  "source_tag" varchar(80) COLLATE "pg_catalog"."default" NOT NULL,
  "source_amount" numeric(20,4) DEFAULT 0,
  "month_day_count" int4 DEFAULT 0,
  "basis_count" numeric(20,4) DEFAULT 0,
  "month_basis_count" numeric(20,4) DEFAULT 0,
  "basis_amount" numeric(20,4) DEFAULT 0,
  "month_basis_amount" numeric(20,4) DEFAULT 0,
  "allocation_rate" numeric(20,10) DEFAULT 0,
  "cost_amount" numeric(20,4) DEFAULT 0,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dwm_finance_channel_cost_pkey" PRIMARY KEY ("id", "report_date")
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
);

ALTER TABLE "public"."dwm_finance_channel_cost_p"
  OWNER TO "qbit_admin";

COMMENT ON TABLE "public"."dwm_finance_channel_cost_p" IS '全产品线金融渠道成本归因明细表';

CREATE INDEX "idx_dwm_finance_channel_cost_acc_sale_am" ON "public"."dwm_finance_channel_cost_p" USING btree (
  "report_date" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" ASC NULLS LAST
);

ALTER TABLE "public"."dwm_finance_channel_cost_p" ATTACH PARTITION "public"."dwm_finance_channel_cost_2026" FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
