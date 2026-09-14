--查询加密收入
SELECT
    sale_id,
    department_id,
    COUNT(*) AS mv_rows,
    SUM(effective_revenue) AS mv_income
FROM dws.mv_sales_commission_recent_estimate
WHERE settlement_month = DATE '2026-08-01'
  AND product = 'crypto'
  AND sale_id = '269ce892-8728-4954-bb05-613163dbd142'
GROUP BY sale_id, department_id;

--查询可用收入分布
SELECT
    CASE
        WHEN a.crypto_active_time IS NULL
            THEN '加密激活时间为空'
        WHEN r.settlement_month - a.crypto_active_time::date
             BETWEEN 0 AND 1095
            THEN '可匹配规则'
        ELSE '活跃天数超范围或为负数'
    END AS match_status,
    COUNT(*) AS row_count,
    SUM(r.income_value) AS income_value
FROM dws.dws_metrics_sales_revenue_monthly r
LEFT JOIN dim.dim_account_analysis a
    ON a.account_id = r.root_account_id
   AND a.delete_time IS NULL
WHERE r.settlement_month = DATE '2026-08-01'
  AND r.product = 'crypto_connect'
  AND r.metric_code = 'main'
  AND r.delete_time IS NULL
  AND COALESCE(r.sale_id, r.am_id)
      = '269ce892-8728-4954-bb05-613163dbd142'
GROUP BY 1
ORDER BY 1;


加密激活时间为空(累计 sell 金额首次超过 20 万美元的那笔交易时间)	19	4840.240
可匹配规则	16	12986.050
活跃天数超范围或为负数	3	2080.098


