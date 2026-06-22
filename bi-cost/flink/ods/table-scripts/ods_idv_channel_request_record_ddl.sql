--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-22
-- 功能：ADBPG ODS目标表 ods_idv_channel_request_record DDL | 按dt日期分区
-- 说明：先执行建表，再跑 Flink 同步作业
-- 源表：public.idv_channel_request_record
--********************************************************************--

CREATE TABLE "ods"."ods_idv_channel_request_record" (
    "id" BIGINT NOT NULL,
    "dt" DATE NOT NULL,
    "create_time" TIMESTAMP,
    "update_time" TIMESTAMP,
    "delete_time" TIMESTAMP,
    "version" INTEGER NOT NULL DEFAULT 1,
    "remarks" TEXT,
    "request_channel" VARCHAR(255),
    "request_type" VARCHAR(255),
    "request_url" VARCHAR(255),
    "request_status" VARCHAR(255),
    "request_time" TIMESTAMP,
    "account_request_id" VARCHAR(255),
    "type" VARCHAR(255),
    "source_id" VARCHAR(255),
    "x_trace_id" VARCHAR(255),
    "account_id" VARCHAR(255),
    "sub_account_id" VARCHAR(255),
    "ext_data1" VARCHAR(255),
    "ext_data2" VARCHAR(255),
    "ext_data3" VARCHAR(255),
    "submit_time" TIMESTAMP,
    CONSTRAINT "ods_idv_channel_request_record_pkey" PRIMARY KEY ("id", "dt")
)
PARTITION BY RANGE ("dt");

ALTER TABLE "ods"."ods_idv_channel_request_record"
    OWNER TO "qbit_admin";

COMMENT ON TABLE "ods"."ods_idv_channel_request_record" IS 'ODS层：idv_channel_request_record 同步表';

-- ==============================================
-- 按年分区 (dt)
-- ==============================================
CREATE TABLE "ods"."ods_idv_channel_request_record_2023" PARTITION OF "ods"."ods_idv_channel_request_record"
  FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE "ods"."ods_idv_channel_request_record_2024" PARTITION OF "ods"."ods_idv_channel_request_record"
  FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE "ods"."ods_idv_channel_request_record_2025" PARTITION OF "ods"."ods_idv_channel_request_record"
  FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE "ods"."ods_idv_channel_request_record_2026" PARTITION OF "ods"."ods_idv_channel_request_record"
  FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
