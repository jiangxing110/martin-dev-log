CREATE OR REPLACE PROCEDURE "public"."sp_init_dim_sale_account_relation_by_day"("p_start_date" date, "p_end_date" date)
 AS $BODY$
BEGIN
    EXECUTE 'SET LOCAL work_mem = ''256MB''';
    EXECUTE 'SET LOCAL synchronous_commit = off';

    UPDATE "public"."dim_sale_account_relation_p"
    SET "delete_time" = NOW(),
        "update_time" = NOW()
    WHERE "report_date" >= p_start_date
      AND "report_date" < p_end_date
      AND "delete_time" IS NULL;

    INSERT INTO "public"."dim_sale_account_relation_p" (
        id, report_date, account_id, root_account_id,
        sale_id, am_id, operation_manager_id,
        version, remarks, create_time, update_time, delete_time
    )
    WITH day_series AS (
        SELECT generate_series(p_start_date, p_end_date - 1, interval '1 day')::date AS report_date
    ),
    direct_rel AS (
        SELECT
            ds.report_date,
            sar."accountId"::text AS account_id,
            sar."accountId"::text AS root_account_id,
            sar."salesId"::text AS sale_id,
            sar."amId"::text AS am_id,
            sar."operationManagerId"::text AS operation_manager_id,
            sar."createTime" AS effective_time,
            1 AS priority
        FROM day_series ds
        JOIN "salesAccountRelation" sar
          ON ds.report_date >= sar."createTime"::date
         AND (sar."deleteTime" IS NULL OR ds.report_date < sar."deleteTime"::date)
    ),
    root_rel AS (
        SELECT
            ds.report_date,
            aar.account_id::text AS account_id,
            aar.root_id::text AS root_account_id,
            sar."salesId"::text AS sale_id,
            sar."amId"::text AS am_id,
            sar."operationManagerId"::text AS operation_manager_id,
            sar."createTime" AS effective_time,
            2 AS priority
        FROM day_series ds
        JOIN "api_account_relation" aar ON TRUE
        JOIN "salesAccountRelation" sar
          ON aar.root_id::text = sar."accountId"::text
         AND ds.report_date >= sar."createTime"::date
         AND (sar."deleteTime" IS NULL OR ds.report_date < sar."deleteTime"::date)
    ),
    union_rel AS (
        SELECT * FROM direct_rel
        UNION ALL
        SELECT * FROM root_rel
    ),
    ranked_rel AS (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY report_date, account_id
                   ORDER BY priority, effective_time DESC
               ) AS rn
        FROM union_rel
    )
    SELECT
        abs(hashtext(report_date::text || ':' || account_id))::bigint AS id,
        report_date,
        account_id,
        root_account_id,
        sale_id,
        am_id,
        operation_manager_id,
        1,
        'daily snapshot',
        NOW(),
        NOW(),
        NULL
    FROM ranked_rel
    WHERE rn = 1
    ON CONFLICT (id, report_date) DO UPDATE SET
        root_account_id = EXCLUDED.root_account_id,
        sale_id = EXCLUDED.sale_id,
        am_id = EXCLUDED.am_id,
        operation_manager_id = EXCLUDED.operation_manager_id,
        update_time = NOW(),
        delete_time = NULL,
        version = "dim_sale_account_relation_p".version + 1;
END $BODY$
  LANGUAGE plpgsql;
