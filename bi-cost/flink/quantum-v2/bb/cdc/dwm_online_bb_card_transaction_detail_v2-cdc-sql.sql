--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-12
-- Description:    BB v2 DWM CDC 增量同步
-- 作业元信息：
--   作业类型：流处理 CDC
--   运行方式：全量初始化 + 增量实时同步
--   运行参数：无
--   源库变更响应：quantum_card_transaction_extend / qbitCardSettlement 变化驱动 DWM 写入。
-- Notes:
--   1. 主业务 CDC 不扫描 ods_bi_month_tag.update_time。
--   2. cost_fixed_fee 由固定成本独立脚本回刷。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'pipeline.default-parallelism' = '1';
SET 'table.exec.resource.default-parallelism' = '1';
SET 'table.optimizer.reuse-source-enabled' = 'false';
SET 'table.optimizer.reuse-sub-plan-enabled' = 'false';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';
SET 'execution.checkpointing.interval' = '10s';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'pipeline.operator-chaining' = 'false';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'execution.checkpointing.timeout' = '30min';

CREATE TEMPORARY TABLE source_quantum_card_transaction_extend (
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
    channel_provision        STRING,
    create_time              TIMESTAMP(6),
    update_time              TIMESTAMP(6),
    delete_time              TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = '${secret_values.PG_TEST_HOST}',
    'port' = '${secret_values.PG_TEST_PORT1}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'database-name' = '${secret_values.PG_TEST_DATABASE}',
    'schema-name' = 'public',
    'table-name' = 'quantum_card_transaction_extend',
    'slot.name' = 'flink_slot_bb_v2_tx_extend_dwm',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.slot.drop.on.stop' = 'true',
    'debezium.decimal.handling.mode' = 'string',
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'false'
);

CREATE TEMPORARY TABLE source_qbit_card_settlement (
    id                      STRING,
    `transactionId`         STRING,
    `qbitCardTransactionId` STRING,
    provider                STRING,
    `transactionType`       STRING,
    `billingAmount`         DOUBLE,
    `rawData`               STRING,
    `createTime`            TIMESTAMP(6),
    `deleteTime`            TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = '${secret_values.PG_TEST_HOST}',
    'port' = '${secret_values.PG_TEST_PORT1}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'database-name' = '${secret_values.PG_TEST_DATABASE}',
    'schema-name' = 'public',
    'table-name' = 'qbitCardSettlement',
    'slot.name' = 'flink_slot_bb_v2_settlement_dwm',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.slot.drop.on.stop' = 'true',
    'debezium.decimal.handling.mode' = 'string',
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'false'
);

