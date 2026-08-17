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

-- ==============================================
-- 0. 先调用删除函数：按唯一业务键精准清空受影响分表行（先清后写，保证幂等）
-- ==============================================
CREATE TEMPORARY TABLE source_delete_ods_fund_profits_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_ods_fund_profits_cdc(false) AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

-- ==============================================
-- 1. 源聚合（留在 PostgreSQL 内执行，复用原版聚合逻辑；只回传受影响 key 的聚合结果）
-- ==============================================
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
        WHERE (tr."create_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."create_time" < CURRENT_DATE) OR (tr."update_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."update_time" < CURRENT_DATE) OR (tr."delete_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."delete_time" < CURRENT_DATE)
    )
    SELECT tr."id", tr."create_time", tr."update_time", tr."delete_time", tr."version", tr."remarks", tr."account_id", tr."product_id", tr."date", tr."currency", tr."profit", (CASE WHEN fee->>'type' = 'SERVICE' THEN (fee->>'amount')::numeric ELSE 0 END) AS "service_fee", tr."status", tr."apr", tr."share", tr."net_value"
    FROM "fund_profits" AS tr
CROSS JOIN LATERAL jsonb_array_elements(fees) AS fee
    JOIN affected a ON (tr."id") IS NOT DISTINCT FROM a.k0
    WHERE tr."delete_time" IS NULL) AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

-- ==============================================
-- 2. 聚合结果视图：计算确定性主键 id = HASH(业务键)
--    （source_ods_fund_profits 已输出聚合列，此处只补 id；列名与 DWS 表一致）
-- ==============================================
CREATE TEMPORARY VIEW v_ods_fund_profits_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(fund_id, '')))) AS BIGINT) AS id,
    *
FROM source_ods_fund_profits;

-- ==============================================
-- 3. 分表 SINK（每个 _YYYY 一个，upsert 按 key 幂等）
-- ==============================================
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

-- ==============================================
-- 4. 写入（CROSS JOIN 确保删除函数先执行；upsert 覆盖同 key / 新增异 key）
-- ==============================================
INSERT INTO sink_ods_fund_profits_2024
SELECT id, fund_id, create_time, update_time, delete_time, version, remarks, account_id, product_id, date, currency, profit, service_fee, status, apr, share, net_value
FROM v_ods_fund_profits_base
CROSS JOIN source_delete_ods_fund_profits_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2024-01-01' AND create_date < DATE '2025-01-01';
INSERT INTO sink_ods_fund_profits_2025
SELECT id, fund_id, create_time, update_time, delete_time, version, remarks, account_id, product_id, date, currency, profit, service_fee, status, apr, share, net_value
FROM v_ods_fund_profits_base
CROSS JOIN source_delete_ods_fund_profits_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2025-01-01' AND create_date < DATE '2026-01-01';
INSERT INTO sink_ods_fund_profits_2026
SELECT id, fund_id, create_time, update_time, delete_time, version, remarks, account_id, product_id, date, currency, profit, service_fee, status, apr, share, net_value
FROM v_ods_fund_profits_base
CROSS JOIN source_delete_ods_fund_profits_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2026-01-01' AND create_date < DATE '2027-01-01';
INSERT INTO sink_ods_fund_profits_2027
SELECT id, fund_id, create_time, update_time, delete_time, version, remarks, account_id, product_id, date, currency, profit, service_fee, status, apr, share, net_value
FROM v_ods_fund_profits_base
CROSS JOIN source_delete_ods_fund_profits_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2027-01-01' AND create_date < DATE '2028-01-01';
