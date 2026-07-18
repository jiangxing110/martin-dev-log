CREATE TABLE "public"."dwm_sl_card_transaction_detail_p" (
  "id" uuid NOT NULL,
  "transaction_id" varchar(100) COLLATE "pg_catalog"."default",
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "transaction_date" date NOT NULL,
  "country" varchar(10) COLLATE "pg_catalog"."default",
  "billing_amount" numeric(20,4) DEFAULT 0,
  "rebate_rate" numeric(10,6) DEFAULT 0,
  "rebate_base" numeric(20,4) DEFAULT 0,
  "rebate_amt" numeric(20,4) DEFAULT 0,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dwm_sl_card_transaction_detail_pkey" PRIMARY KEY ("id", "transaction_date")
)
PARTITION BY RANGE (
  "transaction_date" "pg_catalog"."date_ops"
);

ALTER TABLE "public"."dwm_sl_card_transaction_detail_p"
  OWNER TO "qbit_admin";

COMMENT ON TABLE "public"."dwm_sl_card_transaction_detail_p" IS 'SL渠道交易明细归因表';
COMMENT ON COLUMN "public"."dwm_sl_card_transaction_detail_p"."id" IS '沿用qbitCardSettlement.id';
COMMENT ON COLUMN "public"."dwm_sl_card_transaction_detail_p"."transaction_id" IS '原始交易ID';
COMMENT ON COLUMN "public"."dwm_sl_card_transaction_detail_p"."transaction_date" IS '交易日期-分区键';
COMMENT ON COLUMN "public"."dwm_sl_card_transaction_detail_p"."rebate_base" IS '返现基数';
COMMENT ON COLUMN "public"."dwm_sl_card_transaction_detail_p"."rebate_amt" IS '返现金额';

CREATE INDEX "idx_dwm_sl_card_acc_sale_am" ON "public"."dwm_sl_card_transaction_detail_p" USING btree (
  "transaction_date" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" ASC NULLS LAST
);

ALTER TABLE "public"."dwm_sl_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_sl_card_transaction_2026" FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
