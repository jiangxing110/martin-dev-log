--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-23
-- 功能：ADBPG ODS目标表 ods_crypto_assets_transactions DDL | 按dt日期分区
-- 说明：先执行建表，再跑 Flink 同步作业
-- 源表：public.crypto_assets_transactions
--********************************************************************--

CREATE TABLE "ods"."ods_crypto_assets_transactions" (
    "id" VARCHAR(64) NOT NULL,
    "dt" DATE NOT NULL,
    "trade_id" VARCHAR(64),
    "source_type" VARCHAR(64),
    "source_id" VARCHAR(64),
    "destination_type" VARCHAR(64),
    "destination_id" VARCHAR(64),
    "destination_address" VARCHAR(255),
    "amount" NUMERIC,
    "fee" NUMERIC DEFAULT 0,
    "total_amount" NUMERIC,
    "transaction_hash" VARCHAR(100),
    "status" VARCHAR(20),
    "create_time" TIMESTAMP,
    "update_time" TIMESTAMP,
    "delete_time" TIMESTAMP,
    "version" INTEGER NOT NULL DEFAULT 1,
    "chain" VARCHAR(20),
    "currency" VARCHAR(30) NOT NULL,
    "source_address" VARCHAR(1000),
    "platform" VARCHAR(255) NOT NULL DEFAULT 'CIRCLE',
    "aggregation" BOOLEAN DEFAULT FALSE,
    "remarks" VARCHAR(255),
    "aml_lock" BOOLEAN DEFAULT FALSE,
    "risk_level" VARCHAR(30),
    "submit_time" TIMESTAMP,
    CONSTRAINT "ods_crypto_assets_transactions_pkey" PRIMARY KEY ("id", "dt")
)
PARTITION BY RANGE ("dt");

ALTER TABLE "ods"."ods_crypto_assets_transactions"
    OWNER TO "qbit_admin";

COMMENT ON TABLE "ods"."ods_crypto_assets_transactions" IS 'ODS层：crypto_assets_transactions 同步表';

-- ==============================================
-- 按年分区 (dt)
-- ==============================================
CREATE TABLE "ods"."ods_crypto_assets_transactions_1970" PARTITION OF "ods"."ods_crypto_assets_transactions"
  FOR VALUES FROM ('1970-01-01') TO ('1971-01-01');
CREATE TABLE "ods"."ods_crypto_assets_transactions_2021" PARTITION OF "ods"."ods_crypto_assets_transactions"
  FOR VALUES FROM ('2021-01-01') TO ('2022-01-01');
CREATE TABLE "ods"."ods_crypto_assets_transactions_2022" PARTITION OF "ods"."ods_crypto_assets_transactions"
  FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');
CREATE TABLE "ods"."ods_crypto_assets_transactions_2023" PARTITION OF "ods"."ods_crypto_assets_transactions"
  FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE "ods"."ods_crypto_assets_transactions_2024" PARTITION OF "ods"."ods_crypto_assets_transactions"
  FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE "ods"."ods_crypto_assets_transactions_2025" PARTITION OF "ods"."ods_crypto_assets_transactions"
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE "ods"."ods_crypto_assets_transactions_2026" PARTITION OF "ods"."ods_crypto_assets_transactions"
  FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
