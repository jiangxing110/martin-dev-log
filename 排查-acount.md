select  sum(effective_revenue) , sum(cogs) , sum(gp)  from dws.mv_sales_commission_recent_estimate 
where settlement_month='2026-08-01'
and product ='qbit_card'
and root_account_id='2cef54b6-51c9-47c8-a56a-66934cbfd619'

95676.4400	0.0000	95676.4400
95676.4400	113516.9291	0.0000

排查成本是0 

dws_metrics_sales_revenue_monthly.income_value+渠道返现- 客户返现