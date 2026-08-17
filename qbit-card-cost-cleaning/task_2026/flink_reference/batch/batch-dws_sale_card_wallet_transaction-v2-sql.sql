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

CREATE TEMPORARY TABLE source_delete_dws_sale_card_wallet_transaction_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_dws_sale_card_wallet_transaction_cdc(false, DATE ''2026-01-01'', DATE ''2026-08-17'') AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

CREATE TEMPORARY TABLE source_dws_sale_card_wallet_transaction (
    account_id STRING,
    sale_or_am_id STRING,
    business_type STRING,
    status STRING,
    origin_amount DECIMAL(20,4),
    transaction_count BIGINT,
    fee DECIMAL(20,4),
    create_date DATE,
    version BIGINT,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(WITH affected AS (
        SELECT DISTINCT tr."accountId" AS k0, tr."businessType" AS k1, tr."status" AS k2, DATE(tr."createTime") AS k3, ids."sale_or_am_id" AS k4
        FROM "qbitCardWalletTransaction" AS tr
LEFT JOIN "public"."ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."createTime" < CURRENT_DATE)
    )
    SELECT tr."accountId" AS "account_id", ids."sale_or_am_id" AS "sale_or_am_id", tr."businessType" AS "business_type", tr."status" AS "status", COALESCE(SUM(tr."originAmount"), 0) AS origin_amount, COUNT(*) AS transaction_count, COALESCE(SUM(tr."fee"), 0) AS fee, TO_CHAR(tr."createTime", ''YYYY-MM-DD'')::DATE AS create_date, 1 AS version, NOW() AS create_time, NOW() AS update_time
    FROM "qbitCardWalletTransaction" AS tr
LEFT JOIN "public"."ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
    JOIN affected a ON (tr."accountId") IS NOT DISTINCT FROM a.k0 AND (tr."businessType") IS NOT DISTINCT FROM a.k1 AND (tr."status") IS NOT DISTINCT FROM a.k2 AND (DATE(tr."createTime")) IS NOT DISTINCT FROM a.k3 AND (ids."sale_or_am_id") IS NOT DISTINCT FROM a.k4
    WHERE tr."deleteTime" IS NULL
    GROUP BY tr."accountId", tr."businessType", tr."status", create_date, ids."sale_or_am_id") AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

CREATE TEMPORARY VIEW v_dws_sale_card_wallet_transaction_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(account_id, ''), ': ', COALESCE(business_type, ''), ': ', COALESCE(status, ''), ': ', DATE_FORMAT(create_date, 'yyyy-MM-dd'), ': ', COALESCE(sale_or_am_id, '')))) AS BIGINT) AS id,
    *
FROM source_dws_sale_card_wallet_transaction;

CREATE TEMPORARY TABLE sink_dws_sale_card_wallet_transaction_2024 (
    id BIGINT, account_id STRING, sale_or_am_id STRING, business_type STRING, status STRING, origin_amount DECIMAL(20,4), transaction_count BIGINT, fee DECIMAL(20,4), create_date DATE, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_sale_card_wallet_transaction_2024','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_sale_card_wallet_transaction_2025 (
    id BIGINT, account_id STRING, sale_or_am_id STRING, business_type STRING, status STRING, origin_amount DECIMAL(20,4), transaction_count BIGINT, fee DECIMAL(20,4), create_date DATE, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_sale_card_wallet_transaction_2025','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_sale_card_wallet_transaction_2026 (
    id BIGINT, account_id STRING, sale_or_am_id STRING, business_type STRING, status STRING, origin_amount DECIMAL(20,4), transaction_count BIGINT, fee DECIMAL(20,4), create_date DATE, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_sale_card_wallet_transaction_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_sale_card_wallet_transaction_2027 (
    id BIGINT, account_id STRING, sale_or_am_id STRING, business_type STRING, status STRING, origin_amount DECIMAL(20,4), transaction_count BIGINT, fee DECIMAL(20,4), create_date DATE, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_sale_card_wallet_transaction_2027','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

INSERT INTO sink_dws_sale_card_wallet_transaction_2024
SELECT id, account_id, sale_or_am_id, business_type, status, origin_amount, transaction_count, fee, create_date, version, create_time, update_time
FROM v_dws_sale_card_wallet_transaction_base
CROSS JOIN source_delete_dws_sale_card_wallet_transaction_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2024-01-01' AND create_date < DATE '2025-01-01';
INSERT INTO sink_dws_sale_card_wallet_transaction_2025
SELECT id, account_id, sale_or_am_id, business_type, status, origin_amount, transaction_count, fee, create_date, version, create_time, update_time
FROM v_dws_sale_card_wallet_transaction_base
CROSS JOIN source_delete_dws_sale_card_wallet_transaction_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2025-01-01' AND create_date < DATE '2026-01-01';
INSERT INTO sink_dws_sale_card_wallet_transaction_2026
SELECT id, account_id, sale_or_am_id, business_type, status, origin_amount, transaction_count, fee, create_date, version, create_time, update_time
FROM v_dws_sale_card_wallet_transaction_base
CROSS JOIN source_delete_dws_sale_card_wallet_transaction_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2026-01-01' AND create_date < DATE '2027-01-01';
INSERT INTO sink_dws_sale_card_wallet_transaction_2027
SELECT id, account_id, sale_or_am_id, business_type, status, origin_amount, transaction_count, fee, create_date, version, create_time, update_time
FROM v_dws_sale_card_wallet_transaction_base
CROSS JOIN source_delete_dws_sale_card_wallet_transaction_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2027-01-01' AND create_date < DATE '2028-01-01';
