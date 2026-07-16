--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-15
-- Description:    BB v2 渠道财务汇总表
-- Notes:
--   1. v2 表不替换旧 dws_bb_card_finance_daily_p，先并行落地。
--   2. 粒度为 report_date(月初) + account_id + sale_id + am_id。
--   3. Active Card 按月去重，只在月初 report_date 承载。
--********************************************************************--

CREATE TABLE "dws"."dws_bb_card_finance_daily_v2_p" (
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
  "ac_m_int_decline_count" int4 DEFAULT 0,
  "ac_v_int_decline_count" int4 DEFAULT 0,
  "ac_dom_decline_count" int4 DEFAULT 0,
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
  "m_dom_auth_fee" numeric(20,4) DEFAULT 0,
  "m_int_auth_fee" numeric(20,4) DEFAULT 0,
  "v_dom_auth_fee" numeric(20,4) DEFAULT 0,
  "v_int_auth_fee" numeric(20,4) DEFAULT 0,
  "av_m_dom_fee" numeric(20,4) DEFAULT 0,
  "av_m_int_fee" numeric(20,4) DEFAULT 0,
  "av_v_dom_fee" numeric(20,4) DEFAULT 0,
  "av_v_int_fee" numeric(20,4) DEFAULT 0,
  "m_dom_clearing_fee" numeric(20,4) DEFAULT 0,
  "m_int_clearing_fee" numeric(20,4) DEFAULT 0,
  "v_dom_clearing_fee" numeric(20,4) DEFAULT 0,
  "v_int_clearing_fee" numeric(20,4) DEFAULT 0,
  "m_int_reversal_fee" numeric(20,4) DEFAULT 0,
  "v_int_reversal_fee" numeric(20,4) DEFAULT 0,
  "dom_reversal_fee" numeric(20,4) DEFAULT 0,
  "m_int_refund_fee" numeric(20,4) DEFAULT 0,
  "v_int_refund_fee" numeric(20,4) DEFAULT 0,
  "dom_refund_fee" numeric(20,4) DEFAULT 0,
  "m_int_decline_fee" numeric(20,4) DEFAULT 0,
  "v_int_decline_fee" numeric(20,4) DEFAULT 0,
  "dom_decline_fee" numeric(20,4) DEFAULT 0,
  "ac_m_int_decline_fee" numeric(20,4) DEFAULT 0,
  "ac_v_int_decline_fee" numeric(20,4) DEFAULT 0,
  "ac_dom_decline_fee" numeric(20,4) DEFAULT 0,
  "active_card_account_fee" numeric(20,4) DEFAULT 0,
  "total_net_amount" numeric(20,4) DEFAULT 0,
  "volume_fee_cost" numeric(20,4) DEFAULT 0,
  "cashback_rate" numeric(20,8) DEFAULT 0,
  "cashback_income" numeric(20,4) DEFAULT 0,
  "cost_fixed_fee" numeric(20,4) DEFAULT 0,
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_bb_card_finance_daily_v2_pkey" PRIMARY KEY ("id", "report_date")
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
);

