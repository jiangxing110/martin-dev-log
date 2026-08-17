CREATE OR REPLACE FUNCTION public.fn_delete_dws_sale_card_transaction_cdc(
    p_dry_run BOOLEAN DEFAULT false,
    p_start   DATE DEFAULT NULL,
    p_end     DATE DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $function$
DECLARE
    affected BIGINT := 0;
    v_year   INT;
    v_n      BIGINT;
BEGIN
    IF p_start IS NULL THEN
        -- ===== CDC 模式：按唯一业务键精准删（受影响 key 集合，不再按整天删）=====
        FOR v_year IN
            SELECT DISTINCT EXTRACT(YEAR FROM DATE(tr."createTime"))::INT
            FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
LEFT JOIN "public"."ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
            WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)
        LOOP
            IF p_dry_run THEN
                EXECUTE format('SELECT COUNT(*) FROM public.dws_sale_card_transaction_%s WHERE (account_id, sale_or_am_id, business_type, status, provider, bin, create_date) IN (SELECT DISTINCT tr."accountId", ids."sale_or_am_id", tr."businessType", tr."status", tr."provider", qc."firstSix", DATE(tr."createTime") FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
LEFT JOIN "public"."ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE))', v_year) INTO v_n;
            ELSE
                EXECUTE format('DELETE FROM public.dws_sale_card_transaction_%s WHERE (account_id, sale_or_am_id, business_type, status, provider, bin, create_date) IN (SELECT DISTINCT tr."accountId", ids."sale_or_am_id", tr."businessType", tr."status", tr."provider", qc."firstSix", DATE(tr."createTime") FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
LEFT JOIN "public"."ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE))', v_year);
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    ELSE
        -- ===== 补数/修复模式：按 create_date 区间跨分表清理 =====
        FOR v_year IN
            SELECT DISTINCT gs.y
            FROM generate_series(EXTRACT(YEAR FROM p_start)::INT, EXTRACT(YEAR FROM p_end)::INT) gs(y)
        LOOP
            IF p_dry_run THEN
                EXECUTE format('SELECT COUNT(*) FROM public.dws_sale_card_transaction_%s WHERE create_date >= $1 AND create_date <= $2', v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format('DELETE FROM public.dws_sale_card_transaction_%s WHERE create_date >= $1 AND create_date <= $2', v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_dws_sale_card_transaction_cdc(true);
