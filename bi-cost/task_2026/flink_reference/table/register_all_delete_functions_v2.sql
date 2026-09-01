-- task_2026 v2 全部删除函数（一次注册）
-- 本文件由 gen_all_jobs.py 生成；每次重生成会同步覆盖。

CREATE OR REPLACE FUNCTION public.fn_delete_dws_qbit_card_wallet_transaction_cdc(
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
            SELECT DISTINCT EXTRACT(YEAR FROM tr."createTime"::DATE::TIMESTAMP)::INT
            FROM "qbitCardWalletTransaction" AS tr
            WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_qbit_card_wallet_transaction_%s WHERE (account_id, business_type, create_date, status) IN (SELECT DISTINCT tr."accountId", tr."businessType", tr."createTime"::DATE::TIMESTAMP, tr."status" FROM "qbitCardWalletTransaction" AS tr WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE))$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_qbit_card_wallet_transaction_%s WHERE (account_id, business_type, create_date, status) IN (SELECT DISTINCT tr."accountId", tr."businessType", tr."createTime"::DATE::TIMESTAMP, tr."status" FROM "qbitCardWalletTransaction" AS tr WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE))$fmt$, v_year);
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
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_qbit_card_wallet_transaction_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_qbit_card_wallet_transaction_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_dws_qbit_card_wallet_transaction_cdc(true);


CREATE OR REPLACE FUNCTION public.fn_delete_dws_qbit_card_transaction_cdc(
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
            SELECT DISTINCT EXTRACT(YEAR FROM tr."createTime"::DATE::TIMESTAMP)::INT
            FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
            WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_qbit_card_transaction_%s WHERE (account_id, provider, bin, business_type, create_date, status) IN (SELECT DISTINCT tr."accountId", tr."provider", qc."firstSix", tr."businessType", tr."createTime"::DATE::TIMESTAMP, tr."status" FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id" WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE))$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_qbit_card_transaction_%s WHERE (account_id, provider, bin, business_type, create_date, status) IN (SELECT DISTINCT tr."accountId", tr."provider", qc."firstSix", tr."businessType", tr."createTime"::DATE::TIMESTAMP, tr."status" FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id" WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE))$fmt$, v_year);
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
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_qbit_card_transaction_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_qbit_card_transaction_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_dws_qbit_card_transaction_cdc(true);


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
            SELECT DISTINCT EXTRACT(YEAR FROM tr."createTime"::DATE::TIMESTAMP)::INT
            FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
            WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_qbit_card_transaction_extend_%s WHERE (account_id, provider, bin, business_type, status, transaction_currency, country, create_date) IN (SELECT DISTINCT tr."accountId", tr."provider", qc."firstSix", tr."businessType", tr."status", tr."transactionCurrency", tr."specialSourceData"->>'country', tr."createTime"::DATE::TIMESTAMP FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id" WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE))$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_qbit_card_transaction_extend_%s WHERE (account_id, provider, bin, business_type, status, transaction_currency, country, create_date) IN (SELECT DISTINCT tr."accountId", tr."provider", qc."firstSix", tr."businessType", tr."status", tr."transactionCurrency", tr."specialSourceData"->>'country', tr."createTime"::DATE::TIMESTAMP FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id" WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE))$fmt$, v_year);
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
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_qbit_card_transaction_extend_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_qbit_card_transaction_extend_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end;
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


CREATE OR REPLACE FUNCTION public.fn_delete_dws_qbit_card_group_transaction_cdc(
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
            SELECT DISTINCT EXTRACT(YEAR FROM tr."createTime"::DATE::TIMESTAMP)::INT
            FROM "qbitCardGroupTransaction" AS tr
            WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_qbit_card_group_transaction_%s WHERE (account_id, business_type, create_date, status) IN (SELECT DISTINCT tr."accountId", tr."businessType", tr."createTime"::DATE::TIMESTAMP, tr."status" FROM "qbitCardGroupTransaction" AS tr WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE))$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_qbit_card_group_transaction_%s WHERE (account_id, business_type, create_date, status) IN (SELECT DISTINCT tr."accountId", tr."businessType", tr."createTime"::DATE::TIMESTAMP, tr."status" FROM "qbitCardGroupTransaction" AS tr WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE))$fmt$, v_year);
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
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_qbit_card_group_transaction_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_qbit_card_group_transaction_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_dws_qbit_card_group_transaction_cdc(true);


