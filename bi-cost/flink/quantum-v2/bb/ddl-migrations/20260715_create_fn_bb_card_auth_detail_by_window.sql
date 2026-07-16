-- BB Auth monthly table reader.
-- The monthly raw tables are named public."bb_card_auth_detail_yyyy-mm".
-- This function gives Flink a stable entry point:
--   1. derive the monthly table name from p_start_time
--   2. return no rows when the monthly table does not exist
--   3. scan only the derived monthly table when it exists

CREATE OR REPLACE FUNCTION "public"."fn_bb_card_auth_detail_by_window"(
    p_start_time timestamp,
    p_end_time timestamp
)
RETURNS TABLE (
    "Trans Date / Time" varchar,
    "Program GUID" varchar,
    "Program Name" varchar,
    "Card Proxy" varchar,
    "Person Name" varchar,
    "Request Code" varchar,
    "Request Description" varchar,
    "Local Trans Date / Time" varchar,
    "Auth Txn GUID" varchar,
    "Response Code" varchar,
    "Reason Code" varchar,
    "Txn Amount" varchar,
    "Settle Amount" varchar,
    "Txn Currency" varchar,
    "Merchant Country" varchar,
    "Transmission Date" varchar,
    "Merchant Name" varchar,
    pos_service_code varchar,
    "MCC" varchar,
    authorization_id_code varchar,
    source_table varchar
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_table_name text := 'bb_card_auth_detail_' || to_char(p_start_time, 'YYYY-MM');
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name = v_table_name
    ) THEN
        RETURN;
    END IF;

    RETURN QUERY EXECUTE format(
        $sql$
        SELECT
            "Trans Date / Time"::varchar,
            "Program GUID"::varchar,
            "Program Name"::varchar,
            "Card Proxy"::varchar,
            "Person Name"::varchar,
            "Request Code"::varchar,
            "Request Description"::varchar,
            "Local Trans Date / Time"::varchar,
            "Auth Txn GUID"::varchar,
            "Response Code"::varchar,
            "Reason Code"::varchar,
            "Txn Amount"::varchar,
            "Settle Amount"::varchar,
            "Txn Currency"::varchar,
            "Merchant Country"::varchar,
            "Transmission Date"::varchar,
            "Merchant Name"::varchar,
            pos_service_code::varchar,
            "MCC"::varchar,
            authorization_id_code::varchar,
            %L::varchar AS source_table
        FROM public.%I
        WHERE to_timestamp("Trans Date / Time", 'MM/DD/YYYY HH12:MI:SS AM') >= $1
          AND to_timestamp("Trans Date / Time", 'MM/DD/YYYY HH12:MI:SS AM') < $2
        $sql$,
        v_table_name,
        v_table_name
    )
    USING p_start_time, p_end_time;
END;
$$;

COMMENT ON FUNCTION "public"."fn_bb_card_auth_detail_by_window"(timestamp, timestamp)
IS 'BB Auth monthly table stable reader for Flink. Returns empty result when the derived monthly table does not exist.';
