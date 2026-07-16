--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-15
-- Description:    QI v2 渠道财务汇总表
-- Notes:
--   1. v2 表不替换旧 dws_qi_card_finance_daily_p，先并行落地。
--   2. 只记录成本/返现计费基数和对应 rate，结果金额由下游按 base * rate 计算。
--********************************************************************--

CREATE TABLE "dws"."dws_qi_card_finance_daily_v2_p" (
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
  "cost_reimbursement_base_amt" numeric(20,4) DEFAULT 0,
  "cost_service_base_amt" numeric(20,4) DEFAULT 0,
  "cost_acs_regular_base_amt" numeric(20,4) DEFAULT 0,
  "cost_acs_vip_base_amt" numeric(20,4) DEFAULT 0,
  "cost_vrm_base_amt" numeric(20,4) DEFAULT 0,
  "rebate_interchange_base_amt" numeric(20,4) DEFAULT 0,
  "rebate_incentive_base_amt" numeric(20,4) DEFAULT 0,
  "cost_reimbursement_rate" numeric(20,8) DEFAULT 0,
  "cost_service_rate" numeric(20,8) DEFAULT 0,
  "cost_acs_regular_rate" numeric(20,8) DEFAULT 0,
  "cost_acs_vip_rate" numeric(20,8) DEFAULT 0,
  "cost_vrm_rate" numeric(20,8) DEFAULT 0,
  "rebate_interchange_rate" numeric(20,8) DEFAULT 0,
  "rebate_incentive_rate" numeric(20,8) DEFAULT 0,
  "cost_fixed_fee" numeric(20,4) DEFAULT 0,
  "special_fee_type" varchar(64) COLLATE "pg_catalog"."default",
  CONSTRAINT "dws_qi_card_finance_daily_v2_pkey" PRIMARY KEY ("id", "report_date")
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
);

COMMENT ON TABLE "dws"."dws_qi_card_finance_daily_v2_p" IS 'QI v2 渠道财务汇总表，记录成本/返现计费基数和对应 rate';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."id" IS '唯一标识: report_date + account_id + sale_id + am_id 指纹';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."report_date" IS '报表日期，来源 transaction_time 日期';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."account_id" IS '账户ID';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."account_type" IS '账户类型，来源 DWM/dim_account.account_type';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."account_category" IS '账户分类，来源 DWM/dim_account.type';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."system_type" IS '系统类型，来源 DWM/dim_account.system_type';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."version" IS '版本号';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."remarks" IS '备注';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."delete_time" IS '逻辑删除时间';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."sale_id" IS '销售ID，来源 DWM 销售关系';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."am_id" IS 'AM ID，来源 DWM 销售关系';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."cost_reimbursement_base_amt" IS 'Reimbursement 成本计费基数，非港消费金额 * 0.0135';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."cost_service_base_amt" IS 'Card Service 成本计费基数，非港 Consumption/Reversal/Credit 按金额阶梯计算';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."cost_acs_regular_base_amt" IS 'ACS 普通成本计费基数，非港消费按金额阶梯计算';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."cost_acs_vip_base_amt" IS 'ACS VIP 成本计费基数，非港消费且排除特殊码后按金额阶梯计算';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."cost_vrm_base_amt" IS 'VRM 成本计费基数，满足条件笔数 * 0.09';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."rebate_interchange_base_amt" IS 'Interchange 返现计费基数，非港消费金额 * 0.02';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."rebate_incentive_base_amt" IS 'Incentive 返现计费基数，消费金额 * 0.0118';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."cost_reimbursement_rate" IS 'Reimbursement 月度系数，来源 ods_bi_month_tag.QI_COST_REIMBURSEMENT_RATE';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."cost_service_rate" IS 'Card Service 月度系数，来源 ods_bi_month_tag.QI_COST_SERVICE_RATE';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."cost_acs_regular_rate" IS 'ACS 普通月度系数，来源 ods_bi_month_tag.QI_COST_ACS_REGULAR_RATE';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."cost_acs_vip_rate" IS 'ACS VIP 月度系数，来源 ods_bi_month_tag.QI_COST_ACS_VIP_RATE';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."cost_vrm_rate" IS 'VRM 月度系数，来源 ods_bi_month_tag.QI_COST_VRM_RATE';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."rebate_interchange_rate" IS 'Interchange 返现月度系数，来源 ods_bi_month_tag.QI_REBATE_INTERCHANGE_RATE';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."rebate_incentive_rate" IS 'Incentive 返现月度系数，来源 ods_bi_month_tag.QI_REBATE_INCENTIVE_RATE';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."cost_fixed_fee" IS '固定渠道成本分摊金额';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."special_fee_type" IS '特殊费用行类型，普通行为空；CHANNEL_FIXED_FEE=渠道固定成本特殊行';

CREATE INDEX "idx_dws_qi_v2_daily_acc_sale_am" ON "dws"."dws_qi_card_finance_daily_v2_p" USING btree (
  "report_date" "pg_catalog"."date_ops" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE TABLE "dws"."dws_qi_card_finance_daily_v2_2026" PARTITION OF "dws"."dws_qi_card_finance_daily_v2_p"
FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
