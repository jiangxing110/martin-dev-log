--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-12
-- Description:    BB v2 DWM 批量初始化/回刷
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性初始化/按业务时间回刷
--   运行参数：start_time, end_time
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑或由 CDC 脚本同步。
-- Notes:
--   1. 交易主源: public.quantum_card_transaction_extend。
--   2. 明细粒度: 交易 + BlueBanc 结算明细。
--   3. 不处理 cost_fixed_fee，固定成本由独立脚本回刷。
--********************************************************************--

SET 'parallelism.default' = '1';
-- 下面这些是作业内可控项；TaskManager 进程内存仍以平台侧配置为准。
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

-- 交易主源拆成两个时间窗分支，分别走窄范围过滤，再在 Flink 侧合并。
-- 这样比单个带 OR/UNION 的 JDBC 子查询更容易让数据库走索引。
CREATE TEMPORARY TABLE source_bb_quantum_card_transaction_extend_tx (
    id                       BIGINT,
    source_id                STRING,
    card_transaction_id      STRING,
    account_id               STRING,
    country                  STRING,
    `type`                   STRING,
    transaction_time         TIMESTAMP(6),
    original_completion_time TIMESTAMP(6),
    business_code_list       STRING,
    remarks                  STRING,
    card_id                  STRING,
    detail                   STRING,
    create_time              TIMESTAMP(6),
    update_time              TIMESTAMP(6),
    card_org                 STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT t.id, t.source_id, t.card_transaction_id::text AS card_transaction_id, t.account_id::text AS account_id, t.country, t.type AS "type", t.transaction_time, t.original_completion_time, CAST(t.business_code_list AS text) AS business_code_list, t.remarks, t.card_id::text AS card_id, t.detail, t.create_time, t.update_time, c."type" AS card_org FROM public.quantum_card_transaction_extend t INNER JOIN public."qbitCard" c ON t.card_id = c."id" WHERE t.channel_provision = ''BLUEBANC'' AND t.delete_time IS NULL AND t.type IN (''Consumption'', ''Credit'') AND c."type" IN (''Master'', ''VISA'') AND (t.detail IS NULL OR t.detail NOT LIKE ''AUTO CLASS CAR RENTAL%'') AND t.transaction_time >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND t.transaction_time < CAST(''${end_time}'' AS TIMESTAMP(6))) AS quantum_card_transaction_extend_tx_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_bb_quantum_card_transaction_extend_oc (
    id                       BIGINT,
    source_id                STRING,
    card_transaction_id      STRING,
    account_id               STRING,
    country                  STRING,
    `type`                   STRING,
    transaction_time         TIMESTAMP(6),
    original_completion_time TIMESTAMP(6),
    business_code_list       STRING,
    remarks                  STRING,
    card_id                  STRING,
    detail                   STRING,
    create_time              TIMESTAMP(6),
    update_time              TIMESTAMP(6),
    card_org                 STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT t.id, t.source_id, t.card_transaction_id::text AS card_transaction_id, t.account_id::text AS account_id, t.country, t.type AS "type", t.transaction_time, t.original_completion_time, CAST(t.business_code_list AS text) AS business_code_list, t.remarks, t.card_id::text AS card_id, t.detail, t.create_time, t.update_time, c."type" AS card_org FROM public.quantum_card_transaction_extend t INNER JOIN public."qbitCard" c ON t.card_id = c."id" WHERE t.channel_provision = ''BLUEBANC'' AND t.delete_time IS NULL AND t.type IN (''Consumption'', ''Credit'') AND c."type" IN (''Master'', ''VISA'') AND (t.detail IS NULL OR t.detail NOT LIKE ''AUTO CLASS CAR RENTAL%'') AND t.original_completion_time >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND t.original_completion_time < CAST(''${end_time}'' AS TIMESTAMP(6))) AS quantum_card_transaction_extend_oc_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_bb_quantum_card_transaction_extend_post (
    id                       BIGINT,
    source_id                STRING,
    card_transaction_id      STRING,
    account_id               STRING,
    country                  STRING,
    `type`                   STRING,
    transaction_time         TIMESTAMP(6),
    original_completion_time TIMESTAMP(6),
    business_code_list       STRING,
    remarks                  STRING,
    card_id                  STRING,
    detail                   STRING,
    create_time              TIMESTAMP(6),
    update_time              TIMESTAMP(6),
    card_org                 STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT t.id, t.source_id, t.card_transaction_id::text AS card_transaction_id, t.account_id::text AS account_id, t.country, t.type AS "type", t.transaction_time, t.original_completion_time, CAST(t.business_code_list AS text) AS business_code_list, t.remarks, t.card_id::text AS card_id, t.detail, t.create_time, t.update_time, c."type" AS card_org FROM public.quantum_card_transaction_extend t INNER JOIN public."qbitCard" c ON t.card_id = c."id" WHERE t.channel_provision = ''BLUEBANC'' AND t.delete_time IS NULL AND t.type IN (''Consumption'', ''Credit'') AND c."type" IN (''Master'', ''VISA'') AND (t.detail IS NULL OR t.detail NOT LIKE ''AUTO CLASS CAR RENTAL%'') AND EXISTS (SELECT 1 FROM ods.ods_qbit_card_settlement s WHERE s.delete_time IS NULL AND s.provider = ''BlueBancCard'' AND s.transaction_type = ''refund.clearing'' AND CAST(s.raw_data::json->>''postDate'' AS timestamp) >= CAST(''${start_time}'' AS TIMESTAMP(6)) - INTERVAL ''1'' MONTH AND CAST(s.raw_data::json->>''postDate'' AS timestamp) < CAST(''${end_time}'' AS TIMESTAMP(6)) + INTERVAL ''1'' MONTH AND t.card_transaction_id::text = s.qbit_card_transaction_id)) AS quantum_card_transaction_extend_post_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000',
    'scan.auto-commit' = 'false'
);

