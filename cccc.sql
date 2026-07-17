/Users/martinjiang/martin-dev-log/bi-cost/flink/total_cost/dws_online_total_channel_cost_daily_v2-batch-sql.sql
还是回到这个来啊 
quantum_cost= BB+QI+SL成本+sqlB(QUANTUM_CARD)
acquiring_cost= sqlB:(ACQUIRING )
crypto_cost= sqlB:(CRYPTO_ASSET)
business_cost= sqlB:(GLOBAL_ACCOUNT)
SELECT 
sum(acquiring_cost) acquiring_cost,
sum(business_cost) business_cost,
sum(quantum_cost) quantum_cost, 
sum(crypto_cost) crypto_cost
FROM dws.dws_total_channel_cost_daily_2026
WHERE report_date>='2026-05-01 00:00:00'
and report_date<'2026-06-01 00:00:00'

0.0000	3420.5673	945812.9840	3506.3015


sqlB:
SELECT 
product_line,
sum(cost_amount)
FROM dwm_finance_channel_cost_p
WHERE report_date>='2026-05-01 00:00:00'
and report_date<'2026-06-01 00:00:00'
GROUP BY product_line



65633.4722	117500.3517	11605.9620	1069431.7529


BB:458686
QI:630568
LS:267

其他固定:42485

Safeheron	2500
TZ-wire	4599
BS	2619

BS	2618.9931
TZ-wire	9198.0050