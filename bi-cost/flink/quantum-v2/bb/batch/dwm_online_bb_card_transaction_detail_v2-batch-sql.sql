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
--   1. 交易主源: ods.ods_quantum_card_transaction_extend。
--   2. 明细粒度: 交易 + BlueBanc 结算明细。
--   3. 不处理 cost_fixed_fee，固定成本由独立脚本回刷。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';
SET 'execution.application-management.enabled' = 'true';
SET 'execution.multi-jobs-in-application.enable' = 'true';

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
    card_org                 STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT t.id, t.source_id, t.card_transaction_id, t.account_id, t.country, t.type AS "type", t.transaction_time, t.original_completion_time, t.business_code_list, t.remarks, t.card_id, t.detail, t.channel_provision, t.create_time, t.update_time, t.delete_time, c.type AS card_org FROM ods.ods_quantum_card_transaction_extend t INNER JOIN ods.ods_qbit_card c ON c.id = t.card_id AND c.delete_time IS NULL AND c.type IN (''Master'', ''VISA'') WHERE t.delete_time IS NULL AND t.channel_provision = ''BLUEBANC'' AND t.type IN (''Consumption'', ''Credit'') AND (t.detail IS NULL OR t.detail NOT LIKE ''AUTO CLASS CAR RENTAL%'') AND COALESCE(t.transaction_time, t.original_completion_time) >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND COALESCE(t.transaction_time, t.original_completion_time) < CAST(''${end_time}'' AS TIMESTAMP(6))) AS ods_quantum_card_transaction_extend_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY TABLE source_qbit_card_settlement (
    id                      STRING,
    transaction_id          STRING,
    qbit_card_transaction_id STRING,
    provider                STRING,
    transaction_type        STRING,
    billing_amount          DOUBLE,
    raw_data                STRING,
    create_time             TIMESTAMP(6),
    delete_time             TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT s.id, s.transaction_id, s.qbit_card_transaction_id, s.provider, s.transaction_type, s.billing_amount, s.raw_data, s.create_time, s.delete_time FROM ods.ods_qbit_card_settlement s WHERE s.delete_time IS NULL AND s.provider = ''BlueBancCard'' AND EXISTS (SELECT 1 FROM ods.ods_quantum_card_transaction_extend t WHERE t.delete_time IS NULL AND t.channel_provision = ''BLUEBANC'' AND t.type IN (''Consumption'', ''Credit'') AND COALESCE(t.transaction_time, t.original_completion_time) >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND COALESCE(t.transaction_time, t.original_completion_time) < CAST(''${end_time}'' AS TIMESTAMP(6)) AND (t.source_id = s.transaction_id OR t.card_transaction_id = s.qbit_card_transaction_id))) AS ods_qbit_card_settlement_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

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

CREATE TEMPORARY TABLE source_api_account_relation (
    account_id  STRING,
    root_id     STRING,
    delete_time TIMESTAMP(6),
    PRIMARY KEY (account_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT account_id, root_id, delete_time FROM ods.ods_api_account_relation WHERE delete_time IS NULL) AS ods_api_account_relation_f',
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
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id, relation_account_id, sale_id, am_id, operation_manager_id, relation_start_time, relation_end_time, delete_time FROM dim.dim_sale_account_relation_p WHERE delete_time IS NULL) AS dim_sale_account_relation_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_bb_tx AS
SELECT
    t.*
FROM source_quantum_card_transaction_extend t
WHERE t.channel_provision = 'BLUEBANC'
  AND t.delete_time IS NULL
  AND t.`type` IN ('Consumption', 'Credit')
  AND (
        t.detail IS NULL
        OR t.detail NOT LIKE 'AUTO CLASS CAR RENTAL%'
  )
  AND COALESCE(t.transaction_time, t.original_completion_time) >= CAST('${start_time}' AS TIMESTAMP(6))
  AND COALESCE(t.transaction_time, t.original_completion_time) < CAST('${end_time}' AS TIMESTAMP(6));

CREATE TEMPORARY VIEW v_matched_settle AS
SELECT
    t.id AS txn_id,
    s.*
FROM v_bb_tx t
INNER JOIN source_qbit_card_settlement s
    ON t.source_id = s.transaction_id
   AND s.provider = 'BlueBancCard'
   AND s.delete_time IS NULL
UNION ALL
SELECT
    t.id AS txn_id,
    s.*
FROM v_bb_tx t
INNER JOIN source_qbit_card_settlement s
    ON t.card_transaction_id = s.qbit_card_transaction_id
   AND s.provider = 'BlueBancCard'
   AND s.delete_time IS NULL;

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
    JSON_VALUE(s.raw_data, '$.txnLocation') AS settle_country,
    COALESCE(JSON_VALUE(s.raw_data, '$.txnLocation'), t.country) IN ('US', 'USA') AS is_dom,
    JSON_VALUE(s.raw_data, '$.responseCode') AS resp_code,
    JSON_VALUE(s.raw_data, '$.reasonCode') AS reason_code,
    s.transaction_type AS transaction_type,
    s.transaction_type NOT IN ('ST-REFUND_ADV', 'ST-PURCHASE_ADV', 'ST-ECOMM_ADV', 'ST-SETT_ADV', 'ST-ATM_ADV') AS is_valid_settle,
    s.transaction_type = 'authorization.clearing' AS is_clearing,
    s.transaction_type = 'authorization.reversal' AS is_reversal,
    s.transaction_type = 'refund.clearing' AS is_refund,
    CAST(COALESCE(s.billing_amount, CAST(0 AS DOUBLE)) AS DECIMAL(20, 4)) AS billing_amount,
    CAST(JSON_VALUE(s.raw_data, '$.postDate') AS TIMESTAMP(6)) AS settlement_post_date,
    CAST(JSON_VALUE(s.raw_data, '$.txnDate') AS TIMESTAMP(6)) AS settlement_txn_date,
    1 AS version,
    COALESCE(t.create_time, CURRENT_TIMESTAMP) AS create_time,
    COALESCE(t.update_time, t.create_time, CURRENT_TIMESTAMP) AS update_time,
    t.delete_time
FROM v_bb_tx t
LEFT JOIN v_matched_settle s
    ON s.txn_id = t.id
LEFT JOIN source_dim_account da
    ON da.id = t.account_id;

CREATE TEMPORARY VIEW v_bb_direct_sale_relation AS
SELECT tx_id, sale_id, am_id
FROM (
    SELECT
        b.txn_id AS tx_id,
        sr.sale_id,
        sr.am_id,
        ROW_NUMBER() OVER (
            PARTITION BY b.txn_id
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
        b.txn_id AS tx_id,
        sr.sale_id,
        sr.am_id,
        ROW_NUMBER() OVER (
            PARTITION BY b.txn_id
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
