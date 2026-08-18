--********************************************************************
-- Author:         martinJiang
-- Created Time:   2026-08-18
-- Updated Time:   2026-08-18
-- Description:    dws_crypto_assets_transfers 流处理(CDC) 作业（quantum-v2 范式：确定性哈希主键 + 先清后写）
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
CREATE TEMPORARY TABLE source_delete_dws_crypto_assets_transfers_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_dws_crypto_assets_transfers_cdc(false) AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

-- ==============================================
-- 1. 源聚合（留在 PostgreSQL 内执行，复用原版聚合逻辑；只回传受影响 key 的聚合结果）
-- ==============================================
CREATE TEMPORARY TABLE source_dws_crypto_assets_transfers (
    account_id STRING,
    status STRING,
    sender_type STRING,
    recipient_type STRING,
    transaction_count INT,
    origin_amount DECIMAL(18,2),
    settlement_amount DECIMAL(18,2),
    fee DECIMAL(18,2),
    fee2 DECIMAL(18,2),
    cross_chain_fee DECIMAL(18,2),
    hidden BOOLEAN,
    create_date TIMESTAMP(6),
    currency STRING,
    action STRING,
    version INT,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(WITH affected AS (
        SELECT DISTINCT "account_id" AS k0, "status" AS k1, "sender_type" AS k2, "recipient_type" AS k3, "hidden" AS k4, DATE_TRUNC(''day'' AS k5, tr."create_time")::TIMESTAMP AS k6, "currency" AS k7, "action" AS k8
        FROM "crypto_assets_transfers" AS tr
        WHERE (tr."create_time" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."create_time" < CURRENT_DATE)
    )
    SELECT "account_id" AS "account_id", "status" AS "status", "sender_type" AS "sender_type", "recipient_type" AS "recipient_type", COUNT(*) AS transaction_count, SUM("origin_amount" * "usd_rate") AS origin_amount, SUM("settlement_amount" * "usd_rate") AS settlement_amount, SUM("fee" * "usd_rate") AS fee, SUM("fee2" * "usd_rate") AS fee2, SUM("cross_chain_fee" * "usd_rate") AS cross_chain_fee, "hidden" AS "hidden", TO_CHAR("create_time", ''YYYY-MM-DD'')::DATE AS create_date, "currency" AS "currency", "action" AS "action", 1 AS version, NOW() AS create_time, NOW() AS update_time
    FROM "crypto_assets_transfers" AS tr
    JOIN affected a ON ("account_id") IS NOT DISTINCT FROM a.k0 AND ("status") IS NOT DISTINCT FROM a.k1 AND ("sender_type") IS NOT DISTINCT FROM a.k2 AND ("recipient_type") IS NOT DISTINCT FROM a.k3 AND ("hidden") IS NOT DISTINCT FROM a.k4 AND (DATE_TRUNC(''day'') IS NOT DISTINCT FROM a.k5 AND (tr."create_time")::TIMESTAMP) IS NOT DISTINCT FROM a.k6 AND ("currency") IS NOT DISTINCT FROM a.k7
    WHERE tr."delete_time" IS NULL
    GROUP BY "account_id","status","sender_type","recipient_type","hidden",create_date,"currency","action") AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

-- ==============================================
-- 2. 聚合结果视图：计算确定性主键 id = HASH(业务键)
--    （source_dws_crypto_assets_transfers 已输出聚合列，此处只补 id；列名与 DWS 表一致）
-- ==============================================
CREATE TEMPORARY VIEW v_dws_crypto_assets_transfers_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(account_id, ''), ': ', COALESCE(status, ''), ': ', COALESCE(sender_type, ''), ': ', COALESCE(recipient_type, ''), ': ', COALESCE(hidden, ''), ': ', DATE_FORMAT(create_date, 'yyyy-MM-dd'), ': ', COALESCE(currency, ''), ': ', COALESCE(action, '')))) AS BIGINT) AS id,
    *
FROM source_dws_crypto_assets_transfers;

-- ==============================================
-- 3. 分表 SINK（每个 _YYYY 一个，upsert 按 key 幂等）
-- ==============================================
CREATE TEMPORARY TABLE sink_dws_crypto_assets_transfers_2024 (
    id BIGINT, account_id STRING, status STRING, sender_type STRING, recipient_type STRING, transaction_count INT, origin_amount DECIMAL(18,2), settlement_amount DECIMAL(18,2), fee DECIMAL(18,2), fee2 DECIMAL(18,2), cross_chain_fee DECIMAL(18,2), hidden BOOLEAN, create_date TIMESTAMP(6), currency STRING, action STRING, version INT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_crypto_assets_transfers_2024','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_crypto_assets_transfers_2025 (
    id BIGINT, account_id STRING, status STRING, sender_type STRING, recipient_type STRING, transaction_count INT, origin_amount DECIMAL(18,2), settlement_amount DECIMAL(18,2), fee DECIMAL(18,2), fee2 DECIMAL(18,2), cross_chain_fee DECIMAL(18,2), hidden BOOLEAN, create_date TIMESTAMP(6), currency STRING, action STRING, version INT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_crypto_assets_transfers_2025','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_crypto_assets_transfers_2026 (
    id BIGINT, account_id STRING, status STRING, sender_type STRING, recipient_type STRING, transaction_count INT, origin_amount DECIMAL(18,2), settlement_amount DECIMAL(18,2), fee DECIMAL(18,2), fee2 DECIMAL(18,2), cross_chain_fee DECIMAL(18,2), hidden BOOLEAN, create_date TIMESTAMP(6), currency STRING, action STRING, version INT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_crypto_assets_transfers_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

-- ==============================================
-- 4. 写入（CROSS JOIN 确保删除函数先执行；upsert 覆盖同 key / 新增异 key）
-- ==============================================
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
