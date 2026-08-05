--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-05 16:30:00
-- Description:    总渠道成本日汇总普通物化视图
-- Notes:
--   1. 计算口径对齐 dws_online_total_channel_cost_daily-batch-sql.sql。
--   2. 普通物化视图不会自动维护，由 pg_cron 每 5 小时刷新。
--   3. BB/QI/BZ/SL 作为量子卡成本来源，金融渠道成本按 product_line 分桶。
--********************************************************************--

DROP MATERIALIZED VIEW IF EXISTS "dws"."mv_channel_cost_daily";

CREATE MATERIALIZED VIEW "dws"."mv_channel_cost_daily" AS
WITH bb_month_net_amount AS (
    SELECT
        DATE_TRUNC('month', report_date)::date AS report_month,
        SUM(COALESCE(total_net_amount, 0::numeric))::numeric(20, 4)
            AS month_total_net_amount
    FROM "dws"."dws_bb_card_finance_daily_v2_p"
    WHERE delete_time IS NULL
    GROUP BY DATE_TRUNC('month', report_date)::date
),
channel_cost_source AS (
    SELECT
        bb.report_date,
        bb.account_id,
        bb.sale_id,
        bb.am_id,
        bb.create_time AS source_create_time,
        bb.update_time AS source_update_time,
        'QUANTUM_CARD'::text AS product_line,
        (
            COALESCE(bb.m_dom_auth_count, 0) * 0.1090
          + COALESCE(bb.m_int_auth_count, 0) * 0.4845
          + COALESCE(bb.v_dom_auth_count, 0) * 0.0725
          + COALESCE(bb.v_int_auth_count, 0) * 0.4770
          + COALESCE(bb.av_m_dom_count, 0) * 0.1090
          + COALESCE(bb.av_m_int_count, 0) * 0.4845
          + COALESCE(bb.av_v_dom_count, 0) * 0.0725
          + COALESCE(bb.av_v_int_count, 0) * 0.4770
          + COALESCE(bb.m_dom_clearing_vol, 0::numeric) * 0.0021
          + COALESCE(bb.m_int_clearing_vol, 0::numeric) * 0.0111
          + COALESCE(bb.v_dom_clearing_vol, 0::numeric) * 0.0016
          + COALESCE(bb.v_int_clearing_vol, 0::numeric) * 0.0116
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
          + CASE
                WHEN COALESCE(mn.month_total_net_amount, 0::numeric) = 0
                    THEN 0::numeric
                WHEN mn.month_total_net_amount <= 5000000
                    THEN COALESCE(bb.total_net_amount, 0::numeric) * 0.0055
                WHEN mn.month_total_net_amount <= 10000000
                    THEN COALESCE(bb.total_net_amount, 0::numeric)
                       / mn.month_total_net_amount
                       * (
                            5000000::numeric * 0.0055
                          + (mn.month_total_net_amount - 5000000::numeric) * 0.0045
                       )
                ELSE COALESCE(bb.total_net_amount, 0::numeric)
                   / mn.month_total_net_amount
                   * (
                        5000000::numeric * 0.0055
                      + 5000000::numeric * 0.0045
                      + (mn.month_total_net_amount - 10000000::numeric) * 0.0040
                   )
            END
          + COALESCE(bb.cost_fixed_fee, 0::numeric)
        )::numeric(20, 4) AS cost_amount
    FROM "dws"."dws_bb_card_finance_daily_v2_p" bb
    LEFT JOIN bb_month_net_amount mn
        ON mn.report_month = DATE_TRUNC('month', bb.report_date)::date
    WHERE bb.delete_time IS NULL

    UNION ALL

    SELECT
        bz.report_date,
        bz.account_id,
        bz.sale_id,
        bz.am_id,
        bz.create_time AS source_create_time,
        bz.update_time AS source_update_time,
        'QUANTUM_CARD'::text AS product_line,
        (
            COALESCE(bz.clearing_base_amt, 0::numeric)
                * COALESCE(bz.reimbursement_rate, 0::numeric)
          + COALESCE(bz.refund_base_amt, 0::numeric)
                * COALESCE(bz.reimbursement_rate, 0::numeric)
          + COALESCE(bz.visa_charges_base_amt, 0::numeric)
                * COALESCE(bz.visa_charges_rate, 0::numeric)
          + COALESCE(bz.card_create_count, 0)
                * COALESCE(bz.card_setup_rate, 0::numeric)
          + COALESCE(bz.card_create_count, 0)
                * COALESCE(bz.account_activation_rate, 0::numeric)
          + COALESCE(bz.card_active_count, 0)
                * COALESCE(bz.account_on_file_rate, 0::numeric)
          + COALESCE(bz.settlement_volume, 0::numeric)
                * COALESCE(bz.service_fee_rate, 0::numeric)
          + COALESCE(bz.verify_count, 0)
                * COALESCE(bz.verify_fee_rate, 0::numeric)
          + COALESCE(bz.auth_count, 0)
                * COALESCE(bz.auth_fee_rate, 0::numeric)
          + COALESCE(bz.clearing_count, 0)
                * COALESCE(bz.clearing_fee_rate, 0::numeric)
          + COALESCE(bz.refund_count, 0)
                * COALESCE(bz.refund_fee_rate, 0::numeric)
          + COALESCE(bz.reversal_count, 0)
                * COALESCE(bz.reversal_fee_rate, 0::numeric)
          + COALESCE(bz.cost_fixed_fee, 0::numeric)
        )::numeric(20, 4) AS cost_amount
    FROM "dws"."dws_bz_card_finance_daily_v2_p" bz
    WHERE bz.delete_time IS NULL

    UNION ALL

    SELECT
        qi.report_date,
        qi.account_id,
        qi.sale_id,
        qi.am_id,
        qi.create_time AS source_create_time,
        qi.update_time AS source_update_time,
        'QUANTUM_CARD'::text AS product_line,
        (
            COALESCE(qi.cost_reimbursement_base_amt, 0::numeric)
                * COALESCE(qi.cost_reimbursement_rate, 0::numeric)
          + COALESCE(qi.cost_service_base_amt, 0::numeric)
                * COALESCE(qi.cost_service_rate, 0::numeric)
          + COALESCE(qi.cost_acs_regular_base_amt, 0::numeric)
                * COALESCE(qi.cost_acs_regular_rate, 0::numeric)
          + COALESCE(qi.cost_acs_vip_base_amt, 0::numeric)
                * COALESCE(qi.cost_acs_vip_rate, 0::numeric)
          + COALESCE(qi.cost_vrm_base_amt, 0::numeric)
                * COALESCE(qi.cost_vrm_rate, 0::numeric)
          + COALESCE(qi.cost_hk_regular_base_amt, 0::numeric)
                * COALESCE(qi.cost_hk_regular_rate, 0::numeric)
          + COALESCE(qi.cost_hk_vip_base_amt, 0::numeric)
                * COALESCE(qi.cost_hk_vip_rate, 0::numeric)
          + COALESCE(qi.cost_dcsf_base_amt, 0::numeric)
                * COALESCE(qi.cost_dcsf_rate, 0::numeric)
          + COALESCE(qi.cost_fixed_fee, 0::numeric)
        )::numeric(20, 4) AS cost_amount
    FROM "dws"."dws_qi_card_finance_daily_v2_p" qi
    WHERE qi.delete_time IS NULL

    UNION ALL

    SELECT
        sl.report_date,
        sl.account_id,
        sl.sale_id,
        sl.am_id,
        sl.create_time AS source_create_time,
        sl.update_time AS source_update_time,
        'QUANTUM_CARD'::text AS product_line,
        COALESCE(sl.cost_fixed_fee, 0::numeric)::numeric(20, 4)
            AS cost_amount
    FROM "dws"."dws_sl_card_finance_daily_p" sl
    WHERE sl.delete_time IS NULL

    UNION ALL

    SELECT
        fc.report_date,
        fc.account_id,
        fc.sale_id,
        fc.am_id,
        fc.create_time AS source_create_time,
        fc.update_time AS source_update_time,
        UPPER(TRIM(fc.product_line)) AS product_line,
        COALESCE(fc.cost_amount, 0::numeric)::numeric(20, 4)
            AS cost_amount
    FROM "dwm"."dwm_finance_channel_cost_p" fc
    WHERE fc.delete_time IS NULL
)
SELECT
    (
        ('x' || SUBSTR(
            MD5(CONCAT(
                report_date::text,
                ':',
                COALESCE(account_id, ''),
                ':',
                COALESCE(sale_id, ''),
                ':',
                COALESCE(am_id, '')
            )),
            1,
            15
        ))::bit(60)::bigint
    ) AS id,
    report_date,
    account_id,
    sale_id,
    am_id,
    SUM(
        CASE WHEN product_line = 'ACQUIRING' THEN cost_amount ELSE 0::numeric END
    )::numeric(20, 4) AS acquiring_cost,
    SUM(
        CASE WHEN product_line = 'GLOBAL_ACCOUNT' THEN cost_amount ELSE 0::numeric END
    )::numeric(20, 4) AS business_cost,
    SUM(
        CASE WHEN product_line = 'QUANTUM_CARD' THEN cost_amount ELSE 0::numeric END
    )::numeric(20, 4) AS quantum_cost,
    SUM(
        CASE WHEN product_line = 'CRYPTO_ASSET' THEN cost_amount ELSE 0::numeric END
    )::numeric(20, 4) AS crypto_cost,
    SUM(cost_amount)::numeric(20, 4) AS total_channel_cost,
    1 AS version,
    NULL::text AS remarks,
    MIN(source_create_time)::timestamp AS create_time,
    MAX(source_update_time)::timestamp AS update_time,
    NULL::timestamp AS delete_time
FROM channel_cost_source
GROUP BY report_date, account_id, sale_id, am_id
DISTRIBUTED BY (id);

ALTER MATERIALIZED VIEW "dws"."mv_channel_cost_daily"
    OWNER TO "qbit_admin";

CREATE UNIQUE INDEX IF NOT EXISTS "idx_mv_channel_cost_daily_id"
    ON "dws"."mv_channel_cost_daily" ("id");

CREATE INDEX IF NOT EXISTS "idx_mv_channel_cost_daily_date_account"
    ON "dws"."mv_channel_cost_daily"
    ("report_date", "account_id");

COMMENT ON MATERIALIZED VIEW "dws"."mv_channel_cost_daily" IS
    '总渠道成本日汇总普通物化视图，每 5 小时全量刷新';

-- 手动全量刷新：
-- REFRESH MATERIALIZED VIEW "dws"."mv_channel_cost_daily";
--
-- 手动并发刷新：
-- REFRESH MATERIALIZED VIEW CONCURRENTLY
--     "dws"."mv_channel_cost_daily";
