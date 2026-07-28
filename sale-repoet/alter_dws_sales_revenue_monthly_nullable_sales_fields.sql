ALTER TABLE "dws"."dws_sales_revenue_monthly"
  ALTER COLUMN "sale_department" DROP NOT NULL,
  ALTER COLUMN "operation_manager_id" DROP NOT NULL,
  ALTER COLUMN "am_id" DROP NOT NULL;
