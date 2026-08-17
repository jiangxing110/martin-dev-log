CREATE OR REPLACE FUNCTION public.fn_delete_dws_qbit_card_transaction_extend_cdc(
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
            SELECT DISTINCT EXTRACT(YEAR FROM CURRENT_DATE)::INT
            FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
            WHERE FALSE
        LOOP
            IF p_dry_run THEN
                EXECUTE format('SELECT COUNT(*) FROM public.dws_qbit_card_transaction_extend_%s WHERE (a, c, c, o, u, n, t, _, i, d, ,,  , p, r, o, v, i, d, e, r, ,,  , b, i, n, ,,  , b, u, s, i, n, e, s, s, _, t, y, p, e, ,,  , s, t, a, t, u, s, ,,  , t, r, a, n, s, a, c, t, i, o, n, _, c, u, r, r, e, n, c, y, ,,  , c, o, u, n, t, r, y, ,,  , c, r, e, a, t, e, _, d, a, t, e) IN (SELECT DISTINCT tr."accountId" AS "account_id", tr."provider" AS "provider", qc."firstSix" AS "bin", tr."businessType", tr."status" AS "status", tr."transactionCurrency" AS "transaction_currency", tr."specialSourceData"->>'country' AS "country", CURRENT_DATE FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id" WHERE FALSE)', v_year) INTO v_n;
            ELSE
                EXECUTE format('DELETE FROM public.dws_qbit_card_transaction_extend_%s WHERE (a, c, c, o, u, n, t, _, i, d, ,,  , p, r, o, v, i, d, e, r, ,,  , b, i, n, ,,  , b, u, s, i, n, e, s, s, _, t, y, p, e, ,,  , s, t, a, t, u, s, ,,  , t, r, a, n, s, a, c, t, i, o, n, _, c, u, r, r, e, n, c, y, ,,  , c, o, u, n, t, r, y, ,,  , c, r, e, a, t, e, _, d, a, t, e) IN (SELECT DISTINCT tr."accountId" AS "account_id", tr."provider" AS "provider", qc."firstSix" AS "bin", tr."businessType", tr."status" AS "status", tr."transactionCurrency" AS "transaction_currency", tr."specialSourceData"->>'country' AS "country", CURRENT_DATE FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id" WHERE FALSE)', v_year);
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
                EXECUTE format('SELECT COUNT(*) FROM public.dws_qbit_card_transaction_extend_%s WHERE create_date >= $1 AND create_date <= $2', v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format('DELETE FROM public.dws_qbit_card_transaction_extend_%s WHERE create_date >= $1 AND create_date <= $2', v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_dws_qbit_card_transaction_extend_cdc(true);
