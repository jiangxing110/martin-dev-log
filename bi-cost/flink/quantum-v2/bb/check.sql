--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-07-20
-- Description:    BB 成本口径对账 SQL
-- Purpose:
--   1. 对比 bi_month/BB客户成本-202606.sql 的原始口径与 V2 基数口径。
--   2. 检查为什么 V2 明细里只有少数成本项有值。
--   3. 输出每个成本项的 original_value / v2_value / diff。
-- Usage:
--   1. 修改 params 中的 start_date / end_date。
--   2. 统一按 report month 维度汇总对账。
--********************************************************************--

WITH params AS (
    SELECT
        DATE '2026-06-01' AS start_date,
        DATE '2026-07-01' AS end_date,
        '2026-06'::text AS month_label,
        0.1::numeric AS active_card_rate
),

-- =========================================================
-- Original 202606 logic: aggregated from the monthly script
-- =========================================================
orig_base AS (
    SELECT
        COALESCE(SUM(q1.master_dom_txn_count), 0) AS master_dom_txn_count,
        COALESCE(SUM(q1.master_int_txn_count), 0) AS master_int_txn_count,
        COALESCE(SUM(q1.visa_dom_txn_count), 0) AS visa_dom_txn_count,
        COALESCE(SUM(q1.visa_int_txn_count), 0) AS visa_int_txn_count,

        COALESCE(SUM(q2.ac_master_dom_count), 0) AS ac_master_dom_count,
        COALESCE(SUM(q2.ac_master_int_count), 0) AS ac_master_int_count,
        COALESCE(SUM(q2.ac_visa_dom_count), 0) AS ac_visa_dom_count,
        COALESCE(SUM(q2.ac_visa_int_count), 0) AS ac_visa_int_count,

        COALESCE(SUM(q3.master_dom_net_amount), 0) AS master_dom_net_amount,
        COALESCE(SUM(q3.master_int_net_amount), 0) AS master_int_net_amount,
        COALESCE(SUM(q3.visa_dom_net_amount), 0) AS visa_dom_net_amount,
        COALESCE(SUM(q3.visa_int_net_amount), 0) AS visa_int_net_amount,

        COALESCE(SUM(q4.master_int_reversal_count), 0) AS master_int_reversal_count,
        COALESCE(SUM(q4.visa_int_reversal_count), 0) AS visa_int_reversal_count,
        COALESCE(SUM(q4.dom_reversal_count), 0) AS dom_reversal_count,

        COALESCE(SUM(q5.master_int_refund_count), 0) AS master_int_refund_count,
        COALESCE(SUM(q5.visa_int_refund_count), 0) AS visa_int_refund_count,
        COALESCE(SUM(q5.dom_refund_count), 0) AS dom_refund_count,

        COALESCE(SUM(q6.master_int_decline_count), 0) AS master_int_decline_count,
        COALESCE(SUM(q6.visa_int_decline_count), 0) AS visa_int_decline_count,
        COALESCE(SUM(q6.dom_decline_count), 0) AS dom_decline_count,

        COALESCE(SUM(q7.ac_master_int_decline_count), 0) AS ac_master_int_decline_count,
        COALESCE(SUM(q7.ac_visa_int_decline_count), 0) AS ac_visa_int_decline_count,
        COALESCE(SUM(q7.ac_dom_decline_count), 0) AS ac_dom_decline_count,

        COALESCE(SUM(q8.active_card_account_fee), 0) AS active_card_account_fee
    FROM (
        SELECT
            master_client_id,
            master_dom_txn_count,
            master_int_txn_count,
            visa_dom_txn_count,
            visa_int_txn_count
        FROM (
            SELECT
                AM.master_client_id,
                COUNT(DISTINCT CASE WHEN T.country IN ('US', 'USA') AND T.card_type = 'Master' THEN T.source_id END) AS master_dom_txn_count,
                COUNT(DISTINCT CASE WHEN T.country NOT IN ('US', 'USA') AND T.card_type = 'Master' THEN T.source_id END) AS master_int_txn_count,
                COUNT(DISTINCT CASE WHEN T.country IN ('US', 'USA') AND T.card_type = 'VISA' THEN T.source_id END) AS visa_dom_txn_count,
                COUNT(DISTINCT CASE WHEN T.country NOT IN ('US', 'USA') AND T.card_type = 'VISA' THEN T.source_id END) AS visa_int_txn_count
            FROM tmp_txn_base T
            INNER JOIN tmp_account_master AM ON T.account_id = AM.account_id
            LEFT JOIN tmp_settlement_base S ON T.source_id = S.transaction_id
            CROSS JOIN params p
            WHERE T.type = 'Consumption'
              AND T.business_code_list::TEXT NOT LIKE '%1010%'
              AND T.transaction_time >= p.start_date
              AND T.transaction_time < p.end_date
              AND (S.settlement_id IS NOT NULL OR T.remarks = '超时自动关单')
              AND S.response_code = 'APPROVE'
              AND S.transaction_type IN ('authorization.clearing', 'authorization.reversal')
              AND NOT EXISTS (SELECT 1 FROM tmp_excluded_settlement_ids E WHERE E.settlement_id = S.settlement_id)
            GROUP BY AM.master_client_id
        ) q1
        GROUP BY master_client_id, master_dom_txn_count, master_int_txn_count, visa_dom_txn_count, visa_int_txn_count
    ) q1
    FULL OUTER JOIN (
        SELECT
            AM.master_client_id,
            COUNT(DISTINCT CASE WHEN T.country IN ('US', 'USA') AND T.card_type = 'Master' THEN T.source_id END) AS ac_master_dom_count,
            COUNT(DISTINCT CASE WHEN T.country NOT IN ('US', 'USA') AND T.card_type = 'Master' THEN T.source_id END) AS ac_master_int_count,
            COUNT(DISTINCT CASE WHEN T.country IN ('US', 'USA') AND T.card_type = 'VISA' THEN T.source_id END) AS ac_visa_dom_count,
            COUNT(DISTINCT CASE WHEN T.country NOT IN ('US', 'USA') AND T.card_type = 'VISA' THEN T.source_id END) AS ac_visa_int_count
        FROM tmp_txn_base T
        INNER JOIN tmp_account_master AM ON T.account_id = AM.account_id
        LEFT JOIN tmp_settlement_base S ON T.source_id = S.transaction_id
        CROSS JOIN params p
        WHERE T.type = 'Consumption'
          AND T.business_code_list::TEXT LIKE '%1010%'
          AND T.transaction_time >= p.start_date
          AND T.transaction_time < p.end_date
          AND (S.settlement_id IS NULL
               OR (NOT EXISTS (SELECT 1 FROM tmp_excluded_settlement_ids E WHERE E.settlement_id = S.settlement_id)
                   AND (S.response_code IS NULL OR S.response_code != 'DECLINE')))
        GROUP BY AM.master_client_id
    ) q2 ON TRUE
    FULL OUTER JOIN (
        SELECT
            AM.master_client_id,
            -COALESCE(SUM(CASE WHEN region = 'Domestic' AND card_type = 'Master' THEN net_amount END), 0) AS master_dom_net_amount,
            -COALESCE(SUM(CASE WHEN region = 'International' AND card_type = 'Master' THEN net_amount END), 0) AS master_int_net_amount,
            -COALESCE(SUM(CASE WHEN region = 'Domestic' AND card_type = 'VISA' THEN net_amount END), 0) AS visa_dom_net_amount,
            -COALESCE(SUM(CASE WHEN region = 'International' AND card_type = 'VISA' THEN net_amount END), 0) AS visa_int_net_amount
        FROM (
            SELECT
                AM.master_client_id,
                CASE WHEN RIGHT(S.txn_location, 2) IN ('US','USA') THEN 'Domestic' ELSE 'International' END AS region,
                T.card_type,
                COALESCE(SUM(S.billing_amount), 0) AS net_amount
            FROM tmp_txn_base T
            INNER JOIN tmp_account_master AM ON T.account_id = AM.account_id
            LEFT JOIN tmp_settlement_base S
                ON T.card_transaction_id = S.qbit_card_transaction_id
               AND S.provider = 'BlueBancCard'
               AND S.transaction_type = 'authorization.clearing'
               AND NOT EXISTS (SELECT 1 FROM tmp_excluded_settlement_ids E WHERE E.settlement_id = S.settlement_id)
            CROSS JOIN params p
            WHERE T.type IN ('Credit','Consumption')
              AND T.original_completion_time >= p.start_date
              AND T.original_completion_time < p.end_date
              AND S.response_code = 'APPROVE'
              AND T.card_type IN ('Master', 'VISA')
            GROUP BY AM.master_client_id, region, T.card_type
            UNION ALL
            SELECT
                AM.master_client_id,
                CASE WHEN RIGHT(S.txn_location, 2) IN ('US','USA') THEN 'Domestic' ELSE 'International' END AS region,
                T.card_type,
                COALESCE(SUM(S.billing_amount), 0) AS net_amount
            FROM tmp_txn_base T
            INNER JOIN tmp_account_master AM ON T.account_id = AM.account_id
            LEFT JOIN tmp_settlement_base S
                ON T.card_transaction_id = S.qbit_card_transaction_id
               AND S.provider = 'BlueBancCard'
               AND S.transaction_type = 'refund.clearing'
               AND NOT EXISTS (SELECT 1 FROM tmp_excluded_settlement_ids E WHERE E.settlement_id = S.settlement_id)
            CROSS JOIN params p
            WHERE T.type IN ('Credit','Consumption')
              AND T.original_completion_time >= p.start_date
              AND T.original_completion_time < p.end_date
              AND S.response_code = 'APPROVE'
              AND T.card_type IN ('Master', 'VISA')
            GROUP BY AM.master_client_id, region, T.card_type
        ) amount_detail
        INNER JOIN tmp_account_master AM ON 1 = 1
        GROUP BY AM.master_client_id
    ) q3 ON TRUE
    FULL OUTER JOIN (
        SELECT
            AM.master_client_id,
            COUNT(DISTINCT CASE WHEN T.country NOT IN ('US', 'USA') AND T.card_type = 'Master' AND T.transaction_type = 'authorization.reversal' AND T.resp_code = 'APPROVE' AND T.reason_code = 'APPROVE' THEN T.source_id END) AS master_int_reversal_count,
            COUNT(DISTINCT CASE WHEN T.country NOT IN ('US', 'USA') AND T.card_type = 'VISA' AND T.transaction_type = 'authorization.reversal' AND T.resp_code = 'APPROVE' AND T.reason_code = 'APPROVE' THEN T.source_id END) AS visa_int_reversal_count,
            COUNT(DISTINCT CASE WHEN T.country IN ('US', 'USA') AND T.transaction_type = 'authorization.reversal' AND T.resp_code = 'APPROVE' AND T.reason_code = 'APPROVE' THEN T.source_id END) AS dom_reversal_count
        FROM tmp_txn_base T
        INNER JOIN tmp_account_master AM ON T.account_id = AM.account_id
        CROSS JOIN params p
        WHERE T.type = 'Consumption'
          AND T.business_code_list::TEXT NOT LIKE '%1010%'
          AND T.transaction_time >= p.start_date
          AND T.transaction_time < p.end_date
        GROUP BY AM.master_client_id
    ) q4 ON TRUE
    FULL OUTER JOIN (
        SELECT
            AM.master_client_id,
            COUNT(DISTINCT CASE WHEN T.card_org = 'Master' AND T.settle_country NOT IN ('US', 'USA') AND T.transaction_type = 'refund.clearing' AND T.resp_code = 'APPROVE' THEN T.source_id END) AS master_int_refund_count,
            COUNT(DISTINCT CASE WHEN T.card_org = 'VISA' AND T.settle_country NOT IN ('US', 'USA') AND T.transaction_type = 'refund.clearing' AND T.resp_code = 'APPROVE' THEN T.source_id END) AS visa_int_refund_count,
            COUNT(DISTINCT CASE WHEN T.settle_country IN ('US', 'USA') AND T.transaction_type = 'refund.clearing' AND T.resp_code = 'APPROVE' THEN T.source_id END) AS dom_refund_count
        FROM tmp_txn_base T
        INNER JOIN tmp_account_master AM ON T.account_id = AM.account_id
        CROSS JOIN params p
        WHERE T.type IN ('Credit','Consumption')
          AND T.original_completion_time >= p.start_date
          AND T.original_completion_time < p.end_date
        GROUP BY AM.master_client_id
    ) q5 ON TRUE
    FULL OUTER JOIN (
        SELECT
            AM.master_client_id,
            COUNT(DISTINCT CASE WHEN T.card_org = 'Master' AND T.tx_country NOT IN ('US', 'USA') AND T.resp_code = 'DECLINE' THEN T.source_id END) AS master_int_decline_count,
            COUNT(DISTINCT CASE WHEN T.card_org = 'VISA' AND T.tx_country NOT IN ('US', 'USA') AND T.resp_code = 'DECLINE' THEN T.source_id END) AS visa_int_decline_count,
            COUNT(DISTINCT CASE WHEN T.tx_country IN ('US', 'USA') AND T.resp_code = 'DECLINE' THEN T.source_id END) AS dom_decline_count
        FROM tmp_txn_base T
        INNER JOIN tmp_account_master AM ON T.account_id = AM.account_id
        CROSS JOIN params p
        WHERE T.type = 'Consumption'
          AND T.business_code_list::TEXT NOT LIKE '%1010%'
          AND T.transaction_time >= p.start_date
          AND T.transaction_time < p.end_date
        GROUP BY AM.master_client_id
    ) q6 ON TRUE
    FULL OUTER JOIN (
        SELECT
            AM.master_client_id,
            COUNT(DISTINCT CASE WHEN T.card_org = 'Master' AND T.tx_country NOT IN ('US', 'USA') AND T.is_account_verification = TRUE AND T.is_decline = TRUE THEN T.auth_txn_guid END) AS ac_master_int_decline_count,
            COUNT(DISTINCT CASE WHEN T.card_org = 'VISA' AND T.tx_country NOT IN ('US', 'USA') AND T.is_account_verification = TRUE AND T.is_decline = TRUE THEN T.auth_txn_guid END) AS ac_visa_int_decline_count,
            COUNT(DISTINCT CASE WHEN T.tx_country IN ('US', 'USA') AND T.is_account_verification = TRUE AND T.is_decline = TRUE THEN T.auth_txn_guid END) AS ac_dom_decline_count
        FROM tmp_txn_base T
        INNER JOIN tmp_account_master AM ON T.account_id = AM.account_id
        CROSS JOIN params p
        WHERE T.type = 'Consumption'
          AND T.business_code_list::TEXT LIKE '%1010%'
          AND T.transaction_time >= p.start_date
          AND T.transaction_time < p.end_date
        GROUP BY AM.master_client_id
    ) q7 ON TRUE
    FULL OUTER JOIN (
        SELECT
            AM.master_client_id,
            COUNT(DISTINCT A."Card Proxy") * p.active_card_rate AS active_card_account_fee
        FROM "account" A
        INNER JOIN tmp_account_master AM ON A."id" = AM.account_id
        CROSS JOIN params p
        GROUP BY AM.master_client_id, p.active_card_rate
    ) q8 ON TRUE
),

