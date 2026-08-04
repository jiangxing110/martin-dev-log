--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-28
-- Description:    BZ v2 I2C 结算明细 DWM 表
-- Notes:
--   1. 主源: qbitCardSettlement (provider LIKE '%I2c%', transactionType IN authorization.clearing/refund.clearing)
--   2. 通过 cardHashId = qbitCard.token 关联获取 accountId
--   3. 粒度为结算明细，DWS 按月聚合 settlement 指标
--********************************************************************--

CREATE TABLE "dwm"."dwm_bz_card_settlement_detail_v2_p" (
  "id" varchar(128) COLLATE "pg_catalog"."default" NOT NULL,
  "card_hash_id" varchar(255) COLLATE "pg_catalog"."default",
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "account_type" varchar(30) COLLATE "pg_catalog"."default",
  "account_category" varchar(50) COLLATE "pg_catalog"."default",
  "system_type" varchar(64) COLLATE "pg_catalog"."default",
  "card_id" varchar(64) COLLATE "pg_catalog"."default",
  "transaction_time" timestamptz(6) NOT NULL,
  "settlement_type" varchar(80) COLLATE "pg_catalog"."default",
  "billing_amount" numeric(20,4) DEFAULT 0,
  "country" varchar(10) COLLATE "pg_catalog"."default",
  "is_clearing" bool DEFAULT false,
  "is_refund" bool DEFAULT false,
  "is_us" bool DEFAULT false,
  "source_update_time" timestamp(6),
  "source_delete_time" timestamp(6),
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dwm_bz_card_set_v2_pkey" PRIMARY KEY ("id", "transaction_time")
)
PARTITION BY RANGE (
  "transaction_time" "pg_catalog"."timestamptz_ops"
);

COMMENT ON TABLE "dwm"."dwm_bz_card_settlement_detail_v2_p" IS 'BZ v2 I2C 结算明细 DWM 表，主源 qbitCardSettlement (provider LIKE %I2c%)';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."id" IS 'DWM 主键，对应 qbitCardSettlement.id';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."card_hash_id" IS 'qbitCardSettlement.cardHashId，关联 qbitCard.token';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."account_id" IS '账户ID，来源 qbitCard.accountId';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."account_type" IS '账户类型，来源 dim_account.account_type';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."account_category" IS '账户分类，来源 dim_account.type';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."system_type" IS '系统类型，来源 dim_account.system_type';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."card_id" IS '卡ID，来源 qbitCard.id';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."transaction_time" IS '结算时间，来源 qbitCardSettlement.createTime，DWS report_date 和分区基准';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."settlement_type" IS '结算类型，authorization.clearing 或 refund.clearing';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."billing_amount" IS '结算金额 billingAmount';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."country" IS '交易国家，来源 rawData->merchantInfo->country，USA 判断 Visa_charges';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."is_clearing" IS '是否 authorization.clearing';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."is_refund" IS '是否 refund.clearing';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."is_us" IS '是否美国交易，country = USA';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."source_update_time" IS '来源记录更新时间，用于 CDC 识别影响范围';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."source_delete_time" IS '来源记录软删除时间';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."sale_id" IS '销售ID，按 transaction_time 匹配销售关系';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."am_id" IS 'AM ID，按 transaction_time 匹配销售关系';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."version" IS '版本号';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."remarks" IS '来源备注';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."update_time" IS 'DWM 记录更新时间，用于 CDC 识别影响范围';
COMMENT ON COLUMN "dwm"."dwm_bz_card_settlement_detail_v2_p"."delete_time" IS 'DWM 逻辑删除时间';

CREATE INDEX "idx_dwm_bz_set_v2_time_acc_sale_am" ON "dwm"."dwm_bz_card_settlement_detail_v2_p" USING btree (
  "transaction_time" "pg_catalog"."timestamptz_ops" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dwm_bz_set_v2_source_update" ON "dwm"."dwm_bz_card_settlement_detail_v2_p" USING btree (
  "source_update_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST
);

CREATE TABLE "dwm"."dwm_bz_card_set_v2_2026_01" PARTITION OF "dwm"."dwm_bz_card_settlement_detail_v2_p" FOR VALUES FROM ('2026-01-01 00:00:00+08') TO ('2026-02-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_bz_card_set_v2_2026_02" PARTITION OF "dwm"."dwm_bz_card_settlement_detail_v2_p" FOR VALUES FROM ('2026-02-01 00:00:00+08') TO ('2026-03-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_bz_card_set_v2_2026_03" PARTITION OF "dwm"."dwm_bz_card_settlement_detail_v2_p" FOR VALUES FROM ('2026-03-01 00:00:00+08') TO ('2026-04-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_bz_card_set_v2_2026_04" PARTITION OF "dwm"."dwm_bz_card_settlement_detail_v2_p" FOR VALUES FROM ('2026-04-01 00:00:00+08') TO ('2026-05-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_bz_card_set_v2_2026_05" PARTITION OF "dwm"."dwm_bz_card_settlement_detail_v2_p" FOR VALUES FROM ('2026-05-01 00:00:00+08') TO ('2026-06-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_bz_card_set_v2_2026_06" PARTITION OF "dwm"."dwm_bz_card_settlement_detail_v2_p" FOR VALUES FROM ('2026-06-01 00:00:00+08') TO ('2026-07-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_bz_card_set_v2_2026_07" PARTITION OF "dwm"."dwm_bz_card_settlement_detail_v2_p" FOR VALUES FROM ('2026-07-01 00:00:00+08') TO ('2026-08-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_bz_card_set_v2_2026_08" PARTITION OF "dwm"."dwm_bz_card_settlement_detail_v2_p" FOR VALUES FROM ('2026-08-01 00:00:00+08') TO ('2026-09-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_bz_card_set_v2_2026_09" PARTITION OF "dwm"."dwm_bz_card_settlement_detail_v2_p" FOR VALUES FROM ('2026-09-01 00:00:00+08') TO ('2026-10-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_bz_card_set_v2_2026_10" PARTITION OF "dwm"."dwm_bz_card_settlement_detail_v2_p" FOR VALUES FROM ('2026-10-01 00:00:00+08') TO ('2026-11-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_bz_card_set_v2_2026_11" PARTITION OF "dwm"."dwm_bz_card_settlement_detail_v2_p" FOR VALUES FROM ('2026-11-01 00:00:00+08') TO ('2026-12-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_bz_card_set_v2_2026_12" PARTITION OF "dwm"."dwm_bz_card_settlement_detail_v2_p" FOR VALUES FROM ('2026-12-01 00:00:00+08') TO ('2027-01-01 00:00:00+08');
