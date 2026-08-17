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

CREATE TEMPORARY TABLE source_delete_dws_transfer_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_dws_transfer_cdc(false, DATE ''2026-01-01'', DATE ''2026-08-17'') AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

CREATE TEMPORARY TABLE source_dws_transfer (
    dws_transfer_row STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(WITH affected AS (
        SELECT DISTINCT tr."accountId" AS k0, tr."businessTypeDetail" AS k1, tr."businessCode" AS k2, tr."settlementCurrency" AS k3, CURRENT_DATE AS k4, tr."status" AS k5, "currency" AS k6
        FROM "transfer" AS tr
        WHERE FALSE
    )
    SELECT tr."accountId", tr."businessTypeDetail", tr."businessCode", tr."settlementCurrency", tr."status", COALESCE(SUM(tr."usdAmount"), 0) AS usd_amount, COUNT(*) AS transaction_count, COALESCE(SUM("fee" * "usdRate"), 0) AS fee, "currency", TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS create_date, 1 AS version, NOW() AS create_time, NOW() AS update_time
    FROM "transfer" AS tr s
    JOIN affected a ON (tr."accountId") IS NOT DISTINCT FROM a.k0 AND (tr."businessTypeDetail") IS NOT DISTINCT FROM a.k1 AND (tr."businessCode") IS NOT DISTINCT FROM a.k2 AND (tr."settlementCurrency") IS NOT DISTINCT FROM a.k3 AND (CURRENT_DATE) IS NOT DISTINCT FROM a.k4 AND (tr."status") IS NOT DISTINCT FROM a.k5 AND ("currency") IS NOT DISTINCT FROM a.k6
    WHERE tr."deleteTime" IS NULL
    GROUP BY tr."accountId", tr."businessTypeDetail",tr."businessCode", tr."settlementCurrency", create_date, status, "currency") AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

CREATE TEMPORARY VIEW v_dws_transfer_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(account_id, ''), ': ', COALESCE(business_type_detail, ''), ': ', COALESCE(business_type_code, ''), ': ', COALESCE(settlement_currency, ''), ': ', DATE_FORMAT(create_date, 'yyyy-MM-dd'), ': ', COALESCE(status, ''), ': ', COALESCE(currency, '')))) AS BIGINT) AS id,
    *
FROM source_dws_transfer;

CREATE TEMPORARY TABLE sink_dws_transfer_2024 (
    id BIGINT, account_id STRING, business_type_detail STRING, business_type_code STRING, settlement_currency STRING, status STRING, usd_amount DECIMAL(20,4), transaction_count BIGINT, fee DECIMAL(20,4), currency STRING, create_date DATE, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_transfer_2024','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_transfer_2025 (
    id BIGINT, account_id STRING, business_type_detail STRING, business_type_code STRING, settlement_currency STRING, status STRING, usd_amount DECIMAL(20,4), transaction_count BIGINT, fee DECIMAL(20,4), currency STRING, create_date DATE, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_transfer_2025','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_transfer_2026 (
    id BIGINT, account_id STRING, business_type_detail STRING, business_type_code STRING, settlement_currency STRING, status STRING, usd_amount DECIMAL(20,4), transaction_count BIGINT, fee DECIMAL(20,4), currency STRING, create_date DATE, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_transfer_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_transfer_2027 (
    id BIGINT, account_id STRING, business_type_detail STRING, business_type_code STRING, settlement_currency STRING, status STRING, usd_amount DECIMAL(20,4), transaction_count BIGINT, fee DECIMAL(20,4), currency STRING, create_date DATE, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_transfer_2027','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

INSERT INTO sink_dws_transfer_2024
SELECT id, account_id, business_type_detail, business_type_code, settlement_currency, status, usd_amount, transaction_count, fee, currency, create_date, version, create_time, update_time
FROM v_dws_transfer_base
CROSS JOIN source_delete_dws_transfer_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2024-01-01' AND create_date < DATE '2025-01-01';
INSERT INTO sink_dws_transfer_2025
SELECT id, account_id, business_type_detail, business_type_code, settlement_currency, status, usd_amount, transaction_count, fee, currency, create_date, version, create_time, update_time
FROM v_dws_transfer_base
CROSS JOIN source_delete_dws_transfer_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2025-01-01' AND create_date < DATE '2026-01-01';
INSERT INTO sink_dws_transfer_2026
SELECT id, account_id, business_type_detail, business_type_code, settlement_currency, status, usd_amount, transaction_count, fee, currency, create_date, version, create_time, update_time
FROM v_dws_transfer_base
CROSS JOIN source_delete_dws_transfer_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2026-01-01' AND create_date < DATE '2027-01-01';
INSERT INTO sink_dws_transfer_2027
SELECT id, account_id, business_type_detail, business_type_code, settlement_currency, status, usd_amount, transaction_count, fee, currency, create_date, version, create_time, update_time
FROM v_dws_transfer_base
CROSS JOIN source_delete_dws_transfer_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2027-01-01' AND create_date < DATE '2028-01-01';