CREATE OR REPLACE FUNCTION public.fn_delete_dws_transfer_cdc(
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
            SELECT DISTINCT EXTRACT(YEAR FROM tr."createTime"::DATE::TIMESTAMP)::INT
            FROM "transfer" AS tr
            WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_transfer_%s WHERE (account_id, business_type_detail, business_type_code, settlement_currency, create_date, status, currency) IN (SELECT DISTINCT tr."accountId", tr."businessTypeDetail", tr."businessCode", tr."settlementCurrency", tr."createTime"::DATE::TIMESTAMP, tr."status", "currency" FROM "transfer" AS tr WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE))$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_transfer_%s WHERE (account_id, business_type_detail, business_type_code, settlement_currency, create_date, status, currency) IN (SELECT DISTINCT tr."accountId", tr."businessTypeDetail", tr."businessCode", tr."settlementCurrency", tr."createTime"::DATE::TIMESTAMP, tr."status", "currency" FROM "transfer" AS tr WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE))$fmt$, v_year);
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
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_transfer_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_transfer_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_dws_transfer_cdc(true);


CREATE OR REPLACE FUNCTION public.fn_delete_dws_transfer_extend_cdc(
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
            SELECT DISTINCT EXTRACT(YEAR FROM tr."createTime"::DATE::TIMESTAMP)::INT
            FROM "transfer" AS tr
LEFT JOIN "globalConversion" AS ta ON ta."recordId"::UUID = tr.id
            WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_transfer_extend_%s WHERE (account_id, create_date, status) IN (SELECT DISTINCT tr."accountId", tr."createTime"::DATE::TIMESTAMP, tr."status" FROM "transfer" AS tr
LEFT JOIN "globalConversion" AS ta ON ta."recordId"::UUID = tr.id WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE))$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_transfer_extend_%s WHERE (account_id, create_date, status) IN (SELECT DISTINCT tr."accountId", tr."createTime"::DATE::TIMESTAMP, tr."status" FROM "transfer" AS tr
LEFT JOIN "globalConversion" AS ta ON ta."recordId"::UUID = tr.id WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE))$fmt$, v_year);
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
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_transfer_extend_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_transfer_extend_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_dws_transfer_extend_cdc(true);


