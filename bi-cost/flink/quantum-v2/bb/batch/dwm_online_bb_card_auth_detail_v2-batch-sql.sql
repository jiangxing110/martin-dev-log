--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-12
-- Description:    BB v2 Auth DWM 月表导入
-- 作业元信息：
--   作业类型：批处理
--   运行方式：按月导入存在的 bb_card_auth_detail_yyyy-mm
--   运行参数：auth_table_name
-- Notes:
--   1. Auth 原始表是月表，单月通常 200w+。
--   2. auth_table_name 只传裸表名，例如 bb_card_auth_detail_2026-05。
--   3. JDBC source 直接读取指定 Auth 月表，避免函数入口在 Flink JDBC 中解析不稳定。
--   4. Auth 月表名已经代表账单月份，不再按 Trans Date / Time 做自然月过滤，避免误过滤月初/月末边界数据。
--   5. DWM 通过 upsert 覆盖，不做删除。
--********************************************************************--

SET 'parallelism.default' = '4';
SET 'taskmanager.memory.network.min' = '1gb';
SET 'taskmanager.memory.network.max' = '3gb';
SET 'taskmanager.memory.network.fraction' = '0.2';
SET 'pipeline.default-parallelism' = '4';
SET 'table.exec.resource.default-parallelism' = '4';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'execution.multi-jobs-in-application.enable' = 'false';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';
SET 'execution.application-management.enabled' = 'true';

-- Auth 月表入口。
-- 注意：bb_card_auth_detail_yyyy-mm 表名包含中划线，PostgreSQL 里必须使用双引号。
-- 启动作业时只传裸表名 auth_table_name，例如：bb_card_auth_detail_2026-05。
-- 这里固定拼成 public."${auth_table_name}"，避免变量值里的双引号被调度平台吞掉。
CREATE TEMPORARY TABLE source_bb_card_auth_detail (
    auth_time               TIMESTAMP(6),
    trans_date_time         STRING,
    program_guid            STRING,
    program_name            STRING,
    card_proxy              STRING,
    person_name             STRING,
    request_code            STRING,
    request_description     STRING,
    local_trans_date_time   STRING,
    auth_txn_guid           STRING,
    response_code           STRING,
    reason_code             STRING,
    txn_amount              STRING,
    settle_amount           STRING,
    txn_currency            STRING,
    merchant_country        STRING,
    transmission_date       STRING,
    merchant_name           STRING,
    pos_service_code        STRING,
    mcc                     STRING,
    authorization_id_code   STRING,
    source_table            STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT CAST(TO_TIMESTAMP("Trans Date / Time", ''MM/DD/YYYY HH12:MI:SS AM'') AS timestamp) AS auth_time, "Trans Date / Time" AS trans_date_time, "Program GUID" AS program_guid, "Program Name" AS program_name, "Card Proxy" AS card_proxy, "Person Name" AS person_name, "Request Code" AS request_code, "Request Description" AS request_description, "Local Trans Date / Time" AS local_trans_date_time, "Auth Txn GUID" AS auth_txn_guid, "Response Code" AS response_code, "Reason Code" AS reason_code, "Txn Amount" AS txn_amount, "Settle Amount" AS settle_amount, "Txn Currency" AS txn_currency, "Merchant Country" AS merchant_country, "Transmission Date" AS transmission_date, "Merchant Name" AS merchant_name, pos_service_code, "MCC" AS mcc, authorization_id_code, ''public."${auth_table_name}"'' AS source_table FROM public."${auth_table_name}") AS bb_auth_detail_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_qbit_card (
    id         STRING,
    token      STRING,
    account_id STRING,
    `type`     STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT c.id, c.token, c.account_id, c.type AS "type" FROM ods.ods_qbit_card c WHERE c.delete_time IS NULL AND EXISTS (SELECT 1 FROM public."${auth_table_name}" a WHERE a."Card Proxy" = c.token)) AS ods_qbit_card_f',
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
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'dim.dim_account',
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
    'table-name' = 'dim.dim_sale_account_relation_p',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_auth_base AS
SELECT
    a.auth_time,
    a.auth_txn_guid,
    a.card_proxy,
    c.id AS card_id,
    c.account_id AS account_id,
    da.account_type,
    da.`type` AS account_category,
    da.system_type,
    a.program_name,
    a.merchant_country,
    a.request_code,
    a.request_description,
    a.response_code,
    a.reason_code,
    a.txn_amount,
    a.settle_amount,
    a.txn_currency,
    a.merchant_name,
    a.mcc,
    c.`type` AS card_org,
    a.merchant_country = 'USA' AS is_dom,
    a.response_code = 'DECLINE' AS is_decline,
    a.request_description = 'Account Verification' AS is_account_verification,
    a.request_description IN (
        'Settlement Advice',
        'Card load via OCT Advice',
        'Refund Advice',
        'Refund Advice Completion',
        'E-Commerce or MOTO Advice',
        'ATM Cash Withdrawal Advice',
        'Purchase Advice'
    ) AS is_excluded_request,
    a.source_table
