-- 作业元信息：
--   作业类型：DDL建表/视图脚本
--   运行方式：非运行作业
--   运行参数：无
--   源库变更响应：不涉及源库变更同步；用于创建 ADBPG 目标表、分区、索引或视图。
CREATE TABLE "dws"."dws_qi_card_finance_daily_p" (
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
  "cost_reimbursement_vol" numeric(20,4) DEFAULT 0,
  "cost_service_vol" numeric(20,4) DEFAULT 0,
  "cost_acs_regular_count" int4 DEFAULT 0,
  "cost_acs_vip_count" int4 DEFAULT 0,
  "cost_vrm_count" int4 DEFAULT 0,
  "rebate_interchange_vol" numeric(20,4) DEFAULT 0,
  "rebate_incentive_vol" numeric(20,4) DEFAULT 0,
  "cost_fixed_fee" numeric(20,4) DEFAULT 0,
  CONSTRAINT "dws_qi_daily_pkey" PRIMARY KEY ("id", "report_date")
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
);

ALTER TABLE "dws"."dws_qi_card_finance_daily_p"
  OWNER TO "qbit_admin";

COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."id" IS '唯一标识: 日期+账户+销售+AM业务指纹';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."report_date" IS '报表日期-分区键';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."account_id" IS '账户ID';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."account_type" IS '账户类型，来源 dim_account.account_type';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."account_category" IS '账户分类，来源 dim_account.type';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."system_type" IS '系统类型，来源 dim_account.system_type';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."version" IS '乐观锁版本';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."remarks" IS '备注';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."delete_time" IS '逻辑删除时间';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."sale_id" IS '销售ID';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."am_id" IS 'AM ID';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."cost_reimbursement_vol" IS 'Reimbursement费用基数(非港净消费额)';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."cost_service_vol" IS 'Service Fee费用基数(非港净消费额)';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."cost_acs_regular_count" IS 'ACS普通笔数';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."cost_acs_vip_count" IS 'ACS VIP笔数';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."cost_vrm_count" IS 'VRM验证笔数';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."rebate_interchange_vol" IS 'Interchange返现基数(全球净消费额)';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."rebate_incentive_vol" IS 'Incentive返现基数(全球净消费额)';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."cost_fixed_fee" IS '固定渠道成本分摊金额';
COMMENT ON TABLE "dws"."dws_qi_card_finance_daily_p" IS 'QI渠道财务汇总日表-按年分区';

CREATE INDEX "idx_dws_qi_daily_acc_sale_am" ON "dws"."dws_qi_card_finance_daily_p" USING btree (
  "report_date" "pg_catalog"."date_ops" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dws_qi_account_dim" ON "dws"."dws_qi_card_finance_daily_p" USING btree (
  "report_date" "pg_catalog"."date_ops" ASC NULLS LAST,
  "account_type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "account_category" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "system_type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE TABLE "dws"."dws_qi_daily_2026" PARTITION OF "dws"."dws_qi_card_finance_daily_p"
FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