CREATE OR REPLACE FUNCTION public.fn_delete_dws_crypto_assets_transfers_cdc(
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
            SELECT DISTINCT EXTRACT(YEAR FROM tr."create_time"::DATE::TIMESTAMP)::INT
            FROM "crypto_assets_transfers" AS tr
            WHERE (tr."create_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."create_time" < CURRENT_DATE)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_crypto_assets_transfers_%s WHERE (account_id, status, sender_type, recipient_type, hidden, create_date, currency, action) IN (SELECT DISTINCT "account_id", "status", "sender_type", "recipient_type", "hidden", tr."create_time"::DATE::TIMESTAMP, "currency", "action" FROM "crypto_assets_transfers" AS tr WHERE (tr."create_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."create_time" < CURRENT_DATE))$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_crypto_assets_transfers_%s WHERE (account_id, status, sender_type, recipient_type, hidden, create_date, currency, action) IN (SELECT DISTINCT "account_id", "status", "sender_type", "recipient_type", "hidden", tr."create_time"::DATE::TIMESTAMP, "currency", "action" FROM "crypto_assets_transfers" AS tr WHERE (tr."create_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."create_time" < CURRENT_DATE))$fmt$, v_year);
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
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_crypto_assets_transfers_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_crypto_assets_transfers_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_dws_crypto_assets_transfers_cdc(true);


CREATE OR REPLACE FUNCTION public.fn_delete_ods_fund_profits_cdc(
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
            SELECT DISTINCT EXTRACT(YEAR FROM tr."create_time"::DATE::TIMESTAMP)::INT
            FROM "fund_profits" AS tr
CROSS JOIN LATERAL jsonb_array_elements(fees) AS fee
            WHERE (tr."create_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."create_time" < CURRENT_DATE)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.ods_fund_profits_%s WHERE (fund_id) IN (SELECT DISTINCT tr."id" FROM "fund_profits" AS tr
CROSS JOIN LATERAL jsonb_array_elements(fees) AS fee WHERE (tr."create_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."create_time" < CURRENT_DATE))$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.ods_fund_profits_%s WHERE (fund_id) IN (SELECT DISTINCT tr."id" FROM "fund_profits" AS tr
CROSS JOIN LATERAL jsonb_array_elements(fees) AS fee WHERE (tr."create_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."create_time" < CURRENT_DATE))$fmt$, v_year);
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
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.ods_fund_profits_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.ods_fund_profits_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_ods_fund_profits_cdc(true);


CREATE OR REPLACE FUNCTION public.fn_delete_ods_qbit_card_cdc(
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
            SELECT DISTINCT EXTRACT(YEAR FROM tr."createTime"::DATE::TIMESTAMP)::INT
            FROM "qbitCard" AS tr
            WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.ods_qbit_card_%s WHERE (card_id) IN (SELECT DISTINCT tr."id" FROM "qbitCard" AS tr WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE))$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.ods_qbit_card_%s WHERE (card_id) IN (SELECT DISTINCT tr."id" FROM "qbitCard" AS tr WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE))$fmt$, v_year);
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
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.ods_qbit_card_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.ods_qbit_card_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_ods_qbit_card_cdc(true);


CREATE OR REPLACE FUNCTION public.fn_delete_dws_open_card_cdc(
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
            SELECT DISTINCT EXTRACT(YEAR FROM tr."createTime"::DATE::TIMESTAMP)::INT
            FROM "Transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON qc."id"::VARCHAR = tr."sourceId"
            WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_open_card_%s WHERE (status, account_id, provider, bin, create_date) IN (SELECT DISTINCT tr."status", tr."accountId", qc."provider", qc."firstSix", tr."createTime"::DATE::TIMESTAMP FROM "Transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON qc."id"::VARCHAR = tr."sourceId" WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE))$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_open_card_%s WHERE (status, account_id, provider, bin, create_date) IN (SELECT DISTINCT tr."status", tr."accountId", qc."provider", qc."firstSix", tr."createTime"::DATE::TIMESTAMP FROM "Transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON qc."id"::VARCHAR = tr."sourceId" WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE))$fmt$, v_year);
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
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_open_card_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_open_card_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_dws_open_card_cdc(true);


CREATE OR REPLACE FUNCTION public.fn_delete_dws_physical_card_cdc(
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
            SELECT DISTINCT EXTRACT(YEAR FROM tr."createTime"::DATE::TIMESTAMP)::INT
            FROM "qbitCardWalletTransaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
            WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_physical_card_%s WHERE (account_id, provider, bin, status, create_date) IN (SELECT DISTINCT tr."accountId", qc."provider", qc."firstSix", tr."status", tr."createTime"::DATE::TIMESTAMP FROM "qbitCardWalletTransaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id" WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE))$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_physical_card_%s WHERE (account_id, provider, bin, status, create_date) IN (SELECT DISTINCT tr."accountId", qc."provider", qc."firstSix", tr."status", tr."createTime"::DATE::TIMESTAMP FROM "qbitCardWalletTransaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id" WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE))$fmt$, v_year);
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
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_physical_card_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_physical_card_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_dws_physical_card_cdc(true);


CREATE OR REPLACE FUNCTION public.fn_delete_dws_sale_card_wallet_transaction_cdc(
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
        -- ===== CDC 模式：qi 式按作用域(scope)精准删（受影响 (日期,账户) 集合，先清后重算）=====
        FOR v_year IN
            SELECT DISTINCT EXTRACT(YEAR FROM a.scope_date)::INT
            FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "qbitCardWalletTransaction" AS tr
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) a
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_sale_card_wallet_transaction_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "qbitCardWalletTransaction" AS tr
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_date) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_sale_card_wallet_transaction_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "qbitCardWalletTransaction" AS tr
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_date) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year);
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    ELSE
        -- ===== 补数/修复模式：按日期区间跨分表清理 =====
        FOR v_year IN
            SELECT DISTINCT gs.y
            FROM generate_series(EXTRACT(YEAR FROM p_start)::INT, EXTRACT(YEAR FROM p_end)::INT) gs(y)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_sale_card_wallet_transaction_%s WHERE DATE(create_date) >= $1 AND DATE(create_date) <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_sale_card_wallet_transaction_%s WHERE DATE(create_date) >= $1 AND DATE(create_date) <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_dws_sale_card_wallet_transaction_cdc(true);


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
        -- ===== CDC 模式：qi 式按作用域(scope)精准删（受影响 (日期,账户) 集合，先清后重算）=====
        FOR v_year IN
            SELECT DISTINCT EXTRACT(YEAR FROM a.scope_date)::INT
            FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) a
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_sale_card_transaction_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_date) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_sale_card_transaction_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_date) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year);
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    ELSE
        -- ===== 补数/修复模式：按日期区间跨分表清理 =====
        FOR v_year IN
            SELECT DISTINCT gs.y
            FROM generate_series(EXTRACT(YEAR FROM p_start)::INT, EXTRACT(YEAR FROM p_end)::INT) gs(y)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_sale_card_transaction_%s WHERE DATE(create_date) >= $1 AND DATE(create_date) <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_sale_card_transaction_%s WHERE DATE(create_date) >= $1 AND DATE(create_date) <= $2$fmt$, v_year) USING p_start, p_end;
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


