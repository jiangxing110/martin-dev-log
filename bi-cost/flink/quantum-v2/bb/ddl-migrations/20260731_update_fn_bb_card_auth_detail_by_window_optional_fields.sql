--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-31 10:21:56
-- Description:    BB Auth 月表读取函数兼容 2026-02 缺失扩展字段
-- Notes:
--   1. 2026-02 月表只有成本计算必需字段。
--   2. 函数返回结构保持不变，Merchant Name/MCC 等扩展字段统一返回 NULL。
--   3. 避免 CDC Auth DWM 通过函数读取 2026-02 时访问不存在列。
--********************************************************************--

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
            NULL::varchar AS "Merchant Name",
            NULL::varchar AS pos_service_code,
            NULL::varchar AS "MCC",
            NULL::varchar AS authorization_id_code,
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
IS 'BB Auth monthly table stable reader for Flink. Returns empty result when the derived monthly table does not exist; optional extended fields may be NULL.';
