CREATE OR REPLACE PROCEDURE "public"."sp_init_qi_card_dws_by_fast_v2"("p_start_date" date, "p_end_date" date)
 AS $BODY$
BEGIN
    EXECUTE 'SET LOCAL work_mem = ''256MB''';
    EXECUTE 'SET LOCAL synchronous_commit = off';

    UPDATE "public"."dws_qi_card_finance_daily_p"
    SET "delete_time" = NOW(),
        "update_time" = NOW()
    WHERE "report_date" >= p_start_date
      AND "report_date" < p_end_date
      AND "delete_time" IS NULL;

    INSERT INTO "public"."dws_qi_card_finance_daily_p" (
        id, report_date, account_id, sale_id, am_id,
        version, remarks, create_time, update_time, delete_time,
        cost_reimbursement_vol, cost_service_vol, cost_acs_regular_count,
        cost_acs_vip_count, cost_vrm_count, rebate_interchange_vol,
        rebate_incentive_vol, cost_fixed_fee
    )
    WITH base AS (
        SELECT
            (dwm."transaction_time" AT TIME ZONE 'Asia/Shanghai')::date AS report_date,
            dwm."account_id",
            dwm."status",
            dwm."billing_amount",
            dwm."is_hk_region",
            dwm."business_type",
            dwm."has_special_code",
            dwm."card_id",
            COALESCE(sr.sale_id, NULL) AS sale_id,
            COALESCE(sr.am_id, NULL) AS am_id
        FROM "public"."dwm_qi_card_transaction_detail_p" dwm
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
        1,
        'v2 with sale/am',
        NOW(),
        NOW(),
        NULL,
        COALESCE(SUM(CASE WHEN is_hk_region = FALSE AND business_type = 'Consumption' AND status IN ('Closed', 'Pending')
            THEN billing_amount * 0.0135 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN is_hk_region = FALSE AND status IN ('Closed', 'Pending') AND business_type IN ('Consumption', 'Reversal', 'Credit')
            THEN (
                CASE
                    WHEN ABS(billing_amount) < 5 THEN billing_amount * 0.00095
                    WHEN ABS(billing_amount) < 10 THEN billing_amount * 0.00145
                    WHEN ABS(billing_amount) < 50 THEN billing_amount * 0.0022
                    WHEN ABS(billing_amount) < 250 THEN billing_amount * 0.0037
                    ELSE billing_amount * 0.00445
                END * CASE business_type WHEN 'Consumption' THEN 1 WHEN 'Reversal' THEN -1 WHEN 'Credit' THEN -1 ELSE 0 END
            ) ELSE 0 END), 0),
        COUNT(*) FILTER (WHERE is_hk_region = FALSE AND business_type = 'Consumption' AND status IN ('Closed', 'Pending')),
        COUNT(*) FILTER (WHERE is_hk_region = FALSE AND business_type = 'Consumption' AND has_special_code = FALSE),
        COUNT(*) FILTER (WHERE is_hk_region = FALSE AND business_type = 'Consumption' AND has_special_code = FALSE),
        COALESCE(SUM(CASE WHEN status IN ('Closed', 'Pending') AND is_hk_region = FALSE AND business_type = 'Consumption'
            THEN billing_amount ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN status IN ('Closed', 'Pending') AND business_type = 'Consumption'
            THEN billing_amount ELSE 0 END), 0),
        0
    FROM base
    GROUP BY report_date, account_id, sale_id, am_id
    ON CONFLICT (id, report_date) DO UPDATE SET
        sale_id = EXCLUDED.sale_id,
        am_id = EXCLUDED.am_id,
        cost_reimbursement_vol = EXCLUDED.cost_reimbursement_vol,
        cost_service_vol = EXCLUDED.cost_service_vol,
        cost_acs_regular_count = EXCLUDED.cost_acs_regular_count,
        cost_acs_vip_count = EXCLUDED.cost_acs_vip_count,
        cost_vrm_count = EXCLUDED.cost_vrm_count,
        rebate_interchange_vol = EXCLUDED.rebate_interchange_vol,
        rebate_incentive_vol = EXCLUDED.rebate_incentive_vol,
        cost_fixed_fee = EXCLUDED.cost_fixed_fee,
        update_time = NOW(),
        delete_time = NULL,
        version = "dws_qi_card_finance_daily_p".version + 1;
END $BODY$
  LANGUAGE plpgsql;
