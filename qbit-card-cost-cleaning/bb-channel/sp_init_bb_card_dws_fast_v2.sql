CREATE OR REPLACE PROCEDURE "public"."sp_init_bb_card_dws_fast_v2"("p_start_date" date, "p_end_date" date)
 AS $BODY$
BEGIN
    EXECUTE 'SET LOCAL work_mem = ''256MB''';
    EXECUTE 'SET LOCAL synchronous_commit = off';

    UPDATE "public"."dws_bb_card_finance_daily_p"
    SET "delete_time" = NOW(),
        "update_time" = NOW()
    WHERE "report_date" >= p_start_date
      AND "report_date" < p_end_date
      AND "delete_time" IS NULL;

    INSERT INTO "public"."dws_bb_card_finance_daily_p" (
        id, report_date, account_id, sale_id, am_id,
        m_dom_auth_count, m_int_auth_count, v_dom_auth_count, v_int_auth_count,
        m_int_decline_count, v_int_decline_count, dom_decline_count,
        m_int_reversal_count, v_int_reversal_count, dom_reversal_count,
        m_int_refund_count, v_int_refund_count, dom_refund_count,
        av_m_dom_count, av_m_int_count, av_v_dom_count, av_v_int_count,
        m_dom_clearing_vol, m_int_clearing_vol, v_dom_clearing_vol, v_int_clearing_vol,
        bb_rebate_base_amt, bb_channel_cashback_comm, active_card_count, cost_fixed_fee,
        version, remarks, create_time, update_time, delete_time
    )
    WITH base AS (
        SELECT
            (dwm."transaction_time" AT TIME ZONE 'Asia/Shanghai')::date AS report_date,
            dwm."account_id",
            dwm."card_id",
            dwm."business_type",
            dwm."card_org",
            dwm."is_dom",
            dwm."resp_code",
            dwm."request_code",
            dwm."reason_code",
            dwm."is_valid_settle",
            dwm."is_clearing",
            dwm."is_reversal",
            dwm."is_refund",
            dwm."billing_amount",
            dwm."remarks",
            COALESCE(sr.sale_id, NULL) AS sale_id,
            COALESCE(sr.am_id, NULL) AS am_id
        FROM "public"."dwm_bb_card_transaction_detail_p" dwm
        LEFT JOIN LATERAL (
            SELECT rel.sale_id, rel.am_id
            FROM (
                SELECT
                    sar."salesId"::text AS sale_id,
                    sar."amId"::text AS am_id,
                    sar."createTime" AS effective_time,
                    1 AS priority
                FROM "salesAccountRelation" sar
                WHERE sar."accountId"::text = dwm."account_id"
                  AND dwm."transaction_time" >= sar."createTime"
                  AND (sar."deleteTime" IS NULL OR dwm."transaction_time" < sar."deleteTime")
                UNION ALL
                SELECT
                    sar."salesId"::text AS sale_id,
                    sar."amId"::text AS am_id,
                    sar."createTime" AS effective_time,
                    2 AS priority
                FROM "api_account_relation" aar
                JOIN "salesAccountRelation" sar
                  ON aar.root_id::text = sar."accountId"::text
                WHERE aar.account_id::text = dwm."account_id"
                  AND dwm."transaction_time" >= sar."createTime"
                  AND (sar."deleteTime" IS NULL OR dwm."transaction_time" < sar."deleteTime")
            ) rel
            ORDER BY rel.priority, rel.effective_time DESC
            LIMIT 1
        ) sr ON TRUE
        WHERE (dwm."transaction_time" AT TIME ZONE 'Asia/Shanghai')::date >= p_start_date
          AND (dwm."transaction_time" AT TIME ZONE 'Asia/Shanghai')::date < p_end_date
          AND dwm."delete_time" IS NULL
    )
    SELECT
        abs(hashtext(report_date::text || ':' || account_id || ':' || COALESCE(sale_id, '') || ':' || COALESCE(am_id, '')))::bigint AS id,
        report_date,
        account_id,
        sale_id,
        am_id,
        COUNT(*) FILTER (WHERE business_type = 'Consumption' AND card_org = 'Master' AND is_dom = TRUE AND resp_code = 'APPROVE' AND (is_clearing OR is_reversal)),
        COUNT(*) FILTER (WHERE business_type = 'Consumption' AND card_org = 'Master' AND is_dom = FALSE AND resp_code = 'APPROVE' AND (is_clearing OR is_reversal)),
        COUNT(*) FILTER (WHERE business_type = 'Consumption' AND card_org = 'VISA' AND is_dom = TRUE AND resp_code = 'APPROVE' AND (is_clearing OR is_reversal)),
        COUNT(*) FILTER (WHERE business_type = 'Consumption' AND card_org = 'VISA' AND is_dom = FALSE AND resp_code = 'APPROVE' AND (is_clearing OR is_reversal)),
        COUNT(*) FILTER (WHERE business_type = 'Consumption' AND card_org = 'Master' AND is_dom = FALSE AND resp_code = 'DECLINE'),
        COUNT(*) FILTER (WHERE business_type = 'Consumption' AND card_org = 'VISA' AND is_dom = FALSE AND resp_code = 'DECLINE'),
        COUNT(*) FILTER (WHERE business_type = 'Consumption' AND is_dom = TRUE AND resp_code = 'DECLINE'),
        COUNT(*) FILTER (WHERE business_type = 'Consumption' AND card_org = 'Master' AND is_dom = FALSE AND is_reversal = TRUE AND resp_code = 'APPROVE'),
        COUNT(*) FILTER (WHERE business_type = 'Consumption' AND card_org = 'VISA' AND is_dom = FALSE AND is_reversal = TRUE AND resp_code = 'APPROVE'),
        COUNT(*) FILTER (WHERE business_type = 'Consumption' AND is_dom = TRUE AND is_reversal = TRUE AND resp_code = 'APPROVE'),
        COUNT(*) FILTER (WHERE business_type = 'Credit' AND card_org = 'Master' AND is_dom = FALSE AND is_refund = TRUE AND resp_code = 'APPROVE'),
        COUNT(*) FILTER (WHERE business_type = 'Credit' AND card_org = 'VISA' AND is_dom = FALSE AND is_refund = TRUE AND resp_code = 'APPROVE'),
        COUNT(*) FILTER (WHERE business_type = 'Credit' AND is_dom = TRUE AND is_refund = TRUE AND resp_code = 'APPROVE'),
        COUNT(*) FILTER (WHERE business_type = 'Fee_Consumption' AND remarks = '绑卡验证手续费' AND card_org = 'Master' AND is_dom = TRUE),
        COUNT(*) FILTER (WHERE business_type = 'Fee_Consumption' AND remarks = '绑卡验证手续费' AND card_org = 'Master' AND is_dom = FALSE),
        COUNT(*) FILTER (WHERE business_type = 'Fee_Consumption' AND remarks = '绑卡验证手续费' AND card_org = 'VISA' AND is_dom = TRUE),
        COUNT(*) FILTER (WHERE business_type = 'Fee_Consumption' AND remarks = '绑卡验证手续费' AND card_org = 'VISA' AND is_dom = FALSE),
        COALESCE(SUM(billing_amount) FILTER (WHERE card_org = 'Master' AND is_dom = TRUE AND is_clearing = TRUE), 0),
        COALESCE(SUM(billing_amount) FILTER (WHERE card_org = 'Master' AND is_dom = FALSE AND is_clearing = TRUE), 0),
        COALESCE(SUM(billing_amount) FILTER (WHERE card_org = 'VISA' AND is_dom = TRUE AND is_clearing = TRUE), 0),
        COALESCE(SUM(billing_amount) FILTER (WHERE card_org = 'VISA' AND is_dom = FALSE AND is_clearing = TRUE), 0),
        COALESCE(SUM(billing_amount) FILTER (WHERE is_valid_settle = TRUE AND (is_clearing = TRUE OR is_refund = TRUE)), 0),
        COALESCE(SUM(billing_amount) FILTER (WHERE is_valid_settle = TRUE AND (is_clearing = TRUE OR is_refund = TRUE)), 0),
        COUNT(DISTINCT card_id),
        0,
        1,
        'v2 with sale/am',
        NOW(),
        NOW(),
        NULL
    FROM base
    GROUP BY report_date, account_id, sale_id, am_id
    ON CONFLICT (id, report_date) DO UPDATE SET
        sale_id = EXCLUDED.sale_id,
        am_id = EXCLUDED.am_id,
        m_dom_auth_count = EXCLUDED.m_dom_auth_count,
        m_int_auth_count = EXCLUDED.m_int_auth_count,
        v_dom_auth_count = EXCLUDED.v_dom_auth_count,
        v_int_auth_count = EXCLUDED.v_int_auth_count,
        m_int_decline_count = EXCLUDED.m_int_decline_count,
        v_int_decline_count = EXCLUDED.v_int_decline_count,
        dom_decline_count = EXCLUDED.dom_decline_count,
        m_int_reversal_count = EXCLUDED.m_int_reversal_count,
        v_int_reversal_count = EXCLUDED.v_int_reversal_count,
        dom_reversal_count = EXCLUDED.dom_reversal_count,
        m_int_refund_count = EXCLUDED.m_int_refund_count,
        v_int_refund_count = EXCLUDED.v_int_refund_count,
        dom_refund_count = EXCLUDED.dom_refund_count,
        av_m_dom_count = EXCLUDED.av_m_dom_count,
        av_m_int_count = EXCLUDED.av_m_int_count,
        av_v_dom_count = EXCLUDED.av_v_dom_count,
        av_v_int_count = EXCLUDED.av_v_int_count,
        m_dom_clearing_vol = EXCLUDED.m_dom_clearing_vol,
        m_int_clearing_vol = EXCLUDED.m_int_clearing_vol,
        v_dom_clearing_vol = EXCLUDED.v_dom_clearing_vol,
        v_int_clearing_vol = EXCLUDED.v_int_clearing_vol,
        bb_rebate_base_amt = EXCLUDED.bb_rebate_base_amt,
        bb_channel_cashback_comm = EXCLUDED.bb_channel_cashback_comm,
        active_card_count = EXCLUDED.active_card_count,
        cost_fixed_fee = EXCLUDED.cost_fixed_fee,
        update_time = NOW(),
        delete_time = NULL,
        version = "dws_bb_card_finance_daily_p".version + 1;
END $BODY$
  LANGUAGE plpgsql;
