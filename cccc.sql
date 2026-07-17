量子卡渠道成本
QI:688723.4120
BB:458656.9513
LS:267.0507

SELECT product_line,sum(cost_amount) FROM dwm.dwm_finance_channel_cost_p 
WHERE report_date>='2026-05-01 00:00:00'
and report_date<'2026-06-01 00:00:00'
GROUP BY product_line

GLOBAL_ACCOUNT	120726.1301
ACQUIRING	69376.0002
QUANTUM_CARD	31551.0772
CRYPTO_ASSET	9718.6131

SELECT 
sum(acquiring_cost) acquiring_cost,
sum(business_cost) business_cost,
sum(quantum_cost) quantum_cost, 
sum(crypto_cost) crypto_cost
FROM dws.dws_total_channel_cost_daily_2026
WHERE report_date>='2026-05-01 00:00:00'
and report_date<'2026-06-01 00:00:00'
69376.0002	120726.1301	1131706.9998	11816.9981