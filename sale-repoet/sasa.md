CREATE TABLE "dws"."dws_sales_revenue_monthly" (
  "root_account_id" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "report_date" date NOT NULL,
  "settlement_month" date NOT NULL,
  "product" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "metric_code" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "provider" varchar(255) COLLATE "pg_catalog"."default" NOT NULL,
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "sale_department" varchar(100) COLLATE "pg_catalog"."default",
  "operation_manager_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
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
    "provider"
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


product:
crypto
treasury
qbit_card
group_account

open_api

provider:
qbit_card: BB QI PC SL BZ
group_account:BZ CL

metric_code:
main(默认这个汇总)

open_api:
month_receivable
month_revenue

qbit_card:
physical_card_cost

crypto:
assets_acceptance_fee_gt_zero
assets_acceptance_fee_eq_zero


上面的收入表 dws_sales_revenue_monthly
成本表
1.金融渠道成本记录 全球账户
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
)

'GLOBAL_ACCOUNT' AS product_line,
'BZ|CL' AS provider,

成本加密
crypto 
assets_acceptance_fee_gt_zero*0.09%
assets_acceptance_fee_eq_zero*0.09%

量子卡成本
/Users/martinjiang/VsCodeProjects/martin-dev-log/bi-cost/flink/total_cost/dws_online_total_channel_cost_daily_v3-batch-sql.sql
BB QI

但是注意 dwm_finance_channel_cost_p 和 dws_sales_revenue_monthly都是精确到最底层account的 我们现在的维度要到root_account_id

SELECT aar.root_id,qi.account_id FROM dws_qi_card_finance_daily_v2_p as qi LEFT JOIN api_account_relation as aar ON aar.account_id=qi.account_id 这个表qi 里的数据有可能在aar 里有数据那就要 返回aar.root_id 不然就是qi.account_id
