CREATE OR REPLACE PROCEDURE "public"."sp_init_qi_card_dwm_by_fast"("p_start" timestamp, "p_end" timestamp)
 AS $BODY$
DECLARE
    v_curr_start      TIMESTAMP := p_start;
    v_batch_interval  INTERVAL  := '1 day'; 
    v_table_name      TEXT;
BEGIN
    EXECUTE 'SET LOCAL work_mem = ''256MB''';           
    EXECUTE 'SET LOCAL synchronous_commit = off';      

    WHILE v_curr_start < p_end LOOP
        v_table_name := 'dwm_qi_card_tx_' || to_char(v_curr_start, 'YYYY_MM');

        RAISE NOTICE 'QI DWM 直写子表: %, 时间段: % 至 %', v_table_name, v_curr_start, v_curr_start + v_batch_interval;

        EXECUTE format('
            INSERT INTO %I (
                id, transaction_id, account_id, card_id, 
                status, transaction_time, business_type, 
                version, remarks, create_time, update_time, delete_time,
                billing_amount, is_qbit_provision, is_hk_region, is_consumption, 
                is_reversal_or_credit, has_special_code, is_vip_account
            )
            WITH target_providers AS (
                SELECT system_provider FROM card_bin WHERE brand = ''QbitIssuing''
            ),
            base_tx AS (
                SELECT B.* FROM "qbitCardTransaction" B
                WHERE B."transactionTime" >= %L AND B."transactionTime" < %L
                  AND B."provider" IN (SELECT system_provider FROM target_providers)
            )
            SELECT DISTINCT ON (B.id)
                B.id,                     -- 1
                B."transactionId",        -- 2
                B."accountId",            -- 3
                B."cardId",               -- 4 (已补全)
                B."status",               -- 5
                B."transactionTime",      -- 6
                B."businessType",         -- 7 (已补全)
                COALESCE(B.version, 1),   -- 8
                ''History Init'',           -- 9
                B."createTime",           -- 10
                NOW(),                    -- 11
                B."deleteTime",           -- 12
                COALESCE(D.usd_amount, 0)::numeric(20, 2), -- 13
                (D.channel_provision = ''QBIT''),           -- 14
                (D.country IN (''HK'', ''HKG'')),          -- 15
                (B."businessType" = ''Consumption''),       -- 16
                (B."businessType" IN (''Reversal'', ''Credit'')), -- 17
                CASE WHEN B."specialSourceData"->>''code'' IS NOT NULL 
                     THEN (B."specialSourceData"->>''code'')::JSONB ?| ARRAY[''1001'', ''1103'', ''1105'']
                     ELSE FALSE END,      -- 18
                FALSE                     -- 19 (is_vip_account)
            FROM base_tx B
            LEFT JOIN "quantum_card_transaction_extend" D ON B."transactionId" = D."transaction_id"
            ORDER BY B.id, B."updateTime" DESC
            ON CONFLICT (id, transaction_time) DO UPDATE SET 
                update_time = NOW(), 
                status = EXCLUDED.status, 
                card_id = EXCLUDED.card_id,
                business_type = EXCLUDED.business_type,
                billing_amount = EXCLUDED.billing_amount,
                version = %I.version + 1', 
            v_table_name, v_curr_start, v_curr_start + v_batch_interval, v_table_name
        );
        
        COMMIT; 
        v_curr_start := v_curr_start + v_batch_interval;
    END LOOP;
END $BODY$
  LANGUAGE plpgsql