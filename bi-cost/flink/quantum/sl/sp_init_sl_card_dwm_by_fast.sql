--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-15
-- Description:    Quantum SL DWM 批量初始化/回刷
-- Notes:
--   1. Batch 主源: qbitCardSettlement
--   2. qbitCardSettlement.qbitCardTransactionId 关联 qbit_card_transaction
--   3. 按 qbit_card_transaction.transactionTime 匹配 dim_sale_account_relation_p
--   4. 按 settlement_date 回刷 DWM 分区数据
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

-- 回刷窗口示例:
-- WHERE settlement_date >= DATE '2026-01-01' AND settlement_date < DATE '2026-02-01'

CREATE TEMPORARY TABLE source_qbit_card_settlement (
    id                        STRING,
    `transactionId`           STRING,
    `qbitCardTransactionId`   STRING,
    provider                  STRING,
    `billingAmount`           DECIMAL(38, 18),
    `billingCurrencyCode`     STRING,
    `transactionAmount`       DECIMAL(38, 18),
    `transactionCurrencyCode` STRING,
    `rawData`                 STRING,
    `createTime`              TIMESTAMP(6),
    `updateTime`              TIMESTAMP(6),
    `deleteTime`              TIMESTAMP(6),
    remarks                   STRING,
    version                   INT,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = 'public."qbitCardSettlement"',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY TABLE source_qbit_card_transaction (
    id                STRING,
    `accountId`       STRING,
    `transactionId`   STRING,
    `transactionTime` TIMESTAMP(6),
    `deleteTime`      TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = 'public.qbit_card_transaction',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY TABLE source_api_account_relation (
    account_id  STRING,
    root_id     STRING,
    delete_time TIMESTAMP(6),
    PRIMARY KEY (account_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = 'public.api_account_relation',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
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
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = 'public.dim_sale_account_relation_p',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_sl_base AS
SELECT
    s.id,
    t.`accountId` AS account_id,
    COALESCE(s.version, 1) AS version,
    s.remarks,
    s.`createTime` AS create_time,
    COALESCE(s.`updateTime`, s.`createTime`) AS update_time,
    s.`deleteTime` AS delete_time,
    CAST(JSON_VALUE(s.`rawData`, '$.date') AS DATE) AS settlement_date,
    s.`transactionId` AS settlement_transaction_id,
    s.`qbitCardTransactionId` AS qbit_card_transaction_id,
    t.`transactionId` AS qbit_transaction_id,
    s.provider,
    CAST(COALESCE(s.`billingAmount`, CAST(0 AS DECIMAL(38, 18))) AS DECIMAL(20, 4)) AS billing_amount,
    s.`billingCurrencyCode` AS billing_currency_code,
    CAST(COALESCE(s.`transactionAmount`, CAST(0 AS DECIMAL(38, 18))) AS DECIMAL(20, 4)) AS transaction_amount,
    s.`transactionCurrencyCode` AS transaction_currency_code,
    JSON_VALUE(s.`rawData`, '$.merchantData.location.country') AS country,
    COALESCE(t.`transactionTime`, s.`createTime`) AS sale_match_time,
    s.`rawData` AS raw_data,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS etl_time
FROM source_qbit_card_settlement s
INNER JOIN source_qbit_card_transaction t
    ON t.id = s.`qbitCardTransactionId`
   AND t.`deleteTime` IS NULL
WHERE s.`deleteTime` IS NULL
  AND s.provider LIKE '%Slash%'
  AND JSON_VALUE(s.`rawData`, '$.date') IS NOT NULL;

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
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = 'dwm.dwm_sl_card_transaction_detail_p',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'sink.buffer-flush.max-rows' = '2000',
    'sink.buffer-flush.interval' = '3000'
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
