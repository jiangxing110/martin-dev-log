CREATE TABLE "public"."dwm_finance_quantum_channel_cost_p" (
  "id" int8 NOT NULL,
  "report_date" date NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "provider" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "cost_type" varchar(80) COLLATE "pg_catalog"."default" NOT NULL,
  "cost_amount" numeric(20,4) DEFAULT 0,
  "source_month" date,
  "allocation_basis" varchar(80) COLLATE "pg_catalog"."default",
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dwm_finance_quantum_channel_cost_pkey" PRIMARY KEY ("id", "report_date")
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
);

ALTER TABLE "public"."dwm_finance_quantum_channel_cost_p"
  OWNER TO "qbit_admin";

COMMENT ON TABLE "public"."dwm_finance_quantum_channel_cost_p" IS '量子卡金融补充成本归因表，不包含BB/QI/SL卡渠道DWS成本';
COMMENT ON COLUMN "public"."dwm_finance_quantum_channel_cost_p"."id" IS '主键: 日期+账户+provider+cost_type+销售+AM业务指纹';
COMMENT ON COLUMN "public"."dwm_finance_quantum_channel_cost_p"."report_date" IS '成本归属日期-分区键';
COMMENT ON COLUMN "public"."dwm_finance_quantum_channel_cost_p"."account_id" IS '账户ID';
COMMENT ON COLUMN "public"."dwm_finance_quantum_channel_cost_p"."provider" IS '金融渠道方，如THUNES/BPC/SUMSB/IDEMIA/HZ';
COMMENT ON COLUMN "public"."dwm_finance_quantum_channel_cost_p"."cost_type" IS '成本类型，如BANK_FEE/FIXED_FEE/KYC_FEE/CARD_PRODUCTION_FEE';
COMMENT ON COLUMN "public"."dwm_finance_quantum_channel_cost_p"."cost_amount" IS '已归因到客户和日期的成本金额';
COMMENT ON COLUMN "public"."dwm_finance_quantum_channel_cost_p"."source_month" IS '来源账单月份';
COMMENT ON COLUMN "public"."dwm_finance_quantum_channel_cost_p"."allocation_basis" IS '分摊依据，如active_card/net_consume/kyc_count/physical_card';
COMMENT ON COLUMN "public"."dwm_finance_quantum_channel_cost_p"."sale_id" IS '销售ID';
COMMENT ON COLUMN "public"."dwm_finance_quantum_channel_cost_p"."am_id" IS 'AM ID';
COMMENT ON COLUMN "public"."dwm_finance_quantum_channel_cost_p"."version" IS '乐观锁版本';
COMMENT ON COLUMN "public"."dwm_finance_quantum_channel_cost_p"."remarks" IS '备注';
COMMENT ON COLUMN "public"."dwm_finance_quantum_channel_cost_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "public"."dwm_finance_quantum_channel_cost_p"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "public"."dwm_finance_quantum_channel_cost_p"."delete_time" IS '逻辑删除时间';

CREATE INDEX "idx_dwm_finance_quantum_cost_acc_sale_am" ON "public"."dwm_finance_quantum_channel_cost_p" USING btree (
  "report_date" "pg_catalog"."date_ops" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dwm_finance_quantum_cost_provider_type" ON "public"."dwm_finance_quantum_channel_cost_p" USING btree (
  "provider" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "cost_type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

ALTER TABLE "public"."dwm_finance_quantum_channel_cost_p" ATTACH PARTITION "public"."dwm_finance_quantum_channel_cost_2026" FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
