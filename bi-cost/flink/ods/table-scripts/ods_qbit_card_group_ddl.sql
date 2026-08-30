--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-30
-- 功能：ADBPG ODS目标表 ods_qbit_card_group DDL | 按dt日期分区
-- 源表：public.qbitCardGroup
-- 说明：先执行建表，再运行 ods_online_qbit_card_group-cdc-sql.sql
--********************************************************************--

CREATE TABLE "ods"."ods_qbit_card_group" (
    "id" VARCHAR(64) NOT NULL,
    "dt" DATE NOT NULL,
    "create_time" TIMESTAMP,
    "update_time" TIMESTAMP,
    "delete_time" TIMESTAMP,
    "version" INTEGER NOT NULL DEFAULT 1,
    "group_name" VARCHAR(255),
    "status" VARCHAR(30),
    "submit_time" TIMESTAMP,
    CONSTRAINT "ods_qbit_card_group_pkey" PRIMARY KEY ("id", "dt")
)
PARTITION BY RANGE ("dt");

COMMENT ON TABLE "ods"."ods_qbit_card_group" IS 'ODS层：qbitCardGroup 实时同步表';

CREATE TABLE "ods"."ods_qbit_card_group_2020" PARTITION OF "ods"."ods_qbit_card_group"
  FOR VALUES FROM ('2020-01-01') TO ('2021-01-01');
CREATE TABLE "ods"."ods_qbit_card_group_2021" PARTITION OF "ods"."ods_qbit_card_group"
  FOR VALUES FROM ('2021-01-01') TO ('2022-01-01');
CREATE TABLE "ods"."ods_qbit_card_group_2022" PARTITION OF "ods"."ods_qbit_card_group"
  FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');
CREATE TABLE "ods"."ods_qbit_card_group_2023" PARTITION OF "ods"."ods_qbit_card_group"
  FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE "ods"."ods_qbit_card_group_2024" PARTITION OF "ods"."ods_qbit_card_group"
  FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE "ods"."ods_qbit_card_group_2025" PARTITION OF "ods"."ods_qbit_card_group"
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE "ods"."ods_qbit_card_group_2026" PARTITION OF "ods"."ods_qbit_card_group"
  FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE "ods"."ods_qbit_card_group_2027" PARTITION OF "ods"."ods_qbit_card_group"
  FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE "ods"."ods_qbit_card_group_2028" PARTITION OF "ods"."ods_qbit_card_group"
  FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');
CREATE TABLE "ods"."ods_qbit_card_group_2029" PARTITION OF "ods"."ods_qbit_card_group"
  FOR VALUES FROM ('2029-01-01') TO ('2030-01-01');

