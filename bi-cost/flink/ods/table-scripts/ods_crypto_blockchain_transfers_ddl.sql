--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-22
-- 功能：ADBPG ODS目标表 ods_crypto_blockchain_transfers DDL | 按dt日期分区
-- 作业元信息：
--   作业类型：DDL建表/视图脚本
--   运行方式：非运行作业
--   运行参数：无
--   源库变更响应：不涉及源库变更同步；用于创建 ADBPG 目标表、分区、索引或视图。
-- 说明：先执行建表，再跑 Flink 同步作业
-- 源表视图：public.view_crypto_assets_blockchain_transfers
-- 注意：视图无法 CDC，使用 JDBC 批读
--********************************************************************--

CREATE TABLE "ods"."ods_crypto_blockchain_transfers" (
    "id" VARCHAR(64) NOT NULL,
    "dt" DATE NOT NULL,
    "transaction_display_id" VARCHAR(255),
    "account_id" VARCHAR(64),
    "wallet_id" VARCHAR(64),
    "balance_id" VARCHAR(64),
    "action" VARCHAR(255),
    "currency" VARCHAR(30),
    "chain" VARCHAR(20),
    "source_address" VARCHAR(255),
    "destination_address" VARCHAR(255),
    "amount" VARCHAR(255),
    "gas_fee" VARCHAR(255),
    "cross_chain_fee" VARCHAR(255),
    "status" VARCHAR(255),
    "transaction_hash" VARCHAR(255),
    "risk_level" VARCHAR(255),
    "create_time" TIMESTAMP,
    "third_party_create_time" TIMESTAMP,
    "completion_time" TIMESTAMP,
    "third_party_id" VARCHAR(255),
    "platform" VARCHAR(64),
    "usd_rate" NUMERIC(20, 8),
    "fees" TEXT,
    "submit_time" TIMESTAMP,
    CONSTRAINT "ods_crypto_blockchain_transfers_pkey" PRIMARY KEY ("id", "dt")
)
PARTITION BY RANGE ("dt");

COMMENT ON TABLE "ods"."ods_crypto_blockchain_transfers" IS 'ODS层：view_crypto_assets_blockchain_transfers 同步表';

-- ==============================================
-- 按年分区 (dt)
-- ==============================================
CREATE TABLE "ods"."ods_crypto_blockchain_transfers_2021" PARTITION OF "ods"."ods_crypto_blockchain_transfers"
  FOR VALUES FROM ('2021-01-01') TO ('2022-01-01');
CREATE TABLE "ods"."ods_crypto_blockchain_transfers_2022" PARTITION OF "ods"."ods_crypto_blockchain_transfers"
  FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');
CREATE TABLE "ods"."ods_crypto_blockchain_transfers_2023" PARTITION OF "ods"."ods_crypto_blockchain_transfers"
  FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE "ods"."ods_crypto_blockchain_transfers_2024" PARTITION OF "ods"."ods_crypto_blockchain_transfers"
  FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE "ods"."ods_crypto_blockchain_transfers_2025" PARTITION OF "ods"."ods_crypto_blockchain_transfers"
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE "ods"."ods_crypto_blockchain_transfers_2026" PARTITION OF "ods"."ods_crypto_blockchain_transfers"
  FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
