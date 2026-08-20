--********************************************************************
-- Author:         martinJiang
-- Created Time:   2026-08-18
-- Updated Time:   2026-08-18
-- Description:    ods_sale_fund_profits 流处理(CDC) 作业（quantum-v2 范式：确定性哈希主键 + 先清后写）
-- 作业元信息：
--   作业类型：流处理(CDC)
--   运行方式：每日增量（BATCH 定时触发）：自动按昨天变更窗口(CDC 模式)精准删受影响 key 后 upsert 覆盖。
--   运行参数：（无；CDC 模式自动按昨天变更窗口）
-- Notes:
--   1. 聚合逻辑留在 PostgreSQL（JDBC source 子查询），Flink 仅算 id + upsert，类型转换最少。
--   2. 删除函数按唯一业务键 / 作用域精准删受影响 key，先清后写保证幂等。
--   3. 按 create_date 年份动态路由分表（_YYYY），跨年安全。
--   4. 上线前需对照线上 Flink catalog 校准列类型（UUID / JSON / boolean 等）。
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

-- ==============================================
-- 0. 先调用删除函数：按唯一业务键精准清空受影响分表行（先清后写，保证幂等）
-- ==============================================
CREATE TEMPORARY TABLE source_delete_ods_sale_fund_profits_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_ods_sale_fund_profits_cdc(false) AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

-- ==============================================
-- 1. 源聚合（留在 PostgreSQL 内执行，复用原版聚合逻辑；只回传受影响 key 的聚合结果）
-- ==============================================
CREATE TEMPORARY TABLE source_ods_sale_fund_profits (
    fund_id STRING,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    version INT,
    remarks STRING,
    account_id STRING,
    sale_or_am_id STRING,
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
        SELECT DISTINCT DATE(tr."create_time") AS scope_date, tr."account_id" AS scope_account FROM fund_profits AS tr
CROSS JOIN LATERAL jsonb_array_elements(fees) AS fee
LEFT JOIN (
    SELECT sar."createTime", sar."deleteTime", sar."salesId", sar."amId", sar."accountId"
    FROM "salesAccountRelation" AS sar
    UNION ALL
    SELECT sar."createTime", sar."deleteTime", sar."salesId", sar."amId", account.id AS "accountId"
    FROM account
    INNER JOIN "salesAccountRelation" AS sar ON sar."accountId"::UUID = account."parentAccountId"::UUID
    WHERE account."parentAccountId" != ''00000000-0000-0000-0000-000000000000''
) AS sar ON tr."account_id"::UUID = sar."accountId"::UUID
AND tr."create_time" >= sar."createTime" AND (tr."create_time" <= sar."deleteTime" OR sar."deleteTime" IS NULL)
LEFT JOIN LATERAL (SELECT unnest(ARRAY[sar."salesId"::uuid, sar."amId"::uuid]) AS sale_or_am_id) AS ids ON TRUE WHERE (tr."create_time" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."create_time" < CURRENT_DATE) OR (tr."update_time" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."update_time" < CURRENT_DATE) OR (tr."delete_time" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."delete_time" < CURRENT_DATE)
    )
    SELECT CAST(tr."id" AS text) AS "fund_id", "create_time" AS "create_time", "update_time" AS "update_time", "delete_time" AS "delete_time", tr."version" AS "version", CAST(tr."remarks" AS text) AS "remarks", CAST("account_id" AS text) AS "account_id", CAST(ids."sale_or_am_id" AS text) AS "sale_or_am_id", CAST("product_id" AS text) AS "product_id", "date" AS "date", CAST("currency" AS text) AS "currency", "profit" AS "profit", (CASE WHEN fee->>''type'' = ''SERVICE'' THEN (fee->>''amount'')::numeric ELSE 0 END) AS "service_fee", CAST(tr."status" AS text) AS "status", "apr" AS "apr", "share" AS "share", "net_value" AS "net_value"
    FROM fund_profits AS tr
