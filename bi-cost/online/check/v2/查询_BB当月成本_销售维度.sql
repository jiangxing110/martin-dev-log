--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-11-18 17:56:06
-- Updated Time:   2026-11-18 17:59:21
-- Description:    按销售维度查询 BB v2 每项渠道成本及返现
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
bb_scope AS (
    SELECT
        src.*,
        NULLIF(BTRIM(src.sale_id::varchar), '') AS sale_id_norm
    FROM dws.dws_bb_card_finance_daily_v2_p src
    CROSS JOIN params target
    WHERE src.delete_time IS NULL
      AND src.report_date >= target.start_date
      AND src.report_date < target.end_date
      AND (
          target.sale_id IS NULL
          OR NULLIF(BTRIM(src.sale_id::varchar), '') IS NOT DISTINCT FROM NULLIF(BTRIM(target.sale_id), '')
      )
),
bb_scope_summary AS (
    SELECT
        sale_id_norm,
        COUNT(DISTINCT account_id) AS dws_account_count,
        COUNT(*) AS dws_row_count,
        MIN(report_date) AS data_start_date,
        MAX(report_date) AS data_end_date
    FROM bb_scope
    GROUP BY sale_id_norm
),
bb_cost_items AS (
    SELECT 10 AS item_order, '成本'::text AS item_type, 'Mastercard Domestic 授权笔数费'::text AS cost_item,
           SUM(COALESCE(m_dom_auth_count, 0))::numeric AS base_amount, 0.1090::numeric AS unit_rate,
           SUM(COALESCE(m_dom_auth_count, 0) * 0.1090)::numeric AS item_amount, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 20, '成本', 'Mastercard International 授权笔数费', SUM(COALESCE(m_int_auth_count, 0))::numeric, 0.4845::numeric, SUM(COALESCE(m_int_auth_count, 0) * 0.4845)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 30, '成本', 'VISA Domestic 授权笔数费', SUM(COALESCE(v_dom_auth_count, 0))::numeric, 0.0725::numeric, SUM(COALESCE(v_dom_auth_count, 0) * 0.0725)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 40, '成本', 'VISA International 授权笔数费', SUM(COALESCE(v_int_auth_count, 0))::numeric, 0.4770::numeric, SUM(COALESCE(v_int_auth_count, 0) * 0.4770)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 50, '成本', 'AC Mastercard Domestic 授权笔数费', SUM(COALESCE(av_m_dom_count, 0))::numeric, 0.1090::numeric, SUM(COALESCE(av_m_dom_count, 0) * 0.1090)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 60, '成本', 'AC Mastercard International 授权笔数费', SUM(COALESCE(av_m_int_count, 0))::numeric, 0.4845::numeric, SUM(COALESCE(av_m_int_count, 0) * 0.4845)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 70, '成本', 'AC VISA Domestic 授权笔数费', SUM(COALESCE(av_v_dom_count, 0))::numeric, 0.0725::numeric, SUM(COALESCE(av_v_dom_count, 0) * 0.0725)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 80, '成本', 'AC VISA International 授权笔数费', SUM(COALESCE(av_v_int_count, 0))::numeric, 0.4770::numeric, SUM(COALESCE(av_v_int_count, 0) * 0.4770)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 90, '成本', 'Mastercard Domestic 清算金额费', SUM(COALESCE(m_dom_clearing_vol, 0))::numeric, 0.0021::numeric, SUM(COALESCE(m_dom_clearing_vol, 0) * 0.0021)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 100, '成本', 'Mastercard International 清算金额费', SUM(COALESCE(m_int_clearing_vol, 0))::numeric, 0.0111::numeric, SUM(COALESCE(m_int_clearing_vol, 0) * 0.0111)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 110, '成本', 'VISA Domestic 清算金额费', SUM(COALESCE(v_dom_clearing_vol, 0))::numeric, 0.0016::numeric, SUM(COALESCE(v_dom_clearing_vol, 0) * 0.0016)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 120, '成本', 'VISA International 清算金额费', SUM(COALESCE(v_int_clearing_vol, 0))::numeric, 0.0116::numeric, SUM(COALESCE(v_int_clearing_vol, 0) * 0.0116)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 130, '成本', 'Mastercard International Reversal 费', SUM(COALESCE(m_int_reversal_count, 0))::numeric, 0.7190::numeric, SUM(COALESCE(m_int_reversal_count, 0) * 0.7190)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 140, '成本', 'VISA International Reversal 费', SUM(COALESCE(v_int_reversal_count, 0))::numeric, 0.7140::numeric, SUM(COALESCE(v_int_reversal_count, 0) * 0.7140)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 150, '成本', 'Domestic Reversal 费', SUM(COALESCE(dom_reversal_count, 0))::numeric, 0.1780::numeric, SUM(COALESCE(dom_reversal_count, 0) * 0.1780)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 160, '成本', 'Mastercard International Refund 费', SUM(COALESCE(m_int_refund_count, 0))::numeric, 0.4845::numeric, SUM(COALESCE(m_int_refund_count, 0) * 0.4845)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 170, '成本', 'VISA International Refund 费', SUM(COALESCE(v_int_refund_count, 0))::numeric, 0.4770::numeric, SUM(COALESCE(v_int_refund_count, 0) * 0.4770)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 180, '成本', 'Domestic Refund 费', SUM(COALESCE(dom_refund_count, 0))::numeric, 0.1090::numeric, SUM(COALESCE(dom_refund_count, 0) * 0.1090)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 190, '成本', 'Mastercard International Decline 费', SUM(COALESCE(m_int_decline_count, 0))::numeric, 0.3595::numeric, SUM(COALESCE(m_int_decline_count, 0) * 0.3595)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 200, '成本', 'VISA International Decline 费', SUM(COALESCE(v_int_decline_count, 0))::numeric, 0.3570::numeric, SUM(COALESCE(v_int_decline_count, 0) * 0.3570)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 210, '成本', 'Domestic Decline 费', SUM(COALESCE(dom_decline_count, 0))::numeric, 0.0890::numeric, SUM(COALESCE(dom_decline_count, 0) * 0.0890)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 220, '成本', 'AC Mastercard International Decline 费', SUM(COALESCE(ac_m_int_decline_count, 0))::numeric, 0.3595::numeric, SUM(COALESCE(ac_m_int_decline_count, 0) * 0.3595)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 230, '成本', 'AC VISA International Decline 费', SUM(COALESCE(ac_v_int_decline_count, 0))::numeric, 0.3570::numeric, SUM(COALESCE(ac_v_int_decline_count, 0) * 0.3570)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 240, '成本', 'AC Domestic Decline 费', SUM(COALESCE(ac_dom_decline_count, 0))::numeric, 0.0890::numeric, SUM(COALESCE(ac_dom_decline_count, 0) * 0.0890)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 250, '成本', 'Active Card 账户费', SUM(COALESCE(active_card_count, 0))::numeric, 0.1000::numeric, SUM(COALESCE(active_card_count, 0) * 0.1000)::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 260, '成本', 'Volume Fee 成本', NULL::numeric, NULL::numeric, SUM(COALESCE(volume_fee_cost, 0))::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
    UNION ALL SELECT 270, '成本', '固定成本', NULL::numeric, NULL::numeric, SUM(COALESCE(cost_fixed_fee, 0))::numeric, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
),
bb_total AS (
    SELECT 999 AS item_order, '成本'::text AS item_type, 'BB 渠道总成本'::text AS cost_item,
           NULL::numeric AS base_amount, NULL::numeric AS unit_rate,
           COALESCE(SUM(item_amount), 0)::numeric AS item_amount,
           sale_id_norm
    FROM bb_cost_items
    GROUP BY sale_id_norm
),
bb_cashback_income AS (
    SELECT 1000 AS item_order, '返现收入'::text AS item_type, 'BB 渠道 Cashback 收入'::text AS cost_item,
           SUM(COALESCE(bb_rebate_base_amt, 0))::numeric AS base_amount,
           (SUM(COALESCE(cashback_income, 0)) / NULLIF(SUM(COALESCE(bb_rebate_base_amt, 0)), 0))::numeric AS unit_rate,
           SUM(COALESCE(cashback_income, 0))::numeric AS item_amount, sale_id_norm FROM bb_scope GROUP BY sale_id_norm
),
all_items AS (
    SELECT * FROM bb_cost_items
    UNION ALL SELECT * FROM bb_total
    UNION ALL SELECT * FROM bb_cashback_income
)
SELECT
    'BB' AS channel,
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
    CAST(item.unit_rate AS NUMERIC(20, 8)) AS rate,
    CAST(COALESCE(item.item_amount, 0) AS NUMERIC(20, 4)) AS amount
FROM all_items item
JOIN bb_scope_summary summary
  ON summary.sale_id_norm IS NOT DISTINCT FROM item.sale_id_norm
CROSS JOIN params target
ORDER BY item.sale_id_norm NULLS FIRST, item.item_order;
