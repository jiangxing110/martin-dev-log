--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-11-18 17:56:06
-- Updated Time:   2026-11-18 17:59:21
-- Description:    按销售维度查询 QI v2 每项渠道成本及返现
-- Usage:
--   1. 在 PostgreSQL / ADBPG 中直接执行。
--   2. 修改 params 中的 sale_id、start_date、end_date；end_date 左闭右开。
--   3. 将 sale_id 占位值替换为销售 ID；设为 NULL 查询全部销售，设为空字符串查询未分配销售。
--   4. 按 DWS 中的 sale_id 汇总，空 sale_id 显示为“未分配销售”。
--   5. 每项成本输出计费基数、费率（适用时）、金额；返现收入单独列示。
--********************************************************************--

WITH params AS (
    SELECT
        '替换为saleId'::varchar AS sale_id,
        DATE '2026-10-01' AS start_date,
        DATE '2026-11-01' AS end_date
),
qi_scope AS (
    SELECT
        src.*,
        NULLIF(BTRIM(src.sale_id::varchar), '') AS sale_id_norm
    FROM dws.dws_qi_card_finance_daily_v2_p src
    CROSS JOIN params target
    WHERE src.delete_time IS NULL
      AND src.report_date >= target.start_date
      AND src.report_date < target.end_date
      AND (
          target.sale_id IS NULL
          OR NULLIF(BTRIM(src.sale_id::varchar), '') IS NOT DISTINCT FROM NULLIF(BTRIM(target.sale_id), '')
      )
),
qi_scope_summary AS (
    SELECT
        sale_id_norm,
        COUNT(DISTINCT account_id) AS dws_account_count,
        COUNT(*) AS dws_row_count,
        MIN(report_date) AS data_start_date,
        MAX(report_date) AS data_end_date
    FROM qi_scope
    GROUP BY sale_id_norm
),
qi_cost_items AS (
    SELECT 10 AS item_order, '成本'::text AS item_type, 'Reimbursement 费用'::text AS cost_item,
           SUM(COALESCE(cost_reimbursement_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric AS base_amount,
           (SUM(COALESCE(cost_reimbursement_base_amt, 0) * COALESCE(cost_reimbursement_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(cost_reimbursement_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric AS unit_rate,
           SUM(COALESCE(cost_reimbursement_base_amt, 0) * COALESCE(cost_reimbursement_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric AS item_amount, sale_id_norm FROM qi_scope GROUP BY sale_id_norm
    UNION ALL SELECT 20, '成本', 'Card Service 费用',
           SUM(COALESCE(cost_service_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric,
           (SUM(COALESCE(cost_service_base_amt, 0) * COALESCE(cost_service_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(cost_service_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric,
           SUM(COALESCE(cost_service_base_amt, 0) * COALESCE(cost_service_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric, sale_id_norm FROM qi_scope GROUP BY sale_id_norm
    UNION ALL SELECT 30, '成本', 'ACS Regular 费用',
           SUM(COALESCE(cost_acs_regular_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric,
           (SUM(COALESCE(cost_acs_regular_base_amt, 0) * COALESCE(cost_acs_regular_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(cost_acs_regular_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric,
           SUM(COALESCE(cost_acs_regular_base_amt, 0) * COALESCE(cost_acs_regular_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric, sale_id_norm FROM qi_scope GROUP BY sale_id_norm
    UNION ALL SELECT 40, '成本', 'ACS VIP 费用',
           SUM(COALESCE(cost_acs_vip_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric,
           (SUM(COALESCE(cost_acs_vip_base_amt, 0) * COALESCE(cost_acs_vip_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(cost_acs_vip_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric,
           SUM(COALESCE(cost_acs_vip_base_amt, 0) * COALESCE(cost_acs_vip_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric, sale_id_norm FROM qi_scope GROUP BY sale_id_norm
    UNION ALL SELECT 50, '成本', 'VRM 费用',
           SUM(COALESCE(cost_vrm_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric,
           (SUM(COALESCE(cost_vrm_base_amt, 0) * COALESCE(cost_vrm_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(cost_vrm_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric,
           SUM(COALESCE(cost_vrm_base_amt, 0) * COALESCE(cost_vrm_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric, sale_id_norm FROM qi_scope GROUP BY sale_id_norm
    UNION ALL SELECT 60, '成本', 'HK Regular 费用',
           SUM(COALESCE(cost_hk_regular_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric,
           (SUM(COALESCE(cost_hk_regular_base_amt, 0) * COALESCE(cost_hk_regular_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(cost_hk_regular_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric,
           SUM(COALESCE(cost_hk_regular_base_amt, 0) * COALESCE(cost_hk_regular_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric, sale_id_norm FROM qi_scope GROUP BY sale_id_norm
    UNION ALL SELECT 70, '成本', 'HK VIP 费用',
           SUM(COALESCE(cost_hk_vip_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric,
           (SUM(COALESCE(cost_hk_vip_base_amt, 0) * COALESCE(cost_hk_vip_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(cost_hk_vip_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric,
           SUM(COALESCE(cost_hk_vip_base_amt, 0) * COALESCE(cost_hk_vip_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric, sale_id_norm FROM qi_scope GROUP BY sale_id_norm
    UNION ALL SELECT 80, '成本', 'DCSF 费用',
           SUM(COALESCE(cost_dcsf_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric,
           (SUM(COALESCE(cost_dcsf_base_amt, 0) * COALESCE(cost_dcsf_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(cost_dcsf_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric,
           SUM(COALESCE(cost_dcsf_base_amt, 0) * COALESCE(cost_dcsf_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric, sale_id_norm FROM qi_scope GROUP BY sale_id_norm
    UNION ALL SELECT 90, '成本', '渠道固定成本', NULL::numeric, NULL::numeric,
           SUM(COALESCE(cost_fixed_fee, 0)) FILTER (WHERE special_fee_type = 'CHANNEL_FIXED_FEE')::numeric, sale_id_norm FROM qi_scope GROUP BY sale_id_norm
),
qi_total AS (
    SELECT 999 AS item_order, '成本'::text AS item_type, 'QI 渠道总成本'::text AS cost_item,
           NULL::numeric AS base_amount, NULL::numeric AS unit_rate,
           COALESCE(SUM(item_amount), 0)::numeric AS item_amount,
           sale_id_norm
    FROM qi_cost_items
    GROUP BY sale_id_norm
),
qi_cashback_items AS (
    SELECT 1010 AS item_order, '返现收入'::text AS item_type, 'Interchange 返现收入'::text AS cost_item,
           SUM(COALESCE(rebate_interchange_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric AS base_amount,
           (SUM(COALESCE(rebate_interchange_base_amt, 0) * COALESCE(rebate_interchange_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(rebate_interchange_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric AS unit_rate,
           SUM(COALESCE(rebate_interchange_base_amt, 0) * COALESCE(rebate_interchange_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric AS item_amount, sale_id_norm FROM qi_scope GROUP BY sale_id_norm
    UNION ALL SELECT 1020, '返现收入', 'Incentive 返现收入',
           SUM(COALESCE(rebate_incentive_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL)::numeric,
           (SUM(COALESCE(rebate_incentive_base_amt, 0) * COALESCE(rebate_incentive_rate, 1)) FILTER (WHERE special_fee_type IS NULL)
             / NULLIF(SUM(COALESCE(rebate_incentive_base_amt, 0)) FILTER (WHERE special_fee_type IS NULL), 0))::numeric,
           SUM(COALESCE(rebate_incentive_base_amt, 0) * COALESCE(rebate_incentive_rate, 1)) FILTER (WHERE special_fee_type IS NULL)::numeric, sale_id_norm FROM qi_scope GROUP BY sale_id_norm
),
all_items AS (
    SELECT * FROM qi_cost_items
    UNION ALL SELECT * FROM qi_total
    UNION ALL SELECT * FROM qi_cashback_items
)
SELECT
    'QI' AS channel,
    item.sale_id_norm AS sale_id,
    COALESCE(item.sale_id_norm, '未分配销售') AS sale_display,
    target.start_date AS query_start_date,
    target.end_date AS query_end_date_exclusive,
    summary.dws_account_count,
    summary.dws_row_count,
    CASE WHEN summary.dws_row_count = 0 THEN 'DWS无数据' ELSE '已查到DWS数据' END AS query_status,
    summary.data_start_date,
    summary.data_end_date,
    item.item_type,
    item.cost_item,
    CAST(item.base_amount AS NUMERIC(20, 4)) AS base_amount,
    CAST(item.unit_rate AS NUMERIC(20, 8)) AS weighted_rate,
    CAST(COALESCE(item.item_amount, 0) AS NUMERIC(20, 4)) AS amount
FROM all_items item
JOIN qi_scope_summary summary
  ON summary.sale_id_norm IS NOT DISTINCT FROM item.sale_id_norm
CROSS JOIN params target
ORDER BY item.sale_id_norm NULLS FIRST, item.item_order;
