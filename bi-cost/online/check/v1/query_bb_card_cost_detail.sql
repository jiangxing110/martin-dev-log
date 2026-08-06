--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-07-16
-- Description:    量子卡 BB 渠道成本明细查询
-- Usage:
--   1. 修改 params 中的 start_date / end_date。
--   2. end_date 使用左闭右开，不包含当天。
--   3. 计算口径对齐 BB 渠道明细指标，字段名保持和 BI 指标别名一致。
--********************************************************************--

WITH params AS (
    SELECT
        DATE '2026-05-01' AS start_date,
        DATE '2026-06-01' AS end_date
),
bb_detail AS (
    SELECT
        COALESCE(SUM(bb.m_dom_auth_count * 0.1090), 0) AS "bbMasterDomCnt",
        COALESCE(SUM(bb.m_int_auth_count * 0.4845), 0) AS "bbMasterIntCnt",
        COALESCE(SUM(bb.v_dom_auth_count * 0.0725), 0) AS "bbVisaDomCnt",
        COALESCE(SUM(bb.v_int_auth_count * 0.4700), 0) AS "bbVisaIntCnt",
        COALESCE(SUM(bb.m_int_decline_count * 0.3595), 0) AS "bbMasterIntDecline",
        COALESCE(SUM(bb.v_int_decline_count * 0.3570), 0) AS "bbVisaIntDecline",
        COALESCE(SUM(bb.dom_decline_count * 0.0890), 0) AS "bbDomDecline",
        COALESCE(SUM(bb.m_int_reversal_count * 0.7190), 0) AS "bbMasterIntReversal",
        COALESCE(SUM(bb.v_int_reversal_count * 0.7140), 0) AS "bbVisaIntReversal",
        COALESCE(SUM(bb.dom_reversal_count * 0.1780), 0) AS "bbDomReversal",
        COALESCE(SUM(bb.m_int_refund_count * 0.4845), 0) AS "bbMasterIntRefund",
        COALESCE(SUM(bb.v_int_refund_count * 0.4770), 0) AS "bbVisaIntRefund",
        COALESCE(SUM(bb.dom_refund_count * 0.1090), 0) AS "bbDomRefund",
        COALESCE(SUM(bb.av_m_dom_count * 0.1090), 0) AS "bbAcMasterDomCnt",
        COALESCE(SUM(bb.av_m_int_count * 0.4845), 0) AS "bbAcMasterIntCnt",
        COALESCE(SUM(bb.av_v_dom_count * 0.0725), 0) AS "bbAcVisaDomCnt",
        COALESCE(SUM(bb.av_v_int_count * 0.4770), 0) AS "bbAcVisaIntCnt",
        COALESCE(SUM(bb.m_int_decline_count * 0.3595), 0) AS "bbAcMasterIntDecline",
        COALESCE(SUM(bb.v_int_decline_count * 0.3570), 0) AS "bbAcVisaIntDecline",
        COALESCE(SUM(bb.dom_decline_count * 0.0890), 0) AS "bbAcDomDecline",
        COALESCE(SUM(bb.m_dom_clearing_vol * -0.0021), 0) AS "bbMasterDomVol",
        COALESCE(SUM(bb.m_int_clearing_vol * -0.0111), 0) AS "bbMasterIntVol",
        COALESCE(SUM(bb.v_dom_clearing_vol * -0.0016), 0) AS "bbVisaDomVol",
        COALESCE(SUM(bb.v_int_clearing_vol * -0.0116), 0) AS "bbVisaIntVol",
        COALESCE(SUM(bb.active_card_count * 0.1000), 0) AS "bbActiveCardFee",
        COALESCE(SUM(bb.cost_fixed_fee), 0) AS "bbFixedFee"
    FROM dws.dws_bb_card_finance_daily_p bb
    CROSS JOIN params p
    WHERE bb.delete_time IS NULL
      AND bb.report_date >= p.start_date
      AND bb.report_date < p.end_date
),
bb_cost_item AS (
    SELECT 'bbMasterDomCnt' AS cost_item, "bbMasterDomCnt" AS cost_amount FROM bb_detail
    UNION ALL SELECT 'bbMasterIntCnt', "bbMasterIntCnt" FROM bb_detail
    UNION ALL SELECT 'bbVisaDomCnt', "bbVisaDomCnt" FROM bb_detail
    UNION ALL SELECT 'bbVisaIntCnt', "bbVisaIntCnt" FROM bb_detail
    UNION ALL SELECT 'bbMasterIntDecline', "bbMasterIntDecline" FROM bb_detail
    UNION ALL SELECT 'bbVisaIntDecline', "bbVisaIntDecline" FROM bb_detail
    UNION ALL SELECT 'bbDomDecline', "bbDomDecline" FROM bb_detail
    UNION ALL SELECT 'bbMasterIntReversal', "bbMasterIntReversal" FROM bb_detail
    UNION ALL SELECT 'bbVisaIntReversal', "bbVisaIntReversal" FROM bb_detail
    UNION ALL SELECT 'bbDomReversal', "bbDomReversal" FROM bb_detail
    UNION ALL SELECT 'bbMasterIntRefund', "bbMasterIntRefund" FROM bb_detail
    UNION ALL SELECT 'bbVisaIntRefund', "bbVisaIntRefund" FROM bb_detail
    UNION ALL SELECT 'bbDomRefund', "bbDomRefund" FROM bb_detail
    UNION ALL SELECT 'bbAcMasterDomCnt', "bbAcMasterDomCnt" FROM bb_detail
    UNION ALL SELECT 'bbAcMasterIntCnt', "bbAcMasterIntCnt" FROM bb_detail
    UNION ALL SELECT 'bbAcVisaDomCnt', "bbAcVisaDomCnt" FROM bb_detail
    UNION ALL SELECT 'bbAcVisaIntCnt', "bbAcVisaIntCnt" FROM bb_detail
    UNION ALL SELECT 'bbAcMasterIntDecline', "bbAcMasterIntDecline" FROM bb_detail
    UNION ALL SELECT 'bbAcVisaIntDecline', "bbAcVisaIntDecline" FROM bb_detail
    UNION ALL SELECT 'bbAcDomDecline', "bbAcDomDecline" FROM bb_detail
    UNION ALL SELECT 'bbMasterDomVol', "bbMasterDomVol" FROM bb_detail
    UNION ALL SELECT 'bbMasterIntVol', "bbMasterIntVol" FROM bb_detail
    UNION ALL SELECT 'bbVisaDomVol', "bbVisaDomVol" FROM bb_detail
    UNION ALL SELECT 'bbVisaIntVol', "bbVisaIntVol" FROM bb_detail
    UNION ALL SELECT 'bbActiveCardFee', "bbActiveCardFee" FROM bb_detail
    UNION ALL SELECT 'bbFixedFee', "bbFixedFee" FROM bb_detail
),
result_detail AS (
    SELECT cost_item, CAST(COALESCE(cost_amount, 0) AS NUMERIC(20, 4)) AS cost_amount
    FROM bb_cost_item

    UNION ALL

    SELECT 'TOTAL' AS cost_item, CAST(COALESCE(SUM(cost_amount), 0) AS NUMERIC(20, 4)) AS cost_amount
    FROM bb_cost_item
)
SELECT
    cost_item,
    cost_amount
FROM result_detail
ORDER BY
    CASE cost_item WHEN 'TOTAL' THEN 999 ELSE 1 END,
    cost_item;
