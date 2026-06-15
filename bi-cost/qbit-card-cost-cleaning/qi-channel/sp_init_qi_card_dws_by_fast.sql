CREATE OR REPLACE PROCEDURE "public"."sp_init_qi_card_dws_by_fast"("p_start_date" date, "p_end_date" date)
 AS $BODY$
DECLARE
    v_batch_size  INT := 5000;
    v_offset      INT := 0;
    v_total_units INT;
BEGIN
    EXECUTE 'SET LOCAL work_mem = ''256MB''';
    EXECUTE 'SET LOCAL synchronous_commit = off';

    -- 锁定变动范围
    SELECT COUNT(DISTINCT (transaction_time::date, account_id)) INTO v_total_units 
    FROM "dwm_qi_card_transaction_detail_p" 
    WHERE transaction_time >= p_start_date::timestamp AND transaction_time < p_end_date::timestamp;

    WHILE v_offset < v_total_units LOOP
        INSERT INTO "dws_qi_card_finance_daily_p" (
            id, report_date, account_id, version, update_time,
            cost_reimbursement_vol, 
            cost_service_vol,       
            cost_acs_regular_count, 
            cost_acs_vip_count,     
            cost_vrm_count,         
            rebate_interchange_vol, 
            rebate_incentive_vol
        )
        SELECT 
            ('1' || to_char(sub.r_dt, 'YYYYMMDD') || abs(hashtext(sub.acc_id)))::int8,
            sub.r_dt, sub.acc_id, 1, NOW(),
            
            -- 1. cost_reimbursement_vol (成本五: 非HK, 仅Consumption, 1.35% 费率)
            SUM(CASE WHEN is_hk_region = FALSE AND business_type = 'Consumption' AND status IN ('Closed', 'Pending')
                THEN billing_amount * 0.0135 ELSE 0 END),

            -- 2. cost_service_vol (成本一: 阶梯费率 * 净额方向)
            SUM(
                CASE WHEN is_hk_region = FALSE AND status IN ('Closed', 'Pending') AND business_type IN ('Consumption', 'Reversal', 'Credit')
                THEN (
                    CASE 
                        WHEN ABS(billing_amount) < 5 THEN billing_amount * 0.00095
                        WHEN ABS(billing_amount) < 10 THEN billing_amount * 0.00145
                        WHEN ABS(billing_amount) < 50 THEN billing_amount * 0.0022
                        WHEN ABS(billing_amount) < 250 THEN billing_amount * 0.0037
                        ELSE billing_amount * 0.00445
                    END * (CASE business_type WHEN 'Consumption' THEN 1 WHEN 'Reversal' THEN -1 WHEN 'Credit' THEN -1 ELSE 0 END)
                ) ELSE 0 END
            ),

            -- 3. cost_acs_regular_count (成本二: 非HK消费, 阶梯规费单价累加)
            SUM(CASE WHEN is_hk_region = FALSE AND business_type = 'Consumption' AND status IN ('Closed', 'Pending')
                THEN (CASE 
                        WHEN billing_amount < 5 THEN 0.01 
                        WHEN billing_amount < 10 THEN 0.055 
                        WHEN billing_amount < 50 THEN 0.08 
                        WHEN billing_amount < 250 THEN 0.12 ELSE 0.14 END)
                ELSE 0 END),

            -- 4. cost_acs_vip_count (成本三: 非HK & 非特殊码, VIP阶梯规费单价累加)
            SUM(CASE WHEN is_hk_region = FALSE AND business_type = 'Consumption' AND has_special_code = FALSE
                THEN (CASE 
                          WHEN billing_amount < 5 THEN 0.04 
                          WHEN billing_amount < 10 THEN 0.22 
                          WHEN billing_amount < 50 THEN 0.255 
                          WHEN billing_amount < 250 THEN 0.48 ELSE 0.56 END)
                ELSE 0 END),

            -- 5. cost_vrm_count (成本四: VRM规费 0.07/笔)
            SUM(CASE WHEN is_hk_region = FALSE AND business_type = 'Consumption' AND has_special_code = FALSE
                THEN 0.07 ELSE 0 END),

            -- 6. rebate_interchange_vol (Interchange: 非HK消费净额)
            SUM(CASE WHEN status IN ('Closed', 'Pending') AND is_hk_region = FALSE AND business_type = 'Consumption' 
                THEN billing_amount ELSE 0 END),
            
            -- 7. rebate_incentive_vol (Incentive: 全球消费净额)
            SUM(CASE WHEN status IN ('Closed', 'Pending') AND business_type = 'Consumption' 
                THEN billing_amount ELSE 0 END)

        FROM (
            SELECT (transaction_time AT TIME ZONE 'Asia/Shanghai')::date as r_dt, account_id as acc_id 
            FROM "dwm_qi_card_transaction_detail_p" 
            WHERE transaction_time >= p_start_date::timestamp AND transaction_time < p_end_date::timestamp 
            GROUP BY 1, 2 ORDER BY 1, 2 LIMIT v_batch_size OFFSET v_offset
        ) AS sub
        JOIN "dwm_qi_card_transaction_detail_p" dwm ON (dwm.transaction_time AT TIME ZONE 'Asia/Shanghai')::date = sub.r_dt AND dwm.account_id = sub.acc_id
        WHERE dwm.delete_time IS NULL
        GROUP BY 1, 2, 3
        ON CONFLICT (id, report_date) DO UPDATE SET 
            update_time = NOW(), 
            version = dws_qi_card_finance_daily_p.version + 1,
            cost_reimbursement_vol = EXCLUDED.cost_reimbursement_vol,
            cost_service_vol = EXCLUDED.cost_service_vol,
            cost_acs_regular_count = EXCLUDED.cost_acs_regular_count,
            cost_acs_vip_count = EXCLUDED.cost_acs_vip_count,
            cost_vrm_count = EXCLUDED.cost_vrm_count,
            rebate_interchange_vol = EXCLUDED.rebate_interchange_vol, 
            rebate_incentive_vol = EXCLUDED.rebate_incentive_vol;
        v_offset := v_offset + v_batch_size;
        COMMIT; 
    END LOOP;
END $BODY$
  LANGUAGE plpgsql