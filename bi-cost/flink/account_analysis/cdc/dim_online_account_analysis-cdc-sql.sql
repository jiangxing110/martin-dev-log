--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-28
-- Description:    客户分析维表 dim_account_analysis CDC 增量同步
-- 作业元信息：
--   作业类型：流处理 CDC
--   运行方式：全量初始化 + 增量实时同步
--   运行参数：无
--   源库变更响应：源表 INSERT/UPDATE/DELETE 通过 postgres-cdc 同步到 DIM。
-- Notes:
--   1. 以 account 为客户主 CDC 源，只保留最上层客户类型。
--   2. 激活时间按 api_account_relation.root_id 合并后计算。
--   3. CDC 不使用 OVER 累计窗口，避免 CDC join 产生 update/delete changelog 后无法规划；
--      卡/crypto 激活时间按总额超过阈值后的最早交易时间刷新，精确累计跨阈值时间由 batch 定期重刷兜底。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'sink.parallelism' = '1';
SET 'pipeline.operator-chaining' = 'false';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';
SET 'table.dml-sync' = 'true';
SET 'execution.checkpointing.interval' = '10s';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'execution.checkpointing.timeout' = '30min';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

CREATE TEMPORARY TABLE source_account (
    id                 STRING,
    `verifiedName`     STRING,
    `type`             STRING,
    status             STRING,
    `referralCodeId`   STRING,
    `createTime`       TIMESTAMP(6),
    `updateTime`       TIMESTAMP(6),
    `deleteTime`       TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = '${secret_values.PG_TEST_HOST}',
    'port' = '${secret_values.PG_TEST_PORT1}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'database-name' = '${secret_values.PG_TEST_DATABASE}',
    'schema-name' = 'public',
    'table-name' = 'account',
    'slot.name' = 'flink_slot_account_analysis_account',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.slot.drop.on.stop' = 'true',
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'false'
);

CREATE TEMPORARY TABLE source_account_extend (
    `accountId`  STRING,
    `systemType` STRING,
    `deleteTime` TIMESTAMP(6),
    PRIMARY KEY (`accountId`) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = '${secret_values.PG_TEST_HOST}',
    'port' = '${secret_values.PG_TEST_PORT1}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'database-name' = '${secret_values.PG_TEST_DATABASE}',
    'schema-name' = 'public',
    'table-name' = 'accountExtend',
    'slot.name' = 'flink_slot_account_analysis_account_extend',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.slot.drop.on.stop' = 'true',
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'false'
);

CREATE TEMPORARY TABLE source_referral_code (
    id           STRING,
    `userId`     STRING,
    `deleteTime` TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = '${secret_values.PG_TEST_HOST}',
    'port' = '${secret_values.PG_TEST_PORT1}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'database-name' = '${secret_values.PG_TEST_DATABASE}',
    'schema-name' = 'public',
    'table-name' = 'referralCode',
    'slot.name' = 'flink_slot_account_analysis_referral_code',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.slot.drop.on.stop' = 'true',
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'false'
);

