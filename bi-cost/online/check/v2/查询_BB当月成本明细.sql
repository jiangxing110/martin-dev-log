--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-11-09 14:00:00
-- Updated Time:   2026-11-09 17:10:00
-- Description:    按客户和期间逐项查询 BB v2 渠道成本，API 子户并入主户
-- Usage:
--   1. 在 PostgreSQL / ADBPG 中直接执行。
--   2. 修改 params 中的 account_id、start_date、end_date；end_date 左闭右开。
--   3. account_id 可传 API 主户或子户；API 子户会解析到主户并合并其有效子户。
--   4. 每项成本输出计费基数、费率（适用时）、金额；总成本行不包含 BB 渠道返现收入。
--   5. BB 渠道返现收入另列为“收入”，不计入成本总计。
--********************************************************************--

WITH params AS (
    SELECT
        '替换为accountId'::varchar AS account_id,
        DATE '2026-10-01' AS start_date,
        DATE '2026-11-01' AS end_date
),
api_account_map AS (
    SELECT DISTINCT
        account_id::varchar AS account_id,
        root_id::varchar AS root_id
    FROM public.api_account_relation
    WHERE delete_time IS NULL
),
requested_account AS (
    SELECT
        p.account_id AS input_account_id,
        COALESCE(MAX(api.root_id), p.account_id) AS report_account_id,
        p.start_date,
        p.end_date
    FROM params p
    LEFT JOIN api_account_map api
      ON api.account_id = p.account_id
    GROUP BY p.account_id, p.start_date, p.end_date
),
bb_scope AS (
    SELECT
        bb.*,
        COALESCE(api.root_id, bb.account_id::varchar) AS report_account_id
    FROM dws.dws_bb_card_finance_daily_v2_p bb
    LEFT JOIN api_account_map api
      ON api.account_id = bb.account_id::varchar
    CROSS JOIN requested_account target
    WHERE bb.delete_time IS NULL
      AND bb.report_date >= target.start_date
      AND bb.report_date < target.end_date
      AND COALESCE(api.root_id, bb.account_id::varchar) = target.report_account_id
),
bb_scope_summary AS (
    SELECT
        COUNT(DISTINCT account_id) AS dws_account_count,
        COUNT(*) AS dws_row_count,
        MIN(report_date) AS data_start_date,
        MAX(report_date) AS data_end_date
    FROM bb_scope
),
bb_cost_items AS (
    SELECT 10 AS item_order, '成本'::text AS item_type, 'Mastercard Domestic 授权笔数费'::text AS cost_item,
           SUM(COALESCE(m_dom_auth_count, 0))::numeric AS base_amount, 0.1090::numeric AS unit_rate,
           SUM(COALESCE(m_dom_auth_count, 0) * 0.1090)::numeric AS item_amount FROM bb_scope
    UNION ALL SELECT 20, '成本', 'Mastercard International 授权笔数费', SUM(COALESCE(m_int_auth_count, 0))::numeric, 0.4845::numeric, SUM(COALESCE(m_int_auth_count, 0) * 0.4845)::numeric FROM bb_scope
    UNION ALL SELECT 30, '成本', 'VISA Domestic 授权笔数费', SUM(COALESCE(v_dom_auth_count, 0))::numeric, 0.0725::numeric, SUM(COALESCE(v_dom_auth_count, 0) * 0.0725)::numeric FROM bb_scope
    UNION ALL SELECT 40, '成本', 'VISA International 授权笔数费', SUM(COALESCE(v_int_auth_count, 0))::numeric, 0.4770::numeric, SUM(COALESCE(v_int_auth_count, 0) * 0.4770)::numeric FROM bb_scope
    UNION ALL SELECT 50, '成本', 'AC Mastercard Domestic 授权笔数费', SUM(COALESCE(av_m_dom_count, 0))::numeric, 0.1090::numeric, SUM(COALESCE(av_m_dom_count, 0) * 0.1090)::numeric FROM bb_scope
    UNION ALL SELECT 60, '成本', 'AC Mastercard International 授权笔数费', SUM(COALESCE(av_m_int_count, 0))::numeric, 0.4845::numeric, SUM(COALESCE(av_m_int_count, 0) * 0.4845)::numeric FROM bb_scope
    UNION ALL SELECT 70, '成本', 'AC VISA Domestic 授权笔数费', SUM(COALESCE(av_v_dom_count, 0))::numeric, 0.0725::numeric, SUM(COALESCE(av_v_dom_count, 0) * 0.0725)::numeric FROM bb_scope
    UNION ALL SELECT 80, '成本', 'AC VISA International 授权笔数费', SUM(COALESCE(av_v_int_count, 0))::numeric, 0.4770::numeric, SUM(COALESCE(av_v_int_count, 0) * 0.4770)::numeric FROM bb_scope
    UNION ALL SELECT 90, '成本', 'Mastercard Domestic 清算金额费', SUM(COALESCE(m_dom_clearing_vol, 0))::numeric, 0.0021::numeric, SUM(COALESCE(m_dom_clearing_vol, 0) * 0.0021)::numeric FROM bb_scope
    UNION ALL SELECT 100, '成本', 'Mastercard International 清算金额费', SUM(COALESCE(m_int_clearing_vol, 0))::numeric, 0.0111::numeric, SUM(COALESCE(m_int_clearing_vol, 0) * 0.0111)::numeric FROM bb_scope
    UNION ALL SELECT 110, '成本', 'VISA Domestic 清算金额费', SUM(COALESCE(v_dom_clearing_vol, 0))::numeric, 0.0016::numeric, SUM(COALESCE(v_dom_clearing_vol, 0) * 0.0016)::numeric FROM bb_scope
    UNION ALL SELECT 120, '成本', 'VISA International 清算金额费', SUM(COALESCE(v_int_clearing_vol, 0))::numeric, 0.0116::numeric, SUM(COALESCE(v_int_clearing_vol, 0) * 0.0116)::numeric FROM bb_scope
    UNION ALL SELECT 130, '成本', 'Mastercard International Reversal 费', SUM(COALESCE(m_int_reversal_count, 0))::numeric, 0.7190::numeric, SUM(COALESCE(m_int_reversal_count, 0) * 0.7190)::numeric FROM bb_scope
    UNION ALL SELECT 140, '成本', 'VISA International Reversal 费', SUM(COALESCE(v_int_reversal_count, 0))::numeric, 0.7140::numeric, SUM(COALESCE(v_int_reversal_count, 0) * 0.7140)::numeric FROM bb_scope
    UNION ALL SELECT 150, '成本', 'Domestic Reversal 费', SUM(COALESCE(dom_reversal_count, 0))::numeric, 0.1780::numeric, SUM(COALESCE(dom_reversal_count, 0) * 0.1780)::numeric FROM bb_scope
    UNION ALL SELECT 160, '成本', 'Mastercard International Refund 费', SUM(COALESCE(m_int_refund_count, 0))::numeric, 0.4845::numeric, SUM(COALESCE(m_int_refund_count, 0) * 0.4845)::numeric FROM bb_scope
    UNION ALL SELECT 170, '成本', 'VISA International Refund 费', SUM(COALESCE(v_int_refund_count, 0))::numeric, 0.4770::numeric, SUM(COALESCE(v_int_refund_count, 0) * 0.4770)::numeric FROM bb_scope
    UNION ALL SELECT 180, '成本', 'Domestic Refund 费', SUM(COALESCE(dom_refund_count, 0))::numeric, 0.1090::numeric, SUM(COALESCE(dom_refund_count, 0) * 0.1090)::numeric FROM bb_scope
    UNION ALL SELECT 190, '成本', 'Mastercard International Decline 费', SUM(COALESCE(m_int_decline_count, 0))::numeric, 0.3595::numeric, SUM(COALESCE(m_int_decline_count, 0) * 0.3595)::numeric FROM bb_scope
    UNION ALL SELECT 200, '成本', 'VISA International Decline 费', SUM(COALESCE(v_int_decline_count, 0))::numeric, 0.3570::numeric, SUM(COALESCE(v_int_decline_count, 0) * 0.3570)::numeric FROM bb_scope
    UNION ALL SELECT 210, '成本', 'Domestic Decline 费', SUM(COALESCE(dom_decline_count, 0))::numeric, 0.0890::numeric, SUM(COALESCE(dom_decline_count, 0) * 0.0890)::numeric FROM bb_scope
    UNION ALL SELECT 220, '成本', 'AC Mastercard International Decline 费', SUM(COALESCE(ac_m_int_decline_count, 0))::numeric, 0.3595::numeric, SUM(COALESCE(ac_m_int_decline_count, 0) * 0.3595)::numeric FROM bb_scope
    UNION ALL SELECT 230, '成本', 'AC VISA International Decline 费', SUM(COALESCE(ac_v_int_decline_count, 0))::numeric, 0.3570::numeric, SUM(COALESCE(ac_v_int_decline_count, 0) * 0.3570)::numeric FROM bb_scope
    UNION ALL SELECT 240, '成本', 'AC Domestic Decline 费', SUM(COALESCE(ac_dom_decline_count, 0))::numeric, 0.0890::numeric, SUM(COALESCE(ac_dom_decline_count, 0) * 0.0890)::numeric FROM bb_scope
    UNION ALL SELECT 250, '成本', 'Active Card 账户费', SUM(COALESCE(active_card_count, 0))::numeric, 0.1000::numeric, SUM(COALESCE(active_card_count, 0) * 0.1000)::numeric FROM bb_scope
    UNION ALL SELECT 260, '成本', 'Volume Fee 成本', NULL::numeric, NULL::numeric, SUM(COALESCE(volume_fee_cost, 0))::numeric FROM bb_scope
    UNION ALL SELECT 270, '成本', '固定成本', NULL::numeric, NULL::numeric, SUM(COALESCE(cost_fixed_fee, 0))::numeric FROM bb_scope
),
bb_total AS (
    SELECT 999 AS item_order, '成本'::text AS item_type, 'BB 渠道总成本'::text AS cost_item,
           NULL::numeric AS base_amount, NULL::numeric AS unit_rate,
           COALESCE(SUM(item_amount), 0)::numeric AS item_amount
    FROM bb_cost_items
),
bb_cashback_income AS (
    SELECT 1000 AS item_order, '返现收入'::text AS item_type, 'BB 渠道 Cashback 收入'::text AS cost_item,
           SUM(COALESCE(bb_rebate_base_amt, 0))::numeric AS base_amount,
           (SUM(COALESCE(cashback_income, 0)) / NULLIF(SUM(COALESCE(bb_rebate_base_amt, 0)), 0))::numeric AS unit_rate,
           SUM(COALESCE(cashback_income, 0))::numeric AS item_amount
    FROM bb_scope
),
all_items AS (
    SELECT * FROM bb_cost_items
    UNION ALL SELECT * FROM bb_total
    UNION ALL SELECT * FROM bb_cashback_income
)
SELECT
    'BB' AS channel,
    target.input_account_id,
    target.report_account_id,
    target.start_date AS query_start_date,
    target.end_date AS query_end_date_exclusive,
    summary.dws_account_count,
    summary.dws_row_count,
    CASE WHEN summary.dws_row_count = 0 THEN 'DWS无数据' ELSE '已查到DWS数据' END AS query_status,
    item.item_type,
    item.cost_item,
    CAST(item.base_amount AS NUMERIC(20, 4)) AS base_amount,
    CAST(item.unit_rate AS NUMERIC(20, 8)) AS rate,
    CAST(COALESCE(item.item_amount, 0) AS NUMERIC(20, 4)) AS amount
FROM all_items item
CROSS JOIN requested_account target
CROSS JOIN bb_scope_summary summary
ORDER BY item.item_order;
