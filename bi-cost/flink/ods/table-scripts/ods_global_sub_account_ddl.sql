--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-22
-- 功能：ADBPG ODS目标表 ods_global_sub_account DDL | 按dt日期分区
-- 说明：先执行建表，再跑 Flink 同步作业
-- 源表：public.globalSubAccount
--********************************************************************--

CREATE TABLE "ods"."ods_global_sub_account" (
    "id" VARCHAR(64) NOT NULL,
    "dt" DATE NOT NULL,
    "create_time" TIMESTAMP,
    "update_time" TIMESTAMP,
    "delete_time" TIMESTAMP,
    "version" INTEGER NOT NULL DEFAULT 1,
    "remarks" TEXT,
    "account_id" VARCHAR(64),
    "holder_id" VARCHAR(64),
    "nickname" VARCHAR(255),
    "purpose" VARCHAR(255),
    "currency" VARCHAR(255),
    "is_enabled" BOOLEAN NOT NULL DEFAULT FALSE,
    "cc_balance_relation_id" VARCHAR(64),
    "sub_account_id" VARCHAR(255),
    "balance_id" VARCHAR(64),
    "status" VARCHAR(255) NOT NULL DEFAULT 'Active',
    "open_time" TIMESTAMP,
    "is_free" BOOLEAN,
    "provider" VARCHAR(255) NOT NULL DEFAULT 'CurrencyCloud',
    "extra_data" TEXT,
    "origin_account_id" VARCHAR(64),
    "is_master_account" BOOLEAN,
    "vrn_enable" BOOLEAN DEFAULT FALSE,
    "submit_time" TIMESTAMP,
    CONSTRAINT "ods_global_sub_account_pkey" PRIMARY KEY ("id", "dt")
)
PARTITION BY RANGE ("dt");

ALTER TABLE "ods"."ods_global_sub_account"
    OWNER TO "qbit_admin";

COMMENT ON TABLE "ods"."ods_global_sub_account" IS 'ODS层：globalSubAccount 同步表';

-- ==============================================
-- 按年分区 (dt)
-- ==============================================
CREATE TABLE "ods"."ods_global_sub_account_2023" PARTITION OF "ods"."ods_global_sub_account"
  FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE "ods"."ods_global_sub_account_2024" PARTITION OF "ods"."ods_global_sub_account"
  FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE "ods"."ods_global_sub_account_2025" PARTITION OF "ods"."ods_global_sub_account"
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE "ods"."ods_global_sub_account_2026" PARTITION OF "ods"."ods_global_sub_account"
  FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
