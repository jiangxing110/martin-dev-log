--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-15
-- Updated Time:   2026-08-04 15:32:00
-- 历史名称：sp_sync_qi_card_incremental.sql
-- Description:    Quantum QI v2 CDC 增量同步: qbit_card_transaction -> DWM
-- 作业元信息：
--   作业类型：批式 CDC 修复任务
--   运行方式：默认按昨天变更扫描
--   运行参数：无
--   源库变更响应：按 qbit_card_transaction updateTime/createTime/deleteTime 昨日窗口重刷。
-- Notes:
--   1. CDC 只负责 ODS -> DWM
--   2. 按 transactionTime 匹配 dim_sale_account_relation_p 获取 sale_id / am_id
--   3. DWS 日汇总由 sp_init_qi_card_dws_by_fast.sql 回刷受影响日期
--   4. 主业务 CDC 不扫描 ods_bi_month_tag.update_time
--   5. cost_fixed_fee 由固定成本独立脚本回刷
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'pipeline.operator-chaining' = 'false';
SET 'table.exec.mini-batch.enabled' = 'false';
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
    `transactionId`     STRING,
    `accountId`         STRING,
    `cardId`            STRING,
    status              STRING,
    `transactionTime`   TIMESTAMP(6),
    `businessType`      STRING,
    provider            STRING,
    `specialSourceData` STRING,
    version             INT,
    remarks             STRING,
    `createTime`        TIMESTAMP(6),
    `updateTime`        TIMESTAMP(6),
    `deleteTime`        TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id::text AS id, "transactionId"::text AS "transactionId", "accountId"::text AS "accountId", "cardId"::text AS "cardId", status, "transactionTime", "businessType", provider, CAST("specialSourceData" AS text) AS "specialSourceData", version, remarks, "createTime", "updateTime", "deleteTime" FROM public.qbit_card_transaction WHERE "businessType" IN (''Consumption'', ''Reversal'', ''Credit'') AND ((COALESCE("updateTime", "createTime") >= CAST(CURRENT_DATE - INTERVAL ''1'' DAY AS TIMESTAMP(6)) AND COALESCE("updateTime", "createTime") < CAST(CURRENT_DATE AS TIMESTAMP(6))) OR ("deleteTime" >= CAST(CURRENT_DATE - INTERVAL ''1'' DAY AS TIMESTAMP(6)) AND "deleteTime" < CAST(CURRENT_DATE AS TIMESTAMP(6))))) AS qbit_card_transaction_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_card_bin (
    system_provider STRING,
    brand           STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT system_provider, brand FROM public.card_bin) AS card_bin_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY TABLE source_quantum_card_transaction_extend (
    transaction_id    STRING,
    usd_amount        DECIMAL(20, 4),
    channel_provision STRING,
    country           STRING,
    PRIMARY KEY (transaction_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT transaction_id::text AS transaction_id, usd_amount, channel_provision, country FROM public.quantum_card_transaction_extend) AS quantum_card_transaction_extend_f',
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
    'table-name' = '(SELECT id::text AS id, relation_account_id::text AS relation_account_id, sale_id, am_id, operation_manager_id, relation_start_time, relation_end_time, delete_time FROM dim.dim_sale_account_relation_p WHERE delete_time IS NULL) AS dim_sale_account_relation_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_qi_base AS
SELECT
    t.id,
    t.`transactionId` AS transaction_id,
    t.`accountId` AS account_id,
    da.account_type,
    da.`type` AS account_category,
    da.system_type,
    t.status,
    t.`transactionTime` AS transaction_time,
    COALESCE(t.version, 1) AS version,
    t.remarks,
    t.`createTime` AS create_time,
    COALESCE(t.`updateTime`, t.`createTime`) AS update_time,
    t.`deleteTime` AS delete_time,
    COALESCE(t.`updateTime`, t.`createTime`) AS source_update_time,
    t.`deleteTime` AS source_delete_time,
    t.`deleteTime` IS NULL AS is_current_valid,
    CAST(COALESCE(e.usd_amount, CAST(0 AS DECIMAL(20, 4))) AS DECIMAL(20, 4)) AS billing_amount,
    e.channel_provision = 'QBIT' AS is_qbit_provision,
    e.country IN ('HK', 'HKG') AS is_hk_region,
    t.`businessType` = 'Consumption' AS is_consumption,
    t.`businessType` IN ('Reversal', 'Credit') AS is_reversal_or_credit,
    JSON_VALUE(t.`specialSourceData`, '$.code.1001') IS NOT NULL
        OR JSON_VALUE(t.`specialSourceData`, '$.code.1103') IS NOT NULL
        OR JSON_VALUE(t.`specialSourceData`, '$.code.1105') IS NOT NULL AS has_special_code,
    FALSE AS is_vip_account,
    t.`businessType` AS business_type,
    t.`cardId` AS card_id
FROM source_qbit_card_transaction t
INNER JOIN source_card_bin b
    ON b.system_provider = t.provider
   AND b.brand = 'QbitIssuing'
LEFT JOIN source_quantum_card_transaction_extend e
    ON e.transaction_id = t.`transactionId`
LEFT JOIN source_dim_account da
    ON da.id = t.`accountId`
WHERE t.`deleteTime` IS NULL;

CREATE TEMPORARY VIEW v_qi_direct_sale_relation AS
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
    FROM v_qi_base b
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

CREATE TEMPORARY VIEW v_qi_root_sale_relation AS
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
    FROM v_qi_base b
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

CREATE TEMPORARY VIEW v_dwm_qi_card_transaction_detail AS
SELECT
    b.id,
    b.transaction_id,
    b.account_id,
    b.account_type,
    b.account_category,
    b.system_type,
    b.status,
    b.transaction_time,
    b.version,
    b.remarks,
    b.create_time,
    b.update_time,
    b.delete_time,
    b.source_update_time,
    b.source_delete_time,
    b.is_current_valid,
    b.billing_amount,
    b.is_qbit_provision,
    b.is_hk_region,
    b.is_consumption,
    b.is_reversal_or_credit,
    b.has_special_code,
    b.is_vip_account,
    b.business_type,
    b.card_id,
    COALESCE(d.sale_id, r.sale_id) AS sale_id,
    COALESCE(d.am_id, r.am_id) AS am_id
FROM v_qi_base b
LEFT JOIN v_qi_direct_sale_relation d
    ON d.tx_id = b.id
LEFT JOIN v_qi_root_sale_relation r
    ON r.tx_id = b.id
   AND d.tx_id IS NULL;

CREATE TEMPORARY TABLE sink_dwm_qi_card_transaction_detail_v2_p (
    id                    STRING,
    transaction_id        STRING,
    account_id            STRING,
    account_type          STRING,
    account_category      STRING,
    system_type           STRING,
    status                STRING,
    transaction_time      TIMESTAMP(6),
    version               INT,
    remarks               STRING,
    create_time           TIMESTAMP(6),
    update_time           TIMESTAMP(6),
    delete_time           TIMESTAMP(6),
    source_update_time    TIMESTAMP(6),
    source_delete_time    TIMESTAMP(6),
    is_current_valid      BOOLEAN,
    billing_amount        DECIMAL(20, 4),
    is_qbit_provision     BOOLEAN,
    is_hk_region          BOOLEAN,
    is_consumption        BOOLEAN,
    is_reversal_or_credit BOOLEAN,
    has_special_code      BOOLEAN,
    is_vip_account        BOOLEAN,
    business_type         STRING,
    card_id               STRING,
    sale_id               STRING,
    am_id                 STRING,
    PRIMARY KEY (id, transaction_time) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dwm_qi_card_transaction_detail_v2_p',
    'targetSchema' = 'dwm',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dwm_qi_card_transaction_detail_v2_p
SELECT * FROM v_dwm_qi_card_transaction_detail;
