--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-06 01:45:00
-- Description:    注册 total_cost finance CDC v2 删除函数
-- 作业元信息：
--   作业类型：ADBPG 函数注册
--   运行方式：在目标 ADBPG 数据库执行一次；VVR SQL v2 作业通过 JDBC 调用对应函数
--   运行参数：无
-- Notes:
--   1. 函数返回受影响行数。
--   2. p_dry_run = true 时只统计不删除。
--   3. 删除范围按昨天更新的 ods_bi_month_tag 推导 source_month，并用 product_line/provider/cost_type/remarks 收窄。
--********************************************************************--

CREATE OR REPLACE FUNCTION dwm.fn_delete_finance_channel_cost_cdc(
    p_product_line TEXT,
    p_providers TEXT[],
    p_cost_types TEXT[],
    p_remarks TEXT,
    p_dry_run BOOLEAN DEFAULT false
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $function$
DECLARE
    affected_rows BIGINT;
BEGIN
    IF array_length(p_providers, 1) IS DISTINCT FROM array_length(p_cost_types, 1) THEN
        RAISE EXCEPTION 'p_providers and p_cost_types must have the same length';
    END IF;

    IF p_dry_run THEN
        WITH scope_pairs AS (
            SELECT provider, cost_type
            FROM unnest(p_providers, p_cost_types) AS pair(provider, cost_type)
        ),
        changed_months AS (
            SELECT DISTINCT DATE_TRUNC('month', t.statistics_time)::date AS source_month
            FROM ods.ods_bi_month_tag AS t
            WHERE t.delete_time IS NULL
              AND t.product_line = p_product_line
              AND t.update_time >= CURRENT_DATE - INTERVAL '1 day'
              AND t.update_time < CURRENT_DATE
              AND t.statistics_time IS NOT NULL
              AND EXISTS (
                  SELECT 1
                  FROM scope_pairs AS scope
                  WHERE scope.provider = t.provider
              )
        )
        SELECT COUNT(*)
        INTO affected_rows
        FROM dwm.dwm_finance_channel_cost_p AS target
        WHERE target.product_line = p_product_line
          AND target.remarks = p_remarks
          AND EXISTS (
              SELECT 1
              FROM scope_pairs AS scope
              WHERE scope.provider = target.provider
                AND scope.cost_type = target.cost_type
          )
          AND EXISTS (
              SELECT 1
              FROM changed_months AS month_scope
              WHERE target.source_month = month_scope.source_month
          );

        RETURN affected_rows;
    END IF;

    WITH scope_pairs AS (
        SELECT provider, cost_type
        FROM unnest(p_providers, p_cost_types) AS pair(provider, cost_type)
    ),
    changed_months AS (
        SELECT DISTINCT DATE_TRUNC('month', t.statistics_time)::date AS source_month
        FROM ods.ods_bi_month_tag AS t
        WHERE t.delete_time IS NULL
          AND t.product_line = p_product_line
          AND t.update_time >= CURRENT_DATE - INTERVAL '1 day'
          AND t.update_time < CURRENT_DATE
          AND t.statistics_time IS NOT NULL
          AND EXISTS (
              SELECT 1
              FROM scope_pairs AS scope
              WHERE scope.provider = t.provider
          )
    )
    DELETE FROM dwm.dwm_finance_channel_cost_p AS target
    WHERE target.product_line = p_product_line
      AND target.remarks = p_remarks
      AND EXISTS (
          SELECT 1
          FROM scope_pairs AS scope
          WHERE scope.provider = target.provider
            AND scope.cost_type = target.cost_type
      )
      AND EXISTS (
          SELECT 1
          FROM changed_months AS month_scope
          WHERE target.source_month = month_scope.source_month
      );

    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    RETURN affected_rows;
END;
$function$;

CREATE OR REPLACE FUNCTION dwm.fn_delete_finance_acquiring_cost_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE sql
AS $function$
    SELECT dwm.fn_delete_finance_channel_cost_cdc(
        'ACQUIRING',
        ARRAY['OD', 'WP'],
        ARRAY['ACQUIRING_FEE', 'ACQUIRING_FEE'],
        'acquiring_cdc',
        p_dry_run
    );
$function$;

CREATE OR REPLACE FUNCTION dwm.fn_delete_finance_crypto_asset_bitstamp_cost_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE sql
AS $function$
    SELECT dwm.fn_delete_finance_channel_cost_cdc(
        'CRYPTO_ASSET',
        ARRAY['BS'],
        ARRAY['TRADING_FEE'],
        'crypto_asset_bitstamp_cdc',
        p_dry_run
    );
$function$;

CREATE OR REPLACE FUNCTION dwm.fn_delete_finance_crypto_asset_cregis_cost_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE sql
AS $function$
    SELECT dwm.fn_delete_finance_channel_cost_cdc(
        'CRYPTO_ASSET',
        ARRAY['Cregis'],
        ARRAY['FIXED_FEE'],
        'crypto_asset_cregis_cdc',
        p_dry_run
    );
$function$;

CREATE OR REPLACE FUNCTION dwm.fn_delete_finance_crypto_asset_safeheron_cost_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE sql
AS $function$
    SELECT dwm.fn_delete_finance_channel_cost_cdc(
        'CRYPTO_ASSET',
        ARRAY['Safeheron'],
        ARRAY['FIXED_FEE'],
        'crypto_asset_safeheron_cdc',
        p_dry_run
    );
$function$;

CREATE OR REPLACE FUNCTION dwm.fn_delete_finance_crypto_asset_th_cost_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE sql
AS $function$
    SELECT dwm.fn_delete_finance_channel_cost_cdc(
        'CRYPTO_ASSET',
        ARRAY['TH', 'TH'],
        ARRAY['WIRE_BANK_FEE', 'FIXED_FEE'],
        'crypto_asset_th_cdc',
        p_dry_run
    );
$function$;

CREATE OR REPLACE FUNCTION dwm.fn_delete_finance_crypto_asset_tz_cost_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE sql
AS $function$
    SELECT dwm.fn_delete_finance_channel_cost_cdc(
        'CRYPTO_ASSET',
        ARRAY['TZ-wire', 'TZ-wire', 'TZ-usdt', 'TZ-usdc'],
        ARRAY['WIRE_FEE', 'FIXED_FEE', 'FX_FEE', 'FX_FEE'],
        'crypto_asset_tz_cdc',
        p_dry_run
    );
$function$;

CREATE OR REPLACE FUNCTION dwm.fn_delete_finance_global_account_bz_cost_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE sql
AS $function$
    SELECT dwm.fn_delete_finance_channel_cost_cdc(
        'GLOBAL_ACCOUNT',
        ARRAY['BZ'],
        ARRAY['PAYOUT_FEE'],
        'global_account_cdc',
        p_dry_run
    );
$function$;

CREATE OR REPLACE FUNCTION dwm.fn_delete_finance_global_account_cl_cost_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE sql
AS $function$
    SELECT dwm.fn_delete_finance_channel_cost_cdc(
        'GLOBAL_ACCOUNT',
        ARRAY['CL'],
        ARRAY['ACTIVE_SUB_ACCOUNT_COST'],
        'global_account_cdc',
        p_dry_run
    );
$function$;

CREATE OR REPLACE FUNCTION dwm.fn_delete_finance_global_account_settlement_cost_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE sql
AS $function$
    SELECT dwm.fn_delete_finance_channel_cost_cdc(
        'GLOBAL_ACCOUNT',
        ARRAY['SETTLEMENT'],
        ARRAY['SETTLEMENT_COST'],
        'global_account_settlement_cdc',
        p_dry_run
    );
$function$;

CREATE OR REPLACE FUNCTION dwm.fn_delete_finance_quantum_card_bpc_cost_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE sql
AS $function$
    SELECT dwm.fn_delete_finance_channel_cost_cdc(
        'QUANTUM_CARD',
        ARRAY['BPC'],
        ARRAY['ACTIVE_CARD_COST'],
        'quantum_card_bpc_cdc',
        p_dry_run
    );
$function$;

CREATE OR REPLACE FUNCTION dwm.fn_delete_finance_quantum_card_hz_bank_cost_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE sql
AS $function$
    SELECT dwm.fn_delete_finance_channel_cost_cdc(
        'QUANTUM_CARD',
        ARRAY['HZ_BANK'],
        ARRAY['CONSUME_BANK_FEE'],
        'quantum_card_hz_bank_cdc',
        p_dry_run
    );
$function$;

CREATE OR REPLACE FUNCTION dwm.fn_delete_finance_quantum_card_idemia_cost_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE sql
AS $function$
    SELECT dwm.fn_delete_finance_channel_cost_cdc(
        'QUANTUM_CARD',
        ARRAY['IDEMIA'],
        ARRAY['CARD_PRODUCTION_FEE'],
        'quantum_card_idemia_cdc',
        p_dry_run
    );
$function$;

CREATE OR REPLACE FUNCTION dwm.fn_delete_finance_quantum_card_sumsub_cost_cdc(p_dry_run BOOLEAN DEFAULT false)
RETURNS BIGINT
LANGUAGE sql
AS $function$
    SELECT dwm.fn_delete_finance_channel_cost_cdc(
        'QUANTUM_CARD',
        ARRAY['Sumsub'],
        ARRAY['KYC_FEE'],
        'quantum_card_sumsub_cdc',
        p_dry_run
    );
$function$;

SELECT
    dwm.fn_delete_finance_acquiring_cost_cdc(true) AS finance_acquiring_cost_cdc_matched_rows,
    dwm.fn_delete_finance_crypto_asset_bitstamp_cost_cdc(true) AS finance_crypto_asset_bitstamp_cost_cdc_matched_rows,
    dwm.fn_delete_finance_crypto_asset_cregis_cost_cdc(true) AS finance_crypto_asset_cregis_cost_cdc_matched_rows,
    dwm.fn_delete_finance_crypto_asset_safeheron_cost_cdc(true) AS finance_crypto_asset_safeheron_cost_cdc_matched_rows,
    dwm.fn_delete_finance_crypto_asset_th_cost_cdc(true) AS finance_crypto_asset_th_cost_cdc_matched_rows,
    dwm.fn_delete_finance_crypto_asset_tz_cost_cdc(true) AS finance_crypto_asset_tz_cost_cdc_matched_rows,
    dwm.fn_delete_finance_global_account_bz_cost_cdc(true) AS finance_global_account_bz_cost_cdc_matched_rows,
    dwm.fn_delete_finance_global_account_cl_cost_cdc(true) AS finance_global_account_cl_cost_cdc_matched_rows,
    dwm.fn_delete_finance_global_account_settlement_cost_cdc(true) AS finance_global_account_settlement_cost_cdc_matched_rows,
    dwm.fn_delete_finance_quantum_card_bpc_cost_cdc(true) AS finance_quantum_card_bpc_cost_cdc_matched_rows,
    dwm.fn_delete_finance_quantum_card_hz_bank_cost_cdc(true) AS finance_quantum_card_hz_bank_cost_cdc_matched_rows,
    dwm.fn_delete_finance_quantum_card_idemia_cost_cdc(true) AS finance_quantum_card_idemia_cost_cdc_matched_rows,
    dwm.fn_delete_finance_quantum_card_sumsub_cost_cdc(true) AS finance_quantum_card_sumsub_cost_cdc_matched_rows;
