--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-22
-- 功能：ADBPG ODS目标表 ods_crypto_assets_addresses DDL | 按dt日期分区
-- 说明：先执行建表，再跑 Flink 同步作业
-- 源表：public.crypto_assets_addresses
--********************************************************************--

CREATE TABLE "ods"."ods_crypto_assets_addresses" (
    "id" VARCHAR(64) NOT NULL,
    "dt" DATE NOT NULL,
    "create_time" TIMESTAMP,
    "update_time" TIMESTAMP,
    "delete_time" TIMESTAMP,
    "version" INTEGER NOT NULL DEFAULT 1,
    "account_id" VARCHAR(64),
    "wallet_id" VARCHAR(64),
    "chain" VARCHAR(20),
    "currency" VARCHAR(30),
    "address" VARCHAR(100),
    "address_tag" VARCHAR(255),
    "remarks" TEXT,
    "enable" BOOLEAN NOT NULL DEFAULT TRUE,
    "selected" BOOLEAN NOT NULL DEFAULT TRUE,
    "platform" VARCHAR(64),
    "account_key" VARCHAR(255),
    "submit_time" TIMESTAMP,
    CONSTRAINT "ods_crypto_assets_addresses_pkey" PRIMARY KEY ("id", "dt")
)
PARTITION BY RANGE ("dt");

ALTER TABLE "ods"."ods_crypto_assets_addresses"
    OWNER TO "qbit_admin";

COMMENT ON TABLE "ods"."ods_crypto_assets_addresses" IS 'ODS层：crypto_assets_addresses 同步表';

-- ==============================================
-- 按年分区 (dt)
-- ==============================================
CREATE TABLE "ods"."ods_crypto_assets_addresses_2023" PARTITION OF "ods"."ods_crypto_assets_addresses"
  FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE "ods"."ods_crypto_assets_addresses_2024" PARTITION OF "ods"."ods_crypto_assets_addresses"
  FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE "ods"."ods_crypto_assets_addresses_2025" PARTITION OF "ods"."ods_crypto_assets_addresses"
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE "ods"."ods_crypto_assets_addresses_2026" PARTITION OF "ods"."ods_crypto_assets_addresses"
  FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
