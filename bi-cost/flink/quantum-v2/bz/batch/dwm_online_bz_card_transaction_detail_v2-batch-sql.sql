--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-28
-- Description:    BZ v2 交易明细 DWM 批量初始化/回刷
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性初始化/按业务时间回刷
--   运行参数：start_time, end_time
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑或由 CDC 脚本同步。
-- Notes:
--   1. 主源: qbit_card_transaction (provider LIKE 'I2c%')
--   2. accountId 直接可用，关联 dim_account 获取账户维度
--   3. 销售关系通过 JDBC CTE 下推（direct 优先、root 兜底）
--   4. 不处理固定成本，固定成本由独立脚本回刷
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'taskmanager.memory.network.min' = '1536mb';
SET 'taskmanager.memory.network.max' = '1536mb';
SET 'taskmanager.memory.network.fraction' = '0.45';
SET 'taskmanager.network.sort-shuffle.min-buffers' = '64';
SET 'pipeline.default-parallelism' = '1';
SET 'table.exec.resource.default-parallelism' = '1';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'execution.batch-shuffle-mode' = 'ALL_EXCHANGES_BLOCKING';
SET 'execution.multi-jobs-in-application.enable' = 'false';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';
SET 'execution.application-management.enabled' = 'true';
SET 'heartbeat.interval' = '30 s';
SET 'heartbeat.timeout' = '600 s';
SET 'table.optimizer.union-any-expand' = 'false';

-- 交易主源：qbit_card_transaction，时间窗和 provider 过滤下推到 JDBC 子查询
CREATE TEMPORARY TABLE source_bz_transaction (
    id               STRING,
    account_id       STRING,
    card_id          STRING,
    transaction_time  TIMESTAMP(6),
    business_type     STRING,
    status            STRING,
    has_special_code  BOOLEAN,
    settle_amount     DECIMAL(20, 4),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT t."id"::text AS id, t."accountId"::text AS account_id, t."cardId"::text AS card_id, t."transactionTime" AS transaction_time, t."businessType" AS business_type, t.status, NOT ((t."specialSourceData"->>''code'')::JSONB @> ''[1001]'' OR (t."specialSourceData"->>''code'')::JSONB @> ''[1103]'' OR (t."specialSourceData"->>''code'')::JSONB @> ''[1105]'') AS has_special_code, COALESCE(CAST(t."settleAmount" AS NUMERIC(20,4)), CAST(0 AS NUMERIC(20,4))) AS settle_amount FROM "qbit_card_transaction" t WHERE t.provider LIKE ''I2c%'' AND t."deleteTime" IS NULL AND t."transactionTime" >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND t."transactionTime" < CAST(''${end_time}'' AS TIMESTAMP(6))) AS bz_txn_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000',
    'scan.auto-commit' = 'false'
);

-- 账户维度
CREATE TEMPORARY TABLE source_dim_account (
    id            STRING,
    account_type  STRING,
    `type`        STRING,
    system_type   STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id, account_type, "type", system_type FROM dim.dim_account) AS dim_account_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

