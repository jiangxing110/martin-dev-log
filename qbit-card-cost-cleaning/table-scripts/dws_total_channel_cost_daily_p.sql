CREATE TABLE "public"."dws_total_channel_cost_daily_p" (
  "id" int8 NOT NULL,
  "report_date" date NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "acquiring_cost" numeric(20,4) DEFAULT 0,
  "business_cost" numeric(20,4) DEFAULT 0,
  "quantum_cost" numeric(20,4) DEFAULT 0,
  "crypto_cost" numeric(20,4) DEFAULT 0,
  "total_channel_cost" numeric(20,4) DEFAULT 0,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_total_channel_cost_daily_pkey" PRIMARY KEY ("id", "report_date")
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
);

ALTER TABLE "public"."dws_total_channel_cost_daily_p"
  OWNER TO "qbit_admin";

COMMENT ON TABLE "public"."dws_total_channel_cost_daily_p" IS '客户总渠道成本日汇总表';

CREATE INDEX "idx_dws_total_channel_cost_acc_sale_am" ON "public"."dws_total_channel_cost_daily_p" USING btree (
  "report_date" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" ASC NULLS LAST
);

ALTER TABLE "public"."dws_total_channel_cost_daily_p" ATTACH PARTITION "public"."dws_total_channel_cost_daily_2026" FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
