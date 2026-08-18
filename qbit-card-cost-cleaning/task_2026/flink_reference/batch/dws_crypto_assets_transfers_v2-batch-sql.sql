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

-- 说明：batch 用于一次性修复/补数。删除函数走“修复模式”(传入 p_start/p_end)，按 create_date
--       区间整段清理后由下方重算 upsert 覆盖（幂等）。默认区间 2026-01-01~2026-08-17，按需调整。

CREATE TEMPORARY TABLE source_delete_dws_crypto_assets_transfers_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_dws_crypto_assets_transfers_cdc(false, DATE ''2026-01-01'', DATE ''2026-08-17'') AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

CREATE TEMPORARY TABLE source_dws_crypto_assets_transfers (
    account_id STRING,
    status STRING,
    sender_type STRING,
    recipient_type STRING,
    transaction_count BIGINT,
    origin_amount DECIMAL(20,4),
    settlement_amount DECIMAL(20,4),
    fee DECIMAL(20,4),
    fee2 DECIMAL(20,4),
    cross_chain_fee DECIMAL(20,4),
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
        SELECT DISTINCT "account_id" AS k0, "status" AS k1, "sender_type" AS k2, "recipient_type" AS k3, "hidden" AS k4, DATE(tr."create_time") AS k5, "currency" AS k6, "action" AS k7
        FROM "crypto_assets_transfers" AS tr
        WHERE (tr."create_time" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."create_time" < CURRENT_DATE)
    )
    SELECT "account_id" AS "account_id", "status" AS "status", "sender_type" AS "sender_type", "recipient_type" AS "recipient_type", COUNT(*) AS transaction_count, SUM("origin_amount" * "usd_rate") AS origin_amount, SUM("settlement_amount" * "usd_rate") AS settlement_amount, SUM("fee" * "usd_rate") AS fee, SUM("fee2" * "usd_rate") AS fee2, SUM("cross_chain_fee" * "usd_rate") AS cross_chain_fee, "hidden" AS "hidden", TO_CHAR("create_time", ''YYYY-MM-DD'')::DATE AS create_date, "currency" AS "currency", "action" AS "action", 1 AS version, NOW() AS create_time, NOW() AS update_time
    FROM "crypto_assets_transfers" AS tr
    JOIN affected a ON ("account_id") IS NOT DISTINCT FROM a.k0 AND ("status") IS NOT DISTINCT FROM a.k1 AND ("sender_type") IS NOT DISTINCT FROM a.k2 AND ("recipient_type") IS NOT DISTINCT FROM a.k3 AND ("hidden") IS NOT DISTINCT FROM a.k4 AND (DATE(tr."create_time")) IS NOT DISTINCT FROM a.k5 AND ("currency") IS NOT DISTINCT FROM a.k6 AND ("action") IS NOT DISTINCT FROM a.k7
    WHERE tr."delete_time" IS NULL
    GROUP BY "account_id","status","sender_type","recipient_type","hidden",create_date,"currency","action") AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

CREATE TEMPORARY VIEW v_dws_crypto_assets_transfers_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(account_id, ''), ': ', COALESCE(status, ''), ': ', COALESCE(sender_type, ''), ': ', COALESCE(recipient_type, ''), ': ', COALESCE(hidden, ''), ': ', DATE_FORMAT(create_date, 'yyyy-MM-dd'), ': ', COALESCE(currency, ''), ': ', COALESCE(action, '')))) AS BIGINT) AS id,
    *
FROM source_dws_crypto_assets_transfers;

CREATE TEMPORARY TABLE sink_dws_crypto_assets_transfers_2024 (
    id BIGINT, account_id STRING, status STRING, sender_type STRING, recipient_type STRING, transaction_count BIGINT, origin_amount DECIMAL(20,4), settlement_amount DECIMAL(20,4), fee DECIMAL(20,4), fee2 DECIMAL(20,4), cross_chain_fee DECIMAL(20,4), hidden BOOLEAN, create_date DATE, currency STRING, action STRING, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_crypto_assets_transfers_2024','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_crypto_assets_transfers_2025 (
    id BIGINT, account_id STRING, status STRING, sender_type STRING, recipient_type STRING, transaction_count BIGINT, origin_amount DECIMAL(20,4), settlement_amount DECIMAL(20,4), fee DECIMAL(20,4), fee2 DECIMAL(20,4), cross_chain_fee DECIMAL(20,4), hidden BOOLEAN, create_date DATE, currency STRING, action STRING, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_crypto_assets_transfers_2025','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_crypto_assets_transfers_2026 (
    id BIGINT, account_id STRING, status STRING, sender_type STRING, recipient_type STRING, transaction_count BIGINT, origin_amount DECIMAL(20,4), settlement_amount DECIMAL(20,4), fee DECIMAL(20,4), fee2 DECIMAL(20,4), cross_chain_fee DECIMAL(20,4), hidden BOOLEAN, create_date DATE, currency STRING, action STRING, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_crypto_assets_transfers_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_crypto_assets_transfers_2027 (
    id BIGINT, account_id STRING, status STRING, sender_type STRING, recipient_type STRING, transaction_count BIGINT, origin_amount DECIMAL(20,4), settlement_amount DECIMAL(20,4), fee DECIMAL(20,4), fee2 DECIMAL(20,4), cross_chain_fee DECIMAL(20,4), hidden BOOLEAN, create_date DATE, currency STRING, action STRING, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_crypto_assets_transfers_2027','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

INSERT INTO sink_dws_crypto_assets_transfers_2024
SELECT id, account_id, status, sender_type, recipient_type, transaction_count, origin_amount, settlement_amount, fee, fee2, cross_chain_fee, hidden, create_date, currency, action, version, create_time, update_time
FROM v_dws_crypto_assets_transfers_base
CROSS JOIN source_delete_dws_crypto_assets_transfers_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2024-01-01' AND create_date < DATE '2025-01-01';
INSERT INTO sink_dws_crypto_assets_transfers_2025
SELECT id, account_id, status, sender_type, recipient_type, transaction_count, origin_amount, settlement_amount, fee, fee2, cross_chain_fee, hidden, create_date, currency, action, version, create_time, update_time
FROM v_dws_crypto_assets_transfers_base
CROSS JOIN source_delete_dws_crypto_assets_transfers_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2025-01-01' AND create_date < DATE '2026-01-01';
INSERT INTO sink_dws_crypto_assets_transfers_2026
SELECT id, account_id, status, sender_type, recipient_type, transaction_count, origin_amount, settlement_amount, fee, fee2, cross_chain_fee, hidden, create_date, currency, action, version, create_time, update_time
FROM v_dws_crypto_assets_transfers_base
CROSS JOIN source_delete_dws_crypto_assets_transfers_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2026-01-01' AND create_date < DATE '2027-01-01';
INSERT INTO sink_dws_crypto_assets_transfers_2027
SELECT id, account_id, status, sender_type, recipient_type, transaction_count, origin_amount, settlement_amount, fee, fee2, cross_chain_fee, hidden, create_date, currency, action, version, create_time, update_time
FROM v_dws_crypto_assets_transfers_base
CROSS JOIN source_delete_dws_crypto_assets_transfers_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2027-01-01' AND create_date < DATE '2028-01-01';
