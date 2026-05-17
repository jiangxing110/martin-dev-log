CREATE OR REPLACE PROCEDURE "public"."sp_init_bb_card_dws_fast"("p_start_date" date, "p_end_date" date)
 AS $BODY$
DECLARE
    v_batch_size  INT := 5000;
    v_offset      INT := 0;
    v_total_units INT;
BEGIN
    -- 1. 性能加速配置
    EXECUTE 'SET LOCAL work_mem = ''256MB''';
    EXECUTE 'SET LOCAL synchronous_commit = off';

    -- 2. 确定需要处理的 [日期 + 账户] 单元总数，用于分批（避免大表全量聚合内存溢出）
    SELECT COUNT(DISTINCT ((transaction_time AT TIME ZONE 'Asia/Shanghai')::date, account_id)) INTO v_total_units 
    FROM "dwm_bb_card_transaction_detail_p" 
    WHERE (transaction_time AT TIME ZONE 'Asia/Shanghai')::date >= p_start_date 
      AND (transaction_time AT TIME ZONE 'Asia/Shanghai')::date < p_end_date;

    WHILE v_offset < v_total_units LOOP
        INSERT INTO "dws_bb_card_finance_daily_p" (
            id, report_date, account_id, version, update_time,
            m_dom_auth_count, m_int_auth_count, v_dom_auth_count, v_int_auth_count,
            m_int_decline_count, v_int_decline_count, dom_decline_count,
            m_int_reversal_count, v_int_reversal_count, dom_reversal_count,
            m_int_refund_count, v_int_refund_count, dom_refund_count,
            av_m_dom_count, av_m_int_count, av_v_dom_count, av_v_int_count,
            m_dom_clearing_vol, m_int_clearing_vol, v_dom_clearing_vol, v_int_clearing_vol,
            bb_rebate_base_amt, bb_channel_cashback_comm, active_card_count
        )
        SELECT 
            ('2' || to_char(sub.r_dt, 'YYYYMMDD') || abs(hashtext(sub.acc_id)))::int8,
            sub.r_dt, sub.acc_id, 1, NOW(),
            
            -- 1. Auth Counts (Master/Visa x Dom/Int)
            SUM(CASE WHEN business_type = 'Consumption' AND card_org = 'Master' AND is_dom = TRUE AND resp_code = 'APPROVE' AND (is_clearing OR is_reversal) THEN 1 ELSE 0 END),
            SUM(CASE WHEN business_type = 'Consumption' AND card_org = 'Master' AND is_dom = FALSE AND resp_code = 'APPROVE' AND (is_clearing OR is_reversal) THEN 1 ELSE 0 END),
            SUM(CASE WHEN business_type = 'Consumption' AND card_org = 'VISA' AND is_dom = TRUE AND resp_code = 'APPROVE' AND (is_clearing OR is_reversal) THEN 1 ELSE 0 END),
            SUM(CASE WHEN business_type = 'Consumption' AND card_org = 'VISA' AND is_dom = FALSE AND resp_code = 'APPROVE' AND (is_clearing OR is_reversal) THEN 1 ELSE 0 END),

            -- 2. Decline Counts
            SUM(CASE WHEN business_type = 'Consumption' AND card_org = 'Master' AND tx_country NOT IN ('US','USA') AND is_valid_settle = TRUE  AND resp_code = 'DECLINE' THEN 1 ELSE 0 END),
            SUM(CASE WHEN business_type = 'Consumption' AND card_org = 'VISA' AND tx_country NOT IN ('US','USA') AND is_valid_settle = TRUE AND is_dom = FALSE AND resp_code = 'DECLINE' THEN 1 ELSE 0 END),
            SUM(CASE WHEN business_type = 'Consumption' AND tx_country NOT IN ('US','USA') AND is_valid_settle = TRUE AND resp_code = 'DECLINE' THEN 1 ELSE 0 END),

            -- 3. Reversal Counts
            SUM(CASE WHEN business_type = 'Consumption' AND card_org = 'Master' AND is_valid_settle = TRUE AND is_dom = FALSE AND is_reversal = TRUE AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND request_code IN ('ST-AUTH_REV','ST-PARTIAL_REV') THEN 1 ELSE 0 END),
            SUM(CASE WHEN business_type = 'Consumption' AND card_org = 'VISA' AND is_valid_settle = TRUE AND tx_country NOT IN ('US','USA') AND is_reversal = TRUE AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND request_code IN ('ST-AUTH_REV','ST-PARTIAL_REV') THEN 1 ELSE 0 END),
            SUM(CASE WHEN business_type = 'Consumption' AND is_dom = TRUE AND is_valid_settle = TRUE AND is_reversal = TRUE AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND request_code IN ('ST-AUTH_REV','ST-PARTIAL_REV') THEN 1 ELSE 0 END),

            -- 4. Refund Counts
            SUM(CASE WHEN business_type = 'Credit' AND card_org = 'Master' AND is_valid_settle = TRUE AND settle_country NOT IN ('US','USA') AND is_refund = TRUE AND resp_code = 'APPROVE' THEN 1 ELSE 0 END),            
            SUM(CASE WHEN business_type = 'Credit' AND card_org = 'VISA' AND is_valid_settle = TRUE AND settle_country NOT IN ('US','USA') AND is_refund = TRUE AND resp_code = 'APPROVE' THEN 1 ELSE 0 END),            
            SUM(CASE WHEN business_type = 'Credit' AND settle_country NOT IN ('US','USA') AND is_refund = TRUE AND resp_code = 'APPROVE' THEN 1 ELSE 0 END),

            -- 5. Address Verification (绑卡验证) Counts
            SUM(CASE WHEN business_type = 'Fee_Consumption' AND remarks = '绑卡验证手续费' AND card_org = 'Master' AND tx_country IN ('US','USA') THEN 1 ELSE 0 END),
            SUM(CASE WHEN business_type = 'Fee_Consumption' AND remarks = '绑卡验证手续费' AND card_org = 'Master' AND tx_country NOT IN ('US','USA') THEN 1 ELSE 0 END),
            SUM(CASE WHEN business_type = 'Fee_Consumption' AND remarks = '绑卡验证手续费' AND card_org = 'VISA' AND tx_country IN ('US','USA') THEN 1 ELSE 0 END),
            SUM(CASE WHEN business_type = 'Fee_Consumption' AND remarks = '绑卡验证手续费' AND card_org = 'VISA' AND tx_country NOT IN ('US','USA') THEN 1 ELSE 0 END),

            -- 6. Clearing Volumes (SUM 类型使用 CASE)
            SUM(CASE WHEN card_org = 'Master' AND is_dom = TRUE AND is_clearing = TRUE THEN billing_amount ELSE 0 END),
            SUM(CASE WHEN card_org = 'Master' AND is_dom = FALSE AND is_clearing = TRUE THEN billing_amount ELSE 0 END),
            SUM(CASE WHEN card_org = 'VISA' AND is_dom = TRUE AND is_clearing = TRUE THEN billing_amount ELSE 0 END),
            SUM(CASE WHEN card_org = 'VISA' AND is_dom = FALSE AND is_clearing = TRUE THEN billing_amount ELSE 0 END),

            -- 7. Rebate Base (清算金额 + 退款金额)
            SUM(CASE WHEN is_valid_settle = TRUE AND (is_clearing = TRUE OR is_refund = TRUE) THEN billing_amount ELSE 0 END),
            SUM(CASE WHEN is_valid_settle = TRUE AND (is_clearing = TRUE OR is_refund = TRUE) THEN billing_amount ELSE 0 END),

            -- 8. 活跃卡数 (唯一聚合)
            COUNT(DISTINCT card_id)

        FROM (
            -- 分批获取 [日期+账号] 组合
            SELECT (transaction_time AT TIME ZONE 'Asia/Shanghai')::date as r_dt, account_id as acc_id 
            FROM "dwm_bb_card_transaction_detail_p" 
            WHERE (transaction_time AT TIME ZONE 'Asia/Shanghai')::date >= p_start_date 
              AND (transaction_time AT TIME ZONE 'Asia/Shanghai')::date < p_end_date
            GROUP BY 1, 2 ORDER BY 1, 2 LIMIT v_batch_size OFFSET v_offset
        ) AS sub
        JOIN "dwm_bb_card_transaction_detail_p" dwm ON (dwm.transaction_time AT TIME ZONE 'Asia/Shanghai')::date = sub.r_dt AND dwm.account_id = sub.acc_id
        WHERE dwm.delete_time IS NULL
        GROUP BY 1, 2, 3
        ON CONFLICT (id, report_date) DO UPDATE SET 
            update_time = NOW(),
            version = dws_bb_card_finance_daily_p.version + 1,
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
            active_card_count = EXCLUDED.active_card_count;

        v_offset := v_offset + v_batch_size;
        COMMIT; 
    END LOOP;
END $BODY$
  LANGUAGE plpgsql