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

CREATE TEMPORARY TABLE source_delete_dws_transfer_extend_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_dws_transfer_extend_cdc(false, DATE ''2026-01-01'', DATE ''2026-08-17'') AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

CREATE TEMPORARY TABLE source_dws_transfer_extend (
    account_id STRING,
    status STRING,
    dbs_receive DECIMAL(20,4),
    cl_receive DECIMAL(20,4),
    ep_receive DECIMAL(20,4),
    rd_receive DECIMAL(20,4),
    settle_fx_fee DECIMAL(20,4),
    conversion_fx_amount DECIMAL(20,4),
    conversion_fx_fee DECIMAL(20,4),
    create_date DATE,
    version BIGINT,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(WITH affected AS (
        SELECT DISTINCT tr."accountId" AS k0, DATE(tr."createTime") AS k1, tr."status" AS k2
        FROM "transfer" AS tr
LEFT JOIN "globalConversion" AS ta ON ta."recordId"::UUID = tr.id
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."createTime" < CURRENT_DATE)
    )
    SELECT tr."accountId" AS "account_id", tr."status" AS "status", COALESCE(SUM(CASE WHEN tr."businessTypeDetail" IN (''OtherChannelInbound'') AND UPPER((tr."rawData"::jsonb->> 0)::jsonb->>''source'') IN (''OTT'',''寻汇'',''BEEPAY'') THEN "usdAmount" ELSE 0 END), 0) AS "dbs_receive", COALESCE(SUM(CASE WHEN tr."businessTypeDetail" IN (''OtherChannelInbound'',''CCInbound'') AND tr."provider" = ''Column'' THEN "usdAmount" ELSE 0 END), 0) AS "cl_receive", COALESCE(SUM(CASE WHEN tr."businessTypeDetail" IN (''OtherChannelInbound'',''CCInbound'') AND tr."provider" = ''EP''THEN "usdAmount" ELSE 0 END), 0) AS "ep_receive", COALESCE(SUM(CASE WHEN tr."businessTypeDetail" IN (''OtherChannelInbound'',''CCInbound'') AND tr."provider" = ''RD'' THEN "usdAmount" ELSE 0 END), 0) AS "rd_receive", COALESCE(SUM(CASE WHEN ta."toCurrency" = ''CNY'' AND tr."status" = ''Closed'' AND ta.status = ''Closed'' THEN ta."rateDiffIncomeFromUsdAmount" ELSE 0 END), 0) AS "settle_fx_fee", COALESCE(SUM(CASE WHEN tr."settlementCurrency" != ''CNY'' AND tr."status" = ''Closed'' AND ta.status = ''Closed''  AND tr."businessTypeDetail" IN (''Payment'',''ConversionOut'',''InnerTransferOut'') THEN tr."usdAmount" ELSE 0 END), 0) AS "conversion_fx_amount", COALESCE(SUM(CASE WHEN ta."toCurrency" != ''CNY'' AND tr."status" = ''Closed'' AND ta.status = ''Closed'' THEN ta."rateDiffIncomeFromUsdAmount" ELSE 0 END), 0) AS "conversion_fx_fee", TO_CHAR(tr."createTime", ''YYYY-MM-DD'')::DATE AS create_date, 1 AS version, NOW() AS create_time, NOW() AS update_time
    FROM "transfer" AS tr
LEFT JOIN "globalConversion" AS ta ON ta."recordId"::UUID = tr.id
    JOIN affected a ON (tr."accountId") IS NOT DISTINCT FROM a.k0 AND (DATE(tr."createTime")) IS NOT DISTINCT FROM a.k1 AND (tr."status") IS NOT DISTINCT FROM a.k2
    WHERE tr."deleteTime" IS NULL AND ta."deleteTime" IS NULL
    GROUP BY tr."accountId", create_date, tr.status) AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

CREATE TEMPORARY VIEW v_dws_transfer_extend_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(account_id, ''), ': ', DATE_FORMAT(create_date, 'yyyy-MM-dd'), ': ', COALESCE(status, '')))) AS BIGINT) AS id,
    *
FROM source_dws_transfer_extend;

CREATE TEMPORARY TABLE sink_dws_transfer_extend_2024 (
    id BIGINT, account_id STRING, status STRING, dbs_receive DECIMAL(20,4), cl_receive DECIMAL(20,4), ep_receive DECIMAL(20,4), rd_receive DECIMAL(20,4), settle_fx_fee DECIMAL(20,4), conversion_fx_amount DECIMAL(20,4), conversion_fx_fee DECIMAL(20,4), create_date DATE, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_transfer_extend_2024','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_transfer_extend_2025 (
    id BIGINT, account_id STRING, status STRING, dbs_receive DECIMAL(20,4), cl_receive DECIMAL(20,4), ep_receive DECIMAL(20,4), rd_receive DECIMAL(20,4), settle_fx_fee DECIMAL(20,4), conversion_fx_amount DECIMAL(20,4), conversion_fx_fee DECIMAL(20,4), create_date DATE, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_transfer_extend_2025','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_transfer_extend_2026 (
    id BIGINT, account_id STRING, status STRING, dbs_receive DECIMAL(20,4), cl_receive DECIMAL(20,4), ep_receive DECIMAL(20,4), rd_receive DECIMAL(20,4), settle_fx_fee DECIMAL(20,4), conversion_fx_amount DECIMAL(20,4), conversion_fx_fee DECIMAL(20,4), create_date DATE, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_transfer_extend_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_transfer_extend_2027 (
    id BIGINT, account_id STRING, status STRING, dbs_receive DECIMAL(20,4), cl_receive DECIMAL(20,4), ep_receive DECIMAL(20,4), rd_receive DECIMAL(20,4), settle_fx_fee DECIMAL(20,4), conversion_fx_amount DECIMAL(20,4), conversion_fx_fee DECIMAL(20,4), create_date DATE, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_transfer_extend_2027','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

INSERT INTO sink_dws_transfer_extend_2024
SELECT id, account_id, status, dbs_receive, cl_receive, ep_receive, rd_receive, settle_fx_fee, conversion_fx_amount, conversion_fx_fee, create_date, version, create_time, update_time
FROM v_dws_transfer_extend_base
CROSS JOIN source_delete_dws_transfer_extend_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2024-01-01' AND create_date < DATE '2025-01-01';
INSERT INTO sink_dws_transfer_extend_2025
SELECT id, account_id, status, dbs_receive, cl_receive, ep_receive, rd_receive, settle_fx_fee, conversion_fx_amount, conversion_fx_fee, create_date, version, create_time, update_time
FROM v_dws_transfer_extend_base
CROSS JOIN source_delete_dws_transfer_extend_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2025-01-01' AND create_date < DATE '2026-01-01';
INSERT INTO sink_dws_transfer_extend_2026
SELECT id, account_id, status, dbs_receive, cl_receive, ep_receive, rd_receive, settle_fx_fee, conversion_fx_amount, conversion_fx_fee, create_date, version, create_time, update_time
FROM v_dws_transfer_extend_base
CROSS JOIN source_delete_dws_transfer_extend_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2026-01-01' AND create_date < DATE '2027-01-01';
INSERT INTO sink_dws_transfer_extend_2027
SELECT id, account_id, status, dbs_receive, cl_receive, ep_receive, rd_receive, settle_fx_fee, conversion_fx_amount, conversion_fx_fee, create_date, version, create_time, update_time
FROM v_dws_transfer_extend_base
CROSS JOIN source_delete_dws_transfer_extend_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2027-01-01' AND create_date < DATE '2028-01-01';
