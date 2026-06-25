-- 作业元信息：
--   作业类型：DDL建表/视图脚本
--   运行方式：非运行作业
--   运行参数：无
--   源库变更响应：不涉及源库变更同步；用于创建 ADBPG 目标表、分区、索引或视图。
CREATE TABLE "dwm"."dwm_finance_channel_cost_p" (
  "id" int8 NOT NULL,
  "report_date" date NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "account_type" varchar(30) COLLATE "pg_catalog"."default",
  "account_category" varchar(50) COLLATE "pg_catalog"."default",
  "system_type" varchar(64) COLLATE "pg_catalog"."default",
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "product_line" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "provider" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "cost_type" varchar(80) COLLATE "pg_catalog"."default" NOT NULL,
  "source_month" date NOT NULL,
  "source_tag" varchar(80) COLLATE "pg_catalog"."default" NOT NULL,
  "source_amount" numeric(20,4) DEFAULT 0,
  "month_day_count" int4 DEFAULT 0,
  "basis_count" numeric(20,4) DEFAULT 0,
  "month_basis_count" numeric(20,4) DEFAULT 0,
  "basis_amount" numeric(20,4) DEFAULT 0,
  "month_basis_amount" numeric(20,4) DEFAULT 0,
  "allocation_rate" numeric(20,10) DEFAULT 0,
  "cost_amount" numeric(20,4) DEFAULT 0,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dwm_finance_channel_cost_pkey" PRIMARY KEY ("id", "report_date")
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
);


COMMENT ON TABLE "dwm"."dwm_finance_channel_cost_p" IS '金融渠道成本归因明细表，承载量子卡、全球账户、加密账户、收单账户的金融渠道成本';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."id" IS '主键: 日期+账户+产品线+provider+cost_type+source_month+销售+AM业务指纹';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."report_date" IS '成本归属日期-分区键；月度成本按规则展开到当月每日，交易/KYC类成本按业务发生日归属';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."account_id" IS '账户ID';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."account_type" IS '账户类型，来源 dim_account.account_type';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."account_category" IS '账户分类，来源 dim_account.type';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."system_type" IS '系统类型，来源 dim_account.system_type';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."sale_id" IS '销售ID';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."am_id" IS 'AM ID';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."product_line" IS '产品线，如QUANTUM_CARD/GLOBAL_ACCOUNT/CRYPTO_ASSET/ACQUIRING';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."provider" IS '金融渠道方，如BPC/Sumsub/IDEMIA/HZ_BANK/BZ/CL/TZ-wire/TH/Cregis/Safeheron/BS/OD/WP';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."cost_type" IS '成本类型，如ACTIVE_CARD_COST/KYC_FEE/CARD_PRODUCTION_FEE/CONSUME_BANK_FEE/FIXED_FEE/BANK_FEE';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."source_month" IS '来源账单月份，取当月第一天';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."source_tag" IS 'bi_month_tag.tag，如CHANNEL_COST/CARD_CUSTOMIZATION_FEE/OTHER';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."source_amount" IS 'bi_month_tag当月录入总金额';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."month_day_count" IS '当月天数；月度成本按天均摊时参与分摊，事件类成本可为0';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."basis_count" IS '当前客户分摊数量；客户数、KYC次数、实体卡数等';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."month_basis_count" IS '当月总分摊数量';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."basis_amount" IS '当前客户当天分摊金额权重；净消费量等';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."month_basis_amount" IS '当月总分摊金额权重';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."allocation_rate" IS '最终分摊比例，如basis_count/month_basis_count/month_day_count或basis_amount/month_basis_amount';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."cost_amount" IS '已归因到客户和日期的成本金额，source_amount * allocation_rate';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."version" IS '乐观锁版本';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."remarks" IS '备注';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."delete_time" IS '逻辑删除时间';

CREATE INDEX "idx_dwm_finance_channel_cost_acc_sale_am" ON "dwm"."dwm_finance_channel_cost_p" USING btree (
  "report_date" "pg_catalog"."date_ops" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dwm_finance_channel_cost_account_dim" ON "dwm"."dwm_finance_channel_cost_p" USING btree (
  "report_date" "pg_catalog"."date_ops" ASC NULLS LAST,
  "account_type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "account_category" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "system_type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dwm_finance_channel_cost_provider_type" ON "dwm"."dwm_finance_channel_cost_p" USING btree (
  "source_month" "pg_catalog"."date_ops" ASC NULLS LAST,
  "product_line" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "provider" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "cost_type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dwm_finance_channel_cost_source_tag" ON "dwm"."dwm_finance_channel_cost_p" USING btree (
  "source_month" "pg_catalog"."date_ops" ASC NULLS LAST,
  "source_tag" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE TABLE "dwm"."dwm_finance_channel_cost_202601" PARTITION OF "dwm"."dwm_finance_channel_cost_p"
  FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE "dwm"."dwm_finance_channel_cost_202602" PARTITION OF "dwm"."dwm_finance_channel_cost_p"
  FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE "dwm"."dwm_finance_channel_cost_202603" PARTITION OF "dwm"."dwm_finance_channel_cost_p"
  FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE "dwm"."dwm_finance_channel_cost_202604" PARTITION OF "dwm"."dwm_finance_channel_cost_p"
  FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE "dwm"."dwm_finance_channel_cost_202605" PARTITION OF "dwm"."dwm_finance_channel_cost_p"
  FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE "dwm"."dwm_finance_channel_cost_202606" PARTITION OF "dwm"."dwm_finance_channel_cost_p"
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE "dwm"."dwm_finance_channel_cost_202607" PARTITION OF "dwm"."dwm_finance_channel_cost_p"
  FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE "dwm"."dwm_finance_channel_cost_202608" PARTITION OF "dwm"."dwm_finance_channel_cost_p"
  FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE "dwm"."dwm_finance_channel_cost_202609" PARTITION OF "dwm"."dwm_finance_channel_cost_p"
  FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE "dwm"."dwm_finance_channel_cost_202610" PARTITION OF "dwm"."dwm_finance_channel_cost_p"
  FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE "dwm"."dwm_finance_channel_cost_202611" PARTITION OF "dwm"."dwm_finance_channel_cost_p"
  FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE "dwm"."dwm_finance_channel_cost_202612" PARTITION OF "dwm"."dwm_finance_channel_cost_p"
  FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
