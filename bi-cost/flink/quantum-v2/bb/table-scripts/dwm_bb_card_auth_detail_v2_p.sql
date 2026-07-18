--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-12
-- Description:    BB v2 Auth 明细 DWM 表
-- Notes:
--   1. Auth 原始表按月存在，例如 bb_card_auth_detail_2026-04。
--   2. 本表作为稳定 DWM，供 DWS 汇总 Decline / Active Card。
--   3. AC Decline 明细保留在 DWM，现有 BB DWS 表暂无独立字段承接。
--********************************************************************--

CREATE TABLE "dwm"."dwm_bb_card_auth_detail_v2_p" (
  "id" varchar(128) COLLATE "pg_catalog"."default" NOT NULL,
  "auth_txn_guid" varchar(255) COLLATE "pg_catalog"."default",
  "card_proxy" varchar(255) COLLATE "pg_catalog"."default",
  "account_id" varchar(36) COLLATE "pg_catalog"."default",
  "account_type" varchar(30) COLLATE "pg_catalog"."default",
  "account_category" varchar(50) COLLATE "pg_catalog"."default",
  "system_type" varchar(64) COLLATE "pg_catalog"."default",
  "card_id" varchar(36) COLLATE "pg_catalog"."default",
  "auth_time" timestamp(6) NOT NULL,
  "program_name" varchar(255) COLLATE "pg_catalog"."default",
  "merchant_country" varchar(255) COLLATE "pg_catalog"."default",
  "request_code" varchar(255) COLLATE "pg_catalog"."default",
  "request_description" varchar(255) COLLATE "pg_catalog"."default",
  "response_code" varchar(255) COLLATE "pg_catalog"."default",
  "reason_code" varchar(255) COLLATE "pg_catalog"."default",
  "txn_amount" varchar(255) COLLATE "pg_catalog"."default",
  "settle_amount" varchar(255) COLLATE "pg_catalog"."default",
  "txn_currency" varchar(255) COLLATE "pg_catalog"."default",
  "merchant_name" varchar(255) COLLATE "pg_catalog"."default",
  "mcc" varchar(255) COLLATE "pg_catalog"."default",
  "card_org" varchar(20) COLLATE "pg_catalog"."default",
  "is_dom" bool DEFAULT false,
  "is_decline" bool DEFAULT false,
  "is_account_verification" bool DEFAULT false,
  "is_excluded_request" bool DEFAULT false,
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "source_table" varchar(128) COLLATE "pg_catalog"."default",
  "version" int4 DEFAULT 1,
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dwm_bb_card_auth_v2_pkey" PRIMARY KEY ("id", "auth_time")
)
PARTITION BY RANGE (
  "auth_time" "pg_catalog"."timestamp_ops"
);

COMMENT ON TABLE "dwm"."dwm_bb_card_auth_detail_v2_p" IS 'BB v2 Auth 明细因子层，来源 bb_card_auth_detail_yyyy-mm 月表';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."id" IS 'Auth 明细指纹，通常由 auth_txn_guid + card_proxy + auth_time 生成';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."auth_txn_guid" IS 'Auth 月表 Auth Txn GUID，Decline 指标去重主键';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."card_proxy" IS 'Auth 月表 Card Proxy，Active Card 月度去重基准';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."account_id" IS '账户ID，通过 qbitCard.token/Card Proxy 关联';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."account_type" IS '账户类型，来源 dim_account.account_type';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."account_category" IS '账户分类，来源 dim_account.type';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."system_type" IS '系统类型，来源 dim_account.system_type';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."card_id" IS '卡ID，通过 Card Proxy 关联 qbitCard';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."auth_time" IS 'Auth 交易时间，来源 Trans Date / Time';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."program_name" IS 'Auth 月表 Program Name，用于追溯卡项目/卡 BIN 规则';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."merchant_country" IS '商户国家，Domestic/International 判断';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."request_code" IS 'Auth 请求代码';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."request_description" IS 'Auth 请求描述，用于识别 Account Verification 和 Advice 排除项';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."response_code" IS 'Auth 响应码，DECLINE 表示失败授权';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."reason_code" IS 'Auth 原因码';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."txn_amount" IS 'Auth 原始交易金额文本';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."settle_amount" IS 'Auth 原始清算金额文本';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."txn_currency" IS 'Auth 原始交易币种';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."merchant_name" IS '商户名称';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."mcc" IS 'MCC 商户类别码';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."card_org" IS '卡组织，Master 或 VISA';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."is_dom" IS '是否 Domestic，merchant_country = USA';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."is_account_verification" IS '是否 Account Verification';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."is_decline" IS '是否 DECLINE';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."is_excluded_request" IS '是否 BB 新规则排除的 Advice 类请求';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."sale_id" IS '销售ID，按 auth_time 匹配销售关系';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."am_id" IS 'AM ID，按 auth_time 匹配销售关系';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."source_table" IS '来源 Auth 月表名，例如 bb_card_auth_detail_2026-04';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."version" IS '版本号';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."update_time" IS '记录更新时间，用于 CDC/回刷识别';
COMMENT ON COLUMN "dwm"."dwm_bb_card_auth_detail_v2_p"."delete_time" IS '逻辑删除时间，DWS 重算时剔除';

CREATE INDEX "idx_dwm_bb_auth_v2_time_acc_sale_am" ON "dwm"."dwm_bb_card_auth_detail_v2_p" USING btree (
  "auth_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE TABLE "dwm"."dwm_bb_card_auth_v2_2026_01" PARTITION OF "dwm"."dwm_bb_card_auth_detail_v2_p" FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-02-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_auth_v2_2026_02" PARTITION OF "dwm"."dwm_bb_card_auth_detail_v2_p" FOR VALUES FROM ('2026-02-01 00:00:00') TO ('2026-03-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_auth_v2_2026_03" PARTITION OF "dwm"."dwm_bb_card_auth_detail_v2_p" FOR VALUES FROM ('2026-03-01 00:00:00') TO ('2026-04-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_auth_v2_2026_04" PARTITION OF "dwm"."dwm_bb_card_auth_detail_v2_p" FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-05-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_auth_v2_2026_05" PARTITION OF "dwm"."dwm_bb_card_auth_detail_v2_p" FOR VALUES FROM ('2026-05-01 00:00:00') TO ('2026-06-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_auth_v2_2026_06" PARTITION OF "dwm"."dwm_bb_card_auth_detail_v2_p" FOR VALUES FROM ('2026-06-01 00:00:00') TO ('2026-07-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_auth_v2_2026_07" PARTITION OF "dwm"."dwm_bb_card_auth_detail_v2_p" FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-08-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_auth_v2_2026_08" PARTITION OF "dwm"."dwm_bb_card_auth_detail_v2_p" FOR VALUES FROM ('2026-08-01 00:00:00') TO ('2026-09-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_auth_v2_2026_09" PARTITION OF "dwm"."dwm_bb_card_auth_detail_v2_p" FOR VALUES FROM ('2026-09-01 00:00:00') TO ('2026-10-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_auth_v2_2026_10" PARTITION OF "dwm"."dwm_bb_card_auth_detail_v2_p" FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2026-11-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_auth_v2_2026_11" PARTITION OF "dwm"."dwm_bb_card_auth_detail_v2_p" FOR VALUES FROM ('2026-11-01 00:00:00') TO ('2026-12-01 00:00:00');
CREATE TABLE "dwm"."dwm_bb_card_auth_v2_2026_12" PARTITION OF "dwm"."dwm_bb_card_auth_detail_v2_p" FOR VALUES FROM ('2026-12-01 00:00:00') TO ('2027-01-01 00:00:00');
