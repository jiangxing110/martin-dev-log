--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-11-09 16:22:14
-- Updated Time:   2026-11-09 16:37:22
-- Description:    指定客户 2026-10 BB/QI DWS 成本与销售毛利报表成本比对
-- Usage:
--   1. 在 ADBPG / PostgreSQL 中直接执行，只读查询。
--   2. 按 API 主户归集有效子户；输入客户 ID 可为主户或子户。
--   3. Excel成本采用附件销售毛利表的渠道成本分项合计；DWS 成本由本 SQL 即时计算。
--   4. 客户返现、银行手续费及渠道返现收入不计入此单渠道成本对比。
--   5. end_date 左闭右开，当前查询 2026-10-01 至 2026-11-01。
--   6. 最终输出：渠道、客户名称、客户ID、DWS渠道成本、Excel渠道成本、两者差值。
--********************************************************************--

WITH params AS (
    SELECT
        DATE '2026-10-01' AS start_date,
        DATE '2026-11-01' AS end_date
),
comparison_accounts AS (
    SELECT *
    FROM (VALUES
        ('QI', '838c5b68-4bb1-4960-880a-827399d101fd', 'Sudu Limited', 60538.138773497::numeric, 56093.4688::numeric, 3712.22::numeric, 732.45::numeric),
        ('QI', '451fb6b9-54b7-4e6b-b690-cbe4f77670ed', '香港和優貿易有限公司', 330023.140576409::numeric, 276898.0806::numeric, 49494.16::numeric, 3630.90::numeric),
        ('QI', 'c23e5ba5-1968-4dc5-a714-8da076a3f457', 'Nano Advanced Services Limited', 7012.6509147651::numeric, 3754.3109::numeric, 3207.04::numeric, 51.30::numeric),
        ('QI', 'f67cd913-4d76-47bf-b6f6-02c7531a2a69', 'ORENDA FINANCIAL SERVICES LIMITED', 9796.671629239::numeric, 9681.7216::numeric, 0::numeric, 114.95::numeric),
        ('BB', '046a8fc4-fa68-4746-a6e2-db2d82a1fcc5', 'AQUACEDAR CAPITAL INC.', 327.51::numeric, 327.51::numeric, 0::numeric, 0::numeric),
        ('BB', '95d362d7-56fe-4f50-82cb-f97a51afc263', 'LGENERATION LTD', 135922.71::numeric, 126290.65::numeric, 9632.09::numeric, 0::numeric),
        ('BB', 'e7107263-a635-4e3b-b9be-bb26d3d33e22', 'NOVA SOLUTIONS HK LIMITED', 18941.66::numeric, 17099.70::numeric, 1841.98::numeric, 0::numeric),
        ('BB', '93ad4e12-5262-477d-859b-0dad95b232de', 'Ais Trade Corporation', 72705.11::numeric, 47231.88::numeric, 25473.25::numeric, 0::numeric),
        ('BB', '451fb6b9-54b7-4e6b-b690-cbe4f77670ed', '香港和優貿易有限公司', 52883.46::numeric, 39810.48::numeric, 13072.99::numeric, 0::numeric)
    ) AS v(channel, input_account_id, account_name, report_cost, report_channel_cost, report_customer_cashback_cost, report_bank_fee_cost)
),
api_account_map AS (
    SELECT DISTINCT
        account_id::varchar AS account_id,
        root_id::varchar AS root_id
    FROM public.api_account_relation
    WHERE delete_time IS NULL
),
selected_accounts AS (
    SELECT
        c.*,
        COALESCE(MAX(input_map.root_id), c.input_account_id) AS report_account_id
    FROM comparison_accounts c
    LEFT JOIN api_account_map input_map
      ON input_map.account_id = c.input_account_id
    GROUP BY
        c.channel, c.input_account_id, c.account_name,
        c.report_cost, c.report_channel_cost,
        c.report_customer_cashback_cost, c.report_bank_fee_cost
),
bb_dws AS (
    SELECT
        a.input_account_id,
        COUNT(DISTINCT bb.account_id) AS dws_account_count,
        COUNT(*) AS dws_row_count,
        SUM(
            COALESCE(bb.m_dom_auth_count, 0) * 0.1090
          + COALESCE(bb.m_int_auth_count, 0) * 0.4845
          + COALESCE(bb.v_dom_auth_count, 0) * 0.0725
          + COALESCE(bb.v_int_auth_count, 0) * 0.4770
          + COALESCE(bb.av_m_dom_count, 0) * 0.1090
          + COALESCE(bb.av_m_int_count, 0) * 0.4845
          + COALESCE(bb.av_v_dom_count, 0) * 0.0725
          + COALESCE(bb.av_v_int_count, 0) * 0.4770
          + COALESCE(bb.m_dom_clearing_vol, 0) * 0.0021
          + COALESCE(bb.m_int_clearing_vol, 0) * 0.0111
          + COALESCE(bb.v_dom_clearing_vol, 0) * 0.0016
          + COALESCE(bb.v_int_clearing_vol, 0) * 0.0116
          + COALESCE(bb.m_int_reversal_count, 0) * 0.7190
          + COALESCE(bb.v_int_reversal_count, 0) * 0.7140
          + COALESCE(bb.dom_reversal_count, 0) * 0.1780
          + COALESCE(bb.m_int_refund_count, 0) * 0.4845
          + COALESCE(bb.v_int_refund_count, 0) * 0.4770
          + COALESCE(bb.dom_refund_count, 0) * 0.1090
          + COALESCE(bb.m_int_decline_count, 0) * 0.3595
          + COALESCE(bb.v_int_decline_count, 0) * 0.3570
          + COALESCE(bb.dom_decline_count, 0) * 0.0890
          + COALESCE(bb.ac_m_int_decline_count, 0) * 0.3595
          + COALESCE(bb.ac_v_int_decline_count, 0) * 0.3570
          + COALESCE(bb.ac_dom_decline_count, 0) * 0.0890
          + COALESCE(bb.active_card_count, 0) * 0.1000
          + COALESCE(bb.volume_fee_cost, 0)
          + COALESCE(bb.cost_fixed_fee, 0)
        ) AS query_channel_cost,
        SUM(COALESCE(bb.cashback_income, 0)) AS bb_channel_cashback_income
    FROM dws.dws_bb_card_finance_daily_v2_p bb
    LEFT JOIN api_account_map bb_map
      ON bb_map.account_id = bb.account_id::varchar
    JOIN selected_accounts a
      ON a.channel = 'BB'
     AND COALESCE(bb_map.root_id, bb.account_id::varchar) = a.report_account_id
    CROSS JOIN params p
    WHERE bb.delete_time IS NULL
      AND bb.report_date >= p.start_date
      AND bb.report_date < p.end_date
    GROUP BY a.input_account_id
),
qi_dws AS (
    SELECT
        a.input_account_id,
        COUNT(DISTINCT qi.account_id) AS dws_account_count,
        COUNT(*) AS dws_row_count,
        COALESCE(SUM(
            COALESCE(qi.cost_reimbursement_base_amt, 0) * COALESCE(qi.cost_reimbursement_rate, 1)
          + COALESCE(qi.cost_service_base_amt, 0) * COALESCE(qi.cost_service_rate, 1)
          + COALESCE(qi.cost_acs_regular_base_amt, 0) * COALESCE(qi.cost_acs_regular_rate, 1)
          + COALESCE(qi.cost_acs_vip_base_amt, 0) * COALESCE(qi.cost_acs_vip_rate, 1)
          + COALESCE(qi.cost_vrm_base_amt, 0) * COALESCE(qi.cost_vrm_rate, 1)
          + COALESCE(qi.cost_hk_regular_base_amt, 0) * COALESCE(qi.cost_hk_regular_rate, 1)
          + COALESCE(qi.cost_hk_vip_base_amt, 0) * COALESCE(qi.cost_hk_vip_rate, 1)
          + COALESCE(qi.cost_dcsf_base_amt, 0) * COALESCE(qi.cost_dcsf_rate, 1)
        ) FILTER (WHERE qi.special_fee_type IS NULL), 0)
        + COALESCE(SUM(COALESCE(qi.cost_fixed_fee, 0)) FILTER (WHERE qi.special_fee_type = 'CHANNEL_FIXED_FEE'), 0) AS query_channel_cost,
        SUM(COALESCE(qi.rebate_interchange_base_amt, 0) * COALESCE(qi.rebate_interchange_rate, 1))
            FILTER (WHERE qi.special_fee_type IS NULL) AS qi_interchange_cashback_income,
        SUM(COALESCE(qi.rebate_incentive_base_amt, 0) * COALESCE(qi.rebate_incentive_rate, 1))
            FILTER (WHERE qi.special_fee_type IS NULL) AS qi_incentive_cashback_income
    FROM dws.dws_qi_card_finance_daily_v2_p qi
    LEFT JOIN api_account_map qi_map
      ON qi_map.account_id = qi.account_id::varchar
    JOIN selected_accounts a
      ON a.channel = 'QI'
     AND COALESCE(qi_map.root_id, qi.account_id::varchar) = a.report_account_id
    CROSS JOIN params p
    WHERE qi.delete_time IS NULL
      AND qi.report_date >= p.start_date
      AND qi.report_date < p.end_date
    GROUP BY a.input_account_id
),
query_results AS (
    SELECT
        a.channel,
        a.input_account_id,
        a.report_account_id,
        a.account_name,
        a.report_cost,
        a.report_channel_cost,
        a.report_customer_cashback_cost,
        a.report_bank_fee_cost,
        b.query_channel_cost,
        b.bb_channel_cashback_income AS channel_cashback_income,
        b.dws_account_count,
        b.dws_row_count
    FROM selected_accounts a
    LEFT JOIN bb_dws b
      ON b.input_account_id = a.input_account_id
    WHERE a.channel = 'BB'

    UNION ALL

    SELECT
        a.channel,
        a.input_account_id,
        a.report_account_id,
        a.account_name,
        a.report_cost,
        a.report_channel_cost,
        a.report_customer_cashback_cost,
        a.report_bank_fee_cost,
        q.query_channel_cost,
        COALESCE(q.qi_interchange_cashback_income, 0) + COALESCE(q.qi_incentive_cashback_income, 0) AS channel_cashback_income,
        q.dws_account_count,
        q.dws_row_count
    FROM selected_accounts a
    LEFT JOIN qi_dws q
      ON q.input_account_id = a.input_account_id
    WHERE a.channel = 'QI'
)
SELECT
    r.channel AS 渠道,
    r.account_name AS 客户名称,
    r.input_account_id AS 客户ID,
    CAST(r.query_channel_cost AS NUMERIC(20, 4)) AS DWS单渠道总成本,
    CAST(r.report_channel_cost AS NUMERIC(20, 4)) AS Excel渠道成本,
    CAST(r.query_channel_cost - r.report_channel_cost AS NUMERIC(20, 4)) AS 差值_DWS减Excel
FROM query_results r
ORDER BY r.channel, r.account_name;
