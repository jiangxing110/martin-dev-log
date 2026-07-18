CREATE OR REPLACE PROCEDURE "public"."sp_init_sl_card_dwm_by_fast"("p_start_date" date, "p_end_date" date)
 AS $BODY$
BEGIN
    EXECUTE 'SET LOCAL work_mem = ''256MB''';
    EXECUTE 'SET LOCAL synchronous_commit = off';

    UPDATE "public"."dwm_sl_card_transaction_detail_p"
    SET "delete_time" = NOW(),
        "update_time" = NOW()
    WHERE "transaction_date" >= p_start_date
      AND "transaction_date" < p_end_date
      AND "delete_time" IS NULL;

    INSERT INTO "public"."dwm_sl_card_transaction_detail_p" (
        id, transaction_id, account_id, sale_id, am_id, transaction_date,
        country, billing_amount, rebate_rate, rebate_base, rebate_amt,
        version, remarks, create_time, update_time, delete_time
    )
    WITH base AS (
        SELECT
            s."id"::uuid AS id,
            COALESCE(s."transactionId", s."qbitCardTransactionId")::text AS transaction_id,
            t."accountId"::text AS account_id,
            COALESCE((s."rawData"->>'date')::date, t."transactionTime"::date) AS transaction_date,
            COALESCE(s."rawData"->'merchantData'->'location'->>'country', '') AS country,
            COALESCE(s."billingAmount", 0)::numeric(20,4) AS billing_amount,
            t."transactionTime" AS event_time
        FROM "qbitCardSettlement" s
        JOIN "qbitCardTransaction" t
          ON (
                s."qbitCardTransactionId" = t."id"::text
             OR s."transactionId" = t."sourceId"
             )
        WHERE s."provider" ILIKE '%Slash%'
          AND COALESCE((s."rawData"->>'date')::date, t."transactionTime"::date) >= p_start_date
          AND COALESCE((s."rawData"->>'date')::date, t."transactionTime"::date) < p_end_date
          AND t."deleteTime" IS NULL
    )
    SELECT
        b.id,
        b.transaction_id,
        b.account_id,
        sr.sale_id,
        sr.am_id,
        b.transaction_date,
        b.country,
        b.billing_amount,
        CASE WHEN b.country IN ('US', 'USA') THEN 0.020000 ELSE 0.005000 END AS rebate_rate,
        b.billing_amount AS rebate_base,
        b.billing_amount * CASE WHEN b.country IN ('US', 'USA') THEN 0.020000 ELSE 0.005000 END AS rebate_amt,
        1,
        'slash settlement',
        NOW(),
        NOW(),
        NULL
    FROM base b
    LEFT JOIN LATERAL (
        SELECT rel.sale_id, rel.am_id
        FROM (
            SELECT
                sar."salesId"::text AS sale_id,
                sar."amId"::text AS am_id,
                sar."createTime" AS effective_time,
                1 AS priority
            FROM "salesAccountRelation" sar
            WHERE sar."accountId"::text = b.account_id
              AND b.event_time >= sar."createTime"
              AND (sar."deleteTime" IS NULL OR b.event_time < sar."deleteTime")
            UNION ALL
            SELECT
                sar."salesId"::text AS sale_id,
                sar."amId"::text AS am_id,
                sar."createTime" AS effective_time,
                2 AS priority
            FROM "api_account_relation" aar
            JOIN "salesAccountRelation" sar
              ON aar.root_id::text = sar."accountId"::text
            WHERE aar.account_id::text = b.account_id
              AND b.event_time >= sar."createTime"
              AND (sar."deleteTime" IS NULL OR b.event_time < sar."deleteTime")
        ) rel
        ORDER BY rel.priority, rel.effective_time DESC
        LIMIT 1
    ) sr ON TRUE
    ON CONFLICT (id, transaction_date) DO UPDATE SET
        sale_id = EXCLUDED.sale_id,
        am_id = EXCLUDED.am_id,
        country = EXCLUDED.country,
        billing_amount = EXCLUDED.billing_amount,
        rebate_rate = EXCLUDED.rebate_rate,
        rebate_base = EXCLUDED.rebate_base,
        rebate_amt = EXCLUDED.rebate_amt,
        update_time = NOW(),
        delete_time = NULL,
        version = "dwm_sl_card_transaction_detail_p".version + 1;
END $BODY$
  LANGUAGE plpgsql;
