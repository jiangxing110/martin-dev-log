--********************************************************************--
-- Author:         martin-dev-log aa
-- Created Time:   2026-06-17
-- 功能：ADBPG ODS目标表 ods_qbit_card_settlement DDL | 按dt日期分区
-- 作业元信息：
--   作业类型：DDL建表/视图脚本
--   运行方式：非运行作业
--   运行参数：无
--   源库变更响应：不涉及源库变更同步；用于创建 ADBPG 目标表、分区、索引或视图。
-- 说明：先执行建表，再跑 Flink 同步作业
-- 变更：PK改为(id, dt)，分区键改为dt，避免ON CONFLICT修改分区键报错
--********************************************************************--

CREATE TABLE "ods"."ods_qbit_card_settlement" (
    "id" VARCHAR(64) NOT NULL,
    "dt" DATE NOT NULL,
    "remarks" TEXT,
    "create_time" TIMESTAMP,
    "update_time" TIMESTAMP,
    "delete_time" TIMESTAMP,
    "version" INTEGER NOT NULL DEFAULT 0,
    "card_hash_id" VARCHAR(255),
    "transaction_id" VARCHAR(255),
    "reference_number" VARCHAR(255),
    "record_type" VARCHAR(64),
    "effective_date" VARCHAR(64),
    "batch_date" VARCHAR(64),
    "transaction_type" VARCHAR(64),
    "transaction_code" VARCHAR(64),
    "billing_amount" DOUBLE PRECISION DEFAULT 0,
    "billing_currency_code" VARCHAR(16),
    "transaction_amount" DOUBLE PRECISION DEFAULT 0,
    "transaction_currency_code" VARCHAR(16),
    "authorization_code" VARCHAR(255),
    "description" TEXT,
    "card_acceptor_id" VARCHAR(255),
    "interchange_reference" VARCHAR(255),
    "visa_transaction_id" VARCHAR(64),
    "token_requestor_id" VARCHAR(64),
    "token_number" VARCHAR(64),
    "billing_amount_raw" VARCHAR(64),
    "transaction_amount_raw" VARCHAR(64),
    "raw_data" TEXT,
    "settlement_day" VARCHAR(32),
    "hash" VARCHAR(64),
    "provider" VARCHAR(64),
    "settle_completed" BOOLEAN DEFAULT FALSE,
    "qbit_card_transaction_id" VARCHAR(64),
    "compare_time" TIMESTAMP,
    "id_" BIGINT,
    "status_message" VARCHAR(255),
    "country" VARCHAR(255),
    "mid" VARCHAR(40),
    "merchant_country" VARCHAR(255),
    "channel" VARCHAR(255),
    "wallet" VARCHAR(40),
    "mcc" VARCHAR(64),
    CONSTRAINT "ods_qbit_card_settlementkey" PRIMARY KEY ("id", "dt")
)
PARTITION BY RANGE ("dt");

ALTER TABLE "ods"."ods_qbit_card_settlement"
    OWNER TO "qbit_admin";

COMMENT ON TABLE "ods"."ods_qbit_card_settlement" IS 'ODS层：qbitCardSettlement 实时同步表';

-- ==============================================
-- 按月分区 2024-01 ~ 2026-12 (dt)
-- ==============================================
CREATE TABLE "ods"."ods_qbit_card_settlement_202401" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202402" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202403" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202404" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2024-04-01') TO ('2024-05-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202405" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2024-05-01') TO ('2024-06-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202406" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2024-06-01') TO ('2024-07-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202407" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2024-07-01') TO ('2024-08-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202408" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2024-08-01') TO ('2024-09-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202409" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2024-09-01') TO ('2024-10-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202410" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2024-10-01') TO ('2024-11-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202411" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2024-11-01') TO ('2024-12-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202412" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2024-12-01') TO ('2025-01-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202501" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202502" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202503" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202504" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202505" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202506" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202507" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202508" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202509" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202510" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202511" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202512" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202601" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202602" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202603" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202604" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202605" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202606" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202607" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202608" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202609" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202610" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202611" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE "ods"."ods_qbit_card_settlement_202612" PARTITION OF "ods"."ods_qbit_card_settlement"
  FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
