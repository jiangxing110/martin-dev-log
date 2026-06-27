-- 作业元信息：
--   作业类型：DDL建表/视图脚本
--   运行方式：非运行作业
--   运行参数：无
--   源库变更响应：不涉及源库变更同步；用于创建 ADBPG 目标表、分区、索引或视图。
CREATE TABLE "dws"."dws_total_channel_cost_daily_p" (
  "id" int8 NOT NULL,
  "report_date" date NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "account_type" varchar(30) COLLATE "pg_catalog"."default",
  "account_category" varchar(50) COLLATE "pg_catalog"."default",
  "system_type" varchar(64) COLLATE "pg_catalog"."default",
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "acquiring_cost" numeric(20,4) DEFAULT 0,
  "business_cost" numeric(20,4) DEFAULT 0,
  "quantum_cost" numeric(20,4) DEFAULT 0,
  "crypto_cost" numeric(20,4) DEFAULT 0,
  "total_channel_cost" numeric(20,4) DEFAULT 0,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_total_channel_cost_daily_pkey" PRIMARY KEY ("id", "report_date")
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
);



COMMENT ON TABLE "dws"."dws_total_channel_cost_daily_p" IS '客户总渠道成本日汇总表';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_p"."id" IS '主键: 日期+账户+销售+AM业务指纹';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_p"."report_date" IS '报表日期-分区键';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_p"."account_id" IS '账户ID';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_p"."account_type" IS '账户类型，来源 dim_account.account_type';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_p"."account_category" IS '账户分类，来源 dim_account.type';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_p"."system_type" IS '系统类型，来源 dim_account.system_type';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_p"."sale_id" IS '销售ID';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_p"."am_id" IS 'AM ID';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_p"."acquiring_cost" IS '收单渠道成本';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_p"."business_cost" IS '业务渠道成本';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_p"."quantum_cost" IS '量子卡渠道成本';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_p"."crypto_cost" IS '加密渠道成本';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_p"."total_channel_cost" IS '总渠道成本';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_p"."version" IS '乐观锁版本';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_p"."remarks" IS '备注';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_p"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_p"."delete_time" IS '逻辑删除时间';

CREATE INDEX "idx_dws_total_channel_cost_acc_sale_am" ON "dws"."dws_total_channel_cost_daily_p" USING btree (
  "report_date" "pg_catalog"."date_ops" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dws_total_channel_cost_account_dim" ON "dws"."dws_total_channel_cost_daily_p" USING btree (
  "report_date" "pg_catalog"."date_ops" ASC NULLS LAST,
  "account_type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "account_category" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "system_type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE TABLE "dws"."dws_total_channel_cost_daily_2026" PARTITION OF "dws"."dws_total_channel_cost_daily_p"
FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE "dws"."dws_total_channel_cost_daily_2025_12" PARTITION OF "dws"."dws_total_channel_cost_daily_p"
FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
