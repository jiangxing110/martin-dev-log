CREATE OR REPLACE PROCEDURE "public"."sp_init_sl_card_dws_by_fast"("p_start_date" date, "p_end_date" date)
 AS $BODY$
BEGIN
    EXECUTE 'SET LOCAL work_mem = ''256MB''';
    EXECUTE 'SET LOCAL synchronous_commit = off';

    UPDATE "public"."dws_sl_card_finance_daily_p"
    SET "delete_time" = NOW(),
        "update_time" = NOW()
    WHERE "report_date" >= p_start_date
      AND "report_date" < p_end_date
      AND "delete_time" IS NULL;

    INSERT INTO "public"."dws_sl_card_finance_daily_p" (
        id, report_date, account_id, sale_id, am_id,
        rebate_base, rebate_amt, cost_fixed_fee,
        version, remarks, create_time, update_time, delete_time
    )
    SELECT
        abs(hashtext(transaction_date::text || ':' || account_id || ':' || COALESCE(sale_id, '') || ':' || COALESCE(am_id, '')))::bigint AS id,
        transaction_date AS report_date,
        account_id,
        sale_id,
        am_id,
        COALESCE(SUM(rebate_base), 0),
        COALESCE(SUM(rebate_amt), 0),
        0,
        1,
        'from sl dwm',
        NOW(),
        NOW(),
        NULL
    FROM "public"."dwm_sl_card_transaction_detail_p"
    WHERE "transaction_date" >= p_start_date
      AND "transaction_date" < p_end_date
      AND "delete_time" IS NULL
    GROUP BY transaction_date, account_id, sale_id, am_id
    ON CONFLICT (id, report_date) DO UPDATE SET
        rebate_base = EXCLUDED.rebate_base,
        rebate_amt = EXCLUDED.rebate_amt,
        cost_fixed_fee = EXCLUDED.cost_fixed_fee,
        sale_id = EXCLUDED.sale_id,
        am_id = EXCLUDED.am_id,
        update_time = NOW(),
        delete_time = NULL,
        version = "dws_sl_card_finance_daily_p".version + 1;
END $BODY$
  LANGUAGE plpgsql;
