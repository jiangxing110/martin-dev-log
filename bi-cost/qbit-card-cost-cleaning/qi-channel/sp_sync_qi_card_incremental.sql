CREATE OR REPLACE PROCEDURE "public"."sp_sync_qi_card_incremental"("p_start" timestamp=NULL::timestamp without time zone, "p_end" timestamp=NULL::timestamp without time zone)
 AS $BODY$
DECLARE
    v_start     TIMESTAMP := COALESCE(p_start, CURRENT_TIMESTAMP - INTERVAL '25 hours');
    v_end       TIMESTAMP := COALESCE(p_end, CURRENT_TIMESTAMP);
    v_row_count INT;
BEGIN
    -- STEP 1: ODS -> DWM (明细实时对账)
    INSERT INTO "dwm_qi_card_transaction_detail_p" (
        id, transaction_id, account_id, status, transaction_time, version, update_time, delete_time,
        billing_amount, is_qbit_provision, is_hk_region, is_consumption, is_reversal_or_credit, has_special_code, is_vip_account
    )
    WITH target_providers AS (
        SELECT system_provider FROM card_bin WHERE brand = 'QbitIssuing'
    ),
    base_tx AS (
        SELECT B.* FROM "qbitCardTransaction" B
        WHERE B."updateTime" >= v_start AND B."updateTime" < v_end 
          AND B."provider" IN (SELECT system_provider FROM target_providers)
    )
    SELECT DISTINCT ON (base.id)
        base.id, base."transactionId", base."accountId", base."status", base."transactionTime", 
        COALESCE(base.version, 1), NOW(), base."deleteTime",
        COALESCE(D.usd_amount, 0)::numeric(20, 2),
        (D.channel_provision = 'QBIT'), (D.country IN ('HK', 'HKG')),
        (base."businessType" = 'Consumption'), (base."businessType" IN ('Reversal', 'Credit')),
        CASE WHEN base."specialSourceData"->>'code' IS NOT NULL 
             THEN (base."specialSourceData"->>'code')::JSONB ?| ARRAY['1001', '1103', '1105'] ELSE FALSE END,
        FALSE 
    FROM base_tx base
    LEFT JOIN "quantum_card_transaction_extend" D ON base."transactionId" = D."transaction_id"
    ORDER BY base.id, base."updateTime" DESC
    ON CONFLICT (id, transaction_time) DO UPDATE SET 
        status = EXCLUDED.status, update_time = NOW(), billing_amount = EXCLUDED.billing_amount;

    GET DIAGNOSTICS v_row_count = ROW_COUNT;

    -- STEP 2: DWM -> DWS (级联局部重刷)
    IF v_row_count > 0 THEN
        -- 仅重刷本次有数据变动的 账户+日期
        CREATE TEMP TABLE tmp_sync_scope ON COMMIT DROP AS
        SELECT DISTINCT (transaction_time AT TIME ZONE 'Asia/Shanghai')::date as r_date, account_id 
        FROM "dwm_qi_card_transaction_detail_p" WHERE update_time >= (NOW() - INTERVAL '5 minutes');

        INSERT INTO "dws_qi_card_finance_daily_p" (
            id, report_date, account_id, version, update_time,
            qi_reimbursement_vol, qi_service_vol, qi_acs_regular_count, 
            qi_acs_vip_count, qi_vrm_count, qi_interchange_vol, qi_incentive_vol, qi_active_card_count
        )
        SELECT 
            ('1' || to_char(sc.r_date, 'YYYYMMDD') || abs(hashtext(sc.account_id)))::int8,
            sc.r_date, sc.account_id, 1, NOW(),
            SUM(CASE WHEN is_hk_region = FALSE AND status IN ('Closed', 'Pending') THEN (CASE WHEN is_consumption THEN billing_amount ELSE -billing_amount END) ELSE 0 END),
            SUM(CASE WHEN is_hk_region = FALSE AND status IN ('Closed', 'Pending') THEN (CASE WHEN is_consumption THEN billing_amount ELSE -billing_amount END) ELSE 0 END),
            COUNT(*) FILTER (WHERE is_consumption = TRUE AND is_vip_account = FALSE AND status IN ('Closed', 'Pending')),
            COUNT(*) FILTER (WHERE is_consumption = TRUE AND is_vip_account = TRUE AND status IN ('Closed', 'Pending')),
            COUNT(*) FILTER (WHERE is_consumption = TRUE AND has_special_code = FALSE AND status IN ('Closed', 'Pending')),
            SUM(CASE WHEN status IN ('Closed', 'Pending') THEN (CASE WHEN is_consumption THEN billing_amount ELSE -billing_amount END) ELSE 0 END),
            SUM(CASE WHEN status IN ('Closed', 'Pending') THEN (CASE WHEN is_consumption THEN billing_amount ELSE -billing_amount END) ELSE 0 END),
            COUNT(DISTINCT card_id)
        FROM "dwm_qi_card_transaction_detail_p" dwm
        JOIN tmp_sync_scope sc ON (dwm.transaction_time AT TIME ZONE 'Asia/Shanghai')::date = sc.r_date AND dwm.account_id = sc.account_id
        WHERE dwm.delete_time IS NULL
        GROUP BY 1, 2, 3 
        ON CONFLICT (id, report_date) DO UPDATE SET 
            qi_reimbursement_vol = EXCLUDED.qi_reimbursement_vol,
            qi_active_card_count = EXCLUDED.qi_active_card_count,
            update_time = NOW(), version = dws_qi_card_finance_daily_p.version + 1;
    END IF;
    COMMIT;
END $BODY$
  LANGUAGE plpgsql