orig_cost AS (
    SELECT 'bbMasterDomCnt' AS cost_item, COALESCE(master_dom_txn_count, 0) * 0.1090 AS original_value FROM orig_base
    UNION ALL SELECT 'bbMasterIntCnt', COALESCE(master_int_txn_count, 0) * 0.4845 FROM orig_base
    UNION ALL SELECT 'bbVisaDomCnt', COALESCE(visa_dom_txn_count, 0) * 0.0725 FROM orig_base
    UNION ALL SELECT 'bbVisaIntCnt', COALESCE(visa_int_txn_count, 0) * 0.4770 FROM orig_base
    UNION ALL SELECT 'bbMasterIntDecline', COALESCE(master_int_decline_count, 0) * 0.3595 FROM orig_base
    UNION ALL SELECT 'bbVisaIntDecline', COALESCE(visa_int_decline_count, 0) * 0.3570 FROM orig_base
    UNION ALL SELECT 'bbDomDecline', COALESCE(dom_decline_count, 0) * 0.0890 FROM orig_base
    UNION ALL SELECT 'bbMasterIntReversal', COALESCE(master_int_reversal_count, 0) * 0.7190 FROM orig_base
    UNION ALL SELECT 'bbVisaIntReversal', COALESCE(visa_int_reversal_count, 0) * 0.7140 FROM orig_base
    UNION ALL SELECT 'bbDomReversal', COALESCE(dom_reversal_count, 0) * 0.1780 FROM orig_base
    UNION ALL SELECT 'bbMasterIntRefund', COALESCE(master_int_refund_count, 0) * 0.4845 FROM orig_base
    UNION ALL SELECT 'bbVisaIntRefund', COALESCE(visa_int_refund_count, 0) * 0.4770 FROM orig_base
    UNION ALL SELECT 'bbDomRefund', COALESCE(dom_refund_count, 0) * 0.1090 FROM orig_base
    UNION ALL SELECT 'bbAcMasterDomCnt', COALESCE(ac_master_dom_count, 0) * 0.1090 FROM orig_base
    UNION ALL SELECT 'bbAcMasterIntCnt', COALESCE(ac_master_int_count, 0) * 0.4845 FROM orig_base
    UNION ALL SELECT 'bbAcVisaDomCnt', COALESCE(ac_visa_dom_count, 0) * 0.0725 FROM orig_base
    UNION ALL SELECT 'bbAcVisaIntCnt', COALESCE(ac_visa_int_count, 0) * 0.4770 FROM orig_base
    UNION ALL SELECT 'bbAcMasterIntDecline', COALESCE(ac_master_int_decline_count, 0) * 0.3595 FROM orig_base
    UNION ALL SELECT 'bbAcVisaIntDecline', COALESCE(ac_visa_int_decline_count, 0) * 0.3570 FROM orig_base
    UNION ALL SELECT 'bbAcDomDecline', COALESCE(ac_dom_decline_count, 0) * 0.0890 FROM orig_base
    UNION ALL SELECT 'bbMasterDomVol', COALESCE(master_dom_net_amount, 0) * -0.0021 FROM orig_base
    UNION ALL SELECT 'bbMasterIntVol', COALESCE(master_int_net_amount, 0) * -0.0111 FROM orig_base
    UNION ALL SELECT 'bbVisaDomVol', COALESCE(visa_dom_net_amount, 0) * -0.0016 FROM orig_base
    UNION ALL SELECT 'bbVisaIntVol', COALESCE(visa_int_net_amount, 0) * -0.0116 FROM orig_base
    UNION ALL SELECT 'bbActiveCardFee', COALESCE(active_card_account_fee, 0) FROM orig_base
),

