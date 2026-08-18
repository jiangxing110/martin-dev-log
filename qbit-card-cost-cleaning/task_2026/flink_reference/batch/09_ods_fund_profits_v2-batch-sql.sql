--********************************************************************
-- Author:         martinJiang
-- Created Time:   2026-08-18
-- Updated Time:   2026-08-18
-- Description:    ods_fund_profits 批处理 作业（quantum-v2 范式：确定性哈希主键 + 先清后写）
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

CREATE TEMPORARY TABLE source_delete_ods_fund_profits_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_ods_fund_profits_cdc(false, CAST(''${start_date}'' AS DATE), CAST(''${end_date}'' AS DATE)) AS affected_rows) AS delete_result',
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
    version INT,
    remarks STRING,
    account_id STRING,
    product_id STRING,
    date TIMESTAMP(6),
    currency STRING,
    profit DECIMAL(18,2),
    service_fee DECIMAL(18,2),
    status STRING,
    apr DECIMAL(18,2),
    share DECIMAL(18,2),
    net_value DECIMAL(18,2)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(WITH affected AS (
        SELECT DISTINCT tr."id" AS k0
        FROM "fund_profits" AS tr
CROSS JOIN LATERAL jsonb_array_elements(fees) AS fee
        WHERE (DATE(tr."create_time") >= CAST(''${start_date}'' AS DATE) AND DATE(tr."create_time") <= CAST(''${end_date}'' AS DATE))
    )
    SELECT CAST(tr."id" AS text) AS "fund_id", tr."create_time" AS "create_time", tr."update_time" AS "update_time", tr."delete_time" AS "delete_time", tr."version" AS "version", CAST(tr."remarks" AS text) AS "remarks", CAST(tr."account_id" AS text) AS "account_id", CAST(tr."product_id" AS text) AS "product_id", tr."date" AS "date", CAST(tr."currency" AS text) AS "currency", tr."profit" AS "profit", (CASE WHEN fee->>''type'' = ''SERVICE'' THEN (fee->>''amount'')::numeric ELSE 0 END) AS "service_fee", CAST(tr."status" AS text) AS "status", tr."apr" AS "apr", tr."share" AS "share", tr."net_value" AS "net_value"
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

CREATE TEMPORARY TABLE sink_ods_fund_profits_2026 (
    id BIGINT, fund_id STRING, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version INT, remarks STRING, account_id STRING, product_id STRING, date TIMESTAMP(6), currency STRING, profit DECIMAL(18,2), service_fee DECIMAL(18,2), status STRING, apr DECIMAL(18,2), share DECIMAL(18,2), net_value DECIMAL(18,2),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_fund_profits_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

INSERT INTO sink_ods_fund_profits_2026
SELECT id, fund_id, create_time, update_time, delete_time, version, remarks, account_id, product_id, date, currency, profit, service_fee, status, apr, share, net_value
FROM v_ods_fund_profits_base
CROSS JOIN source_delete_ods_fund_profits_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2026-01-01 00:00:00' AND create_time < TIMESTAMP '2027-01-01 00:00:00';
