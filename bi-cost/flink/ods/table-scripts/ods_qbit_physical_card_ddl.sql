--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-22
-- 功能：ADBPG ODS目标表 ods_qbit_physical_card DDL | 按dt日期分区
-- 说明：先执行建表，再跑 Flink 同步作业
-- 源表：public.qbitPhysicalCard
--********************************************************************--

CREATE TABLE "ods"."ods_qbit_physical_card" (
    "id" VARCHAR(64) NOT NULL,
    "dt" DATE NOT NULL,
    "create_time" TIMESTAMP,
    "update_time" TIMESTAMP,
    "delete_time" TIMESTAMP,
    "version" INTEGER NOT NULL DEFAULT 1,
    "remarks" TEXT,
    "account_id" VARCHAR(64),
    "card_id" VARCHAR(64),
    "shipping_address" TEXT,
    "pin" VARCHAR(255),
    "phone" VARCHAR(255),
    "phone_prefix" VARCHAR(255),
    "first_name" VARCHAR(255),
    "last_name" VARCHAR(255),
    "user_id" VARCHAR(64),
    "is_has_pin" BOOLEAN NOT NULL DEFAULT FALSE,
    "real_name" VARCHAR(255),
    "dob" VARCHAR(255),
    "expiration_date" VARCHAR(255),
    "real_address" TEXT,
    "real_first_name" VARCHAR(255),
    "real_last_name" VARCHAR(255),
    "id_number" VARCHAR(255),
    "is_show" BOOLEAN NOT NULL DEFAULT FALSE,
    "id_type" VARCHAR(255) NOT NULL DEFAULT 'CN-RIC',
    "email" VARCHAR(255),
    "address_id" VARCHAR(64),
    "display_status" VARCHAR(255) NOT NULL DEFAULT 'Na',
    "batch_no" VARCHAR(255),
    "card_style" VARCHAR(255) NOT NULL DEFAULT 'Plastic',
    "shipping_batch_no" VARCHAR(255),
    "design_id" VARCHAR(255),
    "card_package" VARCHAR(255),
    "tax_id" VARCHAR(255),
    "submit_time" TIMESTAMP,
    CONSTRAINT "ods_qbit_physical_card_pkey" PRIMARY KEY ("id", "dt")
)
PARTITION BY RANGE ("dt");

ALTER TABLE "ods"."ods_qbit_physical_card"
    OWNER TO "qbit_admin";

COMMENT ON TABLE "ods"."ods_qbit_physical_card" IS 'ODS层：qbitPhysicalCard 同步表';

-- ==============================================
-- 按年分区 (dt)
-- ==============================================
CREATE TABLE "ods"."ods_qbit_physical_card_2023" PARTITION OF "ods"."ods_qbit_physical_card"
  FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE "ods"."ods_qbit_physical_card_2024" PARTITION OF "ods"."ods_qbit_physical_card"
  FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE "ods"."ods_qbit_physical_card_2025" PARTITION OF "ods"."ods_qbit_physical_card"
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE "ods"."ods_qbit_physical_card_2026" PARTITION OF "ods"."ods_qbit_physical_card"
  FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
