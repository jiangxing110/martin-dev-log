--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-27
-- Description:    BZ v2 I2C 渠道财务汇总表
-- Notes:
--   1. 粒度: report_date(月初) + account_id + sale_id + am_id
--   2. 存储 settlement/transaction/verification/card/signature 基数和对应 rate
--   3. BZ固定成本(remarks IS NULL)按 net_consumption 分摊，I2C固定成本(remarks='I2C')按 card_active 分摊
--   4. I2C 订阅费 + 签名费为阶梯计算后按 card_active/signature_count 占比分摊
--********************************************************************--

CREATE TABLE "dws"."dws_bz_card_finance_daily_v2_p" (
  "id" int8 NOT NULL,
  "report_date" date NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "account_type" varchar(30) COLLATE "pg_catalog"."default",
  "account_category" varchar(50) COLLATE "pg_catalog"."default",
  "system_type" varchar(64) COLLATE "pg_catalog"."default",
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "clearing_count" int4 DEFAULT 0,
  "refund_count" int4 DEFAULT 0,
  "clearing_base_amt" numeric(20,4) DEFAULT 0,
  "refund_base_amt" numeric(20,4) DEFAULT 0,
  "net_consumption" numeric(20,4) DEFAULT 0,
  "visa_charges_base_amt" numeric(20,4) DEFAULT 0,
  "auth_count" int4 DEFAULT 0,
  "reversal_count" int4 DEFAULT 0,
  "settlement_volume" numeric(20,4) DEFAULT 0,
  "verify_count" int4 DEFAULT 0,
  "card_create_count" int4 DEFAULT 0,
  "card_active_count" int4 DEFAULT 0,
  "signature_count" int4 DEFAULT 0,
  "reimbursement_rate" numeric(20,8) DEFAULT 0.02,
  "visa_charges_rate" numeric(20,8) DEFAULT 0.01,
  "clearing_fee_rate" numeric(20,8) DEFAULT 0.1,
  "refund_fee_rate" numeric(20,8) DEFAULT 0.2,
  "auth_fee_rate" numeric(20,8) DEFAULT 0.1,
  "reversal_fee_rate" numeric(20,8) DEFAULT 0.1,
  "service_fee_rate" numeric(20,8) DEFAULT 0.0001,
  "verify_fee_rate" numeric(20,8) DEFAULT 0.09,
  "card_setup_rate" numeric(20,8) DEFAULT 0.012,
  "account_activation_rate" numeric(20,8) DEFAULT 0.0055,
  "account_on_file_rate" numeric(20,8) DEFAULT 0.095,
  "total_net_amount" numeric(20,4) DEFAULT 0,
  "cost_fixed_fee" numeric(20,4) DEFAULT 0,
  "special_fee_type" varchar(64) COLLATE "pg_catalog"."default",
  CONSTRAINT "dws_bz_card_finance_daily_v2_pkey" PRIMARY KEY ("id", "report_date")
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
);

COMMENT ON TABLE "dws"."dws_bz_card_finance_daily_v2_p" IS 'BZ v2 I2C 渠道财务汇总表，按月初 report_date 承载整月成本指标';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."id" IS '唯一标识: report_date + account_id + sale_id + am_id 指纹';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."report_date" IS '报表日期，BZ v2 按月初承载整月结果';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."account_id" IS '账户ID';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."account_type" IS '账户类型，来源 dim_account.account_type';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."account_category" IS '账户分类，来源 dim_account.type';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."system_type" IS '系统类型，来源 dim_account.system_type';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."clearing_count" IS 'authorization.clearing 笔数';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."refund_count" IS 'refund.clearing 笔数';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."clearing_base_amt" IS 'authorization.clearing billingAmount 合计';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."refund_base_amt" IS 'refund.clearing billingAmount 合计';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."net_consumption" IS '净消费 = clearing_base_amt - refund_base_amt，Reimbursement_Fee 基数';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."visa_charges_base_amt" IS 'Visa_charges 基数 = SUM(CASE WHEN US THEN -billingAmount ELSE billingAmount END)';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."auth_count" IS 'Consumption 排除 code 1001/1103/1105 的笔数';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."reversal_count" IS 'Reversal 且 settleAmount!=0 的笔数';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."settlement_volume" IS 'Consumption settleAmount 合计，service_fee 基数';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."verify_count" IS 'i2c_iso_message 验证笔数 (transaction_amount=000000000000)';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."card_create_count" IS 'qbitCard 当月新建卡数';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."card_active_count" IS 'qbitCard 当月活跃卡数';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."signature_count" IS 'i2c_iso_message + i2c_iso_token_message 签名笔数';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."reimbursement_rate" IS 'Reimbursement 费率，默认 0.02';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."visa_charges_rate" IS 'Visa_charges 费率，默认 0.01';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."clearing_fee_rate" IS 'clearing_fee 费率，默认 0.1';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."refund_fee_rate" IS 'refund_fee 费率，默认 0.2';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."auth_fee_rate" IS 'auth_fee 费率，默认 0.1';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."reversal_fee_rate" IS 'reversal_fee 费率，默认 0.1';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."service_fee_rate" IS 'service_fee 费率，默认 0.0001';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."verify_fee_rate" IS 'verify_fee 费率，默认 0.09';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."card_setup_rate" IS 'Card_Account_Setup 费率，默认 0.012';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."account_activation_rate" IS 'Account_Activation 费率，默认 0.0055';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."account_on_file_rate" IS 'Account_on_File 费率，默认 0.095';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."total_net_amount" IS '当月净消费合计，用于固定成本分摊';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."cost_fixed_fee" IS '固定渠道成本分摊金额';
COMMENT ON COLUMN "dws"."dws_bz_card_finance_daily_v2_p"."special_fee_type" IS '特殊费用行类型；CHANNEL_FIXED_FEE=BZ固定成本，I2C_FIXED_FEE=I2C固定成本，I2C_SUBSCRIPTION_FEE=I2C订阅费，SIGNATURE_FEE=签名费';

CREATE INDEX "idx_dws_bz_v2_daily_acc_sale_am" ON "dws"."dws_bz_card_finance_daily_v2_p" USING btree (
  "report_date" "pg_catalog"."date_ops" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE TABLE "dws"."dws_bz_card_finance_daily_v2_2026" PARTITION OF "dws"."dws_bz_card_finance_daily_v2_p"
FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
