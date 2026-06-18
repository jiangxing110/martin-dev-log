--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-15
-- Description:    Quantum SL CDC 增量同步: qbitCardSettlement -> DWM
-- Notes:
--   1. DWM 基于 qbitCardSettlement
--   2. qbitCardSettlement.qbitCardTransactionId 关联 qbit_card_transaction
--   3. 按 qbit_card_transaction.transactionTime 匹配 dim_sale_account_relation_p
--   4. DWS 后续只依赖 DWM 汇总 rebate_base / rebate_amt
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

SET 'execution.checkpointing.interval' = '10s';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'pipeline.operator-chaining' = 'false';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'execution.checkpointing.timeout' = '30min';

SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';


CREATE TEMPORARY TABLE source_qbit_card_settlement (
    id                        STRING,
    transaction_id            STRING,
    qbit_card_transaction_id  STRING,
    provider                  STRING,
    billing_amount            STRING,
    billing_currency_code     STRING,
    transaction_amount        STRING,
    transaction_currency_code STRING,
    raw_data                  STRING,
    create_time               TIMESTAMP(6),
    update_time               TIMESTAMP(6),
    delete_time               TIMESTAMP(6),
    remarks                   STRING,
    version                   INT,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'ods_qbit_card_settlement_sl',
    'targetSchema' = 'ods',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY TABLE source_qbit_card_transaction (
    id                STRING,
    `accountId`       STRING,
    `transactionId`   STRING,
    `transactionTime` TIMESTAMP(6),
    `deleteTime`      TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'qbit_card_transaction',
    'targetSchema' = 'public',
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
    'tableName' = 'ods_api_account_relation',
    'targetSchema' = 'ods',
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

CREATE TEMPORARY VIEW v_sl_base AS
SELECT
    s.id,
    t.`accountId` AS account_id,
    COALESCE(s.version, 1) AS version,
    s.remarks,
    s.create_time AS create_time,
    COALESCE(s.update_time, s.create_time) AS update_time,
    s.delete_time AS delete_time,
    CAST(JSON_VALUE(s.raw_data, '$.date') AS DATE) AS settlement_date,
    s.transaction_id AS settlement_transaction_id,
    s.qbit_card_transaction_id AS qbit_card_transaction_id,
    t.`transactionId` AS qbit_transaction_id,
    s.provider,
    CAST(COALESCE(s.billing_amount, CAST(0 AS DECIMAL(38, 18))) AS DECIMAL(20, 4)) AS billing_amount,
    s.billing_currency_code AS billing_currency_code,
    CAST(COALESCE(s.transaction_amount, CAST(0 AS DECIMAL(38, 18))) AS DECIMAL(20, 4)) AS transaction_amount,
    s.transaction_currency_code AS transaction_currency_code,
    JSON_VALUE(s.raw_data, '$.merchantData.location.country') AS country,
    COALESCE(t.`transactionTime`, s.create_time) AS sale_match_time,
    s.raw_data,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS etl_time
FROM source_qbit_card_settlement s
INNER JOIN source_qbit_card_transaction t
    ON t.id = s.qbit_card_transaction_id
   AND t.`deleteTime` IS NULL
WHERE s.delete_time IS NULL
  AND s.provider LIKE '%Slash%'
  AND JSON_VALUE(s.raw_data, '$.date') IS NOT NULL
  AND s.create_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP)
  AND s.create_time < CAST(CURRENT_DATE AS TIMESTAMP);

CREATE TEMPORARY VIEW v_sl_direct_sale_relation AS
SELECT tx_id, sale_id, am_id
FROM (
    SELECT
        b.id AS tx_id,
        sr.sale_id,
        sr.am_id,
        ROW_NUMBER() OVER (
            PARTITION BY b.id
            ORDER BY sr.relation_start_time DESC
        ) AS rn
    FROM v_sl_base b
    INNER JOIN source_dim_sale_account_relation_p sr
        ON sr.relation_account_id = b.account_id
       AND sr.delete_time IS NULL
       AND b.sale_match_time >= sr.relation_start_time
       AND (
            b.sale_match_time < sr.relation_end_time
            OR sr.relation_end_time IS NULL
       )
) ranked_direct
WHERE rn = 1;

CREATE TEMPORARY VIEW v_sl_root_sale_relation AS
SELECT tx_id, sale_id, am_id
FROM (
    SELECT
        b.id AS tx_id,
        sr.sale_id,
        sr.am_id,
        ROW_NUMBER() OVER (
            PARTITION BY b.id
            ORDER BY sr.relation_start_time DESC
        ) AS rn
    FROM v_sl_base b
    INNER JOIN source_api_account_relation aar
        ON aar.account_id = b.account_id
       AND aar.delete_time IS NULL
    INNER JOIN source_dim_sale_account_relation_p sr
        ON sr.relation_account_id = aar.root_id
       AND sr.delete_time IS NULL
       AND b.sale_match_time >= sr.relation_start_time
       AND (
            b.sale_match_time < sr.relation_end_time
            OR sr.relation_end_time IS NULL
       )
) ranked_root
WHERE rn = 1;

CREATE TEMPORARY VIEW v_dwm_sl_card_transaction_detail AS
SELECT
    b.id,
    b.account_id,
    b.version,
    b.remarks,
    b.create_time,
    b.update_time,
    b.delete_time,
    b.settlement_date,
    b.settlement_transaction_id,
    b.qbit_card_transaction_id,
    b.qbit_transaction_id,
    b.provider,
    b.billing_amount,
    b.billing_currency_code,
    b.transaction_amount,
    b.transaction_currency_code,
    b.country,
    COALESCE(d.sale_id, r.sale_id) AS sale_id,
    COALESCE(d.am_id, r.am_id) AS am_id,
    b.raw_data,
    b.etl_time
FROM v_sl_base b
LEFT JOIN v_sl_direct_sale_relation d
    ON d.tx_id = b.id
LEFT JOIN v_sl_root_sale_relation r
    ON r.tx_id = b.id
   AND d.tx_id IS NULL;

CREATE TEMPORARY TABLE sink_dwm_sl_card_transaction_detail_p (
    id                         STRING,
    account_id                 STRING,
    version                    INT,
    remarks                    STRING,
    create_time                TIMESTAMP(6),
    update_time                TIMESTAMP(6),
    delete_time                TIMESTAMP(6),
    settlement_date            DATE,
    settlement_transaction_id  STRING,
    qbit_card_transaction_id   STRING,
    qbit_transaction_id        STRING,
    provider                   STRING,
    billing_amount             DECIMAL(20, 4),
    billing_currency_code      STRING,
    transaction_amount         DECIMAL(20, 4),
    transaction_currency_code  STRING,
    country                    STRING,
    sale_id                    STRING,
    am_id                      STRING,
    raw_data                   STRING,
    etl_time                   TIMESTAMP(6),
    PRIMARY KEY (id, settlement_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dwm_sl_card_transaction_detail_p',
    'targetSchema' = 'dwm',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
),
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dwm_sl_card_transaction_detail_p
SELECT
    id,
    account_id,
    version,
    remarks,
    create_time,
    update_time,
    delete_time,
    settlement_date,
    settlement_transaction_id,
    qbit_card_transaction_id,
    qbit_transaction_id,
    provider,
    billing_amount,
    billing_currency_code,
    transaction_amount,
    transaction_currency_code,
    country,
    sale_id,
    am_id,
    raw_data,
    etl_time
FROM v_dwm_sl_card_transaction_detail;
