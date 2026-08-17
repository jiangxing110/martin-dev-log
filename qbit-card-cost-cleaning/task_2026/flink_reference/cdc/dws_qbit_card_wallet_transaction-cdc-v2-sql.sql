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
CREATE TEMPORARY TABLE source_delete_dws_qbit_card_wallet_transaction_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_dws_qbit_card_wallet_transaction_cdc(false) AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

-- ==============================================
-- 1. 源聚合（留在 PostgreSQL 内执行，复用原版聚合逻辑；只回传受影响 key 的聚合结果）
-- ==============================================
CREATE TEMPORARY TABLE source_dws_qbit_card_wallet_transaction (
    dws_qbit_card_wallet_transaction_row STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(WITH affected AS (
        SELECT DISTINCT tr."accountId" AS k0, tr."businessType" AS k1, CURRENT_DATE AS k2, tr."status" AS k3
        FROM "qbitCardWalletTransaction" AS tr
        WHERE FALSE
    )
    SELECT tr."accountId", tr."businessType", tr."status", COALESCE(SUM(tr."originAmount"), 0) AS origin_amount, COUNT(*) AS transaction_count, COALESCE(SUM(tr."fee"), 0) AS fee, TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS create_date, 1 AS version, NOW() AS create_time, NOW() AS update_time
    FROM "qbitCardWalletTransaction" AS tr s
    JOIN affected a ON (tr."accountId") IS NOT DISTINCT FROM a.k0 AND (tr."businessType") IS NOT DISTINCT FROM a.k1 AND (CURRENT_DATE) IS NOT DISTINCT FROM a.k2 AND (tr."status") IS NOT DISTINCT FROM a.k3
    WHERE tr."deleteTime" IS NULL
    GROUP BY tr."accountId", tr."businessType", create_date, tr."status") AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

-- ==============================================
-- 2. 聚合结果视图：计算确定性主键 id = HASH(业务键)
--    （source_dws_qbit_card_wallet_transaction 已输出聚合列，此处只补 id；列名与 DWS 表一致）
-- ==============================================
CREATE TEMPORARY VIEW v_dws_qbit_card_wallet_transaction_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(account_id, ''), ': ', COALESCE(business_type, ''), ': ', DATE_FORMAT(create_date, 'yyyy-MM-dd'), ': ', COALESCE(status, '')))) AS BIGINT) AS id,
    *
FROM source_dws_qbit_card_wallet_transaction;

-- ==============================================
-- 3. 分表 SINK（每个 _YYYY 一个，upsert 按 key 幂等）
-- ==============================================
CREATE TEMPORARY TABLE sink_dws_qbit_card_wallet_transaction_2024 (
    id BIGINT, account_id STRING, business_type STRING, status STRING, origin_amount DECIMAL(20,4), transaction_count BIGINT, fee DECIMAL(20,4), create_date DATE, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_qbit_card_wallet_transaction_2024','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_qbit_card_wallet_transaction_2025 (
    id BIGINT, account_id STRING, business_type STRING, status STRING, origin_amount DECIMAL(20,4), transaction_count BIGINT, fee DECIMAL(20,4), create_date DATE, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_qbit_card_wallet_transaction_2025','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_qbit_card_wallet_transaction_2026 (
    id BIGINT, account_id STRING, business_type STRING, status STRING, origin_amount DECIMAL(20,4), transaction_count BIGINT, fee DECIMAL(20,4), create_date DATE, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_qbit_card_wallet_transaction_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_qbit_card_wallet_transaction_2027 (
    id BIGINT, account_id STRING, business_type STRING, status STRING, origin_amount DECIMAL(20,4), transaction_count BIGINT, fee DECIMAL(20,4), create_date DATE, version BIGINT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_qbit_card_wallet_transaction_2027','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

-- ==============================================
-- 4. 写入（CROSS JOIN 确保删除函数先执行；upsert 覆盖同 key / 新增异 key）
-- ==============================================
INSERT INTO sink_dws_qbit_card_wallet_transaction_2024
SELECT id, account_id, business_type, status, origin_amount, transaction_count, fee, create_date, version, create_time, update_time
FROM v_dws_qbit_card_wallet_transaction_base
CROSS JOIN source_delete_dws_qbit_card_wallet_transaction_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2024-01-01' AND create_date < DATE '2025-01-01';
INSERT INTO sink_dws_qbit_card_wallet_transaction_2025
SELECT id, account_id, business_type, status, origin_amount, transaction_count, fee, create_date, version, create_time, update_time
FROM v_dws_qbit_card_wallet_transaction_base
CROSS JOIN source_delete_dws_qbit_card_wallet_transaction_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2025-01-01' AND create_date < DATE '2026-01-01';
INSERT INTO sink_dws_qbit_card_wallet_transaction_2026
SELECT id, account_id, business_type, status, origin_amount, transaction_count, fee, create_date, version, create_time, update_time
FROM v_dws_qbit_card_wallet_transaction_base
CROSS JOIN source_delete_dws_qbit_card_wallet_transaction_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2026-01-01' AND create_date < DATE '2027-01-01';
INSERT INTO sink_dws_qbit_card_wallet_transaction_2027
SELECT id, account_id, business_type, status, origin_amount, transaction_count, fee, create_date, version, create_time, update_time
FROM v_dws_qbit_card_wallet_transaction_base
CROSS JOIN source_delete_dws_qbit_card_wallet_transaction_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2027-01-01' AND create_date < DATE '2028-01-01';
