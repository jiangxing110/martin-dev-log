--********************************************************************--
-- Author:         WorkBuddy
-- Created Time:   2026-08-18
-- Description:    从 DWM 明细直算 BB 7 月渠道成本（batch 口径），与 DWS 对比
-- 目的：
--   DWS 7 月当前并存两批行（batch 9277 行 + CDC 15 行，v4=458,459.73）；
--   昨晚只有 batch（v4=432,056.00）。本脚本绕过 DWS，直接从 DWM 交易/授权明细
--   按月度 batch（bb_v2_batch_q3_refund_net_20260721）的口径重算 7 月成本：
--     - dwm_direct_cost ≈ 458,459 → CDC 补的 15 个账户是真实 7 月数据，batch 漏写
--     - dwm_direct_cost ≈ 432,056 → CDC 15 行是多余/重复，432,056 才对
--     - 其他值 → 两边口径都需再查
-- 口径说明（对齐 monthly-cdc 脚本）：
--   - 计数(授权/冲正/AV)按 transaction_time 归月，窗口 [月初08:00, 次月月初08:00)
--   - 金额(clearing vol)按 original_completion_time 归月
--   - refund 计数按 settlement_post_date 归月
--   - decline 计数来自 dwm_bb_card_auth_detail_v2_p，按 auth_time 归月
--   - 16 个黑名单 settlement 排除（is_excluded_settlement）
-- 注意：只算主链路成本；DWS 的 active_card_fee / fixed_fee 特殊行不在 DWM 中，
--       末尾 active_card_fee / fixed_fee 列给出 DWS 当前特殊行合计，供全口径对比。
--       全口径 v4 cost = dwm_direct_cost + active_card_fee + fixed_fee
-- 用法：改 month_start / month_end 后直接执行，一行输出所有对比指标。
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
-- ============ 计数：按 transaction_time 归月（08:00 窗口，对齐 batch） ============
txn_count AS (
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
        MAX(CASE WHEN business_type='Consumption' AND business_code_list LIKE '%1010%' AND card_org='VISA' AND tx_country NOT IN ('US','USA') AND is_excluded_settlement=FALSE AND (resp_code IS NULL OR resp_code<>'DECLINE') THEN 1 ELSE 0 END) AS av_v_int
    FROM txn t, params p
    WHERE t.transaction_time >= p.month_start + INTERVAL '8 HOUR'
      AND t.transaction_time <  p.month_end   + INTERVAL '8 HOUR'
      AND t.source_id IS NOT NULL
    GROUP BY account_id, COALESCE(sale_id, ''), COALESCE(am_id, ''), source_id
),
txn_count_agg AS (
    SELECT account_id, sale_id, am_id,
        SUM(m_dom_auth) AS m_dom_auth_count, SUM(m_int_auth) AS m_int_auth_count,
        SUM(v_dom_auth) AS v_dom_auth_count, SUM(v_int_auth) AS v_int_auth_count,
        SUM(m_int_reversal) AS m_int_reversal_count, SUM(v_int_reversal) AS v_int_reversal_count,
        SUM(dom_reversal) AS dom_reversal_count,
        SUM(av_m_dom) AS av_m_dom_count, SUM(av_m_int) AS av_m_int_count,
        SUM(av_v_dom) AS av_v_dom_count, SUM(av_v_int) AS av_v_int_count
    FROM txn_count
    GROUP BY account_id, sale_id, am_id
),
-- ============ 金额：按 original_completion_time 归月 ============
txn_amount AS (
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
-- ============ refund 计数：按 settlement_post_date 归月 ============
txn_post AS (
    SELECT account_id, COALESCE(sale_id, '') AS sale_id, COALESCE(am_id, '') AS am_id,
        SUM(CASE WHEN business_type='Credit' AND card_org='Master' AND settle_country NOT IN ('US','USA') AND transaction_type='refund.clearing' AND resp_code='APPROVE' AND is_excluded_settlement=FALSE THEN 1 ELSE 0 END) AS m_int_refund,
        SUM(CASE WHEN business_type='Credit' AND card_org='VISA' AND settle_country NOT IN ('US','USA') AND transaction_type='refund.clearing' AND resp_code='APPROVE' AND is_excluded_settlement=FALSE THEN 1 ELSE 0 END) AS v_int_refund,
        SUM(CASE WHEN business_type='Credit' AND settle_country IN ('US','USA') AND transaction_type='refund.clearing' AND resp_code='APPROVE' AND is_excluded_settlement=FALSE THEN 1 ELSE 0 END) AS dom_refund
    FROM txn t, params p
    WHERE t.settlement_post_date >= p.month_start
      AND t.settlement_post_date <  p.month_end
    GROUP BY account_id, COALESCE(sale_id, ''), COALESCE(am_id, '')
),
-- ============ decline 计数：auth 表按 auth_time 归月 ============
auth_count AS (
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
-- ============ 重建 DWS 账户粒度（batch 口径） ============
dws_rebuild AS (
    SELECT
        COALESCE(t.account_id, m.account_id, r.account_id, d.account_id) AS account_id,
        COALESCE(t.sale_id, m.sale_id, r.sale_id, d.sale_id) AS sale_id,
        COALESCE(t.am_id, m.am_id, r.am_id, d.am_id) AS am_id,
        COALESCE(t.m_dom_auth_count,0) AS m_dom_auth_count,
        COALESCE(t.m_int_auth_count,0) AS m_int_auth_count,
        COALESCE(t.v_dom_auth_count,0) AS v_dom_auth_count,
        COALESCE(t.v_int_auth_count,0) AS v_int_auth_count,
        COALESCE(t.m_int_reversal_count,0) AS m_int_reversal_count,
        COALESCE(t.v_int_reversal_count,0) AS v_int_reversal_count,
        COALESCE(t.dom_reversal_count,0) AS dom_reversal_count,
        COALESCE(t.av_m_dom_count,0) AS av_m_dom_count,
        COALESCE(t.av_m_int_count,0) AS av_m_int_count,
        COALESCE(t.av_v_dom_count,0) AS av_v_dom_count,
        COALESCE(t.av_v_int_count,0) AS av_v_int_count,
        COALESCE(r.m_int_refund,0) AS m_int_refund_count,
        COALESCE(r.v_int_refund,0) AS v_int_refund_count,
        COALESCE(r.dom_refund,0) AS dom_refund_count,
        COALESCE(d.m_int_decline,0) AS m_int_decline_count,
        COALESCE(d.v_int_decline,0) AS v_int_decline_count,
        COALESCE(d.dom_decline,0) AS dom_decline_count,
        COALESCE(d.ac_m_int_decline,0) AS ac_m_int_decline_count,
        COALESCE(d.ac_v_int_decline,0) AS ac_v_int_decline_count,
        COALESCE(d.ac_dom_decline,0) AS ac_dom_decline_count,
        COALESCE(m.m_dom_vol,0) AS m_dom_clearing_vol,
        COALESCE(m.m_int_vol,0) AS m_int_clearing_vol,
        COALESCE(m.v_dom_vol,0) AS v_dom_clearing_vol,
        COALESCE(m.v_int_vol,0) AS v_int_clearing_vol
    FROM txn_count_agg t
    FULL JOIN txn_amount m USING (account_id, sale_id, am_id)
    FULL JOIN txn_post r USING (account_id, sale_id, am_id)
    FULL JOIN auth_count d USING (account_id, sale_id, am_id)
),
base AS (
    SELECT *,
        m_dom_clearing_vol + m_int_clearing_vol + v_dom_clearing_vol + v_int_clearing_vol AS total_net_amount
    FROM dws_rebuild
),
cost_line AS (
    SELECT
        SUM(m_dom_auth_count*0.1090 + m_int_auth_count*0.4845 + v_dom_auth_count*0.0725 + v_int_auth_count*0.4770
          + av_m_dom_count*0.1090 + av_m_int_count*0.4845 + av_v_dom_count*0.0725 + av_v_int_count*0.4770) AS auth_fee,
        SUM(m_int_reversal_count*0.7190 + v_int_reversal_count*0.7140 + dom_reversal_count*0.1780) AS reversal_fee,
        SUM(m_int_refund_count*0.4845 + v_int_refund_count*0.4770 + dom_refund_count*0.1090) AS refund_fee,
        SUM(m_int_decline_count*0.3595 + v_int_decline_count*0.3570 + dom_decline_count*0.0890
          + ac_m_int_decline_count*0.3595 + ac_v_int_decline_count*0.3570 + ac_dom_decline_count*0.0890) AS decline_fee,
        SUM(m_dom_clearing_vol*0.0021 + m_int_clearing_vol*0.0111 + v_dom_clearing_vol*0.0016 + v_int_clearing_vol*0.0116) AS dollar_vol_fee,
        SUM(total_net_amount) AS total_net
    FROM base
),
-- 15 个 CDC 账户的 DWM 直算（费用部分，不含 volume fee 阶梯）
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
          + b.m_dom_clearing_vol*0.0021 + b.m_int_clearing_vol*0.0111 + b.v_dom_clearing_vol*0.0016 + b.v_int_clearing_vol*0.0116) AS cdc_fee_part
    FROM base b
    WHERE b.account_id IN (SELECT account_id FROM cdc_accounts)
),
-- DWS 当前特殊行合计（active_card_fee + fixed_fee）
special_line AS (
    SELECT
        COALESCE(SUM(CASE WHEN special_fee_type='ACTIVE_CARD_ACCOUNT_FEE' THEN active_card_count * 0.1 ELSE 0 END), 0) AS active_card_fee,
        COALESCE(SUM(CASE WHEN special_fee_type='CHANNEL_FIXED_FEE' THEN cost_fixed_fee ELSE 0 END), 0) AS fixed_fee
    FROM dws.dws_bb_card_finance_daily_v2_p
    WHERE report_date >= DATE '2026-07-01' AND report_date < DATE '2026-08-01'
      AND delete_time IS NULL
)
-- ============ 输出：一行全部对比指标 ============
SELECT
    -- A. DWM 直算全月（batch 口径，含 volume fee）
    ROUND(c.auth_fee, 4)    AS auth_fee,
    ROUND(c.reversal_fee, 4) AS reversal_fee,
    ROUND(c.refund_fee, 4)  AS refund_fee,
    ROUND(c.decline_fee, 4) AS decline_fee,
    ROUND(c.dollar_vol_fee, 4) AS dollar_vol_fee,
    ROUND(c.total_net, 4)   AS total_net,
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
    -- B. 15 个 CDC 账户的 DWM 直算（费用部分，不含 volume fee）
    cd.cdc_account_cnt AS cdc_account_cnt,
    ROUND(cd.cdc_net, 4) AS cdc_net,
    ROUND(cd.cdc_fee_part, 4) AS cdc_fee_part,
    -- C. DWS 特殊行合计（全口径 = dwm_direct_cost + 这两项）
    ROUND(sp.active_card_fee, 4) AS active_card_fee,
    ROUND(sp.fixed_fee, 4) AS fixed_fee
FROM cost_line c
CROSS JOIN cdc_line cd
CROSS JOIN special_line sp;

-- 参考值（用于对比）：
--   DWS 昨晚（仅 batch）：         cost = 432,056.0019
--   DWS 今天（batch + CDC 15行）： cost = 458,459.7274（差 +26,403.7255）
--   对比口径：全口径 = dwm_direct_cost + active_card_fee + fixed_fee