CROSS JOIN LATERAL jsonb_array_elements(fees) AS fee
LEFT JOIN (
    SELECT sar."createTime", sar."deleteTime", sar."salesId", sar."amId", sar."accountId"
    FROM "salesAccountRelation" AS sar
    UNION ALL
    SELECT sar."createTime", sar."deleteTime", sar."salesId", sar."amId", account.id AS "accountId"
    FROM account
    INNER JOIN "salesAccountRelation" AS sar ON sar."accountId"::UUID = account."parentAccountId"::UUID
    WHERE account."parentAccountId" != ''00000000-0000-0000-0000-000000000000''
) AS sar ON tr."account_id"::UUID = sar."accountId"::UUID
AND tr."create_time" >= sar."createTime" AND (tr."create_time" <= sar."deleteTime" OR sar."deleteTime" IS NULL)
LEFT JOIN LATERAL (SELECT unnest(ARRAY[sar."salesId"::uuid, sar."amId"::uuid]) AS sale_or_am_id) AS ids ON TRUE
    JOIN affected a ON (DATE(tr."create_time")) = a.scope_date AND (tr."account_id") = a.scope_account
    WHERE tr."delete_time" IS NULL) AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

-- ==============================================
-- 2. 聚合结果视图：计算确定性主键 id = HASH(业务键)
--    （source_ods_sale_fund_profits 已输出聚合列，此处只补 id；列名与 DWS 表一致）
-- ==============================================
CREATE TEMPORARY VIEW v_ods_sale_fund_profits_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(fund_id, '')))) AS BIGINT) AS id,
    *
FROM source_ods_sale_fund_profits;

-- ==============================================
-- 3. 分表 SINK（每个 _YYYY 一个，upsert 按 key 幂等）
-- ==============================================
CREATE TEMPORARY TABLE sink_ods_sale_fund_profits_2024 (
    id BIGINT, fund_id STRING, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version INT, remarks STRING, account_id STRING, sale_or_am_id STRING, product_id STRING, date TIMESTAMP(6), currency STRING, profit DECIMAL(18,2), service_fee DECIMAL(18,2), status STRING, apr DECIMAL(18,2), share DECIMAL(18,2), net_value DECIMAL(18,2),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_sale_fund_profits_2024','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_ods_sale_fund_profits_2025 (
    id BIGINT, fund_id STRING, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version INT, remarks STRING, account_id STRING, sale_or_am_id STRING, product_id STRING, date TIMESTAMP(6), currency STRING, profit DECIMAL(18,2), service_fee DECIMAL(18,2), status STRING, apr DECIMAL(18,2), share DECIMAL(18,2), net_value DECIMAL(18,2),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_sale_fund_profits_2025','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_ods_sale_fund_profits_2026 (
    id BIGINT, fund_id STRING, create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version INT, remarks STRING, account_id STRING, sale_or_am_id STRING, product_id STRING, date TIMESTAMP(6), currency STRING, profit DECIMAL(18,2), service_fee DECIMAL(18,2), status STRING, apr DECIMAL(18,2), share DECIMAL(18,2), net_value DECIMAL(18,2),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.ods_sale_fund_profits_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

-- ==============================================
-- 4. 写入（CROSS JOIN 确保删除函数先执行；upsert 覆盖同 key / 新增异 key）
-- ==============================================
INSERT INTO sink_ods_sale_fund_profits_2024
SELECT id, fund_id, create_time, update_time, delete_time, version, remarks, account_id, sale_or_am_id, product_id, date, currency, profit, service_fee, status, apr, share, net_value
FROM v_ods_sale_fund_profits_base
CROSS JOIN source_delete_ods_sale_fund_profits_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2024-01-01 00:00:00' AND create_time < TIMESTAMP '2025-01-01 00:00:00';
INSERT INTO sink_ods_sale_fund_profits_2025
SELECT id, fund_id, create_time, update_time, delete_time, version, remarks, account_id, sale_or_am_id, product_id, date, currency, profit, service_fee, status, apr, share, net_value
FROM v_ods_sale_fund_profits_base
CROSS JOIN source_delete_ods_sale_fund_profits_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2025-01-01 00:00:00' AND create_time < TIMESTAMP '2026-01-01 00:00:00';
INSERT INTO sink_ods_sale_fund_profits_2026
SELECT id, fund_id, create_time, update_time, delete_time, version, remarks, account_id, sale_or_am_id, product_id, date, currency, profit, service_fee, status, apr, share, net_value
FROM v_ods_sale_fund_profits_base
CROSS JOIN source_delete_ods_sale_fund_profits_result AS del
WHERE del.affected_rows >= 0
  AND create_time >= TIMESTAMP '2026-01-01 00:00:00' AND create_time < TIMESTAMP '2027-01-01 00:00:00';
