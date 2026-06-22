CREATE TABLE "dws"."dws_gross_profit_daily_p" (
  "id" int8 NOT NULL,
  "report_date" date NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "account_type" varchar(30) COLLATE "pg_catalog"."default",
  "account_category" varchar(50) COLLATE "pg_catalog"."default",
  "system_type" varchar(64) COLLATE "pg_catalog"."default",
  "category" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "revenue_amount" numeric(20,4) DEFAULT 0,
  "channel_cost_amount" numeric(20,4) DEFAULT 0,
  "gross_profit_amount" numeric(20,4) DEFAULT 0,
  "gross_margin" numeric(20,8) DEFAULT 0,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_gross_profit_daily_pkey" PRIMARY KEY ("id", "report_date")
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
);

ALTER TABLE "dws"."dws_gross_profit_daily_p"
  OWNER TO "qbit_admin";

COMMENT ON TABLE "dws"."dws_gross_profit_daily_p" IS '客户产品线毛利日汇总表';
COMMENT ON COLUMN "dws"."dws_gross_profit_daily_p"."id" IS '主键: 日期+账户+产品线业务指纹';
COMMENT ON COLUMN "dws"."dws_gross_profit_daily_p"."report_date" IS '报表日期-分区键';
COMMENT ON COLUMN "dws"."dws_gross_profit_daily_p"."account_id" IS '账户ID';
COMMENT ON COLUMN "dws"."dws_gross_profit_daily_p"."account_type" IS '账户类型，来源收入输入或dim_account.account_type';
COMMENT ON COLUMN "dws"."dws_gross_profit_daily_p"."account_category" IS '账户分类，来源收入输入或dim_account.type';
COMMENT ON COLUMN "dws"."dws_gross_profit_daily_p"."system_type" IS '系统类型，来源收入输入或dim_account.system_type';
COMMENT ON COLUMN "dws"."dws_gross_profit_daily_p"."category" IS '收入产品线分类，如qbit_card/global_account/crypto_assets';
COMMENT ON COLUMN "dws"."dws_gross_profit_daily_p"."revenue_amount" IS '产品线收入金额';
COMMENT ON COLUMN "dws"."dws_gross_profit_daily_p"."channel_cost_amount" IS '产品线对应渠道成本金额';
COMMENT ON COLUMN "dws"."dws_gross_profit_daily_p"."gross_profit_amount" IS '毛利金额=收入-渠道成本';
COMMENT ON COLUMN "dws"."dws_gross_profit_daily_p"."gross_margin" IS '毛利率=毛利/收入';
COMMENT ON COLUMN "dws"."dws_gross_profit_daily_p"."version" IS '乐观锁版本';
COMMENT ON COLUMN "dws"."dws_gross_profit_daily_p"."remarks" IS '备注';
COMMENT ON COLUMN "dws"."dws_gross_profit_daily_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dws"."dws_gross_profit_daily_p"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "dws"."dws_gross_profit_daily_p"."delete_time" IS '逻辑删除时间';

CREATE INDEX "idx_dws_gross_profit_acc_category" ON "dws"."dws_gross_profit_daily_p" USING btree (
  "report_date" "pg_catalog"."date_ops" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "category" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dws_gross_profit_account_dim" ON "dws"."dws_gross_profit_daily_p" USING btree (
  "report_date" "pg_catalog"."date_ops" ASC NULLS LAST,
  "account_type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "account_category" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "system_type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE TABLE "dws"."dws_gross_profit_daily_2026" PARTITION OF "dws"."dws_gross_profit_daily_p"
FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
