-- [TODO] ods_sale_fund_profits 检测到嵌套/非标准 FROM（fund_profits AS tr
CROSS JOIN LATERAL js...），
--        删除函数的变更窗口与聚合子查询的源别名引用可能需要人工校准，上线前务必核对。
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
        -- ===== CDC 模式：按唯一业务键精准删（受影响 key 集合，不再按整天删）=====
        FOR v_year IN
            SELECT DISTINCT EXTRACT(YEAR FROM DATE(tr."create_time"))::INT
            FROM fund_profits AS tr
CROSS JOIN LATERAL jsonb_array_elements(fees) AS fee
LEFT JOIN (
    SELECT sar."createTime", sar."deleteTime", sar."salesId", sar."amId", sar."accountId"
    FROM "salesAccountRelation" AS sar
    UNION ALL
    SELECT sar."createTime", sar."deleteTime", sar."salesId", sar."amId", account.id AS "accountId"
    FROM account
    INNER JOIN "salesAccountRelation" AS sar ON sar."accountId"::UUID = account."parentAccountId"::UUID
    WHERE account."parentAccountId" != '00000000-0000-0000-0000-000000000000'
) AS sar ON tr."account_id"::UUID = sar."accountId"::UUID
AND tr."create_time" >= sar."createTime" AND (tr."create_time" <= sar."deleteTime" OR sar."deleteTime" IS NULL)
LEFT JOIN LATERAL (SELECT unnest(ARRAY[sar."salesId"::uuid, sar."amId"::uuid]) AS sale_or_am_id) AS ids ON TRUE
            WHERE (tr."create_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."create_time" < CURRENT_DATE)
        LOOP
            IF p_dry_run THEN
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.ods_sale_fund_profits_%s WHERE (fund_id) IN (SELECT DISTINCT tr."id" FROM fund_profits AS tr
CROSS JOIN LATERAL jsonb_array_elements(fees) AS fee
LEFT JOIN (
    SELECT sar."createTime", sar."deleteTime", sar."salesId", sar."amId", sar."accountId"
    FROM "salesAccountRelation" AS sar
    UNION ALL
    SELECT sar."createTime", sar."deleteTime", sar."salesId", sar."amId", account.id AS "accountId"
    FROM account
    INNER JOIN "salesAccountRelation" AS sar ON sar."accountId"::UUID = account."parentAccountId"::UUID
    WHERE account."parentAccountId" != '00000000-0000-0000-0000-000000000000'
) AS sar ON tr."account_id"::UUID = sar."accountId"::UUID
AND tr."create_time" >= sar."createTime" AND (tr."create_time" <= sar."deleteTime" OR sar."deleteTime" IS NULL)
LEFT JOIN LATERAL (SELECT unnest(ARRAY[sar."salesId"::uuid, sar."amId"::uuid]) AS sale_or_am_id) AS ids ON TRUE WHERE (tr."create_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."create_time" < CURRENT_DATE))$fmt$, v_year) INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.ods_sale_fund_profits_%s WHERE (fund_id) IN (SELECT DISTINCT tr."id" FROM fund_profits AS tr
CROSS JOIN LATERAL jsonb_array_elements(fees) AS fee
LEFT JOIN (
    SELECT sar."createTime", sar."deleteTime", sar."salesId", sar."amId", sar."accountId"
    FROM "salesAccountRelation" AS sar
    UNION ALL
    SELECT sar."createTime", sar."deleteTime", sar."salesId", sar."amId", account.id AS "accountId"
    FROM account
    INNER JOIN "salesAccountRelation" AS sar ON sar."accountId"::UUID = account."parentAccountId"::UUID
    WHERE account."parentAccountId" != '00000000-0000-0000-0000-000000000000'
) AS sar ON tr."account_id"::UUID = sar."accountId"::UUID
AND tr."create_time" >= sar."createTime" AND (tr."create_time" <= sar."deleteTime" OR sar."deleteTime" IS NULL)
LEFT JOIN LATERAL (SELECT unnest(ARRAY[sar."salesId"::uuid, sar."amId"::uuid]) AS sale_or_am_id) AS ids ON TRUE WHERE (tr."create_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."create_time" < CURRENT_DATE))$fmt$, v_year);
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
                EXECUTE format($fmt$SELECT COUNT(*) FROM public.ods_sale_fund_profits_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end INTO v_n;
            ELSE
                EXECUTE format($fmt$DELETE FROM public.ods_sale_fund_profits_%s WHERE create_date >= $1 AND create_date <= $2$fmt$, v_year) USING p_start, p_end;
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
