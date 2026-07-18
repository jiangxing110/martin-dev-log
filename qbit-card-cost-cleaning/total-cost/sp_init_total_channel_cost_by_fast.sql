CREATE OR REPLACE PROCEDURE "public"."sp_init_total_channel_cost_by_fast"("p_start_date" date, "p_end_date" date)
 AS $BODY$
BEGIN
    EXECUTE 'SET LOCAL work_mem = ''256MB''';
    EXECUTE 'SET LOCAL synchronous_commit = off';

    UPDATE "public"."dws_total_channel_cost_daily_p"
    SET "delete_time" = NOW(),
        "update_time" = NOW()
    WHERE "report_date" >= p_start_date
      AND "report_date" < p_end_date
      AND "delete_time" IS NULL;

    INSERT INTO "public"."dws_total_channel_cost_daily_p" (
        id, report_date, account_id, sale_id, am_id,
        acquiring_cost, business_cost, quantum_cost, crypto_cost, total_channel_cost,
        version, remarks, create_time, update_time, delete_time
    )
    WITH source_rows AS (
        SELECT
            report_date,
            account_id,
            sale_id,
            am_id,
            'QUANTUM_CARD'::text AS product_line,
            (
                COALESCE(m_dom_auth_count, 0) * 0.1090
              + COALESCE(av_m_dom_count, 0) * 0.1090
              + COALESCE(m_int_auth_count, 0) * 0.4845
              + COALESCE(av_m_int_count, 0) * 0.4845
              + COALESCE(v_dom_auth_count, 0) * 0.0725
              + COALESCE(av_v_dom_count, 0) * 0.0725
              + COALESCE(v_int_auth_count, 0) * 0.4770
              + COALESCE(av_v_int_count, 0) * 0.4770
              + COALESCE(m_int_decline_count, 0) * 0.3595
              + COALESCE(v_int_decline_count, 0) * 0.3570
              + COALESCE(dom_decline_count, 0) * 0.0890
              + COALESCE(m_int_reversal_count, 0) * 0.7190
              + COALESCE(v_int_reversal_count, 0) * 0.7140
              + COALESCE(dom_reversal_count, 0) * 0.0890
              + COALESCE(m_int_refund_count, 0) * 0.4845
              + COALESCE(v_int_refund_count, 0) * 0.4770
              + COALESCE(dom_refund_count, 0) * 0.1090
              + COALESCE(active_card_count, 0) * 0.1000
              + COALESCE(cost_fixed_fee, 0)
            )::numeric(20,4) AS cost_amount
        FROM "public"."dws_bb_card_finance_daily_p"
        WHERE "report_date" >= p_start_date
          AND "report_date" < p_end_date
          AND "delete_time" IS NULL

        UNION ALL

        SELECT
            report_date,
            account_id,
            sale_id,
            am_id,
            'QUANTUM_CARD'::text AS product_line,
            (
                COALESCE(cost_reimbursement_vol, 0)
              + COALESCE(cost_service_vol, 0)
              + COALESCE(cost_acs_regular_count, 0)
              + COALESCE(cost_acs_vip_count, 0)
              + COALESCE(cost_vrm_count, 0)
              + COALESCE(cost_fixed_fee, 0)
            )::numeric(20,4) AS cost_amount
        FROM "public"."dws_qi_card_finance_daily_p"
        WHERE "report_date" >= p_start_date
          AND "report_date" < p_end_date
          AND "delete_time" IS NULL

        UNION ALL

        SELECT
            report_date,
            account_id,
            sale_id,
            am_id,
            'QUANTUM_CARD'::text AS product_line,
            COALESCE(cost_fixed_fee, 0)::numeric(20,4) AS cost_amount
        FROM "public"."dws_sl_card_finance_daily_p"
        WHERE "report_date" >= p_start_date
          AND "report_date" < p_end_date
          AND "delete_time" IS NULL

        UNION ALL

        SELECT
            report_date,
            account_id,
            sale_id,
            am_id,
            product_line,
            COALESCE(cost_amount, 0)::numeric(20,4) AS cost_amount
        FROM "public"."dwm_finance_channel_cost_p"
        WHERE "report_date" >= p_start_date
          AND "report_date" < p_end_date
          AND "delete_time" IS NULL
    )
    SELECT
        abs(hashtext(report_date::text || ':' || account_id || ':' || COALESCE(sale_id, '') || ':' || COALESCE(am_id, '')))::bigint AS id,
        report_date,
        account_id,
        sale_id,
        am_id,
        COALESCE(SUM(CASE WHEN product_line = 'ACQUIRING' THEN cost_amount ELSE 0 END), 0) AS acquiring_cost,
        COALESCE(SUM(CASE WHEN product_line = 'GLOBAL_ACCOUNT' THEN cost_amount ELSE 0 END), 0) AS business_cost,
        COALESCE(SUM(CASE WHEN product_line = 'QUANTUM_CARD' THEN cost_amount ELSE 0 END), 0) AS quantum_cost,
        COALESCE(SUM(CASE WHEN product_line = 'CRYPTO_ASSET' THEN cost_amount ELSE 0 END), 0) AS crypto_cost,
        COALESCE(SUM(cost_amount), 0) AS total_channel_cost,
        1,
        'monthly rebuild',
        NOW(),
        NOW(),
        NULL
    FROM source_rows
    GROUP BY report_date, account_id, sale_id, am_id
    ON CONFLICT (id, report_date) DO UPDATE SET
        acquiring_cost = EXCLUDED.acquiring_cost,
        business_cost = EXCLUDED.business_cost,
        quantum_cost = EXCLUDED.quantum_cost,
        crypto_cost = EXCLUDED.crypto_cost,
        total_channel_cost = EXCLUDED.total_channel_cost,
        sale_id = EXCLUDED.sale_id,
        am_id = EXCLUDED.am_id,
        update_time = NOW(),
        delete_time = NULL,
        version = "dws_total_channel_cost_daily_p".version + 1;
END $BODY$
  LANGUAGE plpgsql;