-- 结算源拆成两个等值命中路径，避免 EXISTS + OR 触发大范围回扫。
CREATE TEMPORARY TABLE source_qbit_card_settlement_tx (
    id                      STRING,
    transaction_id          STRING,
    qbit_card_transaction_id STRING,
    transaction_type        STRING,
    billing_amount          DOUBLE,
    raw_data                STRING,
    create_time             TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT s.id, s.transaction_id, s.qbit_card_transaction_id, s.transaction_type, s.billing_amount, s.raw_data, s.create_time FROM ods.ods_qbit_card_settlement s WHERE s.delete_time IS NULL AND s.provider = ''BlueBancCard'' AND EXISTS (SELECT 1 FROM public.quantum_card_transaction_extend t INNER JOIN public."qbitCard" c ON t.card_id = c."id" WHERE t.channel_provision = ''BLUEBANC'' AND t.delete_time IS NULL AND t.type IN (''Consumption'', ''Credit'') AND c."type" IN (''Master'', ''VISA'') AND (t.detail IS NULL OR t.detail NOT LIKE ''AUTO CLASS CAR RENTAL%'') AND t.transaction_time >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND t.transaction_time < CAST(''${end_time}'' AS TIMESTAMP(6)) AND t.source_id = s.transaction_id)) AS ods_qbit_card_settlement_tx_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_qbit_card_settlement_oc (
    id                      STRING,
    transaction_id          STRING,
    qbit_card_transaction_id STRING,
    transaction_type        STRING,
    billing_amount          DOUBLE,
    raw_data                STRING,
    create_time             TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT s.id, s.transaction_id, s.qbit_card_transaction_id, s.transaction_type, s.billing_amount, s.raw_data, s.create_time FROM ods.ods_qbit_card_settlement s WHERE s.delete_time IS NULL AND s.provider = ''BlueBancCard'' AND EXISTS (SELECT 1 FROM public.quantum_card_transaction_extend t INNER JOIN public."qbitCard" c ON t.card_id = c."id" WHERE t.channel_provision = ''BLUEBANC'' AND t.delete_time IS NULL AND t.type IN (''Consumption'', ''Credit'') AND c."type" IN (''Master'', ''VISA'') AND (t.detail IS NULL OR t.detail NOT LIKE ''AUTO CLASS CAR RENTAL%'') AND ((t.transaction_time >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND t.transaction_time < CAST(''${end_time}'' AS TIMESTAMP(6))) OR (t.original_completion_time >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND t.original_completion_time < CAST(''${end_time}'' AS TIMESTAMP(6)))) AND t.card_transaction_id::text = s.qbit_card_transaction_id)) AS ods_qbit_card_settlement_oc_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_qbit_card_settlement_post (
    id                      STRING,
    transaction_id          STRING,
    qbit_card_transaction_id STRING,
    transaction_type        STRING,
    billing_amount          DOUBLE,
    raw_data                STRING,
    create_time             TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT s.id, s.transaction_id, s.qbit_card_transaction_id, s.transaction_type, s.billing_amount, s.raw_data, s.create_time FROM ods.ods_qbit_card_settlement s WHERE s.delete_time IS NULL AND s.provider = ''BlueBancCard'' AND s.transaction_type = ''refund.clearing'' AND CAST(s.raw_data::json->>''postDate'' AS timestamp) >= CAST(''${start_time}'' AS TIMESTAMP(6)) - INTERVAL ''1'' MONTH AND CAST(s.raw_data::json->>''postDate'' AS timestamp) < CAST(''${end_time}'' AS TIMESTAMP(6)) + INTERVAL ''1'' MONTH AND EXISTS (SELECT 1 FROM public.quantum_card_transaction_extend t INNER JOIN public."qbitCard" c ON t.card_id = c."id" WHERE t.channel_provision = ''BLUEBANC'' AND t.delete_time IS NULL AND t.type IN (''Consumption'', ''Credit'') AND c."type" IN (''Master'', ''VISA'') AND (t.detail IS NULL OR t.detail NOT LIKE ''AUTO CLASS CAR RENTAL%'') AND t.card_transaction_id::text = s.qbit_card_transaction_id)) AS ods_qbit_card_settlement_post_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000',
    'scan.auto-commit' = 'false'
);

