--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-28
-- Description:    BZ v2 CDC 增量同步: qbitCardSettlement -> DWM 结算明细
-- 作业元信息：
--   作业类型：流处理 CDC
--   运行方式：全量初始化 + 增量实时同步
--   运行参数：无
--   源库变更响应：源表变更通过 postgres-cdc 驱动下游写入。
-- Notes:
--   1. CDC 源: qbitCardSettlement (provider LIKE '%I2c%')
--   2. 通过 cardHashId = qbitCard.token 关联获取 accountId
--   3. 按 createTime 匹配 dim_sale_account_relation_p 获取 sale_id / am_id
--   4. DWS 日汇总由 CDC 脚本按月回刷
--   5. cost_fixed_fee 由固定成本独立脚本回刷
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'pipeline.operator-chaining' = 'false';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

SET 'execution.checkpointing.interval' = '10s';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'execution.checkpointing.timeout' = '30min';

-- CDC 源：qbitCardSettlement (postgres-cdc)
CREATE TEMPORARY TABLE source_qbit_card_settlement (
    id               STRING,
    `cardHashId`     STRING,
    `transactionType` STRING,
    `billingAmount`  STRING,
    `rawData`        STRING,
    provider         STRING,
    `deleteTime`     TIMESTAMP(6),
    `createTime`     TIMESTAMP(6),
    `updateTime`     TIMESTAMP(6),
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
    'slot.name' = 'flink_slot_qbit_card_settlement_bz_dwm',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.slot.drop.on.stop' = 'true',
    'debezium.decimal.handling.mode' = 'string',
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'false'
);

-- qbitCard 查找表（ADB PG）— settlement 需要通过 token 关联获取 accountId
CREATE TEMPORARY TABLE source_qbit_card (
    `token`      STRING,
    `accountId`  STRING,
    `id`         STRING,
    provider     STRING,
    `deleteTime` TIMESTAMP(6),
    PRIMARY KEY (`token`) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'qbitCard',
    'targetSchema' = 'public',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY TABLE source_dim_account (
    id           STRING,
    account_type STRING,
    `type`       STRING,
    system_type  STRING,
    delete_time  TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dim_account',
    'targetSchema' = 'dim',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY TABLE source_dim_sale_account_relation_p (
    id                   STRING,
    relation_account_id  STRING,
    sale_id              STRING,
    am_id                STRING,
    relation_start_time  TIMESTAMP(6),
    relation_end_time    TIMESTAMP(6),
    delete_time          TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dim_sale_account_relation_p',
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

-- 结算基础视图：CDC 源 + qbitCard + dim_account
CREATE TEMPORARY VIEW v_bz_base AS
SELECT
    s.id,
    s.`cardHashId` AS card_hash_id,
    c.`accountId` AS account_id,
    da.account_type,
    da.`type` AS account_category,
    da.system_type,
    c.`id` AS card_id,
    s.`createTime` AS transaction_time,
    s.`transactionType` AS settlement_type,
    CAST(COALESCE(CAST(s.`billingAmount` AS DOUBLE), 0) AS DECIMAL(20, 4)) AS billing_amount,
    JSON_VALUE(s.`rawData`, '$.merchantInfo.country') AS country,
    COALESCE(s.`transactionType` = 'authorization.clearing', FALSE) AS is_clearing,
    COALESCE(s.`transactionType` = 'refund.clearing', FALSE) AS is_refund,
    COALESCE(JSON_VALUE(s.`rawData`, '$.merchantInfo.country') = 'USA', FALSE) AS is_us,
    COALESCE(s.`updateTime`, s.`createTime`) AS source_update_time,
    s.`deleteTime` AS source_delete_time,
    1 AS version,
    CAST(NULL AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    s.`deleteTime` AS delete_time
FROM source_qbit_card_settlement s
INNER JOIN source_qbit_card c
    ON c.`token` = s.`cardHashId`
   AND c.provider LIKE '%I2c%'
   AND c.`deleteTime` IS NULL
LEFT JOIN source_dim_account da
    ON da.id = c.`accountId`
   AND da.delete_time IS NULL
WHERE s.provider LIKE '%I2c%'
  AND s.`deleteTime` IS NULL
  AND s.`transactionType` IN ('authorization.clearing', 'refund.clearing');

-- 销售关系：direct 优先
CREATE TEMPORARY VIEW v_bz_direct_sale_relation AS
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
    FROM v_bz_base b
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

-- 销售关系：root 兜底
CREATE TEMPORARY VIEW v_bz_root_sale_relation AS
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
    FROM v_bz_base b
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

-- 最终 DWM 明细
CREATE TEMPORARY VIEW v_dwm_bz_card_settlement_detail AS
SELECT
    b.id,
    b.card_hash_id,
    b.account_id,
    b.account_type,
    b.account_category,
    b.system_type,
    b.card_id,
    b.transaction_time,
    b.settlement_type,
    b.billing_amount,
    b.country,
    b.is_clearing,
    b.is_refund,
    b.is_us,
    b.source_update_time,
    b.source_delete_time,
    COALESCE(d.sale_id, r.sale_id) AS sale_id,
    COALESCE(d.am_id, r.am_id) AS am_id,
    b.version,
    b.remarks,
    b.create_time,
    b.update_time,
    b.delete_time
FROM v_bz_base b
LEFT JOIN v_bz_direct_sale_relation d
    ON d.tx_id = b.id
LEFT JOIN v_bz_root_sale_relation r
    ON r.tx_id = b.id
   AND d.tx_id IS NULL;

CREATE TEMPORARY TABLE sink_dwm_bz_card_settlement_detail_v2_p (
    id                  STRING,
    card_hash_id        STRING,
    account_id          STRING,
    account_type        STRING,
    account_category    STRING,
    system_type         STRING,
    card_id             STRING,
    transaction_time    TIMESTAMP(6),
    settlement_type     STRING,
    billing_amount      DECIMAL(20, 4),
    country             STRING,
    is_clearing         BOOLEAN,
    is_refund           BOOLEAN,
    is_us               BOOLEAN,
    source_update_time  TIMESTAMP(6),
    source_delete_time  TIMESTAMP(6),
    sale_id             STRING,
    am_id               STRING,
    version             INT,
    remarks             STRING,
    create_time         TIMESTAMP(6),
    update_time         TIMESTAMP(6),
    delete_time         TIMESTAMP(6),
    PRIMARY KEY (id, transaction_time) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dwm_bz_card_settlement_detail_v2_p',
    'targetSchema' = 'dwm',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dwm_bz_card_settlement_detail_v2_p
SELECT * FROM v_dwm_bz_card_settlement_detail;