CREATE OR REPLACE FUNCTION public.fn_delete_dws_sale_card_transaction_extend_cdc(
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
        -- ===== CDC 模式：qi 式按作用域(scope)精准删（受影响 (日期,账户) 集合，先清后重算）=====
        FOR v_year IN
            SELECT DISTINCT EXTRACT(YEAR FROM a.scope_date)::INT
            FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc.id
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) a
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_sale_card_transaction_extend_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc.id
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_date) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_sale_card_transaction_extend_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc.id
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_date) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year);
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    ELSE
        -- ===== 补数/修复模式：按日期区间跨分表清理 =====
        FOR v_year IN
            SELECT DISTINCT gs.y
            FROM generate_series(EXTRACT(YEAR FROM p_start)::INT, EXTRACT(YEAR FROM p_end)::INT) gs(y)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_sale_card_transaction_extend_%s WHERE DATE(create_date) >= $1 AND DATE(create_date) <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_sale_card_transaction_extend_%s WHERE DATE(create_date) >= $1 AND DATE(create_date) <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_dws_sale_card_transaction_extend_cdc(true);


CREATE OR REPLACE FUNCTION public.fn_delete_dws_sale_card_group_transaction_cdc(
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
        -- ===== CDC 模式：qi 式按作用域(scope)精准删（受影响 (日期,账户) 集合，先清后重算）=====
        FOR v_year IN
            SELECT DISTINCT EXTRACT(YEAR FROM a.scope_date)::INT
            FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "qbitCardGroupTransaction" AS tr
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) a
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_sale_card_group_transaction_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "qbitCardGroupTransaction" AS tr
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_date) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_sale_card_group_transaction_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "qbitCardGroupTransaction" AS tr
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_date) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year);
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    ELSE
        -- ===== 补数/修复模式：按日期区间跨分表清理 =====
        FOR v_year IN
            SELECT DISTINCT gs.y
            FROM generate_series(EXTRACT(YEAR FROM p_start)::INT, EXTRACT(YEAR FROM p_end)::INT) gs(y)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_sale_card_group_transaction_%s WHERE DATE(create_date) >= $1 AND DATE(create_date) <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_sale_card_group_transaction_%s WHERE DATE(create_date) >= $1 AND DATE(create_date) <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_dws_sale_card_group_transaction_cdc(true);


