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

CREATE TEMPORARY TABLE source_delete_ods_fund_profits_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_ods_fund_profits_cdc(false, DATE ''2026-01-01'', DATE ''2026-08-17'') AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

CREATE TEMPORARY TABLE source_ods_fund_profits (
    fund_id STRING,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    version BIGINT,
    remarks STRING,
    account_id STRING,
    product_id STRING,
    date DATE,
    currency STRING,
    profit DECIMAL(20,4),
    service_fee DECIMAL(20,4),
    status STRING,
    apr DECIMAL(20,4),
    share DECIMAL(20,4),
    net_value DECIMAL(20,4)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(WITH affected AS (
        SELECT DISTINCT tr."id" AS k0
        FROM "fund_profits" AS tr
CROSS JOIN LATERAL jsonb_array_elements(fees) AS fee
        WHERE (tr."create_time" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."create_time" < CURRENT_DATE)
    )
    SELECT tr."id" AS "fund_id", tr."create_time" AS "create_time", tr."update_time" AS "update_time", tr."delete_time" AS "delete_time", tr."version" AS "version", tr."remarks" AS "remarks", tr."account_id" AS "account_id", tr."product_id" AS "product_id", tr."date" AS "date", tr."currency" AS "currency", tr."profit" AS "profit", (CASE WHEN fee->>''type'' = ''SERVICE'' THEN (fee->>''amount'')::numeric ELSE 0 END) AS "service_fee", tr."status" AS "status", tr."apr" AS "apr", tr."share" AS "share", tr."net_value" AS "net_value"
    FROM "fund_profits" AS tr
CROSS JOIN LATERAL jsonb_array_elements(fees) AS fee
    JOIN affected a ON (tr."id") IS NOT DISTINCT FROM a.k0
    WHERE tr."delete_time" IS NULL) AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

CREATE TEMPORARY VIEW v_ods_fund_profits_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(fund_id, '')))) AS BIGINT) AS id,
    *
FROM source_ods_fund_profits;

CREATE TEMPORARY TABLE sink_ods_fund_profits_2024 (
    id BIGINT, fund_id STRING, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version BIGINT, remarks STRING, account_id STRING, product_id STRING, date DATE, currency STRING, profit DECIMAL(20,4), service_fee DECIMAL(20,4), status STRING, apr DECIMAL(20,4), share DECIMAL(20,4), net_value DECIMAL(20,4),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_fund_profits_2024','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_ods_fund_profits_2025 (
    id BIGINT, fund_id STRING, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version BIGINT, remarks STRING, account_id STRING, product_id STRING, date DATE, currency STRING, profit DECIMAL(20,4), service_fee DECIMAL(20,4), status STRING, apr DECIMAL(20,4), share DECIMAL(20,4), net_value DECIMAL(20,4),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_fund_profits_2025','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_ods_fund_profits_2026 (
    id BIGINT, fund_id STRING, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version BIGINT, remarks STRING, account_id STRING, product_id STRING, date DATE, currency STRING, profit DECIMAL(20,4), service_fee DECIMAL(20,4), status STRING, apr DECIMAL(20,4), share DECIMAL(20,4), net_value DECIMAL(20,4),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_fund_profits_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_ods_fund_profits_2027 (
    id BIGINT, fund_id STRING, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version BIGINT, remarks STRING, account_id STRING, product_id STRING, date DATE, currency STRING, profit DECIMAL(20,4), service_fee DECIMAL(20,4), status STRING, apr DECIMAL(20,4), share DECIMAL(20,4), net_value DECIMAL(20,4),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_fund_profits_2027','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

INSERT INTO sink_ods_fund_profits_2024
SELECT id, fund_id, create_time, update_time, delete_time, version, remarks, account_id, product_id, date, currency, profit, service_fee, status, apr, share, net_value
FROM v_ods_fund_profits_base
CROSS JOIN source_delete_ods_fund_profits_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2024-01-01 00:00:00' AND create_time < TIMESTAMP '2025-01-01 00:00:00';
INSERT INTO sink_ods_fund_profits_2025
SELECT id, fund_id, create_time, update_time, delete_time, version, remarks, account_id, product_id, date, currency, profit, service_fee, status, apr, share, net_value
FROM v_ods_fund_profits_base
CROSS JOIN source_delete_ods_fund_profits_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2025-01-01 00:00:00' AND create_time < TIMESTAMP '2026-01-01 00:00:00';
INSERT INTO sink_ods_fund_profits_2026
SELECT id, fund_id, create_time, update_time, delete_time, version, remarks, account_id, product_id, date, currency, profit, service_fee, status, apr, share, net_value
FROM v_ods_fund_profits_base
CROSS JOIN source_delete_ods_fund_profits_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2026-01-01 00:00:00' AND create_time < TIMESTAMP '2027-01-01 00:00:00';
INSERT INTO sink_ods_fund_profits_2027
SELECT id, fund_id, create_time, update_time, delete_time, version, remarks, account_id, product_id, date, currency, profit, service_fee, status, apr, share, net_value
FROM v_ods_fund_profits_base
CROSS JOIN source_delete_ods_fund_profits_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2027-01-01 00:00:00' AND create_time < TIMESTAMP '2028-01-01 00:00:00';
