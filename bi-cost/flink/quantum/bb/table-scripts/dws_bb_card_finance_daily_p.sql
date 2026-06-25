-- 作业元信息：
--   作业类型：DDL建表/视图脚本
--   运行方式：非运行作业
--   运行参数：无
--   源库变更响应：不涉及源库变更同步；用于创建 ADBPG 目标表、分区、索引或视图。
CREATE TABLE "dws"."dws_bb_card_finance_daily_p" (
  "id" int8 NOT NULL,
  "report_date" date NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "account_type" varchar(30) COLLATE "pg_catalog"."default",
  "account_category" varchar(50) COLLATE "pg_catalog"."default",
  "system_type" varchar(64) COLLATE "pg_catalog"."default",
  "m_dom_auth_count" int4 DEFAULT 0,
  "m_int_auth_count" int4 DEFAULT 0,
  "v_dom_auth_count" int4 DEFAULT 0,
  "v_int_auth_count" int4 DEFAULT 0,
  "m_int_decline_count" int4 DEFAULT 0,
  "v_int_decline_count" int4 DEFAULT 0,
  "dom_decline_count" int4 DEFAULT 0,
  "m_int_reversal_count" int4 DEFAULT 0,
  "v_int_reversal_count" int4 DEFAULT 0,
  "dom_reversal_count" int4 DEFAULT 0,
  "m_int_refund_count" int4 DEFAULT 0,
  "v_int_refund_count" int4 DEFAULT 0,
  "dom_refund_count" int4 DEFAULT 0,
  "av_m_dom_count" int4 DEFAULT 0,
  "av_m_int_count" int4 DEFAULT 0,
  "av_v_dom_count" int4 DEFAULT 0,
  "av_v_int_count" int4 DEFAULT 0,
  "m_dom_clearing_vol" numeric(20,4) DEFAULT 0,
  "m_int_clearing_vol" numeric(20,4) DEFAULT 0,
  "v_dom_clearing_vol" numeric(20,4) DEFAULT 0,
  "v_int_clearing_vol" numeric(20,4) DEFAULT 0,
  "bb_rebate_base_amt" numeric(20,4) DEFAULT 0,
  "bb_channel_cashback_comm" numeric(20,4) DEFAULT 0,
  "active_card_count" int4 DEFAULT 0,
  "cost_fixed_fee" numeric(20,4) DEFAULT 0,
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_bb_daily_pkey" PRIMARY KEY ("id", "report_date")
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
);

ALTER TABLE "dws"."dws_bb_card_finance_daily_p"
  OWNER TO "qbit_admin";

COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_p"."id" IS '主键: 日期+账户+销售+AM业务指纹';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_p"."report_date" IS '统计日期: 以交易北京时间为准';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_p"."account_id" IS '账户ID';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_p"."account_type" IS '账户类型，来源 dim_account.account_type';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_p"."account_category" IS '账户分类，来源 dim_account.type';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_p"."system_type" IS '系统类型，来源 dim_account.system_type';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_p"."cost_fixed_fee" IS '固定渠道成本分摊金额';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_p"."sale_id" IS '销售ID';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_p"."am_id" IS 'AM ID';
COMMENT ON TABLE "dws"."dws_bb_card_finance_daily_p" IS 'BB渠道财务日报汇总表-包含所有计费基数因子';

CREATE INDEX "idx_dws_bb_daily_acc_sale_am" ON "dws"."dws_bb_card_finance_daily_p" USING btree (
  "report_date" "pg_catalog"."date_ops" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dws_bb_account_dim" ON "dws"."dws_bb_card_finance_daily_p" USING btree (
  "report_date" "pg_catalog"."date_ops" ASC NULLS LAST,
  "account_type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "account_category" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "system_type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE TABLE "dws"."dws_bb_cost_daily_2026" PARTITION OF "dws"."dws_bb_card_finance_daily_p"
FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