-- 销售关系（JDBC CTE 下推：direct 优先、root 兜底）
CREATE TEMPORARY TABLE source_bz_transaction_sale_relation (
    tx_id   STRING,
    sale_id STRING,
    am_id   STRING,
    PRIMARY KEY (tx_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(WITH tx AS (SELECT t."id"::text AS tx_id, t."accountId"::text AS account_id, t."transactionTime" AS transaction_time FROM "qbit_card_transaction" t WHERE t.provider LIKE ''I2c%'' AND t."deleteTime" IS NULL AND t."transactionTime" >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND t."transactionTime" < CAST(''${end_time}'' AS TIMESTAMP(6))), direct_rel AS (SELECT DISTINCT ON (tx.tx_id) tx.tx_id, sr.sale_id, sr.am_id FROM tx INNER JOIN dim.dim_sale_account_relation_p sr ON sr.delete_time IS NULL AND sr.relation_account_id::text = tx.account_id AND tx.transaction_time >= sr.relation_start_time AND (tx.transaction_time < sr.relation_end_time OR sr.relation_end_time IS NULL) ORDER BY tx.tx_id, sr.relation_start_time DESC), root_rel AS (SELECT DISTINCT ON (tx.tx_id) tx.tx_id, sr.sale_id, sr.am_id FROM tx INNER JOIN public.api_account_relation aar ON aar.account_id::text = tx.account_id AND aar.delete_time IS NULL INNER JOIN dim.dim_sale_account_relation_p sr ON sr.delete_time IS NULL AND sr.relation_account_id::text = aar.root_id::text AND tx.transaction_time >= sr.relation_start_time AND (tx.transaction_time < sr.relation_end_time OR sr.relation_end_time IS NULL) ORDER BY tx.tx_id, sr.relation_start_time DESC) SELECT tx.tx_id, COALESCE(direct_rel.sale_id, root_rel.sale_id)::text AS sale_id, COALESCE(direct_rel.am_id, root_rel.am_id)::text AS am_id FROM tx LEFT JOIN direct_rel ON direct_rel.tx_id = tx.tx_id LEFT JOIN root_rel ON root_rel.tx_id = tx.tx_id) AS bz_txn_sale_rel_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000',
    'scan.auto-commit' = 'false'
);

-- 交易基础视图
CREATE TEMPORARY VIEW v_bz_base AS
SELECT
    t.id,
    t.account_id,
    da.account_type,
    da.`type` AS account_category,
    da.system_type,
    t.card_id,
    t.transaction_time,
    t.business_type,
    t.status,
    COALESCE(t.settle_amount, CAST(0 AS DECIMAL(20, 4))) AS billing_amount,
    COALESCE(t.business_type = 'Consumption', FALSE) AS is_consumption,
    COALESCE(t.business_type = 'Reversal', FALSE) AS is_reversal,
    COALESCE(t.has_special_code, FALSE) AS has_special_code,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS source_update_time,
    CAST(NULL AS TIMESTAMP(6)) AS source_delete_time,
    1 AS version,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM source_bz_transaction t
LEFT JOIN source_dim_account da
    ON da.id = t.account_id;

-- 最终 DWM 明细
CREATE TEMPORARY VIEW v_dwm_bz_card_transaction_detail AS
SELECT
    b.id,
    b.account_id,
    b.account_type,
    b.account_category,
    b.system_type,
    b.card_id,
    b.transaction_time,
    b.business_type,
    b.status,
    b.billing_amount,
    b.is_consumption,
    b.is_reversal,
    b.has_special_code,
    b.source_update_time,
    b.source_delete_time,
    sr.sale_id,
    sr.am_id,
    b.version,
    b.create_time,
    b.update_time,
    b.delete_time
FROM v_bz_base b
LEFT JOIN source_bz_transaction_sale_relation sr
    ON sr.tx_id = b.id;

CREATE TEMPORARY TABLE sink_dwm_bz_card_transaction_detail_v2_p (
    id                  STRING,
    account_id          STRING,
    account_type        STRING,
    account_category    STRING,
    system_type         STRING,
    card_id             STRING,
    transaction_time    TIMESTAMP(6),
    business_type       STRING,
    status              STRING,
    billing_amount      DECIMAL(20, 4),
    is_consumption      BOOLEAN,
    is_reversal         BOOLEAN,
    has_special_code    BOOLEAN,
    source_update_time  TIMESTAMP(6),
    source_delete_time  TIMESTAMP(6),
    sale_id             STRING,
    am_id               STRING,
    version             INT,
    create_time         TIMESTAMP(6),
    update_time         TIMESTAMP(6),
    delete_time         TIMESTAMP(6),
    PRIMARY KEY (id, transaction_time) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dwm_bz_card_transaction_detail_v2_p',
    'targetSchema' = 'dwm',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dwm_bz_card_transaction_detail_v2_p
SELECT * FROM v_dwm_bz_card_transaction_detail
WHERE transaction_time >= CAST('${start_time}' AS TIMESTAMP(6))
  AND transaction_time < CAST('${end_time}' AS TIMESTAMP(6));