-- Refund 专用直接关联源：按原始月度 SQL 的 qbit_card_transaction_id 直接关联交易。
-- 该分支用于避免拆分读取 transaction/settlement 后在 Flink 二次关联时漏掉 Refund。
CREATE TEMPORARY TABLE source_qbit_card_settlement_refund_direct (
    id                       STRING,
    transaction_id           STRING,
    qbit_card_transaction_id STRING,
    transaction_type        STRING,
    billing_amount           DOUBLE,
    raw_data                 STRING,
    create_time              TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT DISTINCT s.id, s.transaction_id, s.qbit_card_transaction_id, s.transaction_type, s.billing_amount, s.raw_data, s.create_time FROM ods.ods_qbit_card_settlement s INNER JOIN public.quantum_card_transaction_extend t ON t.card_transaction_id::text = s.qbit_card_transaction_id INNER JOIN public."qbitCard" c ON c."id" = t.card_id WHERE t.channel_provision = ''BLUEBANC'' AND t.delete_time IS NULL AND t.type = ''Credit'' AND c."type" IN (''Master'', ''VISA'') AND (t.detail IS NULL OR t.detail NOT LIKE ''AUTO CLASS CAR RENTAL%'') AND s.delete_time IS NULL AND s.provider = ''BlueBancCard'' AND s.transaction_type = ''refund.clearing'' AND s.raw_data::json->>''responseCode'' = ''APPROVE'' AND CAST(s.raw_data::json->>''postDate'' AS timestamp) >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND CAST(s.raw_data::json->>''postDate'' AS timestamp) < CAST(''${end_time}'' AS TIMESTAMP(6))) AS ods_qbit_card_settlement_refund_direct_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000',
    'scan.auto-commit' = 'false'
);

