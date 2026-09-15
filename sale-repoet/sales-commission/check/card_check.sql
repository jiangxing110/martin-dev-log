select  sum(effective_revenue) , sum(cogs) , sum(gp)  from dws.dws_sales_commission_snapshot_detail_p 
where settlement_month='2026-08-01'
and product ='qbit_card'
and root_account_id='2cef54b6-51c9-47c8-a56a-66934cbfd619'
null

select  sum(effective_revenue) , sum(cogs) , sum(gp)  from dws.mv_sales_commission_recent_estimate 
where settlement_month='2026-08-01'
and product ='qbit_card'
and root_account_id='2cef54b6-51c9-47c8-a56a-66934cbfd619'
null 

SELECT
*
FROM dws.dws_metrics_sales_revenue_monthly r
LEFT JOIN dim.dim_account_analysis a
    ON a.account_id = r.root_account_id
   AND a.delete_time IS NULL
WHERE r.settlement_month = DATE '2026-08-01'
  AND r.product = 'qbit_card'
  AND r.metric_code = 'main'
  AND r.delete_time IS NULL
  AND COALESCE(r.sale_id, r.am_id)
      = 'cdecea01-c18b-46fd-8ccb-040fcad51401'
	and r.root_account_id=	'2cef54b6-51c9-47c8-a56a-66934cbfd619'	
04ba392c43c2da137df162b1b7cd7f31	2cef54b6-51c9-47c8-a56a-66934cbfd619	2026-08-01	2026-08-01	qbit_card	main	BB	cdecea01-c18b-46fd-8ccb-040fcad51401		0.000	2026-09-04 10:08:07.719	1	source=unified_dwm_to_monthly_plus_collect;business_version=v2	2026-09-04 10:08:07.719	2026-09-04 10:08:07.719		income	2cef54b6-51c9-47c8-a56a-66934cbfd619	Celest Trading Limited	ApiClient	Active	QbitInternational							2026-09-14 02:47:49.908					2025-11-19 02:44:46.658	2026-09-14 10:47:55.995		838108
9d8f4846a070e9d854fa1a1ba7e1ef05	2cef54b6-51c9-47c8-a56a-66934cbfd619	2026-08-01	2026-08-01	qbit_card	main	BZ	cdecea01-c18b-46fd-8ccb-040fcad51401		0.000	2026-09-04 10:08:07.719	1	source=unified_dwm_to_monthly_plus_collect;business_version=v2	2026-09-04 10:08:07.719	2026-09-04 10:08:07.719		income	2cef54b6-51c9-47c8-a56a-66934cbfd619	Celest Trading Limited	ApiClient	Active	QbitInternational							2026-09-14 02:47:49.908					2025-11-19 02:44:46.658	2026-09-14 10:47:55.995		838108
1f60167d7a614b3eb8eb782b73748f4b	2cef54b6-51c9-47c8-a56a-66934cbfd619	2026-08-01	2026-08-01	qbit_card	main	IQ	cdecea01-c18b-46fd-8ccb-040fcad51401		95676.440	2026-09-04 10:08:07.719	1	source=unified_dwm_to_monthly_plus_collect;business_version=v2	2026-09-04 10:08:07.719	2026-09-04 10:08:07.719		income	2cef54b6-51c9-47c8-a56a-66934cbfd619	Celest Trading Limited	ApiClient	Active	QbitInternational							2026-09-14 02:47:49.908					2025-11-19 02:44:46.658	2026-09-14 10:47:55.995		838108
e39a3c90affc8e41b7cd4372848bf253	2cef54b6-51c9-47c8-a56a-66934cbfd619	2026-08-01	2026-08-01	qbit_card	main	PC	cdecea01-c18b-46fd-8ccb-040fcad51401		0.000	2026-09-04 10:08:07.719	1	source=unified_dwm_to_monthly_plus_collect;business_version=v2	2026-09-04 10:08:07.719	2026-09-04 10:08:07.719		income	2cef54b6-51c9-47c8-a56a-66934cbfd619	Celest Trading Limited	ApiClient	Active	QbitInternational							2026-09-14 02:47:49.908					2025-11-19 02:44:46.658	2026-09-14 10:47:55.995		838108
eab456c44fe35648f40997dd5f337f85	2cef54b6-51c9-47c8-a56a-66934cbfd619	2026-08-01	2026-08-01	qbit_card	main		cdecea01-c18b-46fd-8ccb-040fcad51401		0.000	2026-09-04 10:08:07.719	1	source=unified_dwm_to_monthly_plus_collect;business_version=v2	2026-09-04 10:08:07.719	2026-09-04 10:08:07.719		income	2cef54b6-51c9-47c8-a56a-66934cbfd619	Celest Trading Limited	ApiClient	Active	QbitInternational							2026-09-14 02:47:49.908					2025-11-19 02:44:46.658	2026-09-14 10:47:55.995		838108



我看这个客户的量子卡激活时间是 2026-09-14 02:47:49.908


WITH account_root_relation AS (
    SELECT account_id, root_id
    FROM ods.ods_api_account_relation
    WHERE delete_time IS NULL
)
SELECT
    DATE_TRUNC('month', q.report_date)::date AS settlement_month,
    COALESCE(aar.root_id, q.account_id) AS root_account_id,
    SUM(
        COALESCE(q.cost_reimbursement_base_amt, 0) * COALESCE(q.cost_reimbursement_rate, 0)
      + COALESCE(q.cost_service_base_amt, 0) * COALESCE(q.cost_service_rate, 0)
      + COALESCE(q.cost_acs_regular_base_amt, 0) * COALESCE(q.cost_acs_regular_rate, 0)
      + COALESCE(q.cost_acs_vip_base_amt, 0) * COALESCE(q.cost_acs_vip_rate, 0)
      + COALESCE(q.cost_vrm_base_amt, 0) * COALESCE(q.cost_vrm_rate, 0)
      + COALESCE(q.cost_hk_regular_base_amt, 0) * COALESCE(q.cost_hk_regular_rate, 0)
      + COALESCE(q.cost_hk_vip_base_amt, 0) * COALESCE(q.cost_hk_vip_rate, 0)
      + COALESCE(q.cost_dcsf_base_amt, 0) * COALESCE(q.cost_dcsf_rate, 0)
      + COALESCE(q.cost_fixed_fee, 0)
    ) AS qbit_cost
FROM dws.dws_qi_card_finance_daily_v2_p q
LEFT JOIN account_root_relation aar
    ON aar.account_id = q.account_id
WHERE q.delete_time IS NULL
  AND q.report_date >= DATE '2026-08-01'
  AND q.report_date < DATE '2026-09-01'
  AND COALESCE(aar.root_id, q.account_id)
      = '2cef54b6-51c9-47c8-a56a-66934cbfd619'
GROUP BY
    DATE_TRUNC('month', q.report_date)::date,
    COALESCE(aar.root_id, q.account_id);