FROM source_bb_card_auth_detail a
LEFT JOIN source_qbit_card c
    ON a.card_proxy = c.token
LEFT JOIN source_dim_account da
    ON da.id = c.account_id;

CREATE TEMPORARY VIEW v_auth_direct_sale_relation AS
SELECT auth_txn_guid, sale_id, am_id
FROM (
    SELECT
        b.auth_txn_guid,
        sr.sale_id,
        sr.am_id,
        ROW_NUMBER() OVER (
            PARTITION BY b.auth_txn_guid
            ORDER BY sr.relation_start_time DESC
        ) AS rn
    FROM v_auth_base b
    INNER JOIN source_dim_sale_account_relation_p sr
        ON sr.relation_account_id = b.account_id
       AND sr.delete_time IS NULL
       AND b.auth_time >= sr.relation_start_time
       AND (
            b.auth_time < sr.relation_end_time
            OR sr.relation_end_time IS NULL
       )
) ranked_direct
WHERE rn = 1;

CREATE TEMPORARY VIEW v_auth_root_sale_relation AS
SELECT auth_txn_guid, sale_id, am_id
FROM (
    SELECT
        b.auth_txn_guid,
        sr.sale_id,
        sr.am_id,
        ROW_NUMBER() OVER (
            PARTITION BY b.auth_txn_guid
            ORDER BY sr.relation_start_time DESC
        ) AS rn
    FROM v_auth_base b
    INNER JOIN source_api_account_relation aar
        ON aar.account_id = b.account_id
       AND aar.delete_time IS NULL
    INNER JOIN source_dim_sale_account_relation_p sr
        ON sr.relation_account_id = aar.root_id
       AND sr.delete_time IS NULL
       AND b.auth_time >= sr.relation_start_time
       AND (
            b.auth_time < sr.relation_end_time
            OR sr.relation_end_time IS NULL
       )
) ranked_root
WHERE rn = 1;

CREATE TEMPORARY VIEW v_dwm_bb_card_auth_detail_v2 AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(b.auth_txn_guid, ''), ':', COALESCE(b.card_proxy, ''), ':', DATE_FORMAT(b.auth_time, 'yyyyMMddHHmmss')))) AS STRING) AS id,
    b.auth_txn_guid,
    b.card_proxy,
    b.account_id,
    b.account_type,
    b.account_category,
    b.system_type,
    b.card_id,
    b.auth_time,
    b.program_name,
    b.merchant_country,
    b.request_code,
    b.request_description,
    b.response_code,
    b.reason_code,
    b.txn_amount,
    b.settle_amount,
    b.txn_currency,
    b.merchant_name,
    b.mcc,
    b.card_org,
    b.is_dom,
    b.is_decline,
    b.is_account_verification,
    b.is_excluded_request,
    COALESCE(d.sale_id, r.sale_id) AS sale_id,
    COALESCE(d.am_id, r.am_id) AS am_id,
    b.source_table,
    1 AS version,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_auth_base b
LEFT JOIN v_auth_direct_sale_relation d
    ON d.auth_txn_guid = b.auth_txn_guid
LEFT JOIN v_auth_root_sale_relation r
    ON r.auth_txn_guid = b.auth_txn_guid
   AND d.auth_txn_guid IS NULL
WHERE b.auth_time IS NOT NULL
  AND b.account_id IS NOT NULL;

CREATE TEMPORARY TABLE sink_dwm_bb_card_auth_detail_v2_p (
    id                      STRING,
    auth_txn_guid           STRING,
    card_proxy              STRING,
    account_id              STRING,
    account_type            STRING,
    account_category        STRING,
    system_type             STRING,
    card_id                 STRING,
    auth_time               TIMESTAMP(6),
    program_name            STRING,
    merchant_country        STRING,
    request_code            STRING,
    request_description     STRING,
    response_code           STRING,
    reason_code             STRING,
    txn_amount              STRING,
    settle_amount           STRING,
    txn_currency            STRING,
    merchant_name           STRING,
    mcc                     STRING,
    card_org                STRING,
    is_dom                  BOOLEAN,
    is_decline              BOOLEAN,
    is_account_verification BOOLEAN,
    is_excluded_request     BOOLEAN,
    sale_id                 STRING,
    am_id                   STRING,
    source_table            STRING,
    version                 INT,
    create_time             TIMESTAMP(6),
    update_time             TIMESTAMP(6),
    delete_time             TIMESTAMP(6),
    PRIMARY KEY (id, auth_time) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dwm_bb_card_auth_detail_v2_p',
    'targetSchema' = 'dwm',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dwm_bb_card_auth_detail_v2_p
SELECT * FROM v_dwm_bb_card_auth_detail_v2;
