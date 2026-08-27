// dashboard全局更新
1.线下实体卡制卡费 OFFLINE_PHYSICAL_CARD_FEE("OFFLINE_PHYSICAL_CARD_FEE", "线下实体卡制卡费"),
2.结汇成本 SETTLEMENT_COST("SETTLEMENT_COST", "结汇成本")在金融渠道成本更新


实际在数据库表中插入的应该是account.id，以此获取用户维度数据关联其他模块
指标新增:
全球账户->结汇成本 SETTLEMENT_COST("SETTLEMENT_COST", "结汇成本"),
        线下退款 OFFLINE_REFUND("OFFLINE_REFUND", "线下退款"),
量子卡-> 线下API客户一次性收入 OFFLINE_API_INCOME("OFFLINE_API_INCOME", "线下API客户一次性收入"),
        线下实体卡制卡费 OFFLINE_PHYSICAL_CARD_FEE("OFFLINE_PHYSICAL_CARD_FEE", "线下实体卡制卡费"),
        返现调整减少 CASHBACK_ADJUSTMENT_DECREASE("CASHBACK_ADJUSTMENT_DECREASE", "返现调整减少"),
        返现调整增加 CASHBACK_ADJUSTMENT_INCREASE("CASHBACK_ADJUSTMENT_INCREASE", "返现调整增加"),
        线下退款 OFFLINE_REFUND("OFFLINE_REFUND", "线下退款"),
        收入调整减少 INCOME_ADJUSTMENT_DECREASE("INCOME_ADJUSTMENT_DECREASE", "收入调整减少"),
        收入调整增加 INCOME_ADJUSTMENT_INCREASE("INCOME_ADJUSTMENT_INCREASE", "收入调整增加"),
        API客户低消调整减少API_MINIMUM_CONSUMPTION_ADJUSTMENT_DECREASE("API_MINIMUM_CONSUMPTION_ADJUSTMENT_DECREASE", "API客户低消调整减少"),

加密资产-> 线下退款 OFFLINE_REFUND("OFFLINE_REFUND", "线下退款")

// SaleCommision全局更新
1.全球账户->结汇成本 SETTLEMENT_COST("SETTLEMENT_COST", "结汇成本"),
全球账户付款手续费成本- 结汇由bi_month_tag表（枚举由其他任务更新），根据结汇金额均摊
SELECT "accountId",sum("usdAmount") FROM transfer 
WHERE "deleteTime" is null AND status='Closed'
and "settlementCurrency"='CNY' AND "transferType"='Settle'
AND "transactionTime">='2026-07-01 00:00:00'
AND "transactionTime"<'2026-08-01 00:00:00'
GROUP BY "accountId"

其他付款交易成本根据统一付款表payment_transaction_record 中的extra->'fee_cost'获取
SELECT *
FROM payment_transaction_record
WHERE COALESCE(NULLIF(extra->>'fee_cost', '')::NUMERIC, 0) > 0;

线下退款:成本
结汇成本:在金融渠道成本更新
线下API客户一次性收入,线下实体卡制卡费:收入
返现调整减少,返现调整增加:用于计算后补的返现记录或者直接走财务流程的返现记录
收入调整减少,收入调整增加:收入
并更新到SaleCommision统计逻辑中

/Users/martinjiang/VsCodeProjects/martin-dev-log/sale-repoet/sales-commission/table-scripts/mv_sales_commission_recent_estimate.sql
1.现在的销售返佣的视图本次需求mv_sales_commission_recent_estimate_v2.sql
2.
收入  这个增加 就是+ 减少就是-
返现 这个增加 就是+ 减少就是-
3.payment_transaction_record这个量子卡成本我不确定是建一个dwm的表还是直接查询因为生产数据很少看了一下只有几千条全表
后续爆发的可能也很小上线两年了


CREATE TABLE "ods"."ods_bi_month_tag" (
  "id" int8 NOT NULL,
  "create_time" timestamptz(6) NOT NULL,
  "update_time" timestamptz(6) NOT NULL,
  "delete_time" timestamptz(6),
  "version" int4 NOT NULL DEFAULT 1,
  "tag" varchar(255) COLLATE "pg_catalog"."default",
  "statistics_time" timestamptz(6),
  "amount" numeric DEFAULT 0,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "detail" varchar(255) COLLATE "pg_catalog"."default",
  "account_type" varchar(255) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'fullCustomer'::character varying,
  "provider" varchar(255) COLLATE "pg_catalog"."default",
  "product_line" varchar(255) COLLATE "pg_catalog"."default",
  "account_id" varchar(50) COLLATE "pg_catalog"."default",
  CONSTRAINT "ods_bi_month_tag_pkey" PRIMARY KEY ("id")
)
;

ALTER TABLE "ods"."ods_bi_month_tag" 
  OWNER TO "qbit_admin";

CREATE INDEX "idx_ods_bi_month_tag_account_id" ON "ods"."ods_bi_month_tag" USING btree (
  "account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."id" IS '主键';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."create_time" IS '创建时间';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."update_time" IS '数据更新时间';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."delete_time" IS '删除时间';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."version" IS '乐观锁';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."tag" IS '记录标签';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."statistics_time" IS '统计月份';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."amount" IS '金额';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."detail" IS '统计月份';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."account_type" IS '账号类型';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."provider" IS '渠道';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."product_line" IS '产品线';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."account_id" IS '客户ID，关联account表的id字段';

COMMENT ON TABLE "ods"."ods_bi_month_tag" IS 'PG业务表bi_month_tag同步ODS层表';

我们本迭代新增了account_id
dashboard全局更新
1.线下实体卡制卡费 OFFLINE_PHYSICAL_CARD_FEE("OFFLINE_PHYSICAL_CARD_FEE", "线下实体卡制卡费"),
  收入调整减少 INCOME_ADJUSTMENT_DECREASE("INCOME_ADJUSTMENT_DECREASE", "收入调整减少"),
  收入调整增加 INCOME_ADJUSTMENT_INCREASE("INCOME_ADJUSTMENT_INCREASE", "收入调整增加"),
  API客户低消调整减少API_MINIMUM_CONSUMPTION_ADJUSTMENT_DECREASE("API_MINIMUM_CONSUMPTION_ADJUSTMENT_DECREASE", "API客户低消调整减少"),
这个
收入视图/Users/martinjiang/VsCodeProjects/martin-dev-log/bi-cost/online/incremental-view/dws_revenue_summary_daily_mv_from_revenue_daily.sql
现在需要把线下实体卡制卡费加入到这两个视图里
属于
category类型card revenue_source类型
offline_physical_card_fee
income_adjustment_decrease
income_adjustment_increase
api_minimum_consumption_adjustment_decrease

然后看看
/Users/martinjiang/VsCodeProjects/martin-dev-log/sale-repoet/sales-commission/table-scripts/mv_sales_commission_recent_estimate_v2.sql
收入调整减少 INCOME_ADJUSTMENT_DECREASE("INCOME_ADJUSTMENT_DECREASE", "收入调整减少"),
  收入调整增加 INCOME_ADJUSTMENT_INCREASE("INCOME_ADJUSTMENT_INCREASE", "收入调整增加"),
  这个之前已经加了 现在要加API客户低消调整减少这部分
  先检查一下告诉我怎么改

mv_sales_commission_recent_estimate 这个视图里也是记录 provider 
量子卡相关的主要是   IQ BB BZ LS 
我们这些枚举都是量子卡 的