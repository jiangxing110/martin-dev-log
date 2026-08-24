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





dashboard全局更新
1.线下实体卡制卡费 OFFLINE_PHYSICAL_CARD_FEE("OFFLINE_PHYSICAL_CARD_FEE", "线下实体卡制卡费"),
这个
有效收入视图
/Users/martinjiang/VsCodeProjects/martin-dev-log/bi-cost/online/incremental-view/dws_effective_revenue_daily_mv.sql
收入视图
/Users/martinjiang/VsCodeProjects/martin-dev-log/bi-cost/online/incremental-view/dws_revenue_summary_daily_mv_from_revenue_daily.sql
现在需要把线下实体卡制卡费加入到这两个视图里
属于
category类型card
revenue_source类型offline_physical_card_fee

你可以最后给我可以每个给一个v2版本