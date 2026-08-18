--********************************************************************--
-- Author:         WorkBuddy
-- Created Time:   2026-08-18
-- Description:    从 DWM 直算 BB 7 月成本（v2，UNION ALL 结构，对齐 batch monthly-cdc）
-- 说明：v1 用 4 路 FULL JOIN 聚合，多 key 组合可能拆错费用；v2 改为 batch 脚本的
--       UNION ALL + GROUP BY 结构，消除聚合歧义。结果与 v1 对比验证。
-- 输出：一行指标（同 v1），重点看 dwm_direct_cost 是否仍 ≈ 432,030。
--********************************************************************--

WITH params AS (
    SELECT DATE '2026-07-01' AS month_start,
           DATE '2026-08-01' AS month_end
),
excluded_settlements AS (
    SELECT unnest(ARRAY[
        '234e26db-0e1d-424f-952b-053ab2e42d30',
        '82ff7fa6-8035-4c7b-8c18-ace860c3dfae',
        '711e7995-ea26-499f-a1c5-9e4faf15f31f',
        '5e974989-8792-401f-93b6-b107e0b46e51',
        '0af98098-eb5e-4d5b-a5ad-76c1b1c0ae72',
        'a97006e9-2609-4e70-a165-2ae6b9f49689',
        'ad861604-ff4f-4cd1-997e-fe613c67970e',
        '37959ee2-880f-49ea-8d74-976a69382c90',
        'bebf7744-ed33-46cd-8ca6-40bc43d928eb',
        'ece578c8-e8c1-46ec-83b9-116ea049a2e8',
        '69e04460-0cb4-4d9d-9001-2b786cfc3d7b',
        '7fa7ea4f-40fa-4153-9ec1-426f4b2c5470',
        'cff4d9c4-ee01-43fa-9518-62872afbbe91',
        '160b403b-2a16-4b43-afac-a3b37916c968',
        '0fd4e8ed-e208-44e5-b463-ece053a915f3',
        '4a63f4ec-637e-4627-a668-5339fe64b9be'
    ]) AS settlement_id
),
txn AS (
    SELECT t.*,
           COALESCE(t.settlement_id IN (SELECT settlement_id FROM excluded_settlements), FALSE) AS is_excluded_settlement
    FROM dwm.dwm_bb_card_transaction_detail_v2_p t, params p
    WHERE t.delete_time IS NULL
      AND ( (t.transaction_time        >= p.month_start AND t.transaction_time        < p.month_end)
         OR (t.original_completion_time >= p.month_start AND t.original_completion_time < p.month_end)
         OR (t.settlement_post_date     >= p.month_start AND t.settlement_post_date     < p.month_end) )
),
-- 计数（transaction_time 归月，08:00 窗口；每 source 一行 MAX，再按账户 SUM —— 对齐 batch）
txn_count_rows AS (
    SELECT account_id, COALESCE(sale_id, '') AS sale_id, COALESCE(am_id, '') AS am_id, source_id,
        MAX(CASE WHEN business_type='Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org='Master' AND tx_country IN ('US','USA') AND resp_code='APPROVE' AND transaction_type IN ('authorization.clearing','authorization.reversal') AND is_excluded_settlement=FALSE THEN 1 ELSE 0 END) AS m_dom_auth,
        MAX(CASE WHEN business_type='Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org='Master' AND tx_country NOT IN ('US','USA') AND resp_code='APPROVE' AND transaction_type IN ('authorization.clearing','authorization.reversal') AND is_excluded_settlement=FALSE THEN 1 ELSE 0 END) AS m_int_auth,
        MAX(CASE WHEN business_type='Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org='VISA' AND tx_country IN ('US','USA') AND resp_code='APPROVE' AND transaction_type IN ('authorization.clearing','authorization.reversal') AND is_excluded_settlement=FALSE THEN 1 ELSE 0 END) AS v_dom_auth,
        MAX(CASE WHEN business_type='Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org='VISA' AND tx_country NOT IN ('US','USA') AND resp_code='APPROVE' AND transaction_type IN ('authorization.clearing','authorization.reversal') AND is_excluded_settlement=FALSE THEN 1 ELSE 0 END) AS v_int_auth,
        MAX(CASE WHEN business_type='Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org='Master' AND tx_country NOT IN ('US','USA') AND resp_code='APPROVE' AND reason_code='APPROVE' AND transaction_type='authorization.reversal' AND is_excluded_settlement=FALSE THEN 1 ELSE 0 END) AS m_int_reversal,
        MAX(CASE WHEN business_type='Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org='VISA' AND tx_country NOT IN ('US','USA') AND resp_code='APPROVE' AND reason_code='APPROVE' AND transaction_type='authorization.reversal' AND is_excluded_settlement=FALSE THEN 1 ELSE 0 END) AS v_int_reversal,
        MAX(CASE WHEN business_type='Consumption' AND business_code_list NOT LIKE '%1010%' AND tx_country IN ('US','USA') AND resp_code='APPROVE' AND reason_code='APPROVE' AND transaction_type='authorization.reversal' AND is_excluded_settlement=FALSE THEN 1 ELSE 0 END) AS dom_reversal,
        MAX(CASE WHEN business_type='Consumption' AND business_code_list LIKE '%1010%' AND card_org='Master' AND tx_country IN ('US','USA') AND is_excluded_settlement=FALSE AND (resp_code IS NULL OR resp_code<>'DECLINE') THEN 1 ELSE 0 END) AS av_m_dom,
        MAX(CASE WHEN business_type='Consumption' AND business_code_list LIKE '%1010%' AND card_org='Master' AND tx_country NOT IN ('US','USA') AND is_excluded_settlement=FALSE AND (resp_code IS NULL OR resp_code<>'DECLINE') THEN 1 ELSE 0 END) AS av_m_int,
        MAX(CASE WHEN business_type='Consumption' AND business_code_list LIKE '%1010%' AND card_org='VISA' AND tx_country IN ('US','USA') AND is_excluded_settlement=FALSE AND (resp_code IS NULL OR resp_code<>'DECLINE') THEN 1 ELSE 0 END) AS av_v_dom,
        MAX(CASE WHEN business_type='Consumption' AND business_code_list LIKE '%1010%' AND card_org='VISA' AND tx_country NOT IN ('US','USA') AND is_excluded_settlement=FALSE AND (resp_code IS NULL OR resp_code<>'DECLINE') THEN 1 ELSE 0 END) AS av_v_int,
        0 AS m_int_refund, 0 AS v_int_refund, 0 AS dom_refund
    FROM txn t, params p
    WHERE t.transaction_time >= p.month_start + INTERVAL '8 HOUR'
      AND t.transaction_time <  p.month_end   + INTERVAL '8 HOUR'
      AND t.source_id IS NOT NULL
    GROUP BY account_id, COALESCE(sale_id, ''), COALESCE(am_id, ''), source_id
),
-- refund 计数（settlement_post_date 归月）
post_count_rows AS (
    SELECT account_id, COALESCE(sale_id, '') AS sale_id, COALESCE(am_id, '') AS am_id, source_id,
        0 AS m_dom_auth, 0 AS m_int_auth, 0 AS v_dom_auth, 0 AS v_int_auth,
        0 AS m_int_reversal, 0 AS v_int_reversal, 0 AS dom_reversal,
        0 AS av_m_dom, 0 AS av_m_int, 0 AS av_v_dom, 0 AS av_v_int,
        MAX(CASE WHEN business_type='Credit' AND card_org='Master' AND settle_country NOT IN ('US','USA') AND transaction_type='refund.clearing' AND resp_code='APPROVE' AND is_excluded_settlement=FALSE THEN 1 ELSE 0 END) AS m_int_refund,
        MAX(CASE WHEN business_type='Credit' AND card_org='VISA' AND settle_country NOT IN ('US','USA') AND transaction_type='refund.clearing' AND resp_code='APPROVE' AND is_excluded_settlement=FALSE THEN 1 ELSE 0 END) AS v_int_refund,
        MAX(CASE WHEN business_type='Credit' AND settle_country IN ('US','USA') AND transaction_type='refund.clearing' AND resp_code='APPROVE' AND is_excluded_settlement=FALSE THEN 1 ELSE 0 END) AS dom_refund
    FROM txn t, params p
    WHERE t.settlement_post_date >= p.month_start
      AND t.settlement_post_date <  p.month_end
      AND t.source_id IS NOT NULL
    GROUP BY account_id, COALESCE(sale_id, ''), COALESCE(am_id, ''), source_id
),
count_metrics AS (
    SELECT account_id, sale_id, am_id,
        SUM(m_dom_auth) AS m_dom_auth_count, SUM(m_int_auth) AS m_int_auth_count,
        SUM(v_dom_auth) AS v_dom_auth_count, SUM(v_int_auth) AS v_int_auth_count,
        SUM(m_int_reversal) AS m_int_reversal_count, SUM(v_int_reversal) AS v_int_reversal_count,
        SUM(dom_reversal) AS dom_reversal_count,
        SUM(av_m_dom) AS av_m_dom_count, SUM(av_m_int) AS av_m_int_count,
        SUM(av_v_dom) AS av_v_dom_count, SUM(av_v_int) AS av_v_int_count,
        SUM(m_int_refund) AS m_int_refund_count, SUM(v_int_refund) AS v_int_refund_count,
        SUM(dom_refund) AS dom_refund_count
    FROM (SELECT * FROM txn_count_rows UNION ALL SELECT * FROM post_count_rows) u
    GROUP BY account_id, sale_id, am_id
),
-- 金额（original_completion_time 归月）
amount_metrics AS (
    SELECT account_id, COALESCE(sale_id, '') AS sale_id, COALESCE(am_id, '') AS am_id,
        SUM(CASE WHEN business_type IN ('Credit','Consumption') AND card_org='Master' AND settle_country IN ('US','USA') AND transaction_type IN ('authorization.clearing','refund.clearing') AND settlement_match_type='card_transaction_id' AND resp_code='APPROVE' AND is_excluded_settlement=FALSE THEN -billing_amount ELSE 0 END) AS m_dom_vol,
        SUM(CASE WHEN business_type IN ('Credit','Consumption') AND card_org='Master' AND settle_country NOT IN ('US','USA') AND transaction_type IN ('authorization.clearing','refund.clearing') AND settlement_match_type='card_transaction_id' AND resp_code='APPROVE' AND is_excluded_settlement=FALSE THEN -billing_amount ELSE 0 END) AS m_int_vol,
        SUM(CASE WHEN business_type IN ('Credit','Consumption') AND card_org='VISA' AND settle_country IN ('US','USA') AND transaction_type IN ('authorization.clearing','refund.clearing') AND settlement_match_type='card_transaction_id' AND resp_code='APPROVE' AND is_excluded_settlement=FALSE THEN -billing_amount ELSE 0 END) AS v_dom_vol,
        SUM(CASE WHEN business_type IN ('Credit','Consumption') AND card_org='VISA' AND settle_country NOT IN ('US','USA') AND transaction_type IN ('authorization.clearing','refund.clearing') AND settlement_match_type='card_transaction_id' AND resp_code='APPROVE' AND is_excluded_settlement=FALSE THEN -billing_amount ELSE 0 END) AS v_int_vol
    FROM txn t, params p
    WHERE t.original_completion_time >= p.month_start
      AND t.original_completion_time <  p.month_end
    GROUP BY account_id, COALESCE(sale_id, ''), COALESCE(am_id, '')
),
-- auth decline（auth_time 归月）
auth_metrics AS (
    SELECT account_id, COALESCE(sale_id, '') AS sale_id, COALESCE(am_id, '') AS am_id,
        COUNT(DISTINCT CASE WHEN is_decline=TRUE AND is_account_verification=FALSE AND is_excluded_request=FALSE AND card_org='Master' AND is_dom=FALSE THEN auth_txn_guid END) AS m_int_decline,
        COUNT(DISTINCT CASE WHEN is_decline=TRUE AND is_account_verification=FALSE AND is_excluded_request=FALSE AND card_org='VISA' AND is_dom=FALSE THEN auth_txn_guid END) AS v_int_decline,
        COUNT(DISTINCT CASE WHEN is_decline=TRUE AND is_account_verification=FALSE AND is_excluded_request=FALSE AND is_dom=TRUE THEN auth_txn_guid END) AS dom_decline,
        COUNT(DISTINCT CASE WHEN is_decline=TRUE AND is_account_verification=TRUE AND is_excluded_request=FALSE AND card_org='Master' AND is_dom=FALSE THEN auth_txn_guid END) AS ac_m_int_decline,
        COUNT(DISTINCT CASE WHEN is_decline=TRUE AND is_account_verification=TRUE AND is_excluded_request=FALSE AND card_org='VISA' AND is_dom=FALSE THEN auth_txn_guid END) AS ac_v_int_decline,
        COUNT(DISTINCT CASE WHEN is_decline=TRUE AND is_account_verification=TRUE AND is_excluded_request=FALSE AND is_dom=TRUE THEN auth_txn_guid END) AS ac_dom_decline
    FROM dwm.dwm_bb_card_auth_detail_v2_p a, params p
    WHERE a.delete_time IS NULL
      AND a.auth_time >= p.month_start
      AND a.auth_time <  p.month_end
    GROUP BY account_id, COALESCE(sale_id, ''), COALESCE(am_id, '')
),
-- 合并（UNION ALL + GROUP BY，对齐 batch 的 v_dws_bb_daily_base）
merged AS (
    SELECT account_id, sale_id, am_id,
        m_dom_auth_count, m_int_auth_count, v_dom_auth_count, v_int_auth_count,
        m_int_reversal_count, v_int_reversal_count, dom_reversal_count,
        m_int_refund_count, v_int_refund_count, dom_refund_count,
        av_m_dom_count, av_m_int_count, av_v_dom_count, av_v_int_count,
        m_int_decline_count, v_int_decline_count, dom_decline_count,
        ac_m_int_decline_count, ac_v_int_decline_count, ac_dom_decline_count,
        m_dom_vol, m_int_vol, v_dom_vol, v_int_vol
    FROM (
        SELECT c.account_id, c.sale_id, c.am_id,
            c.m_dom_auth_count, c.m_int_auth_count, c.v_dom_auth_count, c.v_int_auth_count,
            c.m_int_reversal_count, c.v_int_reversal_count, c.dom_reversal_count,
            c.m_int_refund_count, c.v_int_refund_count, c.dom_refund_count,
            c.av_m_dom_count, c.av_m_int_count, c.av_v_dom_count, c.av_v_int_count,
            CAST(0 AS BIGINT) AS m_int_decline_count, CAST(0 AS BIGINT) AS v_int_decline_count,
            CAST(0 AS BIGINT) AS dom_decline_count, CAST(0 AS BIGINT) AS ac_m_int_decline_count,
            CAST(0 AS BIGINT) AS ac_v_int_decline_count, CAST(0 AS BIGINT) AS ac_dom_decline_count,
            CAST(0 AS NUMERIC(20,4)) AS m_dom_vol, CAST(0 AS NUMERIC(20,4)) AS m_int_vol,
            CAST(0 AS NUMERIC(20,4)) AS v_dom_vol, CAST(0 AS NUMERIC(20,4)) AS v_int_vol
        FROM count_metrics c
        UNION ALL
        SELECT a.account_id, a.sale_id, a.am_id,
            CAST(0 AS BIGINT), CAST(0 AS BIGINT), CAST(0 AS BIGINT), CAST(0 AS BIGINT),
            CAST(0 AS BIGINT), CAST(0 AS BIGINT), CAST(0 AS BIGINT),
            CAST(0 AS BIGINT), CAST(0 AS BIGINT), CAST(0 AS BIGINT),
            CAST(0 AS BIGINT), CAST(0 AS BIGINT), CAST(0 AS BIGINT), CAST(0 AS BIGINT),
            a.m_int_decline_count, a.v_int_decline_count, a.dom_decline_count,
            a.ac_m_int_decline_count, a.ac_v_int_decline_count, a.ac_dom_decline_count,
            CAST(0 AS NUMERIC(20,4)), CAST(0 AS NUMERIC(20,4)),
            CAST(0 AS NUMERIC(20,4)), CAST(0 AS NUMERIC(20,4))
        FROM auth_metrics a
        UNION ALL
        SELECT m.account_id, m.sale_id, m.am_id,
            CAST(0 AS BIGINT), CAST(0 AS BIGINT), CAST(0 AS BIGINT), CAST(0 AS BIGINT),
            CAST(0 AS BIGINT), CAST(0 AS BIGINT), CAST(0 AS BIGINT),
            CAST(0 AS BIGINT), CAST(0 AS BIGINT), CAST(0 AS BIGINT),
            CAST(0 AS BIGINT), CAST(0 AS BIGINT), CAST(0 AS BIGINT), CAST(0 AS BIGINT),
            CAST(0 AS BIGINT), CAST(0 AS BIGINT), CAST(0 AS BIGINT),
            CAST(0 AS BIGINT), CAST(0 AS BIGINT), CAST(0 AS BIGINT),
            m.m_dom_vol, m.m_int_vol, m.v_dom_vol, m.v_int_vol
        FROM amount_metrics m
    ) u
    GROUP BY account_id, sale_id, am_id
),
base AS (
    SELECT *,
        m_dom_vol + m_int_vol + v_dom_vol + v_int_vol AS total_net_amount
    FROM merged
),
cost_line AS (
    SELECT
        SUM(m_dom_auth_count*0.1090 + m_int_auth_count*0.4845 + v_dom_auth_count*0.0725 + v_int_auth_count*0.4770
          + av_m_dom_count*0.1090 + av_m_int_count*0.4845 + av_v_dom_count*0.0725 + av_v_int_count*0.4770) AS auth_fee,
        SUM(m_int_reversal_count*0.7190 + v_int_reversal_count*0.7140 + dom_reversal_count*0.1780) AS reversal_fee,
        SUM(m_int_refund_count*0.4845 + v_int_refund_count*0.4770 + dom_refund_count*0.1090) AS refund_fee,
        SUM(m_int_decline_count*0.3595 + v_int_decline_count*0.3570 + dom_decline_count*0.0890
          + ac_m_int_decline_count*0.3595 + ac_v_int_decline_count*0.3570 + ac_dom_decline_count*0.0890) AS decline_fee,
        SUM(m_dom_vol*0.0021 + m_int_vol*0.0111 + v_dom_vol*0.0016 + v_int_vol*0.0116) AS dollar_vol_fee,
        SUM(total_net_amount) AS total_net
    FROM base
),
cdc_accounts AS (
    SELECT account_id FROM dws.dws_bb_card_finance_daily_v2_p
    WHERE report_date >= DATE '2026-07-01' AND report_date < DATE '2026-08-01'
      AND remarks = 'bb_v2_cdc' AND delete_time IS NULL
),
cdc_line AS (
    SELECT
        COUNT(DISTINCT b.account_id) AS cdc_account_cnt,
        SUM(b.total_net_amount) AS cdc_net,
        SUM(b.m_dom_auth_count*0.1090 + b.m_int_auth_count*0.4845 + b.v_dom_auth_count*0.0725 + b.v_int_auth_count*0.4770
          + b.av_m_dom_count*0.1090 + b.av_m_int_count*0.4845 + b.av_v_dom_count*0.0725 + b.av_v_int_count*0.4770
          + b.m_int_reversal_count*0.7190 + b.v_int_reversal_count*0.7140 + b.dom_reversal_count*0.1780
          + b.m_int_refund_count*0.4845 + b.v_int_refund_count*0.4770 + b.dom_refund_count*0.1090
          + b.m_int_decline_count*0.3595 + b.v_int_decline_count*0.3570 + b.dom_decline_count*0.0890
          + b.ac_m_int_decline_count*0.3595 + b.ac_v_int_decline_count*0.3570 + b.ac_dom_decline_count*0.0890
          + b.m_dom_vol*0.0021 + b.m_int_vol*0.0111 + b.v_dom_vol*0.0016 + b.v_int_vol*0.0116) AS cdc_fee_part
    FROM base b
    WHERE b.account_id IN (SELECT account_id FROM cdc_accounts)
),
special_line AS (
    SELECT
        COALESCE(SUM(CASE WHEN special_fee_type='ACTIVE_CARD_ACCOUNT_FEE' THEN active_card_count * 0.1 ELSE 0 END), 0) AS active_card_fee,
        COALESCE(SUM(CASE WHEN special_fee_type='CHANNEL_FIXED_FEE' THEN cost_fixed_fee ELSE 0 END), 0) AS fixed_fee
    FROM dws.dws_bb_card_finance_daily_v2_p
    WHERE report_date >= DATE '2026-07-01' AND report_date < DATE '2026-08-01'
      AND delete_time IS NULL
)
SELECT
    ROUND(c.auth_fee, 4) AS auth_fee,
    ROUND(c.reversal_fee, 4) AS reversal_fee,
    ROUND(c.refund_fee, 4) AS refund_fee,
    ROUND(c.decline_fee, 4) AS decline_fee,
    ROUND(c.dollar_vol_fee, 4) AS dollar_vol_fee,
    ROUND(c.total_net, 4) AS total_net,
    ROUND(CASE
        WHEN c.total_net = 0 THEN 0
        WHEN c.total_net <= 5000000 THEN c.total_net * 0.0055
        WHEN c.total_net <= 10000000 THEN 5000000*0.0055 + (c.total_net-5000000)*0.0045
        ELSE 5000000*0.0055 + 5000000*0.0045 + (c.total_net-10000000)*0.004
    END, 4) AS volume_fee_cost,
    ROUND(c.auth_fee + c.reversal_fee + c.refund_fee + c.decline_fee + c.dollar_vol_fee
        + CASE
            WHEN c.total_net = 0 THEN 0
            WHEN c.total_net <= 5000000 THEN c.total_net * 0.0055
            WHEN c.total_net <= 10000000 THEN 5000000*0.0055 + (c.total_net-5000000)*0.0045
            ELSE 5000000*0.0055 + 5000000*0.0045 + (c.total_net-10000000)*0.004
          END, 4) AS dwm_direct_cost,
    cd.cdc_account_cnt AS cdc_account_cnt,
    ROUND(cd.cdc_net, 4) AS cdc_net,
    ROUND(cd.cdc_fee_part, 4) AS cdc_fee_part,
    ROUND(sp.active_card_fee, 4) AS active_card_fee,
    ROUND(sp.fixed_fee, 4) AS fixed_fee
FROM cost_line c
CROSS JOIN cdc_line cd
CROSS JOIN special_line sp;