CREATE OR REPLACE FUNCTION public.fn_delete_dws_sale_transfer_cdc(
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
        -- ===== CDC 模式：qi 式按作用域(scope)精准删（受影响 (日期,账户) 集合，先清后重算）=====
        FOR v_year IN
            SELECT DISTINCT EXTRACT(YEAR FROM a.scope_date)::INT
            FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "transfer" AS tr
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) a
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_sale_transfer_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "transfer" AS tr
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_date) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_sale_transfer_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "transfer" AS tr
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_date) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year);
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    ELSE
        -- ===== 补数/修复模式：按日期区间跨分表清理 =====
        FOR v_year IN
            SELECT DISTINCT gs.y
            FROM generate_series(EXTRACT(YEAR FROM p_start)::INT, EXTRACT(YEAR FROM p_end)::INT) gs(y)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_sale_transfer_%s WHERE DATE(create_date) >= $1 AND DATE(create_date) <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_sale_transfer_%s WHERE DATE(create_date) >= $1 AND DATE(create_date) <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_dws_sale_transfer_cdc(true);


CREATE OR REPLACE FUNCTION public.fn_delete_dws_sale_transfer_extend_cdc(
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
        -- ===== CDC 模式：qi 式按作用域(scope)精准删（受影响 (日期,账户) 集合，先清后重算）=====
        FOR v_year IN
            SELECT DISTINCT EXTRACT(YEAR FROM a.scope_date)::INT
            FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "transfer" as tr
LEFT JOIN "globalConversion" as ta on ta."recordId"::UUID = tr.id
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
WHERE
tr."deleteTime" IS NULL and ta."deleteTime" IS NULL
AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' 
AND tr."createTime" < CURRENT_DATE
) as tt
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) a
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_sale_transfer_extend_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "transfer" as tr
LEFT JOIN "globalConversion" as ta on ta."recordId"::UUID = tr.id
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
WHERE
tr."deleteTime" IS NULL and ta."deleteTime" IS NULL
AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' 
AND tr."createTime" < CURRENT_DATE
) as tt
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_date) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_sale_transfer_extend_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "transfer" as tr
LEFT JOIN "globalConversion" as ta on ta."recordId"::UUID = tr.id
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
WHERE
tr."deleteTime" IS NULL and ta."deleteTime" IS NULL
AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' 
AND tr."createTime" < CURRENT_DATE
) as tt
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_date) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year);
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    ELSE
        -- ===== 补数/修复模式：按日期区间跨分表清理 =====
        FOR v_year IN
            SELECT DISTINCT gs.y
            FROM generate_series(EXTRACT(YEAR FROM p_start)::INT, EXTRACT(YEAR FROM p_end)::INT) gs(y)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_sale_transfer_extend_%s WHERE DATE(create_date) >= $1 AND DATE(create_date) <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_sale_transfer_extend_%s WHERE DATE(create_date) >= $1 AND DATE(create_date) <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_dws_sale_transfer_extend_cdc(true);


