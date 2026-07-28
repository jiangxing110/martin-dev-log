CREATE TABLE "dws"."dws_sales_revenue_monthly" (

  "root_account_id" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "create_date" date NOT NULL,
  "settlement_month" date NOT NULL,
  "product" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "metric_code" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "provider" varchar(255) COLLATE "pg_catalog"."default" NOT NULL,
  "sale_id" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "sale_department" varchar(100) COLLATE "pg_catalog"."default" NOT NULL,
  "operation_manager_id" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "am_id" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "income_value" numeric(20,3) NOT NULL,
  "loaded_at" timestamp(6) NOT NULL,
  "real_income_value" numeric(20,3),
  CONSTRAINT "dws_sales_revenue_monthly_pkey" PRIMARY KEY ("root_account_id", "create_date", "settlement_month", "product", "metric_code", "provider", "sale_id", "sale_department", "operation_manager_id", "am_id")
)
;
 "id" int8 NOT NULL,

COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."report_date" IS '报表日期，来源 transaction_time 日期';

COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."version" IS '版本号';

COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."remarks" IS '备注';

COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."create_time" IS '记录创建时间';

COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."update_time" IS '记录更新时间';

COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."delete_time" IS '逻辑删除时间';

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



SELECT
    COALESCE(aar.root_id::text, qi.account_id::text) AS account_id,
		qi.sale_id,
		qi.am_id
FROM dws_qi_card_finance_daily_v2_p AS qi
LEFT JOIN api_account_relation AS aar
    ON aar.account_id::VARCHAR = qi.account_id
GROUP BY COALESCE(aar.root_id::text, qi.account_id::text),	qi.sale_id,
		qi.am_id;

我想要mock一批数据这里大概有375条account_id 数据=root_account_id  
report_date :2026-05-02 ,2026-05-15,2026-05-30 ,2026-05-30,
             2026-06-02

"income_value" numeric(20,3) NOT NULL,
 30-500

"real_income_value" numeric(20,3),
 30-500
 这两个值相同