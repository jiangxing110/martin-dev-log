--********************************************************************
-- Author:         martinJiang
-- Created Time:   2026-08-18
-- Updated Time:   2026-08-18
-- Description:    dws_transfer 流处理(CDC) 作业（quantum-v2 范式：确定性哈希主键 + 先清后写）
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
CREATE TEMPORARY TABLE source_delete_dws_transfer_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_dws_transfer_cdc(false) AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

-- ==============================================
-- 1. 源聚合（留在 PostgreSQL 内执行，复用原版聚合逻辑；只回传受影响 key 的聚合结果）
-- ==============================================
CREATE TEMPORARY TABLE source_dws_transfer (
    account_id STRING,
    business_type_detail STRING,
    business_type_code STRING,
    settlement_currency STRING,
    status STRING,
    usd_amount DECIMAL(20,4),
    transaction_count BIGINT,
    fee DECIMAL(20,4),
    currency STRING,
    create_date DATE,
    version BIGINT,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(WITH affected AS (
        SELECT DISTINCT tr."accountId" AS k0, tr."businessTypeDetail" AS k1, tr."businessCode" AS k2, tr."settlementCurrency" AS k3, DATE(tr."createTime") AS k4, tr."status" AS k5, "currency" AS k6
        FROM "transfer" AS tr
        WHERE (tr."createTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."createTime" < CURRENT_DATE)
    )
    SELECT tr."accountId" AS "account_id", tr."businessTypeDetail" AS "business_type_detail", tr."businessCode" AS "business_type_code", tr."settlementCurrency" AS "settlement_currency", tr."status" AS "status", COALESCE(SUM(tr."usdAmount"), 0) AS usd_amount, COUNT(*) AS transaction_count, COALESCE(SUM("fee" * "usdRate"), 0) AS fee, "currency" AS "currency", TO_CHAR(tr."createTime", ''YYYY-MM-DD'')::DATE AS create_date, 1 AS version, NOW() AS create_time, NOW() AS update_time
    FROM "transfer" AS tr
    JOIN affected a ON (tr."accountId") IS NOT DISTINCT FROM a.k0 AND (tr."businessTypeDetail") IS NOT DISTINCT FROM a.k1 AND (tr."businessCode") IS NOT DISTINCT FROM a.k2 AND (tr."settlementCurrency") IS NOT DISTINCT FROM a.k3 AND (DATE(tr."createTime")) IS NOT DISTINCT FROM a.k4 AND (tr."status") IS NOT DISTINCT FROM a.k5 AND ("currency") IS NOT DISTINCT FROM a.k6
    WHERE tr."deleteTime" IS NULL
    GROUP BY tr."accountId", tr."businessTypeDetail",tr."businessCode", tr."settlementCurrency", create_date, status, "currency") AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

-- ==============================================
-- 2. 聚合结果视图：计算确定性主键 id = HASH(业务键)
--    （source_dws_transfer 已输出聚合列，此处只补 id；列名与 DWS 表一致）
-- ==============================================
CREATE TEMPORARY VIEW v_dws_transfer_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(account_id, ''), ': ', COALESCE(business_type_detail, ''), ': ', COALESCE(business_type_code, ''), ': ', COALESCE(settlement_currency, ''), ': ', DATE_FORMAT(create_date, 'yyyy-MM-dd'), ': ', COALESCE(status, ''), ': ', COALESCE(currency, '')))) AS BIGINT) AS id,
    *
FROM source_dws_transfer;

-- ==============================================
-- 3. 分表 SINK（每个 _YYYY 一个，upsert 按 key 幂等）
-- ==============================================
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

-- ==============================================
-- 4. 写入（CROSS JOIN 确保删除函数先执行；upsert 覆盖同 key / 新增异 key）
-- ==============================================
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
