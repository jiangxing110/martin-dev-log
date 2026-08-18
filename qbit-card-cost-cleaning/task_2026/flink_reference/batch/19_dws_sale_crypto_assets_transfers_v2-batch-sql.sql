--********************************************************************
-- Author:         martinJiang
-- Created Time:   2026-08-18
-- Updated Time:   2026-08-18
-- Description:    dws_sale_crypto_assets_transfers 批处理 作业（quantum-v2 范式：确定性哈希主键 + 先清后写）
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性修复/补数：VVR 作业参数 start_date/end_date 指定回刷区间（含两端，YYYY-MM-DD）；删除函数走修复模式按 create_date 跨分表清理，再由重算 upsert 覆盖（幂等）。
--   运行参数：start_date, end_date（YYYY-MM-DD，含两端）
-- Notes:
--   1. 一次性修复/补数作业：通过 VVR 作业参数 start_date/end_date 指定回刷区间（YYYY-MM-DD，含两端）。
--   2. 删除函数走“修复模式”，按 create_date 区间跨分表整段清理。
--   3. 源聚合仅重算该区间内受影响 key 的当前有效行，upsert 覆盖（幂等）。
--   4. 删除与重算必须严格共用同一 start_date/end_date，否则出现区间缺口或越界残留。
--   5. 上线前需对照线上 Flink catalog 校准列类型（UUID / JSON / boolean 等）。
--********************************************************************
SET 'parallelism.default' = '1';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'sink.parallelism' = '1';
SET 'table.dml-sync' = 'true';
SET 'execution.checkpointing.interval' = '5min';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'execution.checkpointing.timeout' = '30min';
SET 'table.optimizer.reuse-source-enabled' = 'true';
SET 'table.optimizer.reuse-sub-plan-enabled' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

CREATE TEMPORARY TABLE source_delete_dws_sale_crypto_assets_transfers_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_dws_sale_crypto_assets_transfers_cdc(false, CAST(''${start_date}'' AS DATE), CAST(''${end_date}'' AS DATE)) AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

CREATE TEMPORARY TABLE source_dws_sale_crypto_assets_transfers (
    account_id STRING,
    sale_or_am_id STRING,
    status STRING,
    sender_type STRING,
    recipient_type STRING,
    transaction_count BIGINT,
    origin_amount DECIMAL(20,4),
    settlement_amount DECIMAL(20,4),
    fee DECIMAL(20,4),
    fee2 DECIMAL(20,4),
    cross_chain_fee DECIMAL(20,4),
    exchange_profit DECIMAL(20,4),
    payment_profit DECIMAL(20,4),
    hidden BOOLEAN,
    create_date DATE,
    currency STRING,
    action STRING,
    version BIGINT,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(WITH affected AS (
        SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account FROM "crypto_assets_transfers" AS tr
LEFT JOIN "ods_sale_am_transaction_2026" AS osat ON tr."transaction_id"::UUID = osat.transaction_id::UUID
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE WHERE (DATE(tr."createTime") >= CAST(''${start_date}'' AS DATE) AND DATE(tr."createTime") <= CAST(''${end_date}'' AS DATE))
    )
    SELECT "account_id" AS "account_id", ids."sale_or_am_id" AS "sale_or_am_id", "status" AS "status", "sender_type" AS "sender_type", "recipient_type" AS "recipient_type", COUNT(*) AS transaction_count, SUM("origin_amount" * "usd_rate") AS origin_amount, SUM("settlement_amount" * "usd_rate") AS settlement_amount, SUM("fee" * "usd_rate") AS fee, SUM("fee2" * "usd_rate") AS fee2, SUM("cross_chain_fee" * "usd_rate") AS cross_chain_fee, SUM(CASE WHEN tr."status" = ''Closed'' AND tr."action" = ''sell'' AND tr.hidden = FALSE AND (tr."fee" - tr."origin_amount" * 0.0009) > 0 THEN (tr."fee" - tr."origin_amount" * 0.0009) ELSE 0 END) AS exchange_profit, SUM(CASE WHEN tr."recipient_type" IN (''wire'',''outside_bank'') AND tr."status" IN (''Processing'',''Closed'') AND (tr."fee" - 25) > 0 THEN (tr."fee" - 25) ELSE 0 END) AS withdraw_fee_diff AS "payment_profit", "hidden" AS "hidden", TO_CHAR(tr."create_time", ''YYYY-MM-DD'')::DATE AS create_date, "currency" AS "currency", "action" AS "action", 1 AS version, NOW() AS create_time, NOW() AS update_time
    FROM "crypto_assets_transfers" AS tr
LEFT JOIN "ods_sale_am_transaction_2026" AS osat ON tr."transaction_id"::UUID = osat.transaction_id::UUID
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
    JOIN affected a ON (DATE(tr."createTime")) = a.scope_date AND (tr."accountId") = a.scope_account
    WHERE tr."delete_time" IS NULL
    GROUP BY "account_id", "status", "sender_type", "recipient_type","hidden", create_date, "currency", "action", ids."sale_or_am_id") AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

CREATE TEMPORARY VIEW v_dws_sale_crypto_assets_transfers_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(account_id, ''), ': ', COALESCE(status, ''), ': ', COALESCE(sender_type, ''), ': ', COALESCE(recipient_type, ''), ': ', COALESCE(hidden, ''), ': ', DATE_FORMAT(create_date, 'yyyy-MM-dd'), ': ', COALESCE(currency, ''), ': ', COALESCE(action, ''), ': ', COALESCE(sale_or_am_id, '')))) AS BIGINT) AS id,
    *