-- Refund 交易专用直接关联源，确保 postDate 命中的 Credit 交易进入 v_bb_tx。
CREATE TEMPORARY TABLE source_bb_quantum_card_transaction_refund_direct (
    id                       BIGINT,
    source_id                STRING,
    card_transaction_id      STRING,
    account_id               STRING,
    country                  STRING,
    `type`                   STRING,
    transaction_time         TIMESTAMP(6),
    original_completion_time TIMESTAMP(6),
    business_code_list       STRING,
    remarks                  STRING,
    card_id                  STRING,
    detail                   STRING,
    create_time              TIMESTAMP(6),
    update_time              TIMESTAMP(6),
    card_org                 STRING,
    PRIMARY KEY (id, card_transaction_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT DISTINCT t.id, t.source_id, t.card_transaction_id::text AS card_transaction_id, t.account_id::text AS account_id, t.country, t.type AS "type", t.transaction_time, t.original_completion_time, CAST(t.business_code_list AS text) AS business_code_list, t.remarks, t.card_id::text AS card_id, t.detail, t.create_time, t.update_time, c."type" AS card_org FROM public.quantum_card_transaction_extend t INNER JOIN public."qbitCard" c ON c."id" = t.card_id INNER JOIN ods.ods_qbit_card_settlement s ON t.card_transaction_id::text = s.qbit_card_transaction_id WHERE t.channel_provision = ''BLUEBANC'' AND t.delete_time IS NULL AND t.type = ''Credit'' AND c."type" IN (''Master'', ''VISA'') AND (t.detail IS NULL OR t.detail NOT LIKE ''AUTO CLASS CAR RENTAL%'') AND s.delete_time IS NULL AND s.provider = ''BlueBancCard'' AND s.transaction_type = ''refund.clearing'' AND s.raw_data::json->>''responseCode'' = ''APPROVE'' AND CAST(s.raw_data::json->>''postDate'' AS timestamp) >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND CAST(s.raw_data::json->>''postDate'' AS timestamp) < CAST(''${end_time}'' AS TIMESTAMP(6))) AS quantum_card_transaction_refund_direct_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000',
    'scan.auto-commit' = 'false'
);

