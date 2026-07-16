--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-12
-- Description:    BB v2 交易 + 结算明细 DWM 表
-- Notes:
--   1. v2 以 quantum_card_transaction_extend 为交易主源。
--   2. 粒度为交易 + 结算明细，保留 BB 新规则计算需要的中间字段。
--   3. 不替换旧 dwm_bb_card_transaction_detail_p，先并行落地。
--********************************************************************--

CREATE TABLE "dwm"."dwm_bb_card_transaction_detail_v2_p" (
  "id" varchar(128) COLLATE "pg_catalog"."default" NOT NULL,
  "txn_id" int8 NOT NULL,
  "settlement_id" uuid,
  "source_id" varchar(128) COLLATE "pg_catalog"."default",
  "card_transaction_id" varchar(128) COLLATE "pg_catalog"."default",
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "account_type" varchar(30) COLLATE "pg_catalog"."default",
  "account_category" varchar(50) COLLATE "pg_catalog"."default",
  "system_type" varchar(64) COLLATE "pg_catalog"."default",
  "card_id" uuid NOT NULL,
  "transaction_time" timestamp(6) NOT NULL,
  "original_completion_time" timestamp(6),
  "business_type" varchar(50) COLLATE "pg_catalog"."default",
  "business_code_list" text COLLATE "pg_catalog"."default",
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "detail" text COLLATE "pg_catalog"."default",
  "card_org" varchar(20) COLLATE "pg_catalog"."default",
  "tx_country" varchar(10) COLLATE "pg_catalog"."default",
  "settle_country" varchar(10) COLLATE "pg_catalog"."default",
  "is_dom" bool DEFAULT false,
  "resp_code" varchar(20) COLLATE "pg_catalog"."default",
  "reason_code" varchar(50) COLLATE "pg_catalog"."default",
  "transaction_type" varchar(80) COLLATE "pg_catalog"."default",
  "is_valid_settle" bool DEFAULT false,
  "is_clearing" bool DEFAULT false,
  "is_reversal" bool DEFAULT false,
  "is_refund" bool DEFAULT false,
  "billing_amount" numeric(20,4) DEFAULT 0,
  "settlement_post_date" timestamp(6),
  "settlement_txn_date" timestamp(6),
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "version" int4 DEFAULT 1,
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dwm_bb_card_tx_v2_pkey" PRIMARY KEY ("id", "transaction_time")
)
PARTITION BY RANGE (
  "transaction_time" "pg_catalog"."timestamp_ops"
);

COMMENT ON TABLE "dwm"."dwm_bb_card_transaction_detail_v2_p" IS 'BB v2 渠道交易结算明细因子层，交易主源为 quantum_card_transaction_extend';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."id" IS '交易+结算明细指纹';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."txn_id" IS 'quantum_card_transaction_extend.id';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."settlement_id" IS 'qbitCardSettlement.id';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."source_id" IS 'quantum_card_transaction_extend.source_id';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."card_transaction_id" IS 'quantum_card_transaction_extend.card_transaction_id';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."account_id" IS '账户ID，来源 quantum_card_transaction_extend.account_id';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."account_type" IS '账户类型，来源 dim_account.account_type';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."account_category" IS '账户分类，来源 dim_account.type';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."system_type" IS '系统类型，来源 dim_account.system_type';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."card_id" IS '卡ID，来源 quantum_card_transaction_extend.card_id';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."transaction_time" IS '交易发生时间，授权笔数类指标统计基准';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."original_completion_time" IS '三方完成时间，BB Volume Fee 统计基准';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."business_type" IS '业务类型，Consumption/Credit 等';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."business_code_list" IS '业务编码列表，用于识别 Account Verification';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."remarks" IS '交易备注，用于兼容超时自动关单等特殊场景';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."detail" IS '交易详情，用于排除 AUTO CLASS CAR RENTAL';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."card_org" IS '卡组织，Master 或 VISA';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."tx_country" IS '交易国家，授权笔数 Domestic/International 判断';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."settle_country" IS '清算国家，金额类 Domestic/International 判断';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."is_dom" IS '是否 Domestic，美国/USA 口径';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."resp_code" IS '清算响应码，APPROVE/DECLINE 等';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."reason_code" IS '清算原因码，Reversal 指标需要 APPROVE';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."transaction_type" IS '清算交易类型，如 authorization.clearing、authorization.reversal、refund.clearing';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."is_valid_settle" IS '是否有效 settlement，排除 Advice 类记录';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."is_clearing" IS '是否 authorization.clearing';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."is_reversal" IS '是否 authorization.reversal';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."is_refund" IS '是否 refund.clearing';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."billing_amount" IS '清算 billingAmount，BB 金额类指标基础';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."settlement_post_date" IS 'settlement rawData.postDate，Refund 指标统计基准';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."settlement_txn_date" IS 'settlement rawData.txnDate，用于对账追溯';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."sale_id" IS '销售ID，按交易时间匹配销售关系';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."am_id" IS 'AM ID，按交易时间匹配销售关系';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."version" IS '版本号';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."update_time" IS '记录更新时间，用于 CDC 识别影响范围';
COMMENT ON COLUMN "dwm"."dwm_bb_card_transaction_detail_v2_p"."delete_time" IS '逻辑删除时间，DWS 重算时剔除';

CREATE INDEX "idx_dwm_bb_tx_v2_time_acc_sale_am" ON "dwm"."dwm_bb_card_transaction_detail_v2_p" USING btree (
  "transaction_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dwm_bb_tx_v2_original_completion" ON "dwm"."dwm_bb_card_transaction_detail_v2_p" USING btree (
  "original_completion_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE TABLE "dwm"."dwm_bb_card_tx_v2_2026_01" PARTITION OF "dwm"."dwm_bb_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-02-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_tx_v2_2026_02" PARTITION OF "dwm"."dwm_bb_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-02-01 00:00:00') TO ('2026-03-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_tx_v2_2026_03" PARTITION OF "dwm"."dwm_bb_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-03-01 00:00:00') TO ('2026-04-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_tx_v2_2026_04" PARTITION OF "dwm"."dwm_bb_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-05-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_tx_v2_2026_05" PARTITION OF "dwm"."dwm_bb_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-05-01 00:00:00') TO ('2026-06-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_tx_v2_2026_06" PARTITION OF "dwm"."dwm_bb_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-06-01 00:00:00') TO ('2026-07-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_tx_v2_2026_07" PARTITION OF "dwm"."dwm_bb_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-08-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_tx_v2_2026_08" PARTITION OF "dwm"."dwm_bb_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-08-01 00:00:00') TO ('2026-09-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_tx_v2_2026_09" PARTITION OF "dwm"."dwm_bb_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-09-01 00:00:00') TO ('2026-10-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_tx_v2_2026_10" PARTITION OF "dwm"."dwm_bb_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2026-11-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_tx_v2_2026_11" PARTITION OF "dwm"."dwm_bb_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-11-01 00:00:00') TO ('2026-12-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_tx_v2_2026_12" PARTITION OF "dwm"."dwm_bb_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-12-01 00:00:00') TO ('2027-01-01 00:00:00');