FROM source_dws_sale_crypto_assets_transfers;

CREATE TEMPORARY TABLE sink_dws_sale_crypto_assets_transfers_2024 (
    id BIGINT, account_id STRING, sale_or_am_id STRING, status STRING, sender_type STRING, recipient_type STRING, transaction_count BIGINT, origin_amount DECIMAL(20,4), settlement_amount DECIMAL(20,4), fee DECIMAL(20,4), fee2 DECIMAL(20,4), cross_chain_fee DECIMAL(20,4), exchange_profit DECIMAL(20,4), payment_profit DECIMAL(20,4), hidden BOOLEAN, create_date DATE, currency STRING, action STRING, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_sale_crypto_assets_transfers_2024','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_sale_crypto_assets_transfers_2025 (
    id BIGINT, account_id STRING, sale_or_am_id STRING, status STRING, sender_type STRING, recipient_type STRING, transaction_count BIGINT, origin_amount DECIMAL(20,4), settlement_amount DECIMAL(20,4), fee DECIMAL(20,4), fee2 DECIMAL(20,4), cross_chain_fee DECIMAL(20,4), exchange_profit DECIMAL(20,4), payment_profit DECIMAL(20,4), hidden BOOLEAN, create_date DATE, currency STRING, action STRING, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_sale_crypto_assets_transfers_2025','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_sale_crypto_assets_transfers_2026 (
    id BIGINT, account_id STRING, sale_or_am_id STRING, status STRING, sender_type STRING, recipient_type STRING, transaction_count BIGINT, origin_amount DECIMAL(20,4), settlement_amount DECIMAL(20,4), fee DECIMAL(20,4), fee2 DECIMAL(20,4), cross_chain_fee DECIMAL(20,4), exchange_profit DECIMAL(20,4), payment_profit DECIMAL(20,4), hidden BOOLEAN, create_date DATE, currency STRING, action STRING, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_sale_crypto_assets_transfers_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_sale_crypto_assets_transfers_2027 (
    id BIGINT, account_id STRING, sale_or_am_id STRING, status STRING, sender_type STRING, recipient_type STRING, transaction_count BIGINT, origin_amount DECIMAL(20,4), settlement_amount DECIMAL(20,4), fee DECIMAL(20,4), fee2 DECIMAL(20,4), cross_chain_fee DECIMAL(20,4), exchange_profit DECIMAL(20,4), payment_profit DECIMAL(20,4), hidden BOOLEAN, create_date DATE, currency STRING, action STRING, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_sale_crypto_assets_transfers_2027','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

INSERT INTO sink_dws_sale_crypto_assets_transfers_2024
SELECT id, account_id, sale_or_am_id, status, sender_type, recipient_type, transaction_count, origin_amount, settlement_amount, fee, fee2, cross_chain_fee, exchange_profit, payment_profit, hidden, create_date, currency, action, version, create_time, update_time
FROM v_dws_sale_crypto_assets_transfers_base
CROSS JOIN source_delete_dws_sale_crypto_assets_transfers_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2024-01-01' AND create_date < DATE '2025-01-01';
INSERT INTO sink_dws_sale_crypto_assets_transfers_2025
SELECT id, account_id, sale_or_am_id, status, sender_type, recipient_type, transaction_count, origin_amount, settlement_amount, fee, fee2, cross_chain_fee, exchange_profit, payment_profit, hidden, create_date, currency, action, version, create_time, update_time
FROM v_dws_sale_crypto_assets_transfers_base
CROSS JOIN source_delete_dws_sale_crypto_assets_transfers_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2025-01-01' AND create_date < DATE '2026-01-01';
INSERT INTO sink_dws_sale_crypto_assets_transfers_2026
SELECT id, account_id, sale_or_am_id, status, sender_type, recipient_type, transaction_count, origin_amount, settlement_amount, fee, fee2, cross_chain_fee, exchange_profit, payment_profit, hidden, create_date, currency, action, version, create_time, update_time
FROM v_dws_sale_crypto_assets_transfers_base
CROSS JOIN source_delete_dws_sale_crypto_assets_transfers_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2026-01-01' AND create_date < DATE '2027-01-01';
INSERT INTO sink_dws_sale_crypto_assets_transfers_2027
SELECT id, account_id, sale_or_am_id, status, sender_type, recipient_type, transaction_count, origin_amount, settlement_amount, fee, fee2, cross_chain_fee, exchange_profit, payment_profit, hidden, create_date, currency, action, version, create_time, update_time
FROM v_dws_sale_crypto_assets_transfers_base
CROSS JOIN source_delete_dws_sale_crypto_assets_transfers_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2027-01-01' AND create_date < DATE '2028-01-01';