-- 账户维度：只取 DWM 需要落表的账户分类字段。
CREATE TEMPORARY TABLE source_dim_account (
    id                STRING,
    account_type      STRING,
    `type`            STRING,
    system_type       STRING,
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

-- 销售关系映射前置到 JDBC 子查询中，参考 QI 的做法先在数据库侧完成候选收敛。
CREATE TEMPORARY TABLE source_bb_sale_relation (
    tx_id   STRING,
    sale_id STRING,
    am_id   STRING,
    PRIMARY KEY (tx_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(WITH tx AS (SELECT t.id::text AS tx_id, t.account_id::text AS account_id, COALESCE(t.transaction_time, t.original_completion_time) AS transaction_time FROM public.quantum_card_transaction_extend t WHERE t.channel_provision = ''BLUEBANC'' AND t.delete_time IS NULL AND (((t.transaction_time >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND t.transaction_time < CAST(''${end_time}'' AS TIMESTAMP(6))) OR (t.original_completion_time >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND t.original_completion_time < CAST(''${end_time}'' AS TIMESTAMP(6)))) OR EXISTS (SELECT 1 FROM ods.ods_qbit_card_settlement s WHERE s.delete_time IS NULL AND s.provider = ''BlueBancCard'' AND s.transaction_type = ''refund.clearing'' AND CAST(s.raw_data::json->>''postDate'' AS timestamp) >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND CAST(s.raw_data::json->>''postDate'' AS timestamp) < CAST(''${end_time}'' AS TIMESTAMP(6)) AND t.card_transaction_id::text = s.qbit_card_transaction_id))), direct_rel AS (SELECT DISTINCT ON (tx.tx_id) tx.tx_id, sr.sale_id::text AS sale_id, sr.am_id::text AS am_id FROM tx INNER JOIN dim.dim_sale_account_relation_p sr ON sr.delete_time IS NULL AND sr.relation_account_id::text = tx.account_id AND sr.relation_start_time < CAST(''${end_time}'' AS TIMESTAMP(6)) AND (sr.relation_end_time >= CAST(''${start_time}'' AS TIMESTAMP(6)) OR sr.relation_end_time IS NULL) AND tx.transaction_time >= sr.relation_start_time AND (tx.transaction_time < sr.relation_end_time OR sr.relation_end_time IS NULL) ORDER BY tx.tx_id, sr.relation_start_time DESC), root_rel AS (SELECT DISTINCT ON (tx.tx_id) tx.tx_id, sr.sale_id::text AS sale_id, sr.am_id::text AS am_id FROM tx INNER JOIN ods.ods_api_account_relation aar ON aar.delete_time IS NULL AND aar.account_id::text = tx.account_id INNER JOIN dim.dim_sale_account_relation_p sr ON sr.delete_time IS NULL AND sr.relation_account_id::text = aar.root_id::text AND sr.relation_start_time < CAST(''${end_time}'' AS TIMESTAMP(6)) AND (sr.relation_end_time >= CAST(''${start_time}'' AS TIMESTAMP(6)) OR sr.relation_end_time IS NULL) AND tx.transaction_time >= sr.relation_start_time AND (tx.transaction_time < sr.relation_end_time OR sr.relation_end_time IS NULL) ORDER BY tx.tx_id, sr.relation_start_time DESC) SELECT tx.tx_id, COALESCE(direct_rel.sale_id, root_rel.sale_id) AS sale_id, COALESCE(direct_rel.am_id, root_rel.am_id) AS am_id FROM tx LEFT JOIN direct_rel ON direct_rel.tx_id = tx.tx_id LEFT JOIN root_rel ON root_rel.tx_id = tx.tx_id) AS bb_sale_relation_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000',
    'scan.auto-commit' = 'false'
);

-- BB 交易口径入口。
-- 大表过滤已经下推到 JDBC 子查询里，这里只保留轻量投影，避免 Flink 再生成宽表扫描条件。
CREATE TEMPORARY VIEW v_bb_tx AS
SELECT
    *
FROM source_bb_quantum_card_transaction_extend_tx
UNION
SELECT
    *
FROM source_bb_quantum_card_transaction_extend_oc
UNION
SELECT
    *
FROM source_bb_quantum_card_transaction_extend_post
UNION
SELECT
    *
FROM source_bb_quantum_card_transaction_refund_direct;

CREATE TEMPORARY VIEW v_qbit_card_settlement_refund_direct AS
SELECT * FROM source_qbit_card_settlement_refund_direct;

CREATE TEMPORARY VIEW v_qbit_card_settlement AS
SELECT
    *
FROM source_qbit_card_settlement_tx
UNION
SELECT
    *
FROM source_qbit_card_settlement_oc
UNION
SELECT
    *
FROM source_qbit_card_settlement_post
UNION
SELECT
    *
FROM v_qbit_card_settlement_refund_direct;

-- 结算匹配拆成两条等值路径再合并，避免 OR join 触发低效计划。
-- 同一笔交易可能同时命中两个键，使用 UNION 去重，保持最终明细不重复。
CREATE TEMPORARY VIEW v_matched_settle AS
SELECT
    t.id AS txn_id,
    s.id,
    s.transaction_id,
    s.qbit_card_transaction_id,
    s.transaction_type,
    s.billing_amount,
    s.raw_data,
    s.create_time,
    'source_id' AS settlement_match_type
FROM v_bb_tx t
INNER JOIN v_qbit_card_settlement s
    ON t.source_id = s.transaction_id
UNION
SELECT
    t.id AS txn_id,
    s.id,
    s.transaction_id,
    s.qbit_card_transaction_id,
    s.transaction_type,
    s.billing_amount,
    s.raw_data,
    s.create_time,
    'card_transaction_id' AS settlement_match_type
FROM v_bb_tx t
INNER JOIN v_qbit_card_settlement s
    ON t.card_transaction_id = s.qbit_card_transaction_id;

-- 交易基础明细层：把交易、结算、账户维度合并成 DWM 主体字段。
-- 成本指标不在这里计算，这里只沉淀可复用明细和判断标识。
CREATE TEMPORARY VIEW v_bb_base_normal AS
SELECT
    t.id AS txn_id,
    s.id AS settlement_id,
    s.settlement_match_type,
    t.source_id,
    t.card_transaction_id,
    t.account_id,
    da.account_type,
    da.`type` AS account_category,
    da.system_type,
    t.card_id,
    COALESCE(t.transaction_time, t.original_completion_time) AS transaction_time,
    t.original_completion_time,
    t.`type` AS business_type,
    t.business_code_list,
    t.remarks,
    t.detail,
    t.card_org,
    t.country AS tx_country,
    RIGHT(JSON_VALUE(s.raw_data, '$.txnLocation'), 2) AS settle_country,
    COALESCE(COALESCE(RIGHT(JSON_VALUE(s.raw_data, '$.txnLocation'), 2), t.country) IN ('US', 'USA'), FALSE) AS is_dom,
    JSON_VALUE(s.raw_data, '$.responseCode') AS resp_code,
    JSON_VALUE(s.raw_data, '$.reasonCode') AS reason_code,
    s.transaction_type AS transaction_type,
    COALESCE(s.transaction_type NOT IN ('ST-REFUND_ADV', 'ST-PURCHASE_ADV', 'ST-ECOMM_ADV', 'ST-SETT_ADV', 'ST-ATM_ADV'), FALSE) AS is_valid_settle,
    COALESCE(s.transaction_type = 'authorization.clearing', FALSE) AS is_clearing,
    COALESCE(s.transaction_type = 'authorization.reversal', FALSE) AS is_reversal,
    COALESCE(s.transaction_type = 'refund.clearing', FALSE) AS is_refund,
    CAST(COALESCE(s.billing_amount, CAST(0 AS DOUBLE)) AS DECIMAL(20, 4)) AS billing_amount,
    CAST(REPLACE(REPLACE(JSON_VALUE(s.raw_data, '$.postDate'), 'T', ' '), 'Z', '') AS TIMESTAMP(6)) AS settlement_post_date,
    CAST(REPLACE(REPLACE(JSON_VALUE(s.raw_data, '$.txnDate'), 'T', ' '), 'Z', '') AS TIMESTAMP(6)) AS settlement_txn_date,
    1 AS version,
    COALESCE(t.create_time, CURRENT_TIMESTAMP) AS create_time,
    COALESCE(t.update_time, t.create_time, CURRENT_TIMESTAMP) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_bb_tx t
LEFT JOIN v_matched_settle s
    ON s.txn_id = t.id
LEFT JOIN source_dim_account da
    ON da.id = t.account_id;

-- 直接关联的 Refund base：不依赖 v_matched_settle，确保 settlement 字段完整落入 DWM。
CREATE TEMPORARY VIEW v_bb_refund_direct_base AS
SELECT
    t.id AS txn_id,
    s.id AS settlement_id,
    'card_transaction_id' AS settlement_match_type,
    t.source_id,
    t.card_transaction_id,
    t.account_id,
    da.account_type,
    da.`type` AS account_category,
    da.system_type,
    t.card_id,
    COALESCE(t.transaction_time, t.original_completion_time) AS transaction_time,
    t.original_completion_time,
    t.`type` AS business_type,
    t.business_code_list,
    t.remarks,
    t.detail,
    t.card_org,
    t.country AS tx_country,
    RIGHT(JSON_VALUE(s.raw_data, '$.txnLocation'), 2) AS settle_country,
    COALESCE(COALESCE(RIGHT(JSON_VALUE(s.raw_data, '$.txnLocation'), 2), t.country) IN ('US', 'USA'), FALSE) AS is_dom,
    JSON_VALUE(s.raw_data, '$.responseCode') AS resp_code,
    JSON_VALUE(s.raw_data, '$.reasonCode') AS reason_code,
    s.transaction_type AS transaction_type,
    TRUE AS is_valid_settle,
    FALSE AS is_clearing,
    FALSE AS is_reversal,
    TRUE AS is_refund,
    CAST(COALESCE(s.billing_amount, CAST(0 AS DOUBLE)) AS DECIMAL(20, 4)) AS billing_amount,
    CAST(REPLACE(REPLACE(JSON_VALUE(s.raw_data, '$.postDate'), 'T', ' '), 'Z', '') AS TIMESTAMP(6)) AS settlement_post_date,
    CAST(REPLACE(REPLACE(JSON_VALUE(s.raw_data, '$.txnDate'), 'T', ' '), 'Z', '') AS TIMESTAMP(6)) AS settlement_txn_date,
    1 AS version,
    COALESCE(t.create_time, CURRENT_TIMESTAMP) AS create_time,
    COALESCE(t.update_time, t.create_time, CURRENT_TIMESTAMP) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM source_bb_quantum_card_transaction_refund_direct t
INNER JOIN source_qbit_card_settlement_refund_direct s
    ON t.card_transaction_id = s.qbit_card_transaction_id
LEFT JOIN source_dim_account da
    ON da.id = t.account_id;

CREATE TEMPORARY VIEW v_bb_base AS
SELECT * FROM v_bb_base_normal
UNION ALL
SELECT * FROM v_bb_refund_direct_base;

-- 最终 DWM 明细：销售关系按 direct 优先、root 兜底后的唯一结果写入 upsert sink。
CREATE TEMPORARY VIEW v_dwm_bb_card_transaction_detail_v2 AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(CAST(b.txn_id AS STRING), ':', COALESCE(b.settlement_id, 'NO_SETTLEMENT')))) AS STRING) AS id,
    b.txn_id,
    b.settlement_id,
    b.settlement_match_type,
    b.source_id,
    b.card_transaction_id,
    b.account_id,
    b.account_type,
    b.account_category,
    b.system_type,
    b.card_id,
    b.transaction_time,
    b.original_completion_time,
    b.business_type,
    b.business_code_list,
    b.remarks,
    b.detail,
    b.card_org,
    b.tx_country,
    b.settle_country,
    b.is_dom,
    b.resp_code,
    b.reason_code,
    b.transaction_type,
    b.is_valid_settle,
    b.is_clearing,
    b.is_reversal,
    b.is_refund,
    b.billing_amount,
    b.settlement_post_date,
    b.settlement_txn_date,
    s.sale_id,
    s.am_id,
    b.version,
    CAST(b.create_time AS TIMESTAMP(6)) AS create_time,
    CAST(b.update_time AS TIMESTAMP(6)) AS update_time,
    b.delete_time