CREATE OR REPLACE FUNCTION public.fn_delete_dws_sale_crypto_assets_transfers_cdc(
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
        -- ===== CDC 模式：qi 式按作用域(scope)精准删（受影响 (日期,账户) 集合，先清后重算）=====
        FOR v_year IN
            SELECT DISTINCT EXTRACT(YEAR FROM a.scope_date)::INT
            FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "crypto_assets_transfers" AS tr
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."account_id"::text
      AND tr."create_time" >= sr.relation_start_time AND (tr."create_time" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."account_id"::text
      AND sr.delete_time IS NULL AND tr."create_time" >= sr.relation_start_time
      AND (tr."create_time" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) a
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_sale_crypto_assets_transfers_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "crypto_assets_transfers" AS tr
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."account_id"::text
      AND tr."create_time" >= sr.relation_start_time AND (tr."create_time" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."account_id"::text
      AND sr.delete_time IS NULL AND tr."create_time" >= sr.relation_start_time
      AND (tr."create_time" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_date) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_sale_crypto_assets_transfers_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "crypto_assets_transfers" AS tr
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."account_id"::text
      AND tr."create_time" >= sr.relation_start_time AND (tr."create_time" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."account_id"::text
      AND sr.delete_time IS NULL AND tr."create_time" >= sr.relation_start_time
      AND (tr."create_time" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_date) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year);
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    ELSE
        -- ===== 补数/修复模式：按日期区间跨分表清理 =====
        FOR v_year IN
            SELECT DISTINCT gs.y
            FROM generate_series(EXTRACT(YEAR FROM p_start)::INT, EXTRACT(YEAR FROM p_end)::INT) gs(y)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_sale_crypto_assets_transfers_%s WHERE DATE(create_date) >= $1 AND DATE(create_date) <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_sale_crypto_assets_transfers_%s WHERE DATE(create_date) >= $1 AND DATE(create_date) <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_dws_sale_crypto_assets_transfers_cdc(true);


CREATE OR REPLACE FUNCTION public.fn_delete_ods_sale_fund_profits_cdc(
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
        -- ===== CDC 模式：qi 式按作用域(scope)精准删（受影响 (日期,账户) 集合，先清后重算）=====
        FOR v_year IN
            SELECT DISTINCT EXTRACT(YEAR FROM a.scope_date)::INT
            FROM (SELECT DISTINCT DATE(tr."create_time") AS scope_date, tr."account_id" AS scope_account
        FROM fund_profits AS tr
CROSS JOIN LATERAL jsonb_array_elements(fees) AS fee
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."account_id"::text
      AND tr."create_time" >= sr.relation_start_time AND (tr."create_time" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."account_id"::text
      AND sr.delete_time IS NULL AND tr."create_time" >= sr.relation_start_time
      AND (tr."create_time" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."create_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."create_time" < CURRENT_DATE) OR (tr."update_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."update_time" < CURRENT_DATE) OR (tr."delete_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."delete_time" < CURRENT_DATE)) a
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.ods_sale_fund_profits_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."create_time") AS scope_date, tr."account_id" AS scope_account
        FROM fund_profits AS tr
CROSS JOIN LATERAL jsonb_array_elements(fees) AS fee
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."account_id"::text
      AND tr."create_time" >= sr.relation_start_time AND (tr."create_time" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."account_id"::text
      AND sr.delete_time IS NULL AND tr."create_time" >= sr.relation_start_time
      AND (tr."create_time" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."create_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."create_time" < CURRENT_DATE) OR (tr."update_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."update_time" < CURRENT_DATE) OR (tr."delete_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."delete_time" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_time) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.ods_sale_fund_profits_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."create_time") AS scope_date, tr."account_id" AS scope_account
        FROM fund_profits AS tr
CROSS JOIN LATERAL jsonb_array_elements(fees) AS fee
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."account_id"::text
      AND tr."create_time" >= sr.relation_start_time AND (tr."create_time" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."account_id"::text
      AND sr.delete_time IS NULL AND tr."create_time" >= sr.relation_start_time
      AND (tr."create_time" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."create_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."create_time" < CURRENT_DATE) OR (tr."update_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."update_time" < CURRENT_DATE) OR (tr."delete_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."delete_time" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_time) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year);
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    ELSE
        -- ===== 补数/修复模式：按日期区间跨分表清理 =====
        FOR v_year IN
            SELECT DISTINCT gs.y
            FROM generate_series(EXTRACT(YEAR FROM p_start)::INT, EXTRACT(YEAR FROM p_end)::INT) gs(y)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.ods_sale_fund_profits_%s WHERE DATE(create_time) >= $1 AND DATE(create_time) <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.ods_sale_fund_profits_%s WHERE DATE(create_time) >= $1 AND DATE(create_time) <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_ods_sale_fund_profits_cdc(true);


CREATE OR REPLACE FUNCTION public.fn_delete_ods_sale_qbit_card_cdc(
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
        -- ===== CDC 模式：qi 式按作用域(scope)精准删（受影响 (日期,账户) 集合，先清后重算）=====
        FOR v_year IN
            SELECT DISTINCT EXTRACT(YEAR FROM a.scope_date)::INT
            FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "qbitCard" AS tr
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."account_id"::text
      AND tr."create_time" >= sr.relation_start_time AND (tr."create_time" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."account_id"::text
      AND sr.delete_time IS NULL AND tr."create_time" >= sr.relation_start_time
      AND (tr."create_time" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) a
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.ods_sale_qbit_card_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "qbitCard" AS tr
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."account_id"::text
      AND tr."create_time" >= sr.relation_start_time AND (tr."create_time" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."account_id"::text
      AND sr.delete_time IS NULL AND tr."create_time" >= sr.relation_start_time
      AND (tr."create_time" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_time) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.ods_sale_qbit_card_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "qbitCard" AS tr
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."account_id"::text
      AND tr."create_time" >= sr.relation_start_time AND (tr."create_time" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."account_id"::text
      AND sr.delete_time IS NULL AND tr."create_time" >= sr.relation_start_time
      AND (tr."create_time" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_time) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year);
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    ELSE
        -- ===== 补数/修复模式：按日期区间跨分表清理 =====
        FOR v_year IN
            SELECT DISTINCT gs.y
            FROM generate_series(EXTRACT(YEAR FROM p_start)::INT, EXTRACT(YEAR FROM p_end)::INT) gs(y)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.ods_sale_qbit_card_%s WHERE DATE(create_time) >= $1 AND DATE(create_time) <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.ods_sale_qbit_card_%s WHERE DATE(create_time) >= $1 AND DATE(create_time) <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_ods_sale_qbit_card_cdc(true);


CREATE OR REPLACE FUNCTION public.fn_delete_dws_sale_open_card_cdc(
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
        -- ===== CDC 模式：qi 式按作用域(scope)精准删（受影响 (日期,账户) 集合，先清后重算）=====
        FOR v_year IN
            SELECT DISTINCT EXTRACT(YEAR FROM a.scope_date)::INT
            FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "Transaction" as "tr"
LEFT JOIN "qbitCard" qc ON qc."id" :: VARCHAR = "tr"."sourceId"
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) a
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_sale_open_card_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "Transaction" as "tr"
LEFT JOIN "qbitCard" qc ON qc."id" :: VARCHAR = "tr"."sourceId"
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_date) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_sale_open_card_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "Transaction" as "tr"
LEFT JOIN "qbitCard" qc ON qc."id" :: VARCHAR = "tr"."sourceId"
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_date) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year);
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    ELSE
        -- ===== 补数/修复模式：按日期区间跨分表清理 =====
        FOR v_year IN
            SELECT DISTINCT gs.y
            FROM generate_series(EXTRACT(YEAR FROM p_start)::INT, EXTRACT(YEAR FROM p_end)::INT) gs(y)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_sale_open_card_%s WHERE DATE(create_date) >= $1 AND DATE(create_date) <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_sale_open_card_%s WHERE DATE(create_date) >= $1 AND DATE(create_date) <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_dws_sale_open_card_cdc(true);


CREATE OR REPLACE FUNCTION public.fn_delete_dws_sale_physical_card_cdc(
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
        -- ===== CDC 模式：qi 式按作用域(scope)精准删（受影响 (日期,账户) 集合，先清后重算）=====
        FOR v_year IN
            SELECT DISTINCT EXTRACT(YEAR FROM a.scope_date)::INT
            FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "qbitCardWalletTransaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) a
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_sale_physical_card_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "qbitCardWalletTransaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_date) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_sale_physical_card_%s t
                    WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account
        FROM "qbitCardWalletTransaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."deleteTime" < CURRENT_DATE)) scope
                        WHERE DATE(t.create_date) = scope.scope_date AND t.account_id = scope.scope_account)$fmt$, v_year);
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    ELSE
        -- ===== 补数/修复模式：按日期区间跨分表清理 =====
        FOR v_year IN
            SELECT DISTINCT gs.y
            FROM generate_series(EXTRACT(YEAR FROM p_start)::INT, EXTRACT(YEAR FROM p_end)::INT) gs(y)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.dws_sale_physical_card_%s WHERE DATE(create_date) >= $1 AND DATE(create_date) <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.dws_sale_physical_card_%s WHERE DATE(create_date) >= $1 AND DATE(create_date) <= $2$fmt$, v_year) USING p_start, p_end;
                GET DIAGNOSTICS v_n = ROW_COUNT;
            END IF;
            affected := affected + v_n;
        END LOOP;
    END IF;
    RETURN affected;
END;
$function$;

-- 首次部署请先 dry-run 核对影响行数：
-- SELECT public.fn_delete_dws_sale_physical_card_cdc(true);

