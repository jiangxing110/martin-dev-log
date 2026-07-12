-- 作业元信息：
--   作业类型：DDL建表/视图脚本
--   运行方式：非运行作业
--   运行参数：无
--   源库变更响应：不涉及源库变更同步；用于创建 ADBPG 目标表、分区、索引或视图。
CREATE TABLE "dwm"."dwm_qi_card_transaction_detail_p" (
  "id" uuid NOT NULL,
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
  CONSTRAINT "dwm_qi_card_tx_pkey" PRIMARY KEY ("id", "transaction_time")
)
PARTITION BY RANGE (
  "transaction_time" "pg_catalog"."timestamptz_ops"
);



COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."id" IS '主键ID-对应ODS层交易ID';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."transaction_id" IS '原始交易ID';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."account_id" IS '账户ID';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."account_type" IS '账户类型，来源 dim_account.account_type';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."account_category" IS '账户分类，来源 dim_account.type';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."system_type" IS '系统类型，来源 dim_account.system_type';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."status" IS '交易状态';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."transaction_time" IS '交易时间-分区键';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."version" IS '乐观锁版本';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."remarks" IS '备注';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."delete_time" IS '逻辑删除时间';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."billing_amount" IS '清算/计费金额(USD)';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."is_qbit_provision" IS '是否Qbit预置卡';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."is_hk_region" IS '是否香港地区交易';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."is_consumption" IS '是否消费类型';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."is_reversal_or_credit" IS '是否冲正或退款';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."has_special_code" IS '是否含特殊码';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."is_vip_account" IS '是否ACS VIP账户';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."business_type" IS '业务类型';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."card_id" IS '卡片ID';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."sale_id" IS '销售ID';
COMMENT ON COLUMN "dwm"."dwm_qi_card_transaction_detail_p"."am_id" IS 'AM ID';
COMMENT ON TABLE "dwm"."dwm_qi_card_transaction_detail_p" IS 'QI渠道明细因子层-月度分区表';

CREATE INDEX "idx_dwm_qi_tx_time_acc_sale_am" ON "dwm"."dwm_qi_card_transaction_detail_p" USING btree (
  "transaction_time" "pg_catalog"."timestamptz_ops" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dwm_qi_account_dim" ON "dwm"."dwm_qi_card_transaction_detail_p" USING btree (
  "transaction_time" "pg_catalog"."timestamptz_ops" ASC NULLS LAST,
  "account_type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "account_category" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "system_type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dwm_qi_update_time" ON "dwm"."dwm_qi_card_transaction_detail_p" USING btree (
  "update_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST
);

CREATE TABLE "dwm"."dwm_qi_card_tx_2026_01" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_p" FOR VALUES FROM ('2026-01-01 00:00:00+08') TO ('2026-02-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_2026_02" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_p" FOR VALUES FROM ('2026-02-01 00:00:00+08') TO ('2026-03-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_2026_03" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_p" FOR VALUES FROM ('2026-03-01 00:00:00+08') TO ('2026-04-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_2026_04" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_p" FOR VALUES FROM ('2026-04-01 00:00:00+08') TO ('2026-05-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_2026_05" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_p" FOR VALUES FROM ('2026-05-01 00:00:00+08') TO ('2026-06-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_2026_06" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_p" FOR VALUES FROM ('2026-06-01 00:00:00+08') TO ('2026-07-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_2026_07" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_p" FOR VALUES FROM ('2026-07-01 00:00:00+08') TO ('2026-08-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_2026_08" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_p" FOR VALUES FROM ('2026-08-01 00:00:00+08') TO ('2026-09-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_2026_09" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_p" FOR VALUES FROM ('2026-09-01 00:00:00+08') TO ('2026-10-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_2026_10" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_p" FOR VALUES FROM ('2026-10-01 00:00:00+08') TO ('2026-11-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_2026_11" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_p" FOR VALUES FROM ('2026-11-01 00:00:00+08') TO ('2026-12-01 00:00:00+08');
CREATE TABLE "dwm"."dwm_qi_card_tx_2026_12" PARTITION OF "dwm"."dwm_qi_card_transaction_detail_p" FOR VALUES FROM ('2026-12-01 00:00:00+08') TO ('2027-01-01 00:00:00+08');
