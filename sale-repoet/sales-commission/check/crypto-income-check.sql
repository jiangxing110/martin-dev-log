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






SELECT
*
FROM dws.dws_metrics_sales_revenue_monthly 
WHERE root_account_id ='95d362d7-56fe-4f50-82cb-f97a51afc263'
and product='crypto_connect'
and settlement_month='2026-08-01'
d3688bd186583ff2228e355062523e96	95d362d7-56fe-4f50-82cb-f97a51afc263	2026-08-01	2026-08-01	crypto_connect	crypto_connect_income		cfd8b2a8-af2d-474a-9923-3a5ef0335f52	7ba5aa24-bfb8-424b-84f9-d8cc067b8e6e	0.000	2026-09-04 15:23:33.553	1	source=global_crypto_dwm_daily;route=account_to_monthly;business_version=v1	2026-09-04 15:23:33.553	2026-09-04 15:23:33.553		income
78913e68cbe83fd5c1cf6b57f0a01ad7	95d362d7-56fe-4f50-82cb-f97a51afc263	2026-08-01	2026-08-01	crypto_connect	main		cfd8b2a8-af2d-474a-9923-3a5ef0335f52	7ba5aa24-bfb8-424b-84f9-d8cc067b8e6e	0.000	2026-09-04 15:23:33.553	1	source=global_crypto_dwm_daily;route=account_to_monthly;business_version=v1	2026-09-04 15:23:33.553	2026-09-04 15:23:33.553		income
e4b29668110683810bb8560f1e539091	95d362d7-56fe-4f50-82cb-f97a51afc263	2026-08-01	2026-08-01	crypto_connect	assets_acceptance_fee_eq_zero		cfd8b2a8-af2d-474a-9923-3a5ef0335f52	7ba5aa24-bfb8-424b-84f9-d8cc067b8e6e	2604904.425	2026-09-04 15:23:33.553	1	source=global_crypto_dwm_daily;route=account_to_monthly;business_version=v1	2026-09-04 15:23:33.553	2026-09-04 15:23:33.553		base_metric


SELECT
*
FROM dws.mv_sales_commission_recent_estimate 
WHERE root_account_id ='95d362d7-56fe-4f50-82cb-f97a51afc263'
and product='crypto'
and settlement_month='2026-08-01'
433940151	2026-09-14	2026-08-01	95d362d7-56fe-4f50-82cb-f97a51afc263	crypto			real_time_processing_fee	current_payout	cfd8b2a8-af2d-474a-9923-3a5ef0335f52	7ba5aa24-bfb8-424b-84f9-d8cc067b8e6e	1851130772357509121	non_direct	2026-08-01	2026-08-01	2026-08-01	0.0000	0.0000	0.0000	0.0000	0.100000	0.0000	0	overseas_sales_2_non_direct_gp_10pct	2026-09-14 16:01:48.496819+08

拿这种情况下为什么没有记你这个时候毛利应该是负数

SELECT
*
FROM dws.dws_sales_commission_snapshot_detail_p 
WHERE root_account_id ='95d362d7-56fe-4f50-82cb-f97a51afc263'
and product='crypto'
and settlement_month='2026-08-01'