CREATE TEMPORARY TABLE source_qbit_card (
    id          STRING,
    token       STRING,
    `accountId` STRING,
    `type`      STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'qbitCard',
    'targetSchema' = 'public',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY TABLE source_dim_account (
    id                STRING,
    account_type      STRING,
    `type`            STRING,
    system_type       STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dim_account',
    'targetSchema' = 'dim',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY TABLE source_api_account_relation (
    account_id  STRING,
    root_id     STRING,
    delete_time TIMESTAMP(6),
    PRIMARY KEY (account_id) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'api_account_relation',
    'targetSchema' = 'public',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY TABLE source_dim_sale_account_relation_p (
    id                    STRING,
    relation_account_id   STRING,
    sale_id               STRING,
    am_id                 STRING,
    operation_manager_id  STRING,
    relation_start_time   TIMESTAMP(6),
    relation_end_time     TIMESTAMP(6),
    delete_time           TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dim_sale_account_relation_p',
    'targetSchema' = 'dim',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY VIEW v_bb_tx AS
SELECT
    t.*,
    c.`type` AS card_org
FROM source_quantum_card_transaction_extend t
INNER JOIN source_qbit_card c
    ON c.id = t.card_id
WHERE t.channel_provision = 'BLUEBANC'
  AND t.delete_time IS NULL
  AND t.`type` IN ('Consumption', 'Credit')
  AND c.`type` IN ('Master', 'VISA')
  AND (
        t.detail IS NULL
        OR t.detail NOT LIKE 'AUTO CLASS CAR RENTAL%'
  );

CREATE TEMPORARY VIEW v_matched_settle AS
SELECT t.id AS txn_id, s.*
FROM v_bb_tx t
INNER JOIN source_qbit_card_settlement s
    ON t.source_id = s.`transactionId`
   AND s.provider = 'BlueBancCard'
   AND s.`deleteTime` IS NULL
UNION ALL
SELECT t.id AS txn_id, s.*
FROM v_bb_tx t
INNER JOIN source_qbit_card_settlement s
    ON t.card_transaction_id = s.`qbitCardTransactionId`
   AND s.provider = 'BlueBancCard'
   AND s.`deleteTime` IS NULL;

CREATE TEMPORARY VIEW v_bb_base AS
SELECT
    t.id AS txn_id,
    s.id AS settlement_id,
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
    JSON_VALUE(s.`rawData`, '$.txnLocation') AS settle_country,
    COALESCE(JSON_VALUE(s.`rawData`, '$.txnLocation'), t.country) IN ('US', 'USA') AS is_dom,
    JSON_VALUE(s.`rawData`, '$.responseCode') AS resp_code,
    JSON_VALUE(s.`rawData`, '$.reasonCode') AS reason_code,
    s.`transactionType` AS transaction_type,
    s.`transactionType` NOT IN ('ST-REFUND_ADV', 'ST-PURCHASE_ADV', 'ST-ECOMM_ADV', 'ST-SETT_ADV', 'ST-ATM_ADV') AS is_valid_settle,
    s.`transactionType` = 'authorization.clearing' AS is_clearing,
    s.`transactionType` = 'authorization.reversal' AS is_reversal,
    s.`transactionType` = 'refund.clearing' AS is_refund,
    CAST(COALESCE(s.`billingAmount`, CAST(0 AS DOUBLE)) AS DECIMAL(20, 4)) AS billing_amount,
    CAST(JSON_VALUE(s.`rawData`, '$.postDate') AS TIMESTAMP(6)) AS settlement_post_date,
    CAST(JSON_VALUE(s.`rawData`, '$.txnDate') AS TIMESTAMP(6)) AS settlement_txn_date,
    1 AS version,
    COALESCE(t.create_time, CURRENT_TIMESTAMP) AS create_time,
    COALESCE(t.update_time, t.create_time, CURRENT_TIMESTAMP) AS update_time,
    t.delete_time
FROM v_bb_tx t
LEFT JOIN v_matched_settle s
    ON s.txn_id = t.id
LEFT JOIN source_dim_account da
    ON da.id = t.account_id
WHERE COALESCE(t.transaction_time, t.original_completion_time) IS NOT NULL;

CREATE TEMPORARY VIEW v_bb_direct_sale_relation AS
SELECT tx_id, sale_id, am_id
FROM (
    SELECT
        b.txn_id AS tx_id,
        sr.sale_id,
        sr.am_id,
        ROW_NUMBER() OVER (PARTITION BY b.txn_id ORDER BY sr.relation_start_time DESC) AS rn
    FROM v_bb_base b
    INNER JOIN source_dim_sale_account_relation_p sr
        ON sr.relation_account_id = b.account_id
       AND sr.delete_time IS NULL
       AND b.transaction_time >= sr.relation_start_time
       AND (b.transaction_time < sr.relation_end_time OR sr.relation_end_time IS NULL)
) ranked_direct
WHERE rn = 1;

CREATE TEMPORARY VIEW v_bb_root_sale_relation AS
SELECT tx_id, sale_id, am_id
FROM (
    SELECT
        b.txn_id AS tx_id,
        sr.sale_id,
        sr.am_id,
        ROW_NUMBER() OVER (PARTITION BY b.txn_id ORDER BY sr.relation_start_time DESC) AS rn
    FROM v_bb_base b
    INNER JOIN source_api_account_relation aar
        ON aar.account_id = b.account_id
       AND aar.delete_time IS NULL
    INNER JOIN source_dim_sale_account_relation_p sr
        ON sr.relation_account_id = aar.root_id
       AND sr.delete_time IS NULL
       AND b.transaction_time >= sr.relation_start_time
       AND (b.transaction_time < sr.relation_end_time OR sr.relation_end_time IS NULL)
) ranked_root
WHERE rn = 1;

CREATE TEMPORARY VIEW v_dwm_bb_card_transaction_detail_v2 AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(CAST(b.txn_id AS STRING), ':', COALESCE(b.settlement_id, 'NO_SETTLEMENT')))) AS STRING) AS id,
    b.txn_id,
    b.settlement_id,
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
    COALESCE(d.sale_id, r.sale_id) AS sale_id,
    COALESCE(d.am_id, r.am_id) AS am_id,
    b.version,
    CAST(b.create_time AS TIMESTAMP(6)) AS create_time,
    CAST(b.update_time AS TIMESTAMP(6)) AS update_time,
    b.delete_time
FROM v_bb_base b
LEFT JOIN v_bb_direct_sale_relation d
    ON d.tx_id = b.txn_id
LEFT JOIN v_bb_root_sale_relation r
    ON r.tx_id = b.txn_id
   AND d.tx_id IS NULL;

CREATE TEMPORARY TABLE sink_dwm_bb_card_transaction_detail_v2_p (
    id                       STRING,
    txn_id                   BIGINT,
    settlement_id            STRING,
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
