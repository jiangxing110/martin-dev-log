CREATE OR REPLACE PROCEDURE "public"."sp_init_finance_channel_cost_by_fast"(
    "p_source_month" date,
    "p_product_line" varchar,
    "p_provider" varchar,
    "p_source_tag" varchar,
    "p_cost_type" varchar
)
 AS $BODY$
DECLARE
    v_month_end        DATE := (p_source_month + INTERVAL '1 month')::date;
    v_month_day_count  INT  := EXTRACT(day FROM ((p_source_month + INTERVAL '1 month') - p_source_month));
    v_source_amount    NUMERIC(20,4);
BEGIN
    EXECUTE 'SET LOCAL work_mem = ''256MB''';
    EXECUTE 'SET LOCAL synchronous_commit = off';

    SELECT COALESCE(MAX("amount"), 0)
      INTO v_source_amount
    FROM "bi_month_tag"
    WHERE "statistics_time" = p_source_month
      AND "product_line" = p_product_line
      AND "provider" = p_provider
      AND "tag" = p_source_tag
      AND "delete_time" IS NULL;

    UPDATE "public"."dwm_finance_channel_cost_p"
    SET "delete_time" = NOW(),
        "update_time" = NOW()
    WHERE "source_month" = p_source_month
      AND "product_line" = p_product_line
      AND "provider" = p_provider
      AND "source_tag" = p_source_tag
      AND "cost_type" = p_cost_type
      AND "delete_time" IS NULL;

    IF v_source_amount = 0 THEN
        RAISE NOTICE 'bi_month_tag 未找到金额, 跳过: %, %, %, %', p_source_month, p_product_line, p_provider, p_source_tag;
        RETURN;
    END IF;

    IF p_provider = 'BPC' THEN
        INSERT INTO "public"."dwm_finance_channel_cost_p" (
            id, report_date, account_id, sale_id, am_id, product_line, provider, cost_type,
            source_month, source_tag, source_amount, month_day_count,
            basis_count, month_basis_count, basis_amount, month_basis_amount,
            allocation_rate, cost_amount, version, remarks, create_time, update_time, delete_time
        )
        WITH day_series AS (
            SELECT generate_series(p_source_month, v_month_end - 1, interval '1 day')::date AS report_date
        ),
        basis AS (
            SELECT ds.report_date, c."accountId"::text AS account_id
            FROM day_series ds
            JOIN "qbitCard" c
              ON c."provider" ILIKE '%Qbit%'
             AND (c."deleteCardTime" IS NULL OR c."deleteCardTime" > ds.report_date::timestamp)
            GROUP BY ds.report_date, c."accountId"
        ),
        total_basis AS (
            SELECT COUNT(DISTINCT account_id) AS month_basis_count FROM basis
        )
        SELECT
            abs(hashtext(b.report_date::text || ':' || b.account_id || ':' || p_provider || ':' || p_cost_type || ':' || p_source_tag))::bigint,
            b.report_date,
            b.account_id,
            rel.sale_id,
            rel.am_id,
            p_product_line,
            p_provider,
            p_cost_type,
            p_source_month,
            p_source_tag,
            v_source_amount,
            v_month_day_count,
            1,
            tb.month_basis_count,
            0,
            0,
            CASE WHEN tb.month_basis_count = 0 THEN 0 ELSE 1::numeric / tb.month_basis_count / v_month_day_count END,
            CASE WHEN tb.month_basis_count = 0 THEN 0 ELSE v_source_amount / tb.month_basis_count / v_month_day_count END,
            1,
            'BPC active card allocation',
            NOW(),
            NOW(),
            NULL
        FROM basis b
        CROSS JOIN total_basis tb
        LEFT JOIN LATERAL (
            SELECT sale_id, am_id
            FROM "public"."dim_sale_account_relation_p" d
            WHERE d."report_date" = b.report_date
              AND d."account_id" = b.account_id
              AND d."delete_time" IS NULL
            LIMIT 1
        ) rel ON TRUE;

    ELSIF p_provider = 'SUMSUB' THEN
        INSERT INTO "public"."dwm_finance_channel_cost_p" (
            id, report_date, account_id, sale_id, am_id, product_line, provider, cost_type,
            source_month, source_tag, source_amount, month_day_count,
            basis_count, month_basis_count, basis_amount, month_basis_amount,
            allocation_rate, cost_amount, version, remarks, create_time, update_time, delete_time
        )
        WITH basis AS (
            SELECT
                r."createTime"::date AS report_date,
                r."account_id"::text AS account_id,
                COUNT(*) AS basis_count
            FROM "idv_channel_request_record" r
            WHERE r."request_channel" = 'sumsub'
              AND r."request_type" = 'POST'
              AND r."createTime" >= p_source_month
              AND r."createTime" < v_month_end
            GROUP BY 1, 2
        ),
        total_basis AS (
            SELECT COALESCE(SUM(basis_count), 0) AS month_basis_count FROM basis
        )
        SELECT
            abs(hashtext(b.report_date::text || ':' || b.account_id || ':' || p_provider || ':' || p_cost_type || ':' || p_source_tag))::bigint,
            b.report_date,
            b.account_id,
            rel.sale_id,
            rel.am_id,
            p_product_line,
            p_provider,
            p_cost_type,
            p_source_month,
            p_source_tag,
            v_source_amount,
            v_month_day_count,
            b.basis_count,
            tb.month_basis_count,
            0,
            0,
            CASE WHEN tb.month_basis_count = 0 THEN 0 ELSE b.basis_count / tb.month_basis_count END,
            CASE WHEN tb.month_basis_count = 0 THEN 0 ELSE v_source_amount * b.basis_count / tb.month_basis_count END,
            1,
            'Sumsub kyc allocation',
            NOW(),
            NOW(),
            NULL
        FROM basis b
        CROSS JOIN total_basis tb
        LEFT JOIN LATERAL (
            SELECT sale_id, am_id
            FROM "public"."dim_sale_account_relation_p" d
            WHERE d."report_date" = b.report_date
              AND d."account_id" = b.account_id
              AND d."delete_time" IS NULL
            LIMIT 1
        ) rel ON TRUE;

    ELSIF p_provider = 'IDEMIA' THEN
        INSERT INTO "public"."dwm_finance_channel_cost_p" (
            id, report_date, account_id, sale_id, am_id, product_line, provider, cost_type,
            source_month, source_tag, source_amount, month_day_count,
            basis_count, month_basis_count, basis_amount, month_basis_amount,
            allocation_rate, cost_amount, version, remarks, create_time, update_time, delete_time
        )
        WITH day_series AS (
            SELECT generate_series(p_source_month, v_month_end - 1, interval '1 day')::date AS report_date
        ),
        basis AS (
            SELECT
                ds.report_date,
                p."accountId"::text AS account_id,
                COUNT(*) AS basis_count
            FROM day_series ds
            JOIN "qbitPhysicalCard" p
              ON p."createTime" >= p_source_month
             AND p."createTime" < v_month_end
            GROUP BY ds.report_date, p."accountId"
        ),
        total_basis AS (
            SELECT COALESCE(SUM(basis_count), 0) AS month_basis_count
            FROM (
                SELECT "accountId", COUNT(*) AS basis_count
                FROM "qbitPhysicalCard"
                WHERE "createTime" >= p_source_month
                  AND "createTime" < v_month_end
                GROUP BY "accountId"
            ) t
        )
        SELECT
            abs(hashtext(b.report_date::text || ':' || b.account_id || ':' || p_provider || ':' || p_cost_type || ':' || p_source_tag))::bigint,
            b.report_date,
            b.account_id,
            rel.sale_id,
            rel.am_id,
            p_product_line,
            p_provider,
            p_cost_type,
            p_source_month,
            p_source_tag,
            v_source_amount,
            v_month_day_count,
            b.basis_count,
            tb.month_basis_count,
            0,
            0,
            CASE WHEN tb.month_basis_count = 0 THEN 0 ELSE b.basis_count / tb.month_basis_count / v_month_day_count END,
            CASE WHEN tb.month_basis_count = 0 THEN 0 ELSE v_source_amount * b.basis_count / tb.month_basis_count / v_month_day_count END,
            1,
            'IDEMIA physical card allocation',
            NOW(),
            NOW(),
            NULL
        FROM basis b
        CROSS JOIN total_basis tb
        LEFT JOIN LATERAL (
            SELECT sale_id, am_id
            FROM "public"."dim_sale_account_relation_p" d
            WHERE d."report_date" = b.report_date
              AND d."account_id" = b.account_id
              AND d."delete_time" IS NULL
            LIMIT 1
        ) rel ON TRUE;

    ELSIF p_provider = 'HZ_BANK' THEN
        INSERT INTO "public"."dwm_finance_channel_cost_p" (
            id, report_date, account_id, sale_id, am_id, product_line, provider, cost_type,
            source_month, source_tag, source_amount, month_day_count,
            basis_count, month_basis_count, basis_amount, month_basis_amount,
            allocation_rate, cost_amount, version, remarks, create_time, update_time, delete_time
        )
        WITH basis AS (
            SELECT
                tr."transactionTime"::date AS report_date,
                tr."accountId"::text AS account_id,
                COALESCE(
                    SUM(CASE WHEN tr."businessType" = 'Consumption' AND tr."status" IN ('Closed', 'Pending') THEN tr."settleAmount" ELSE 0 END)
                  - SUM(CASE WHEN tr."businessType" = 'Reversal' AND tr."status" IN ('Closed', 'Pending') THEN tr."settleAmount" ELSE 0 END)
                  - SUM(CASE WHEN tr."businessType" = 'Credit' AND tr."status" = 'Closed' THEN tr."settleAmount" ELSE 0 END),
                    0
                ) AS basis_amount
            FROM "qbitCardTransaction" tr
            WHERE tr."provider" ILIKE '%Qbit%'
              AND tr."businessType" IN ('Consumption', 'Reversal', 'Credit')
              AND tr."deleteTime" IS NULL
              AND tr."transactionTime" >= p_source_month
              AND tr."transactionTime" < v_month_end
            GROUP BY 1, 2
        ),
        total_basis AS (
            SELECT COALESCE(SUM(basis_amount), 0) AS month_basis_amount FROM basis
        )
        SELECT
            abs(hashtext(b.report_date::text || ':' || b.account_id || ':' || p_provider || ':' || p_cost_type || ':' || p_source_tag))::bigint,
            b.report_date,
            b.account_id,
            rel.sale_id,
            rel.am_id,
            p_product_line,
            p_provider,
            p_cost_type,
            p_source_month,
            p_source_tag,
            v_source_amount,
            v_month_day_count,
            0,
            0,
            b.basis_amount,
            tb.month_basis_amount,
            CASE WHEN tb.month_basis_amount = 0 THEN 0 ELSE b.basis_amount / tb.month_basis_amount END,
            CASE WHEN tb.month_basis_amount = 0 THEN 0 ELSE v_source_amount * b.basis_amount / tb.month_basis_amount END,
            1,
            'HZ bank consume allocation',
            NOW(),
            NOW(),
            NULL
        FROM basis b
        CROSS JOIN total_basis tb
        LEFT JOIN LATERAL (
            SELECT sale_id, am_id
            FROM "public"."dim_sale_account_relation_p" d
            WHERE d."report_date" = b.report_date
              AND d."account_id" = b.account_id
              AND d."delete_time" IS NULL
            LIMIT 1
        ) rel ON TRUE;

    ELSE
        RAISE NOTICE '当前补充版过程未内置 provider %, 请按同口径补充分支', p_provider;
    END IF;
END $BODY$
  LANGUAGE plpgsql;
