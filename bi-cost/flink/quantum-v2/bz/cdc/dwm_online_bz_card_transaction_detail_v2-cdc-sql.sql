--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-28
-- Updated Time:   2026-08-04 15:36:00
-- Description:    BZ v2 CDC 增量同步: qbit_card_transaction -> DWM 交易明细
-- 作业元信息：
--   作业类型：批式 CDC 修复任务
--   运行方式：默认按昨天变更扫描
--   运行参数：无
--   源库变更响应：按 qbit_card_transaction updateTime/createTime/deleteTime 昨日窗口重刷。
-- Notes:
--   1. CDC 源: qbit_card_transaction (provider LIKE 'I2c%')
--   2. accountId 直接可用，关联 dim_account 获取账户维度
--   3. 按 transactionTime 匹配 dim_sale_account_relation_p 获取 sale_id / am_id
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

CREATE TEMPORARY TABLE source_qbit_card_transaction (
    id                  STRING,
    `accountId`         STRING,
    `cardId`            STRING,
    `transactionTime`   TIMESTAMP(6),
    `businessType`      STRING,
    status              STRING,
    `settleAmount`      STRING,
    `specialSourceData` STRING,
    provider            STRING,
    `deleteTime`        TIMESTAMP(6),
    `createTime`        TIMESTAMP(6),
    `updateTime`        TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id::text AS id, "accountId"::text AS "accountId", "cardId"::text AS "cardId", "transactionTime", "businessType", status, "settleAmount", CAST("specialSourceData" AS text) AS "specialSourceData", provider, "deleteTime", "createTime", "updateTime" FROM public.qbit_card_transaction WHERE provider LIKE ''I2c%'' AND ((COALESCE("updateTime", "createTime") >= CAST(CURRENT_DATE - INTERVAL ''1'' DAY AS TIMESTAMP(6)) AND COALESCE("updateTime", "createTime") < CAST(CURRENT_DATE AS TIMESTAMP(6))) OR ("deleteTime" >= CAST(CURRENT_DATE - INTERVAL ''1'' DAY AS TIMESTAMP(6)) AND "deleteTime" < CAST(CURRENT_DATE AS TIMESTAMP(6))))) AS qbit_card_transaction_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_dim_account (
    id           STRING,
    account_type STRING,
    `type`       STRING,
    system_type  STRING,
    delete_time  TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id::text AS id, account_type, "type", system_type, delete_time FROM dim.dim_account) AS dim_account_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
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
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id::text AS id, relation_account_id::text AS relation_account_id, sale_id, am_id, relation_start_time, relation_end_time, delete_time FROM dim.dim_sale_account_relation_p WHERE delete_time IS NULL) AS dim_sale_account_relation_p_f',
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
    'table-name' = '(SELECT account_id::text AS account_id, root_id::text AS root_id, delete_time FROM public.api_account_relation WHERE delete_time IS NULL) AS api_account_relation_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

-- 交易基础视图：CDC 源 + dim_account
CREATE TEMPORARY VIEW v_bz_base AS
SELECT
    t.id,
    t.`accountId` AS account_id,
    da.account_type,
    da.`type` AS account_category,
    da.system_type,
    t.`cardId` AS card_id,
    t.`transactionTime` AS transaction_time,
    t.`businessType` AS business_type,
    t.status,
    CAST(COALESCE(CAST(t.`settleAmount` AS DECIMAL(20, 4)), CAST(0 AS DECIMAL(20, 4))) AS DECIMAL(20, 4)) AS billing_amount,
    COALESCE(t.`businessType` = 'Consumption', FALSE) AS is_consumption,
    COALESCE(t.`businessType` = 'Reversal', FALSE) AS is_reversal,
    COALESCE(
        NOT (
            JSON_QUERY(t.`specialSourceData`, '$.code') LIKE '%1001%'
            OR JSON_QUERY(t.`specialSourceData`, '$.code') LIKE '%1103%'
            OR JSON_QUERY(t.`specialSourceData`, '$.code') LIKE '%1105%'
        ),
        FALSE
    ) AS has_special_code,
    COALESCE(t.`updateTime`, t.`createTime`) AS source_update_time,
    t.`deleteTime` AS source_delete_time,
    1 AS version,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    t.`deleteTime` AS delete_time
FROM source_qbit_card_transaction t
LEFT JOIN source_dim_account da
    ON da.id = t.`accountId`
   AND da.delete_time IS NULL
WHERE t.provider LIKE 'I2c%'
  AND t.`deleteTime` IS NULL;

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
    COALESCE(d.sale_id, r.sale_id) AS sale_id,
    COALESCE(d.am_id, r.am_id) AS am_id,
    b.version,
    b.create_time,
    b.update_time,
    b.delete_time
FROM v_bz_base b
LEFT JOIN v_bz_direct_sale_relation d
    ON d.tx_id = b.id
LEFT JOIN v_bz_root_sale_relation r
    ON r.tx_id = b.id
   AND d.tx_id IS NULL;

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
SELECT * FROM v_dwm_bz_card_transaction_detail;
