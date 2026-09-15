这里都是QI的
FX_Cross费用收入：62332
Settlement_Auth_Fee收入：20665
其他费用收入：18068
之前月账单_QI汇总：22749.34
量子卡Cashback ： 119805.05829692

成本
QI成本：121958.75750463
返现：3595.94
代收：33524.25

SELECT
r.*
FROM dws.dws_metrics_sales_revenue_monthly r
WHERE r.settlement_month = DATE '2026-08-01'
and r.root_account_id= '2cef54b6-51c9-47c8-a56a-66934cbfd619'
收入 
94806.520
渠道返现
119728.157676280000
成本
121986.903946050000   

select metric_code, product, provider , count(1) ct, sum(income_value) incone
from dws.dws_metrics_sales_revenue_monthly
where report_date BETWEEN  '2026-08-01' and '2026-08-31'
and root_account_id='2cef54b6-51c9-47c8-a56a-66934cbfd619'
group by metric_code, product, provider
 order by product  , metric_code;

assets_acceptance_fee_gt_zero	crypto_connect		1	3797237.080
crypto_connect_income	crypto_connect		1	7600.000
main	crypto_connect		1	7600.000
month_receivable	open_api		1	21736.040
month_revenue	open_api	BB	1	0.240
month_revenue	open_api	IQ	1	22749.340
month_revenue	open_api		1	0.000
main	qbit_card	BB	1	0.000
main	qbit_card	BZ	1	0.000
main	qbit_card	IQ	1	94806.520
main	qbit_card	PC	1	0.000
main	qbit_card		1	0.000
physical_card_cost	qbit_card	BB	1	0.000
physical_card_cost	qbit_card	BZ	1	0.000
physical_card_cost	qbit_card	IQ	1	0.000
physical_card_cost	qbit_card	PC	1	0.000
physical_card_cost	qbit_card		1	0.000
qbit_account_recharge_fee	qbit_card	BB	1	0.000
qbit_account_recharge_fee	qbit_card	BZ	1	0.000
qbit_account_recharge_fee	qbit_card	IQ	1	0.000
qbit_account_recharge_fee	qbit_card	PC	1	0.000
qbit_card_collection_fee	qbit_card	IQ	1	32279.180
qbit_card_main_fee	qbit_card	IQ	1	94806.520
virtual_card_create_fee_amount	qbit_card		1	0.000

我想问month_revenue	open_api	BB	1	0.240
month_revenue	open_api	IQ	1	22749.340
month_revenue	open_api		1	0.000
sql1:
crypto	2026-03-01		current_payout		240.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-03-01		current_payout	BB	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-03-01		current_payout	BZ	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-03-01		current_payout	IQ	1703.5375	2026-09-15 18:14:02.096068+08
qbit_card	2026-03-01		current_payout	LS	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-03-01		current_payout	NM	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-03-01		current_payout		0.0000	2026-09-15 18:14:02.096068+08
crypto	2026-04-01		current_payout		390.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-04-01		current_payout	BB	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-04-01		current_payout	BZ	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-04-01		current_payout	IQ	4703.2270	2026-09-15 18:14:02.096068+08
qbit_card	2026-04-01		current_payout	LS	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-04-01		current_payout	NM	0.0000	2026-09-15 18:14:02.096068+08
crypto	2026-05-01		current_payout		6240.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-05-01		current_payout	BB	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-05-01		current_payout	BZ	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-05-01		current_payout	IQ	152411.9824	2026-09-15 18:14:02.096068+08
qbit_card	2026-05-01		current_payout	LS	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-05-01		current_payout	NM	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-05-01		current_payout	PC	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-05-01		current_payout	RP	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-05-01		current_payout		0.0000	2026-09-15 18:14:02.096068+08
crypto	2026-06-01		current_payout		12741.6500	2026-09-15 18:14:02.096068+08
qbit_card	2026-06-01		current_payout	BB	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-06-01		current_payout	BZ	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-06-01		current_payout	IQ	349329.1572	2026-09-15 18:14:02.096068+08
qbit_card	2026-06-01		current_payout	LS	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-06-01		current_payout	NM	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-06-01		current_payout	PC	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-06-01		current_payout		0.0000	2026-09-15 18:14:02.096068+08
crypto	2026-07-01		current_payout		9358.3900	2026-09-15 18:14:02.096068+08
qbit_card	2026-07-01		current_payout	BB	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-07-01		current_payout	BZ	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-07-01		current_payout	IQ	271507.7459	2026-09-15 18:14:02.096068+08
qbit_card	2026-07-01		current_payout	LS	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-07-01		current_payout	PC	0.0000	2026-09-15 18:14:02.096068+08
crypto	2026-08-01		current_payout		7600.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-08-01		current_payout	BB	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-08-01		current_payout	BZ	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-08-01		current_payout	IQ	214534.6777	2026-09-15 18:14:02.096068+08
qbit_card	2026-08-01		current_payout	PC	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-08-01		current_payout		0.0000	2026-09-15 18:14:02.096068+08
crypto	2026-09-01		current_payout		600.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-09-01		current_payout	BB	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-09-01		current_payout	BZ	0.0000	2026-09-15 18:14:02.096068+08
qbit_card	2026-09-01		current_payout	IQ	41562.1296	2026-09-15 18:14:02.096068+08
qbit_card	2026-09-01		current_payout	PC	0.0000	2026-09-15 18:14:02.096068+08

sql2:
2026-08-01	2026-07-01	2cef54b6-51c9-47c8-a56a-66934cbfd619	month_revenue	open_api		0.000	
2026-08-01	2026-07-01	2cef54b6-51c9-47c8-a56a-66934cbfd619	month_revenue	open_api	BB	0.240	
2026-08-01	2026-07-01	2cef54b6-51c9-47c8-a56a-66934cbfd619	month_revenue	open_api	IQ	22749.340	