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
    "extra" JSON DEFAULT '{}'::json,
    "submit_time" TIMESTAMP,
    CONSTRAINT "ods_payment_transaction_record_pkey" PRIMARY KEY ("id", "dt")
)
PARTITION BY RANGE ("dt");

ALTER TABLE "ods"."ods_payment_transaction_record"
    OWNER TO "qbit_admin";

COMMENT ON TABLE "ods"."ods_payment_transaction_record" IS 'ODS层：payment_transaction_record 同步表';

-- ==============================================
-- 按月分区 2024-01 ~ 2026-12 (dt)
-- ==============================================
CREATE TABLE "ods"."ods_payment_transaction_record_202401" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202402" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202403" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202404" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2024-04-01') TO ('2024-05-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202405" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2024-05-01') TO ('2024-06-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202406" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2024-06-01') TO ('2024-07-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202407" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2024-07-01') TO ('2024-08-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202408" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2024-08-01') TO ('2024-09-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202409" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2024-09-01') TO ('2024-10-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202410" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2024-10-01') TO ('2024-11-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202411" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2024-11-01') TO ('2024-12-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202412" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202501" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202502" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202503" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202504" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202505" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202506" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202507" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202508" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202509" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202510" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202511" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202512" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202601" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202602" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202603" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202604" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202605" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202606" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202607" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202608" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202609" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202610" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202611" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE "ods"."ods_payment_transaction_record_202612" PARTITION OF "ods"."ods_payment_transaction_record"
  FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
