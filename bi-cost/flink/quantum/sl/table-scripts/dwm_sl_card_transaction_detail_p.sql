-- 作业元信息：
--   作业类型：DDL建表/视图脚本
--   运行方式：非运行作业
--   运行参数：无
--   源库变更响应：不涉及源库变更同步；用于创建 ADBPG 目标表、分区、索引或视图。
CREATE TABLE "dwm"."dwm_sl_card_transaction_detail_p" (
  "id" uuid NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "account_type" varchar(30) COLLATE "pg_catalog"."default",
  "account_category" varchar(50) COLLATE "pg_catalog"."default",
  "system_type" varchar(64) COLLATE "pg_catalog"."default",
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  "settlement_date" date NOT NULL,
  "settlement_transaction_id" varchar(100) COLLATE "pg_catalog"."default",
  "qbit_card_transaction_id" uuid,
  "qbit_transaction_id" varchar(100) COLLATE "pg_catalog"."default",
  "provider" varchar(50) COLLATE "pg_catalog"."default",
  "billing_amount" numeric(20,4) DEFAULT 0,
  "billing_currency_code" varchar(20) COLLATE "pg_catalog"."default",
  "transaction_amount" numeric(20,4) DEFAULT 0,
  "transaction_currency_code" varchar(20) COLLATE "pg_catalog"."default",
  "country" varchar(20) COLLATE "pg_catalog"."default",
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "raw_data" text COLLATE "pg_catalog"."default",
  "etl_time" timestamp(6) NOT NULL DEFAULT now(),
  CONSTRAINT "dwm_sl_card_transaction_detail_pkey" PRIMARY KEY ("id", "settlement_date")
)
PARTITION BY RANGE (
  "settlement_date" "pg_catalog"."date_ops"
);

ALTER TABLE "dwm"."dwm_sl_card_transaction_detail_p" OWNER TO "qbit_admin";

COMMENT ON TABLE "dwm"."dwm_sl_card_transaction_detail_p" IS 'SL渠道DWM结算明细表-基于qbitCardSettlement挂销售归属';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."id" IS '主键ID，沿用qbitCardSettlement.id';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."account_id" IS '账户ID';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."account_type" IS '账户类型，来源 dim_account.account_type';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."account_category" IS '账户分类，来源 dim_account.type';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."system_type" IS '系统类型，来源 dim_account.system_type';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."version" IS '乐观锁版本';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."remarks" IS '备注';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."delete_time" IS '逻辑删除时间';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."settlement_date" IS '结算日期，来自 settlement_day';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."settlement_transaction_id" IS 'qbitCardSettlement.transactionId';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."qbit_card_transaction_id" IS 'qbitCardSettlement.qbitCardTransactionId';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."qbit_transaction_id" IS 'qbit_card_transaction.transactionId';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."provider" IS '结算通道provider';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."billing_amount" IS '计费金额';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."billing_currency_code" IS '计费币种';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."transaction_amount" IS '交易金额';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."transaction_currency_code" IS '交易币种';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."country" IS '商户国家';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."sale_id" IS '销售ID';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."am_id" IS 'AM ID';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."raw_data" IS 'qbitCardSettlement.rawData';
COMMENT ON COLUMN "dwm"."dwm_sl_card_transaction_detail_p"."etl_time" IS 'ETL时间';

CREATE INDEX IF NOT EXISTS "idx_dwm_sl_settlement_date_acc" ON "dwm"."dwm_sl_card_transaction_detail_p" USING btree (
  "settlement_date" "pg_catalog"."date_ops" ASC NULLS LAST,
  "account_id" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE INDEX IF NOT EXISTS "idx_dwm_sl_account_dim" ON "dwm"."dwm_sl_card_transaction_detail_p" USING btree (
  "settlement_date" "pg_catalog"."date_ops" ASC NULLS LAST,
  "account_type" "pg_catalog"."text_ops" ASC NULLS LAST,
  "account_category" "pg_catalog"."text_ops" ASC NULLS LAST,
  "system_type" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE INDEX IF NOT EXISTS "idx_dwm_sl_qbit_card_tx_id" ON "dwm"."dwm_sl_card_transaction_detail_p" USING btree (
  "qbit_card_transaction_id" "pg_catalog"."uuid_ops" ASC NULLS LAST
);

CREATE INDEX IF NOT EXISTS "idx_dwm_sl_sale_am" ON "dwm"."dwm_sl_card_transaction_detail_p" USING btree (
  "sale_id" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE TABLE "dwm"."dwm_sl_card_transaction_detail_p_2026_01" PARTITION OF "dwm"."dwm_sl_card_transaction_detail_p"
FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE "dwm"."dwm_sl_card_transaction_detail_p_2026_02" PARTITION OF "dwm"."dwm_sl_card_transaction_detail_p"
FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE "dwm"."dwm_sl_card_transaction_detail_p_2026_03" PARTITION OF "dwm"."dwm_sl_card_transaction_detail_p"
FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE "dwm"."dwm_sl_card_transaction_detail_p_2026_04" PARTITION OF "dwm"."dwm_sl_card_transaction_detail_p"
FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE "dwm"."dwm_sl_card_transaction_detail_p_2026_05" PARTITION OF "dwm"."dwm_sl_card_transaction_detail_p"
FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE "dwm"."dwm_sl_card_transaction_detail_p_2026_06" PARTITION OF "dwm"."dwm_sl_card_transaction_detail_p"
FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE "dwm"."dwm_sl_card_transaction_detail_p_2026_07" PARTITION OF "dwm"."dwm_sl_card_transaction_detail_p"
FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE "dwm"."dwm_sl_card_transaction_detail_p_2026_08" PARTITION OF "dwm"."dwm_sl_card_transaction_detail_p"
FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE "dwm"."dwm_sl_card_transaction_detail_p_2026_09" PARTITION OF "dwm"."dwm_sl_card_transaction_detail_p"
FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE "dwm"."dwm_sl_card_transaction_detail_p_2026_10" PARTITION OF "dwm"."dwm_sl_card_transaction_detail_p"
FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE "dwm"."dwm_sl_card_transaction_detail_p_2026_11" PARTITION OF "dwm"."dwm_sl_card_transaction_detail_p"
FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE "dwm"."dwm_sl_card_transaction_detail_p_2026_12" PARTITION OF "dwm"."dwm_sl_card_transaction_detail_p"
FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
