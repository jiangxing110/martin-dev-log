WITH channel_cost AS (

    -- BB 总成本
    SELECT
        'BB' AS cost_source,
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
        ) AS cost_amount
    FROM dws.dws_bb_card_finance_daily_v2_p bb
    WHERE bb.delete_time IS NULL
      AND bb.report_date >= DATE '2026-07-01'
      AND bb.report_date <  DATE '2026-08-01'

    UNION ALL

    -- BZ 总成本
    SELECT
        'BZ' AS cost_source,
        SUM(
             COALESCE(bz.refund_base_amt, 0)
                * COALESCE(bz.reimbursement_rate, 0)
          + COALESCE(bz.visa_charges_base_amt, 0)
                * COALESCE(bz.visa_charges_rate, 0)
          + COALESCE(bz.card_create_count, 0)
                * COALESCE(bz.card_setup_rate, 0)
          + COALESCE(bz.card_create_count, 0)
                * COALESCE(bz.account_activation_rate, 0)
          + COALESCE(bz.card_active_count, 0)
                * COALESCE(bz.account_on_file_rate, 0)
          + COALESCE(bz.settlement_volume, 0)
                * COALESCE(bz.service_fee_rate, 0)
          + COALESCE(bz.verify_count, 0)
                * COALESCE(bz.verify_fee_rate, 0)
          + COALESCE(bz.auth_count, 0)
                * COALESCE(bz.auth_fee_rate, 0)
          + COALESCE(bz.clearing_count, 0)
                * COALESCE(bz.clearing_fee_rate, 0)
          + COALESCE(bz.refund_count, 0)
                * COALESCE(bz.refund_fee_rate, 0)
          + COALESCE(bz.reversal_count, 0)
                * COALESCE(bz.reversal_fee_rate, 0)
          + COALESCE(bz.cost_fixed_fee, 0)
        ) AS cost_amount
    FROM dws.dws_bz_card_finance_daily_v2_p bz
    WHERE bz.delete_time IS NULL
      AND bz.report_date >= DATE '2026-07-01'
      AND bz.report_date <  DATE '2026-08-01'

    UNION ALL

    -- QI 总成本
    SELECT
        'QI' AS cost_source,
        SUM(
            COALESCE(qi.cost_reimbursement_base_amt, 0)
                * COALESCE(qi.cost_reimbursement_rate, 0)
          + COALESCE(qi.cost_service_base_amt, 0)
                * COALESCE(qi.cost_service_rate, 0)
          + COALESCE(qi.cost_acs_regular_base_amt, 0)
                * COALESCE(qi.cost_acs_regular_rate, 0)
          + COALESCE(qi.cost_acs_vip_base_amt, 0)
                * COALESCE(qi.cost_acs_vip_rate, 0)
          + COALESCE(qi.cost_vrm_base_amt, 0)
                * COALESCE(qi.cost_vrm_rate, 0)
          + COALESCE(qi.cost_hk_regular_base_amt, 0)
                * COALESCE(qi.cost_hk_regular_rate, 0)
          + COALESCE(qi.cost_hk_vip_base_amt, 0)
                * COALESCE(qi.cost_hk_vip_rate, 0)
          + COALESCE(qi.cost_dcsf_base_amt, 0)
                * COALESCE(qi.cost_dcsf_rate, 0)
          + COALESCE(qi.cost_fixed_fee, 0)
        ) AS cost_amount
    FROM dws.dws_qi_card_finance_daily_v2_p qi
    WHERE qi.delete_time IS NULL
      AND qi.report_date >= DATE '2026-07-01'
      AND qi.report_date <  DATE '2026-08-01'

    UNION ALL

    -- SL 固定费
    SELECT
        'SL' AS cost_source,
        SUM(COALESCE(sl.cost_fixed_fee, 0)) AS cost_amount
    FROM dws.dws_sl_card_finance_daily_p sl
    WHERE sl.delete_time IS NULL
      AND sl.report_date >= DATE '2026-07-01'
      AND sl.report_date <  DATE '2026-08-01'

    UNION ALL

    -- 金融渠道表中的 QUANTUM_CARD 总成本
    SELECT
        'FINANCE_QUANTUM_CARD' AS cost_source,
        SUM(COALESCE(fc.cost_amount, 0)) AS cost_amount
    FROM dwm.dwm_finance_channel_cost_p fc
    WHERE fc.delete_time IS NULL
      AND UPPER(TRIM(fc.product_line)) = 'QUANTUM_CARD'
      AND fc.report_date >= DATE '2026-07-01'
      AND fc.report_date <  DATE '2026-08-01'
),

summary AS (
    SELECT
        cost_source,
        CAST(COALESCE(cost_amount, 0) AS NUMERIC(20, 4)) AS cost_amount
    FROM channel_cost

    UNION ALL

    SELECT
        'TOTAL' AS cost_source,
        CAST(SUM(COALESCE(cost_amount, 0)) AS NUMERIC(20, 4))
    FROM channel_cost
),

result AS (
    SELECT
        cost_source,
        cost_amount,
        CAST(
            cost_amount
            / NULLIF(SUM(cost_amount) OVER (), 0)
            * 100
            AS NUMERIC(20, 4)
        ) AS cost_ratio_pct,
        CASE
            WHEN cost_source = 'TOTAL' THEN 2
            ELSE 1
        END AS sort_order
    FROM summary
)

SELECT
    cost_source,
    cost_amount,
    cost_ratio_pct
FROM result
ORDER BY
    sort_order,
    cost_amount DESC;
		