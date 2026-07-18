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
FROM dws.dws_total_channel_cost_daily_v2_p
WHERE report_date>='2026-05-01 00:00:00'
and report_date<'2026-06-01 00:00:00'
69376.0002	120726.1301	1131706.9998	11816.9981



select sum(channel_cost_amount) from dws.mv_gross_profit_daily
WHERE report_date>='2026-05-01 00:00:00'
and report_date<'2026-06-01 00:00:00'


select sum(channel_cost_amount) from dws.dws_gross_profit_daily_p
WHERE report_date>='2026-05-01 00:00:00'
and report_date<'2026-06-01 00:00:00'


{
    "code": 200,
    "message": "success",
    "data": [
        {
            "category": "qbit_card",
            "categoryName": "Card",
            "revenueAmount": 2219546.7466,
            "grossProfitAmount": 1040348.2325,
            "cogsAmount": 1179198.5141
        },
        {
            "category": "crypto_assets",
            "categoryName": "crypto",
            "revenueAmount": 395623.1508,
            "grossProfitAmount": 385904.5377,
            "cogsAmount": 9718.6131
        },
        {
            "category": "global_account",
            "categoryName": "Global Account",
            "revenueAmount": 9057.4000,
            "grossProfitAmount": -111668.7301,
            "cogsAmount": 120726.1301
        }
    ]
}