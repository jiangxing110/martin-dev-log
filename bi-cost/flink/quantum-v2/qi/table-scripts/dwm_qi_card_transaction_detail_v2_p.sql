--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-15
-- Description:    QI v2 渠道交易明细 DWM 表
-- Notes:
--   1. v2 表不替换旧 dwm_qi_card_transaction_detail_p，先并行落地。
--   2. 保留完整交易状态，DWS 通过删除重算处理 Pending -> Failed 等状态流转。
--********************************************************************--

CREATE TABLE "dwm"."dwm_qi_card_transaction_detail_v2_p" (
  "id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "transaction_id" varchar(100) COLLATE "pg_catalog"."default" NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "account_type" varchar(30) COLLATE "pg_catalog"."default",
  "account_category" varchar(50) COLLATE "pg_catalog"."default",
  "system_type" varchar(64) COLLATE "pg_catalog"."default",
  "status" varchar(20) COLLATE "pg_catalog"."default",
  "transaction_time" timestamptz(6) NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  "source_update_time" timestamp(6),
  "source_delete_time" timestamp(6),
  "is_current_valid" bool DEFAULT true,
  "billing_amount" numeric(20,4) DEFAULT 0,
  "is_qbit_provision" bool DEFAULT false,
  "is_hk_region" bool DEFAULT false,
  "is_consumption" bool DEFAULT false,
  "is_reversal_or_credit" bool DEFAULT false,
  "has_special_code" bool DEFAULT false,
  "is_vip_account" bool DEFAULT false,
  "business_type" varchar(50) COLLATE "pg_catalog"."default",
  "card_id" varchar(255) COLLATE "pg_catalog"."default",
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  CONSTRAINT "dwm_qi_card_tx_v2_pkey" PRIMARY KEY ("id", "transaction_time")
)
PARTITION BY RANGE (
  "transaction_time" "pg_catalog"."timestamptz_ops"
);

COMMENT ON TABLE "dwm"."dwm_qi_card_transaction_detail_v2_p" IS 'QI v2 渠道交易明细 DWM 表，保留状态机当前事实';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."id" IS 'DWM 主键，对应 qbit_card_transaction.id';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."transaction_id" IS '原始交易ID，用于关联 quantum_card_transaction_extend.transaction_id';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."account_id" IS '账户ID，来源 qbit_card_transaction.accountId';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."account_type" IS '账户类型，来源 dim_account.account_type';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."account_category" IS '账户分类，来源 dim_account.type';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."system_type" IS '系统类型，来源 dim_account.system_type';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."status" IS '交易状态，DWS 按 Closed/Pending 等业务规则计算';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."transaction_time" IS '交易时间，DWS report_date 和分区基准';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."version" IS '来源版本号';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."remarks" IS '来源备注';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."update_time" IS 'DWM 记录更新时间';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."delete_time" IS 'DWM 逻辑删除时间';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."source_update_time" IS '来源记录更新时间，用于 CDC 识别影响范围';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."source_delete_time" IS '来源记录软删除时间';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."is_current_valid" IS '当前记录是否可作为 DWS 候选，最终计算仍由 DWS 状态条件决定';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."billing_amount" IS '清算/计费金额 USD';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."is_qbit_provision" IS '是否 QBIT 渠道，来源 quantum_card_transaction_extend.channel_provision';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."is_hk_region" IS '是否香港地区交易，country IN (HK,HKG)';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."is_consumption" IS '是否 Consumption 交易';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."is_reversal_or_credit" IS '是否 Reversal 或 Credit，用于净额抵减';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."has_special_code" IS '是否包含 1001/1103/1105 等特殊码';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."is_vip_account" IS '是否 VIP 账号，当前预留扩展字段';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."business_type" IS '业务类型，Consumption/Reversal/Credit 等';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."card_id" IS '卡ID';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."sale_id" IS '销售ID，按 transaction_time 匹配销售关系';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_v2_p"."am_id" IS 'AM ID，按 transaction_time 匹配销售关系';

CREATE INDEX "idx_dwm_qi_tx_v2_time_acc_sale_am" ON "dwm"."dwm_qi_card_transaction_detail_v2_p" USING btree (
  "transaction_time" "pg_catalog"."timestamptz_ops" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dwm_qi_tx_v2_source_update" ON "dwm"."dwm_qi_card_transaction_detail_v2_p" USING btree (
  "source_update_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST
);

CREATE TABLE "dwm"."dwm_qi_card_tx_v2_2026_01" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-01-01 00:00:00+08') TO ('2026-02-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_v2_2026_02" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-02-01 00:00:00+08') TO ('2026-03-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_v2_2026_03" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-03-01 00:00:00+08') TO ('2026-04-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_v2_2026_04" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-04-01 00:00:00+08') TO ('2026-05-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_v2_2026_05" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-05-01 00:00:00+08') TO ('2026-06-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_v2_2026_06" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-06-01 00:00:00+08') TO ('2026-07-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_v2_2026_07" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-07-01 00:00:00+08') TO ('2026-08-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_v2_2026_08" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-08-01 00:00:00+08') TO ('2026-09-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_v2_2026_09" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-09-01 00:00:00+08') TO ('2026-10-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_v2_2026_10" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-10-01 00:00:00+08') TO ('2026-11-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_v2_2026_11" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-11-01 00:00:00+08') TO ('2026-12-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_v2_2026_12" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_v2_p" FOR VALUES FROM ('2026-12-01 00:00:00+08') TO ('2027-01-01 00:00:00+08');
