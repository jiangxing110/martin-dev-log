--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-22
-- 功能：ADBPG ODS目标表 ods_payment_transaction_record DDL | 按dt日期分区
-- 说明：先执行建表，再跑 Flink 同步作业
-- 源表：public.payment_transaction_record
--********************************************************************--

CREATE TABLE "ods"."ods_payment_transaction_record" (
    "id" VARCHAR(64) NOT NULL,
    "dt" DATE NOT NULL,
    "create_time" TIMESTAMP,
    "update_time" TIMESTAMP,
    "delete_time" TIMESTAMP,
    "version" INTEGER NOT NULL DEFAULT 1,
    "remarks" TEXT,
    "source_transaction_id" VARCHAR(255),
    "inquiry_id" BIGINT,
    "business_type" VARCHAR(255),
    "account_id" VARCHAR(64),
    "status" VARCHAR(255),
    "channel" VARCHAR(255),
    "third_party_payment_id" VARCHAR(255),
    "from_amount" NUMERIC(20, 8),
    "from_currency" VARCHAR(255),
    "to_amount" NUMERIC(20, 8),
    "to_currency" VARCHAR(255),
    "settle_amount" NUMERIC(20, 8),
    "rate" NUMERIC(20, 8),
    "payee_id" BIGINT,
    "parent_id" BIGINT DEFAULT 0,
    "same_name_payment" BOOLEAN NOT NULL DEFAULT FALSE,
    "balance_id" VARCHAR(255),
    "settle_currency" VARCHAR(255),
    "fee" NUMERIC(20, 8) DEFAULT 0,
    "balance_channel" VARCHAR(255),
    "payout_direction_type" VARCHAR(255),
    "third_party_reason" VARCHAR(255),
    "refund_amount" NUMERIC(20, 8) DEFAULT 0,
    "refund_rate" NUMERIC(20, 8),
    "transaction_display_id" VARCHAR(255),
    "webhook_status" VARCHAR(255),
    "payout_mode" VARCHAR(255),
    "extra" TEXT,
    "submit_time" TIMESTAMP,
    CONSTRAINT "ods_payment_transaction_record_pkey" PRIMARY KEY ("id", "dt")
)
PARTITION BY RANGE ("dt");

ALTER TABLE "ods"."ods_payment_transaction_record"
    OWNER TO "qbit_admin";

COMMENT ON TABLE "ods"."ods_payment_transaction_record" IS 'ODS层：payment_transaction_record 同步表';

-- ==============================================
-- 按年分区 (dt)
-- ==============================================
CREATE TABLE "ods"."ods_payment_transaction_record_2024" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE "ods"."ods_payment_transaction_record_2025" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE "ods"."ods_payment_transaction_record_2026" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
