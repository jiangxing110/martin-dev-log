-- 总渠道成本 DWS 汇总表 V2
--   用途：承接 dws_online_total_channel_cost_daily_v3-batch-sql.sql 的试算结果。
--   说明：V2 表不替换老表 dws_total_channel_cost_daily_p，先独立落地用于核对数据。
--   口径：acquiring/business/quantum/crypto 四类成本按日、账户、销售、AM 汇总。

CREATE TABLE "dws"."dws_total_channel_cost_daily_v2_p" (
  "id" int8 NOT NULL,
  "report_date" date NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
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
  CONSTRAINT "dws_total_channel_cost_daily_v2_pkey" PRIMARY KEY ("id", "report_date")
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
);

COMMENT ON TABLE "dws"."dws_total_channel_cost_daily_v2_p" IS '总渠道成本 DWS 汇总表 V2，用于承接 v3 试算结果';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_v2_p"."id" IS '唯一标识: 报表日期+账户+销售+AM 指纹';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_v2_p"."report_date" IS '报表日期';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_v2_p"."account_id" IS '账户ID';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_v2_p"."sale_id" IS '销售ID';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_v2_p"."am_id" IS 'AM ID';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_v2_p"."acquiring_cost" IS '收单渠道成本';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_v2_p"."business_cost" IS '全球账户/业务渠道成本';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_v2_p"."quantum_cost" IS '量子卡渠道成本，包含 BB/QI/SL 和金融渠道 QUANTUM_CARD';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_v2_p"."crypto_cost" IS '加密资产渠道成本';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_v2_p"."total_channel_cost" IS '总渠道成本';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_v2_p"."version" IS '版本号';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_v2_p"."remarks" IS '备注';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_v2_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_v2_p"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "dws"."dws_total_channel_cost_daily_v2_p"."delete_time" IS '逻辑删除时间';

CREATE INDEX "idx_dws_total_channel_cost_v2_acc_sale_am" ON "dws"."dws_total_channel_cost_daily_v2_p" USING btree (
  "report_date" "pg_catalog"."date_ops" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE TABLE "dws"."dws_total_channel_cost_daily_v2_2026" PARTITION OF "dws"."dws_total_channel_cost_daily_v2_p"
FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

CREATE TABLE "dws"."dws_total_channel_cost_daily_v2_2025_12" PARTITION OF "dws"."dws_total_channel_cost_daily_v2_p"
FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