CREATE TEMPORARY TABLE source_caas_open_api_extend (
    account_id     STRING,
    business_mode  STRING,
    access_type    STRING,
    mor_type       STRING,
    mor_type_extra STRING,
    delete_time    TIMESTAMP(6),
    PRIMARY KEY (account_id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = '${secret_values.PG_TEST_HOST}',
    'port' = '${secret_values.PG_TEST_PORT1}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'database-name' = '${secret_values.PG_TEST_DATABASE}',
    'schema-name' = 'public',
    'table-name' = 'caas_open_api_extend',
    'slot.name' = 'flink_slot_account_analysis_caas_extend',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.slot.drop.on.stop' = 'true',
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'false'
);

CREATE TEMPORARY TABLE source_cdd_risk_rating (
    `accountId`        STRING,
    `accountRiskLevel` STRING,
    `updateTime`       TIMESTAMP(6),
    `deleteTime`       TIMESTAMP(6),
    PRIMARY KEY (`accountId`) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = '${secret_values.PG_TEST_HOST}',
    'port' = '${secret_values.PG_TEST_PORT1}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'database-name' = '${secret_values.PG_TEST_DATABASE}',
    'schema-name' = 'public',
    'table-name' = 'cddRiskRating',
    'slot.name' = 'flink_slot_account_analysis_cdd_risk',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.slot.drop.on.stop' = 'true',
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'false'
);

CREATE TEMPORARY TABLE source_api_account_relation (
    account_id  STRING,
    root_id     STRING,
    delete_time TIMESTAMP(6),
    PRIMARY KEY (account_id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = '${secret_values.PG_TEST_HOST}',
    'port' = '${secret_values.PG_TEST_PORT1}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'database-name' = '${secret_values.PG_TEST_DATABASE}',
    'schema-name' = 'public',
    'table-name' = 'api_account_relation',
    'slot.name' = 'flink_slot_account_analysis_api_account_relation',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.slot.drop.on.stop' = 'true',
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'false'
);

CREATE TEMPORARY TABLE source_qbit_card_wallet_transaction (
    id                STRING,
    `accountId`       STRING,
    `businessType`    STRING,
    status            STRING,
    `originAmount`    DECIMAL(20, 4),
    `transactionTime` TIMESTAMP(6),
    `deleteTime`      TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = '${secret_values.PG_TEST_HOST}',
    'port' = '${secret_values.PG_TEST_PORT1}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'database-name' = '${secret_values.PG_TEST_DATABASE}',
    'schema-name' = 'public',
    'table-name' = 'qbitCardWalletTransaction',
    'slot.name' = 'flink_slot_account_analysis_card_wallet',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.slot.drop.on.stop' = 'true',
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'false'
);

CREATE TEMPORARY TABLE source_transfer (
    id                STRING,
    `accountId`       STRING,
    `transactionTime` TIMESTAMP(6),
    `deleteTime`      TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = '${secret_values.PG_TEST_HOST}',
    'port' = '${secret_values.PG_TEST_PORT1}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'database-name' = '${secret_values.PG_TEST_DATABASE}',
    'schema-name' = 'public',
    'table-name' = 'transfer',
    'slot.name' = 'flink_slot_account_analysis_transfer',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.slot.drop.on.stop' = 'true',
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'false'
);

CREATE TEMPORARY TABLE source_crypto_assets_transfers (
    id             STRING,
    account_id     STRING,
    action         STRING,
    status         STRING,
    hidden         BOOLEAN,
    origin_amount  DECIMAL(20, 4),
    usd_rate       DECIMAL(20, 8),
    create_time    TIMESTAMP(6),
    delete_time    TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = '${secret_values.PG_TEST_HOST}',
    'port' = '${secret_values.PG_TEST_PORT1}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'database-name' = '${secret_values.PG_TEST_DATABASE}',
    'schema-name' = 'public',
    'table-name' = 'crypto_assets_transfers',
    'slot.name' = 'flink_slot_account_analysis_crypto_transfer',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.slot.drop.on.stop' = 'true',
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'false'
);

CREATE TEMPORARY TABLE source_open_api_client_config (
    id           STRING,
    `clientId`   STRING,
    online_time  TIMESTAMP(6),
    `deleteTime` TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = '${secret_values.PG_TEST_HOST}',
    'port' = '${secret_values.PG_TEST_PORT1}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'database-name' = '${secret_values.PG_TEST_DATABASE}',
    'schema-name' = 'public',
    'table-name' = 'openApiClientConfig',
    'slot.name' = 'flink_slot_account_analysis_open_api_config',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.slot.drop.on.stop' = 'true',
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'false'
);

CREATE TEMPORARY TABLE source_fund_orders (
    id          STRING,
    account_id  STRING,
    `type`      STRING,
    status      STRING,
    create_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = '${secret_values.PG_TEST_HOST}',
    'port' = '${secret_values.PG_TEST_PORT1}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'database-name' = '${secret_values.PG_TEST_DATABASE}',
    'schema-name' = 'public',
    'table-name' = 'fund_orders',
    'slot.name' = 'flink_slot_account_analysis_fund_orders',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.slot.drop.on.stop' = 'true',
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'false'
);

CREATE TEMPORARY VIEW v_card_active AS
SELECT
    root_account_id,
    MIN(transaction_time) AS card_active_time
FROM (
    SELECT
        COALESCE(aar.root_id, t.`accountId`) AS root_account_id,
        t.`transactionTime` AS transaction_time,
        COALESCE(t.`originAmount`, CAST(0 AS DECIMAL(20, 4))) AS origin_amount
    FROM source_qbit_card_wallet_transaction t
    LEFT JOIN source_api_account_relation aar
        ON aar.account_id = t.`accountId`
       AND aar.delete_time IS NULL
    WHERE t.`businessType` IN (
        'TransferInFromIPeakoin',
        'QbitCryptoToQbitCardWallet',
        'TransferInFromQbitGlobal',
        'Deposit',
        'TransferInFromFinancing',
        'TransferInFromCryptoAssets',
        'AccountDepositCNY'
    )
      AND t.status = 'Closed'
      AND t.`deleteTime` IS NULL
) recharge_base
GROUP BY root_account_id
HAVING SUM(origin_amount) > CAST(5000 AS DECIMAL(20, 4));

CREATE TEMPORARY VIEW v_global_active AS
SELECT
    COALESCE(aar.root_id, t.`accountId`) AS root_account_id,
    MIN(t.`transactionTime`) AS global_active_time
FROM source_transfer t
LEFT JOIN source_api_account_relation aar
    ON aar.account_id = t.`accountId`
   AND aar.delete_time IS NULL
WHERE t.`deleteTime` IS NULL
GROUP BY COALESCE(aar.root_id, t.`accountId`);

CREATE TEMPORARY VIEW v_crypto_active AS
SELECT
    root_account_id,
    MIN(create_time) AS crypto_active_time
FROM (
    SELECT
        COALESCE(aar.root_id, t.account_id) AS root_account_id,
        t.create_time,
        CAST(COALESCE(t.origin_amount, CAST(0 AS DECIMAL(20, 4))) * COALESCE(t.usd_rate, CAST(0 AS DECIMAL(20, 8))) AS DECIMAL(20, 4)) AS usd_amount
    FROM source_crypto_assets_transfers t
    LEFT JOIN source_api_account_relation aar
        ON aar.account_id = t.account_id
       AND aar.delete_time IS NULL
    WHERE t.action = 'sell'
      AND t.status = 'Closed'
      AND COALESCE(t.hidden, FALSE) = FALSE
      AND t.delete_time IS NULL
) crypto_base
GROUP BY root_account_id
HAVING SUM(usd_amount) > CAST(200000 AS DECIMAL(20, 4));

CREATE TEMPORARY VIEW v_api_active AS
SELECT
    COALESCE(aar.root_id, c.`clientId`) AS root_account_id,
    MIN(c.online_time) AS api_active_time
FROM source_open_api_client_config c
LEFT JOIN source_api_account_relation aar
    ON aar.account_id = c.`clientId`
   AND aar.delete_time IS NULL
WHERE c.online_time IS NOT NULL
  AND c.`deleteTime` IS NULL
GROUP BY COALESCE(aar.root_id, c.`clientId`);

CREATE TEMPORARY VIEW v_treasury_active AS
SELECT
    COALESCE(aar.root_id, f.account_id) AS root_account_id,
    MIN(f.create_time) AS treasury_active_time
FROM source_fund_orders f
LEFT JOIN source_api_account_relation aar
    ON aar.account_id = f.account_id
   AND aar.delete_time IS NULL
WHERE f.`type` = 'purchase'
  AND f.status = 'complete'
  AND f.delete_time IS NULL
GROUP BY COALESCE(aar.root_id, f.account_id);

CREATE TEMPORARY VIEW v_dim_account_analysis AS
SELECT
    a.id AS account_id,
    a.`verifiedName` AS verified_name,
    a.`type` AS account_category,
    a.status,
    ae.`systemType` AS system_type,
    cae.business_mode,
    cae.access_type,
    cae.mor_type,
    cae.mor_type_extra,
    crr.`accountRiskLevel` AS account_risk_level,
    rc.`userId` AS referral_user_id,
    ca.card_active_time,
    ga.global_active_time,
    cra.crypto_active_time,
    aa.api_active_time,
    ta.treasury_active_time,
    COALESCE(a.`createTime`, CURRENT_TIMESTAMP) AS create_time,
    CURRENT_TIMESTAMP AS update_time,
    a.`deleteTime` AS delete_time
FROM source_account a
LEFT JOIN source_account_extend ae
    ON ae.`accountId` = a.id
   AND ae.`deleteTime` IS NULL
LEFT JOIN source_caas_open_api_extend cae
    ON cae.account_id = a.id
   AND cae.delete_time IS NULL
LEFT JOIN source_cdd_risk_rating crr
    ON crr.`accountId` = a.id
   AND crr.`deleteTime` IS NULL
LEFT JOIN source_referral_code rc
    ON rc.id = a.`referralCodeId`
   AND rc.`deleteTime` IS NULL
LEFT JOIN v_card_active ca
    ON ca.root_account_id = a.id
LEFT JOIN v_global_active ga
    ON ga.root_account_id = a.id
LEFT JOIN v_crypto_active cra
    ON cra.root_account_id = a.id
LEFT JOIN v_api_active aa
    ON aa.root_account_id = a.id
LEFT JOIN v_treasury_active ta
    ON ta.root_account_id = a.id
WHERE a.`type` IN ('ApiClient', 'MasterAccount', 'Merchant', 'TestAccount');

CREATE TEMPORARY TABLE sink_dim_account_analysis (
    account_id           STRING,
    verified_name        STRING,
    account_category     STRING,
    status               STRING,
    system_type          STRING,
    business_mode        STRING,
    access_type          STRING,
    mor_type             STRING,
    mor_type_extra       STRING,
    account_risk_level   STRING,
    referral_user_id     STRING,
    card_active_time     TIMESTAMP(6),
    global_active_time   TIMESTAMP(6),
    crypto_active_time   TIMESTAMP(6),
    api_active_time      TIMESTAMP(6),
    treasury_active_time TIMESTAMP(6),
    create_time          TIMESTAMP(6),
    update_time          TIMESTAMP(6),
    delete_time          TIMESTAMP(6),
    PRIMARY KEY (account_id) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dim_account_analysis',
    'targetSchema' = 'dim',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '200'
);

INSERT INTO sink_dim_account_analysis
SELECT * FROM v_dim_account_analysis;
