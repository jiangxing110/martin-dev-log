--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-15
-- Description:    Quantum BB DWM 批量初始化/回刷
-- Notes:
--   1. Batch 主源: qbit_card_transaction
--   2. 关联 qbitCardSettlement 提取清算/响应/国家因子
--   3. 按 transactionTime 匹配 dim_sale_account_relation_p 获取 sale_id / am_id
--   4. DWM 按 transaction_time 月分区
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

CREATE TEMPORARY TABLE source_qbit_card_transaction (
    id                  STRING,
    `transactionId`     STRING,
    `sourceId`          STRING,
    `accountId`         STRING,
    `cardId`            STRING,
    `transactionTime`   TIMESTAMP(6),
    `createTime`        TIMESTAMP(6),
    `thirdCompleteTime` TIMESTAMP(6),
    `businessType`      STRING,
    status              STRING,
    remarks             STRING,
    provider            STRING,
    `specialSourceData` STRING,
    `updateTime`        TIMESTAMP(6),
    `deleteTime`        TIMESTAMP(6),
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

CREATE TEMPORARY TABLE source_qbit_card_settlement (
    id                      STRING,
    `transactionId`         STRING,
    `qbitCardTransactionId` STRING,
    provider                STRING,
    `transactionType`       STRING,
    `billingAmount`         DECIMAL(38, 18),
    `rawData`               STRING,
    `createTime`            TIMESTAMP(6),
    `deleteTime`            TIMESTAMP(6),
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

CREATE TEMPORARY TABLE source_qbit_card (
    id     STRING,
    `type` STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = 'public."qbitCard"',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY TABLE source_card_bin (
    system_provider STRING,
    brand           STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = 'public.card_bin',
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
    'table-name' = 'dim.dim_sale_account_relation_p',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_bb_base AS
WITH bb_tx AS (
    SELECT
        t.*,
        c.`type` AS card_org
    FROM source_qbit_card_transaction t
    LEFT JOIN source_qbit_card c
        ON c.id = t.`cardId`
    INNER JOIN source_card_bin b
        ON b.system_provider = t.provider
       AND b.brand = 'BlueBanc'
    WHERE t.`deleteTime` IS NULL
),
matched_settle AS (
    SELECT
        t.id AS tx_uuid,
        s.*
    FROM bb_tx t
    INNER JOIN source_qbit_card_settlement s
        ON t.`sourceId` = s.`transactionId`
       AND s.provider = 'BlueBancCard'
       AND s.`deleteTime` IS NULL
    UNION ALL
    SELECT
        t.id AS tx_uuid,
        s.*
    FROM bb_tx t
    INNER JOIN source_qbit_card_settlement s
        ON t.id = s.`qbitCardTransactionId`
       AND s.provider = 'BlueBancCard'
       AND s.`deleteTime` IS NULL
),
latest_settle AS (
    SELECT *
    FROM (
        SELECT
            m.*,
            ROW_NUMBER() OVER (PARTITION BY tx_uuid ORDER BY `createTime` DESC) AS rn
        FROM matched_settle m
    ) ranked_settle
    WHERE rn = 1
)
SELECT
    t.id,
    t.`accountId` AS account_id,
    t.`cardId` AS card_id,
    COALESCE(t.`transactionTime`, t.`createTime`) AS transaction_time,
    t.`thirdCompleteTime` AS third_complete_time,
    t.`businessType` AS business_type,
    t.status,
    t.remarks,
    t.card_org,
    JSON_VALUE(s.`rawData`, '$.txnLocation') IN ('US', 'USA') OR JSON_VALUE(t.`specialSourceData`, '$.country') IN ('US', 'USA') AS is_dom,
    JSON_VALUE(s.`rawData`, '$.responseCode') AS resp_code,
    JSON_VALUE(s.`rawData`, '$.requestCode') AS request_code,
    JSON_VALUE(s.`rawData`, '$.reasonCode') AS reason_code,
    s.`transactionType` NOT IN ('ST-REFUND_ADV', 'ST-PURCHASE_ADV', 'ST-ECOMM_ADV', 'ST-SETT_ADV', 'ST-ATM_ADV') AS is_valid_settle,
    s.`transactionType` = 'authorization.clearing' AS is_clearing,
    s.`transactionType` = 'authorization.reversal' AS is_reversal,
    s.`transactionType` = 'refund.clearing' AS is_refund,
    CAST(COALESCE(s.`billingAmount`, CAST(0 AS DECIMAL(38, 18))) AS DECIMAL(20, 4)) AS billing_amount,
    1 AS version,
    t.`createTime` AS create_time,
    COALESCE(t.`updateTime`, t.`createTime`) AS update_time,
    t.`deleteTime` AS delete_time,
    JSON_VALUE(s.`rawData`, '$.txnLocation') AS settle_country,
    JSON_VALUE(t.`specialSourceData`, '$.country') AS tx_country
FROM bb_tx t
LEFT JOIN latest_settle s
    ON s.tx_uuid = t.id;

CREATE TEMPORARY VIEW v_bb_direct_sale_relation AS
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
    FROM v_bb_base b
    INNER JOIN source_dim_sale_account_relation_p sr
        ON sr.relation_account_id = b.account_id
       AND sr.delete_time IS NULL
       AND b.transaction_time >= sr.relation_start_time
       AND (
            b.transaction_time < sr.relation_end_time
            OR sr.relation_end_time IS NULL
       )
) ranked_direct
WHERE rn = 1;

CREATE TEMPORARY VIEW v_bb_root_sale_relation AS
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
    FROM v_bb_base b
    INNER JOIN source_api_account_relation aar
        ON aar.account_id = b.account_id
       AND aar.delete_time IS NULL
    INNER JOIN source_dim_sale_account_relation_p sr
        ON sr.relation_account_id = aar.root_id
       AND sr.delete_time IS NULL
       AND b.transaction_time >= sr.relation_start_time
       AND (
            b.transaction_time < sr.relation_end_time
            OR sr.relation_end_time IS NULL
       )
) ranked_root
WHERE rn = 1;

CREATE TEMPORARY VIEW v_dwm_bb_card_transaction_detail AS
SELECT
    b.id,
    b.account_id,
    b.card_id,
    b.transaction_time,
    b.third_complete_time,
    b.business_type,
    b.status,
    b.remarks,
    b.card_org,
    b.is_dom,
    b.resp_code,
    b.request_code,
    b.reason_code,
    b.is_valid_settle,
    b.is_clearing,
    b.is_reversal,
    b.is_refund,
    b.billing_amount,
    b.version,
    b.create_time,
    b.update_time,
    b.delete_time,
    b.settle_country,
    b.tx_country,
    COALESCE(d.sale_id, r.sale_id) AS sale_id,
    COALESCE(d.am_id, r.am_id) AS am_id
FROM v_bb_base b
LEFT JOIN v_bb_direct_sale_relation d
    ON d.tx_id = b.id
LEFT JOIN v_bb_root_sale_relation r
    ON r.tx_id = b.id
   AND d.tx_id IS NULL;

CREATE TEMPORARY TABLE sink_dwm_bb_card_transaction_detail_p (
    id                  STRING,
    account_id          STRING,
    card_id             STRING,
    transaction_time    TIMESTAMP(6),
    third_complete_time TIMESTAMP(6),
    business_type       STRING,
    status              STRING,
    remarks             STRING,
    card_org            STRING,
    is_dom              BOOLEAN,
    resp_code           STRING,
    request_code        STRING,
    reason_code         STRING,
    is_valid_settle     BOOLEAN,
    is_clearing         BOOLEAN,
    is_reversal         BOOLEAN,
    is_refund           BOOLEAN,
    billing_amount      DECIMAL(20, 4),
    version             INT,
    create_time         TIMESTAMP(6),
    update_time         TIMESTAMP(6),
    delete_time         TIMESTAMP(6),
    settle_country      STRING,
    tx_country          STRING,
    sale_id             STRING,
    am_id               STRING,
    PRIMARY KEY (id, transaction_time) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = 'dwm.dwm_bb_card_transaction_detail_p',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'sink.buffer-flush.max-rows' = '2000',
    'sink.buffer-flush.interval' = '3000'
);

INSERT INTO sink_dwm_bb_card_transaction_detail_p
SELECT * FROM v_dwm_bb_card_transaction_detail;