COMMENT ON TABLE "dws"."dws_bb_card_finance_daily_v2_p" IS 'BB v2 渠道财务汇总表，按月初 report_date 承载整月成本指标';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."id" IS '唯一标识: report_date + account_id + sale_id + am_id 指纹';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."report_date" IS '报表日期，BB v2 按月初承载整月结果';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."account_id" IS '账户ID';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."account_type" IS '账户类型，来源 dim_account.account_type';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."account_category" IS '账户分类，来源 dim_account.type';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."system_type" IS '系统类型，来源 dim_account.system_type';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."m_dom_auth_count" IS 'Mastercard Domestic 普通授权交易笔数，非 Account Verification';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."m_int_auth_count" IS 'Mastercard International 普通授权交易笔数，非 Account Verification';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."v_dom_auth_count" IS 'VISA Domestic 普通授权交易笔数，非 Account Verification';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."v_int_auth_count" IS 'VISA International 普通授权交易笔数，非 Account Verification';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."m_int_decline_count" IS 'Mastercard International 非验证 Decline 笔数';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."v_int_decline_count" IS 'VISA International 非验证 Decline 笔数';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."dom_decline_count" IS 'Domestic 非验证 Decline 笔数';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."ac_m_int_decline_count" IS 'Mastercard International Account Verification Decline 笔数';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."ac_v_int_decline_count" IS 'VISA International Account Verification Decline 笔数';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."ac_dom_decline_count" IS 'Domestic Account Verification Decline 笔数';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."m_int_reversal_count" IS 'Mastercard International Reversal 笔数';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."v_int_reversal_count" IS 'VISA International Reversal 笔数';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."dom_reversal_count" IS 'Domestic Reversal 笔数';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."m_int_refund_count" IS 'Mastercard International Refund 笔数';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."v_int_refund_count" IS 'VISA International Refund 笔数';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."dom_refund_count" IS 'Domestic Refund 笔数';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."av_m_dom_count" IS 'Mastercard Domestic Account Verification 授权笔数';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."av_m_int_count" IS 'Mastercard International Account Verification 授权笔数';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."av_v_dom_count" IS 'VISA Domestic Account Verification 授权笔数';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."av_v_int_count" IS 'VISA International Account Verification 授权笔数';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."m_dom_clearing_vol" IS 'Mastercard Domestic clearing/refund approved 净额';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."m_int_clearing_vol" IS 'Mastercard International clearing/refund approved 净额';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."v_dom_clearing_vol" IS 'VISA Domestic clearing/refund approved 净额';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."v_int_clearing_vol" IS 'VISA International clearing/refund approved 净额';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."bb_rebate_base_amt" IS 'BB 返现/收入基数金额，按 approved clearing/refund 净额计算';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."bb_channel_cashback_comm" IS 'BB 渠道 cashback 计算基数，当前口径等于 bb_rebate_base_amt';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."active_card_count" IS '月度 active card 去重数，不能按日累加';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."m_dom_auth_fee" IS 'm_dom_auth_count * 0.1090';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."m_int_auth_fee" IS 'm_int_auth_count * 0.4845';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."v_dom_auth_fee" IS 'v_dom_auth_count * 0.0725';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."v_int_auth_fee" IS 'v_int_auth_count * 0.4770';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."av_m_dom_fee" IS 'av_m_dom_count * 0.1090';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."av_m_int_fee" IS 'av_m_int_count * 0.4845';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."av_v_dom_fee" IS 'av_v_dom_count * 0.0725';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."av_v_int_fee" IS 'av_v_int_count * 0.4770';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."m_dom_clearing_fee" IS 'm_dom_clearing_vol * 0.0021';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."m_int_clearing_fee" IS 'm_int_clearing_vol * 0.0111';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."v_dom_clearing_fee" IS 'v_dom_clearing_vol * 0.0016';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."v_int_clearing_fee" IS 'v_int_clearing_vol * 0.0116';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."m_int_reversal_fee" IS 'm_int_reversal_count * 0.7190';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."v_int_reversal_fee" IS 'v_int_reversal_count * 0.7140';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."dom_reversal_fee" IS 'dom_reversal_count * 0.1780';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."m_int_refund_fee" IS 'm_int_refund_count * 0.4845';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."v_int_refund_fee" IS 'v_int_refund_count * 0.4770';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."dom_refund_fee" IS 'dom_refund_count * 0.1090';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."m_int_decline_fee" IS 'm_int_decline_count * 0.3595';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."v_int_decline_fee" IS 'v_int_decline_count * 0.3570';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."dom_decline_fee" IS 'dom_decline_count * 0.0890';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."ac_m_int_decline_fee" IS 'ac_m_int_decline_count * 0.3595';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."ac_v_int_decline_fee" IS 'ac_v_int_decline_count * 0.3570';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."ac_dom_decline_fee" IS 'ac_dom_decline_count * 0.0890';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."active_card_account_fee" IS 'active_card_count * 0.1';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."total_net_amount" IS 'BB 当行总净额，用于 Volume Fee Cost 和 Cashback Income';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."volume_fee_cost" IS '按全月 total_net_amount 阶梯后按行净额占比分摊';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."cashback_rate" IS 'BB 月度 Cashback 费率，建议来源 ods_bi_month_tag';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."cashback_income" IS 'bb_rebate_base_amt * cashback_rate';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."cost_fixed_fee" IS 'BB 月度固定渠道成本分摊金额';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."sale_id" IS '销售ID，按交易或授权时间匹配销售关系';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."am_id" IS 'AM ID，按交易或授权时间匹配销售关系';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."version" IS '版本号';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."remarks" IS '备注';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."delete_time" IS '逻辑删除时间';

CREATE INDEX "idx_dws_bb_v2_daily_acc_sale_am" ON "dws"."dws_bb_card_finance_daily_v2_p" USING btree (
  "report_date" "pg_catalog"."date_ops" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE TABLE "dws"."dws_bb_card_finance_daily_v2_2026" PARTITION OF "dws"."dws_bb_card_finance_daily_v2_p"
FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
