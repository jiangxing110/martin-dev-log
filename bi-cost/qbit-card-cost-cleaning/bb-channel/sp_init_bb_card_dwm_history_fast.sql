CREATE OR REPLACE PROCEDURE "public"."sp_init_bb_card_dwm_history_fast"("p_start_time" timestamp, "p_end_time" timestamp)
 AS $BODY$
DECLARE
    v_curr_start      TIMESTAMP := p_start_time; 
    v_batch_interval  INTERVAL  := '1 day'; -- 建议步长改为 1 天
    v_table_name      TEXT;
BEGIN
    -- 1. 性能加速配置
    EXECUTE 'SET LOCAL synchronous_commit = off';
    EXECUTE 'SET LOCAL work_mem = ''256MB''';

    WHILE v_curr_start < p_end_time LOOP
        -- 2. 动态计算分区子表名 (例如: dwm_bb_card_tx_2026_01)
        v_table_name := 'dwm_bb_card_tx_' || to_char(v_curr_start, 'YYYY_MM');

        RAISE NOTICE 'BB DWM 直写子表: %, 时间段: % 至 %', v_table_name, v_curr_start, v_curr_start + v_batch_interval;

        -- 3. 使用 EXECUTE format 执行动态 SQL
        EXECUTE format('
            INSERT INTO %I (
                id, account_id, card_id, transaction_time, third_complete_time,
                business_type, status, remarks, card_org, 
                settle_country, tx_country, is_dom, resp_code, 
                request_code, reason_code, is_valid_settle, is_clearing, 
                is_reversal, is_refund, billing_amount, version
            )
            WITH bb_providers AS (
                SELECT system_provider FROM card_bin WHERE brand = ''BlueBanc''
            ),
            base_tx AS (
                SELECT A.*, C."type" as card_type
                FROM "qbitCardTransaction" A
                LEFT JOIN "qbitCard" C ON A."cardId" = C."id"
                WHERE A."createTime" >= %L 
                  AND A."createTime" < %L
                  AND A."provider" IN (SELECT system_provider FROM bb_providers)
            ),
            matched_settle AS (
                SELECT t.id as tx_uuid, B.* FROM base_tx t
                INNER JOIN "qbitCardSettlement" B ON t."sourceId" = B."transactionId"
                WHERE B."provider" = ''BlueBancCard''
                UNION ALL
                SELECT t.id as tx_uuid, B.* FROM base_tx t
                INNER JOIN "qbitCardSettlement" B ON B."qbitCardTransactionId" = t.id::text
                WHERE B."provider" = ''BlueBancCard''
            )
            SELECT DISTINCT ON (base.id)
                base.id, 
                base."accountId", 
                base."cardId", 
                base."createTime", 
                base."thirdCompleteTime",
                base."businessType", 
                base."status", 
                base."remarks", 
                base.card_type,
                -- 字段 1：提取结算数据的国家
                NULLIF(RIGHT(safe_json_text(m."rawData", ''txnLocation''), 2), '''') AS settle_country,
                -- 字段 2：提取交易数据的国家
                NULLIF(base."specialSourceData"->>''country'', '''') AS tx_country,
                -- 跨境判定逻辑
                CASE 
                    WHEN RIGHT(safe_json_text(m."rawData", ''txnLocation''), 2) IN (''US'',''USA'') 
                    OR base."specialSourceData"->>''country'' IN (''US'',''USA'') THEN TRUE 
                    ELSE FALSE 
                END AS is_dom,
                safe_json_text(m."rawData", ''responseCode''),
                safe_json_text(m."rawData", ''requestCode''),
                safe_json_text(m."rawData", ''reasonCode''),
                -- 有效结算判定
                CASE WHEN m."transactionType" NOT IN (''ST-REFUND_ADV'',''ST-PURCHASE_ADV'',''ST-ECOMM_ADV'',''ST-SETT_ADV'',''ST-ATM_ADV'') THEN TRUE ELSE FALSE END,
                CASE WHEN m."transactionType" = ''authorization.clearing'' THEN TRUE ELSE FALSE END,
                CASE WHEN m."transactionType" = ''authorization.reversal'' THEN TRUE ELSE FALSE END,
                CASE WHEN m."transactionType" = ''refund.clearing'' THEN TRUE ELSE FALSE END,
                COALESCE(m."billingAmount", 0)::numeric(20, 2),
                1
            FROM base_tx base
            LEFT JOIN matched_settle m ON base.id = m.tx_uuid
            ORDER BY base.id, m."createTime" DESC NULLS LAST
            ON CONFLICT (id, transaction_time) DO UPDATE SET 
                update_time = NOW(),
                settle_country = EXCLUDED.settle_country,
                tx_country = EXCLUDED.tx_country,
                billing_amount = EXCLUDED.billing_amount,
                status = EXCLUDED.status,
                version = %I.version + 1', 
            v_table_name, v_curr_start, v_curr_start + v_batch_interval, v_table_name
        );

        COMMIT; 
        v_curr_start := v_curr_start + v_batch_interval;
    END LOOP;
END $BODY$
  LANGUAGE plpgsql