-- =========================================================
-- V2 logic: from dws.dws_bb_card_finance_daily_v2_p
-- =========================================================
v2_cost AS (
    SELECT 'bbMasterDomCnt' AS cost_item, COALESCE(SUM(bb.m_dom_auth_count), 0) * 0.1090 AS v2_value
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbMasterIntCnt', COALESCE(SUM(bb.m_int_auth_count), 0) * 0.4845
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbVisaDomCnt', COALESCE(SUM(bb.v_dom_auth_count), 0) * 0.0725
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbVisaIntCnt', COALESCE(SUM(bb.v_int_auth_count), 0) * 0.4770
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbMasterIntDecline', COALESCE(SUM(bb.m_int_decline_count), 0) * 0.3595
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbVisaIntDecline', COALESCE(SUM(bb.v_int_decline_count), 0) * 0.3570
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbDomDecline', COALESCE(SUM(bb.dom_decline_count), 0) * 0.0890
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbMasterIntReversal', COALESCE(SUM(bb.m_int_reversal_count), 0) * 0.7190
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbVisaIntReversal', COALESCE(SUM(bb.v_int_reversal_count), 0) * 0.7140
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbDomReversal', COALESCE(SUM(bb.dom_reversal_count), 0) * 0.1780
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbMasterIntRefund', COALESCE(SUM(bb.m_int_refund_count), 0) * 0.4845
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbVisaIntRefund', COALESCE(SUM(bb.v_int_refund_count), 0) * 0.4770
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbDomRefund', COALESCE(SUM(bb.dom_refund_count), 0) * 0.1090
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbAcMasterDomCnt', COALESCE(SUM(bb.av_m_dom_count), 0) * 0.1090
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbAcMasterIntCnt', COALESCE(SUM(bb.av_m_int_count), 0) * 0.4845
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbAcVisaDomCnt', COALESCE(SUM(bb.av_v_dom_count), 0) * 0.0725
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbAcVisaIntCnt', COALESCE(SUM(bb.av_v_int_count), 0) * 0.4770
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbAcMasterIntDecline', COALESCE(SUM(bb.ac_m_int_decline_count), 0) * 0.3595
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbAcVisaIntDecline', COALESCE(SUM(bb.ac_v_int_decline_count), 0) * 0.3570
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbAcDomDecline', COALESCE(SUM(bb.ac_dom_decline_count), 0) * 0.0890
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbMasterDomVol', COALESCE(SUM(bb.m_dom_clearing_vol), 0) * -0.0021
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbMasterIntVol', COALESCE(SUM(bb.m_int_clearing_vol), 0) * -0.0111
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbVisaDomVol', COALESCE(SUM(bb.v_dom_clearing_vol), 0) * -0.0016
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbVisaIntVol', COALESCE(SUM(bb.v_int_clearing_vol), 0) * -0.0116
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
    UNION ALL SELECT 'bbActiveCardFee', COALESCE(SUM(bb.active_card_count), 0) * 0.1
    FROM dws.dws_bb_card_finance_daily_v2_p bb CROSS JOIN params p
    WHERE bb.delete_time IS NULL AND bb.report_date >= p.start_date AND bb.report_date < p.end_date
),

check_rows AS (
    SELECT
        COALESCE(o.cost_item, v.cost_item) AS cost_item,
        ROUND(COALESCE(o.original_value, 0)::numeric, 4) AS original_value,
        ROUND(COALESCE(v.v2_value, 0)::numeric, 4) AS v2_value,
        ROUND((COALESCE(v.v2_value, 0) - COALESCE(o.original_value, 0))::numeric, 4) AS diff
    FROM orig_cost o
    FULL OUTER JOIN v2_cost v
        ON o.cost_item = v.cost_item
)

SELECT
    cost_item,
    original_value,
    v2_value,
    diff
FROM check_rows
ORDER BY
    CASE cost_item WHEN 'bbActiveCardFee' THEN 999 ELSE 1 END,
    cost_item;
