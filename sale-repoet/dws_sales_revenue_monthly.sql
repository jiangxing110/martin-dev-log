CREATE TABLE "dws"."dws_sales_revenue_monthly" (
  "root_account_id" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "report_date" date NOT NULL,
  "settlement_month" date NOT NULL,
  "product" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "metric_code" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "provider" varchar(255) COLLATE "pg_catalog"."default" NOT NULL,
  "sale_id" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "sale_department" varchar(100) COLLATE "pg_catalog"."default" NOT NULL,
  "operation_manager_id" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "am_id" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "income_value" numeric(20,3) NOT NULL,
  "real_income_value" numeric(20,3),
  "loaded_at" timestamp(6) NOT NULL,
  "version" int4 NOT NULL DEFAULT 1,
  "remarks" varchar(2000) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "update_time" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "delete_time" timestamp(6),
  CONSTRAINT "dws_sales_revenue_monthly_pkey" PRIMARY KEY (
    "root_account_id",
    "report_date",
    "settlement_month",
    "product",
    "metric_code",
    "provider",
    "sale_id",
    "sale_department",
    "operation_manager_id",
    "am_id"
  )
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
);

CREATE TABLE "dws"."dws_sales_revenue_monthly_2026" PARTITION OF "dws"."dws_sales_revenue_monthly"
FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

COMMENT ON TABLE "dws"."dws_sales_revenue_monthly" IS '销售收入月度汇总表-按年分区';

COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."root_account_id" IS '根账户ID';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."report_date" IS '报表日期-分区键';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."settlement_month" IS '结算月份';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."product" IS '产品';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."metric_code" IS '指标编码';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."provider" IS '服务商';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."sale_id" IS '销售ID';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."sale_department" IS '销售部门';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."operation_manager_id" IS '运营经理ID';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."am_id" IS '客户经理ID';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."income_value" IS '收入金额';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."real_income_value" IS '实际收入金额';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."loaded_at" IS '数据加载时间';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."version" IS '版本号';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."remarks" IS '备注';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."delete_time" IS '逻辑删除时间';