FROM v_bb_base b
LEFT JOIN source_bb_sale_relation s
    ON s.tx_id = b.txn_id;

CREATE TEMPORARY TABLE sink_dwm_bb_card_transaction_detail_v2_p (
    id                       STRING,
    txn_id                   BIGINT,
    settlement_id            STRING,
    settlement_match_type    STRING,
    source_id                STRING,
    card_transaction_id      STRING,
    account_id               STRING,
    account_type             STRING,
    account_category         STRING,
    system_type              STRING,
    card_id                  STRING,
    transaction_time         TIMESTAMP(6),
    original_completion_time TIMESTAMP(6),
    business_type            STRING,
    business_code_list       STRING,
    remarks                  STRING,
    detail                   STRING,
    card_org                 STRING,
    tx_country               STRING,
    settle_country           STRING,
    is_dom                   BOOLEAN,
    resp_code                STRING,
    reason_code              STRING,
    transaction_type         STRING,
    is_valid_settle          BOOLEAN,
    is_clearing              BOOLEAN,
    is_reversal              BOOLEAN,
    is_refund                BOOLEAN,
    billing_amount           DECIMAL(20, 4),
    settlement_post_date     TIMESTAMP(6),
    settlement_txn_date      TIMESTAMP(6),
    sale_id                  STRING,
    am_id                    STRING,
    version                  INT,
    create_time              TIMESTAMP(6),
    update_time              TIMESTAMP(6),
    delete_time              TIMESTAMP(6),
    PRIMARY KEY (id, transaction_time) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dwm_bb_card_transaction_detail_v2_p',
    'targetSchema' = 'dwm',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dwm_bb_card_transaction_detail_v2_p
SELECT * FROM v_dwm_bb_card_transaction_detail_v2;
