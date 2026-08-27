--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-25 00:00:00
-- Updated Time:   2026-08-25 18:00:00
-- Description:    量子卡交易大宽表批量初始化/回刷（多 JDBC source）
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'sink.parallelism' = '1';
-- 多 source + Lookup Join 需要更多网络 buffer，避免 TaskManager 初始化阶段失败。
SET 'taskmanager.memory.network.fraction' = '0.20';
SET 'taskmanager.memory.network.min' = '256mb';
SET 'taskmanager.memory.network.max' = '512mb';
SET 'table.dml-sync' = 'true';
SET 'execution.checkpointing.interval' = '5min';
SET 'execution.checkpointing.timeout' = '30min';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '1';
SET 'restart-strategy.fixed-delay.delay' = '60s';

-- 交易 source：只负责按 createTime 读取交易事实，不在 JDBC 查询中关联维度。
CREATE TEMPORARY TABLE source_qbit_card_transaction (
    id STRING,
    account_id STRING,
    card_id STRING,
    provider STRING,
    business_type STRING,
    status STRING,
    display_status STRING,
    currency STRING,
    settle_amount DECIMAL(20,4),
    original_amount DECIMAL(20,4),
    transaction_currency STRING,
    transaction_amount DECIMAL(20,4),
    fee DECIMAL(20,4),
    detail STRING,
    source_id STRING,
    transaction_time TIMESTAMP(6),
    complete_time TIMESTAMP(6),
    transaction_ref_id STRING,
    related_qbit_tx_id STRING,
    payment_label STRING,
    platform_label STRING,
    second_label STRING,
    comments STRING,
    authorization_code STRING,
    is_show BOOLEAN,
    released BOOLEAN,
    third_complete_time TIMESTAMP(6),
    special_source_data STRING,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    version INT,
    proc_time AS PROCTIME(),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT "id"::text AS id, "accountId"::text AS account_id, "cardId"::text AS card_id, "provider"::text AS provider, "businessType"::text AS business_type, "status"::text AS status, "displayStatus"::text AS display_status, "currency"::text AS currency, "settleAmount"::numeric(20,4) AS settle_amount, "originalAmount"::numeric(20,4) AS original_amount, "transactionCurrency"::text AS transaction_currency, "transactionAmount"::numeric(20,4) AS transaction_amount, "fee"::numeric(20,4) AS fee, "detail"::text AS detail, "sourceId"::text AS source_id, "transactionTime" AS transaction_time, "completeTime" AS complete_time, "transactionId"::text AS transaction_ref_id, "relatedQbitTxId"::text AS related_qbit_tx_id, "paymentLabel"::text AS payment_label, "platformLabel"::text AS platform_label, "secondLabel"::text AS second_label, "comments"::text AS comments, "authorizationCode"::text AS authorization_code, "isShow" AS is_show, "released" AS released, "thirdCompleteTime" AS third_complete_time, "specialSourceData"::text AS special_source_data, "createTime" AS create_time, "updateTime" AS update_time, "deleteTime" AS delete_time, COALESCE("version", 1) AS version FROM public."qbit_card_transaction" WHERE "createTime" >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND "createTime" < CAST(''${end_time}'' AS TIMESTAMP(6))) AS qbit_card_transaction_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

-- 卡维度 Lookup：按交易 card_id 点查，不全量扫描卡表。
CREATE TEMPORARY TABLE lookup_qbit_card (
    id STRING, `qbitCardNoLastFour` STRING, provider STRING, `type` STRING, label STRING,
    `groupId` STRING, `balanceId` STRING, `firstSix` STRING, `cardBelong` STRING,
    `physicalCardStatus` STRING, `cardMode` STRING, status STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc', 'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'public."qbitCard"', 'username' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver', 'lookup.cache.max-rows' = '200000', 'lookup.cache.ttl' = '30 min'
);

-- 卡组维度 Lookup：按 qbitCard.group_id 点查。
CREATE TEMPORARY TABLE lookup_qbit_card_group (
    id STRING, `groupName` STRING, status STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc', 'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'public."qbitCardGroup"', 'username' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver', 'lookup.cache.max-rows' = '100000', 'lookup.cache.ttl' = '30 min'
);

-- 账户维度 Lookup；注册国家实际来自 account.country。
CREATE TEMPORARY TABLE lookup_account (
    id STRING, `verifiedName` STRING, `parentAccountId` STRING, `accountType` STRING,
    country STRING, `referralCodeId` STRING, `type` STRING, `displayId` STRING, `tenantId` BIGINT,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc', 'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'public."account"', 'username' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver', 'lookup.cache.max-rows' = '200000', 'lookup.cache.ttl' = '30 min'
);

-- 根账户关系 Lookup。
CREATE TEMPORARY TABLE lookup_api_account_relation (
    account_id STRING, root_id STRING, delete_time TIMESTAMP(6),
    PRIMARY KEY (account_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc', 'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'public.api_account_relation', 'username' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver', 'lookup.cache.max-rows' = '200000', 'lookup.cache.ttl' = '30 min'
);

-- 销售关系 source：由 Flink 按交易发生时间计算直接关系和根账户关系。
CREATE TEMPORARY TABLE source_sale_account_relation (
    id STRING, relation_account_id STRING, sale_id STRING, am_id STRING, operation_manager_id STRING,
    relation_start_time TIMESTAMP(6), relation_end_time TIMESTAMP(6), delete_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc', 'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id::text AS id, relation_account_id::text AS relation_account_id, sale_id::text AS sale_id, am_id::text AS am_id, operation_manager_id::text AS operation_manager_id, relation_start_time, relation_end_time, delete_time FROM dim.dim_sale_account_relation_p) AS sale_account_relation_f', 'username' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver', 'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_transaction_base AS
SELECT
    qt.*,
    qc.`qbitCardNoLastFour` AS card_no_last_four, qc.provider AS card_provider, qc.`type` AS card_type_dim,
    qc.label, qc.`groupId` AS group_id, qc.`balanceId` AS balance_id, qc.`firstSix` AS first_six,
    qc.`cardBelong` AS card_belong, qc.`physicalCardStatus` AS physical_card_status, qc.`cardMode` AS card_mode,
    qc.status AS card_status, qcg.`groupName` AS group_name, qcg.status AS group_status,
    acc.`verifiedName` AS acc_verified_name, acc.`parentAccountId` AS parent_account_id,
    acc.`accountType` AS account_type, acc.country AS acc_country, acc.`referralCodeId` AS referral_code_id,
    acc.`type` AS acc_type, acc.`displayId` AS acc_display_id, acc.`tenantId` AS tenant_id,
    COALESCE(aar.root_id, qt.account_id) AS root_account_id,
    JSON_VALUE(qt.special_source_data, '$.authorizationTime') AS spc_authorization_time_string,
    JSON_VALUE(qt.special_source_data, '$.authorizationDate') AS spc_authorization_date_string,
    JSON_VALUE(qt.special_source_data, '$.thirdpartySettleAmount') AS spc_thirdparty_settle_amount_string,
    COALESCE(JSON_VALUE(qt.special_source_data, '$.markupFee'), JSON_VALUE(qt.special_source_data, '$.markUpFee')) AS spc_markup_fee_string,
    JSON_VALUE(qt.special_source_data, '$.qbitCardRechargeType') AS spc_qbit_card_recharge_type,
    JSON_VALUE(qt.special_source_data, '$.transactionId') AS spc_transaction_id,
    JSON_VALUE(qt.special_source_data, '$.merchantSourceAmount') AS spc_merchant_source_amount_string,
    JSON_VALUE(qt.special_source_data, '$.date') AS spc_date_string,
    COALESCE(JSON_VALUE(qt.special_source_data, '$.card_acceptor.name'), JSON_VALUE(qt.special_source_data, '$.name'), JSON_VALUE(qt.special_source_data, '$.merchName')) AS spc_merchant_name,
    COALESCE(JSON_VALUE(qt.special_source_data, '$.card_acceptor.mid'), JSON_VALUE(qt.special_source_data, '$.mid')) AS spc_mid,
    COALESCE(JSON_VALUE(qt.special_source_data, '$.card_acceptor.mcc'), JSON_VALUE(qt.special_source_data, '$.mcc')) AS spc_mcc,
    COALESCE(JSON_VALUE(qt.special_source_data, '$.card_acceptor.city'), JSON_VALUE(qt.special_source_data, '$.city')) AS spc_city,
    COALESCE(JSON_VALUE(qt.special_source_data, '$.card_acceptor.country'), JSON_VALUE(qt.special_source_data, '$.country')) AS spc_country,
    COALESCE(JSON_VALUE(qt.special_source_data, '$.card_acceptor.state'), JSON_VALUE(qt.special_source_data, '$.state')) AS spc_state,
    COALESCE(JSON_VALUE(qt.special_source_data, '$.card_acceptor.zip_code'), JSON_VALUE(qt.special_source_data, '$.zipCode'), JSON_VALUE(qt.special_source_data, '$.merchPostCode')) AS spc_zip_code,
    JSON_QUERY(qt.special_source_data, '$.code') AS business_code_list,
    JSON_VALUE(qt.special_source_data, '$.systemTraceAuditNumber') AS spc_system_trace_audit_no,
    JSON_VALUE(qt.special_source_data, '$.failReason') AS spc_fail_reason
FROM source_qbit_card_transaction qt
LEFT JOIN lookup_qbit_card FOR SYSTEM_TIME AS OF qt.proc_time qc ON qc.id = qt.card_id
LEFT JOIN lookup_qbit_card_group FOR SYSTEM_TIME AS OF qt.proc_time qcg ON qcg.id = qc.`groupId`
LEFT JOIN lookup_account FOR SYSTEM_TIME AS OF qt.proc_time acc ON acc.id = qt.account_id
LEFT JOIN lookup_api_account_relation FOR SYSTEM_TIME AS OF qt.proc_time aar ON aar.account_id = qt.account_id AND aar.delete_time IS NULL;

CREATE TEMPORARY VIEW v_direct_sale_relation AS
SELECT txn_id, sale_id, am_id, operation_manager_id
FROM (
    SELECT b.id AS txn_id, sr.sale_id, sr.am_id, sr.operation_manager_id,
           ROW_NUMBER() OVER (PARTITION BY b.id ORDER BY sr.relation_start_time DESC, sr.id DESC) AS rn
    FROM v_transaction_base b
    INNER JOIN source_sale_account_relation sr
        ON sr.relation_account_id = b.account_id
       AND sr.delete_time IS NULL
       AND b.transaction_time >= sr.relation_start_time
       AND (b.transaction_time < sr.relation_end_time OR sr.relation_end_time IS NULL)
) ranked
WHERE rn = 1;

CREATE TEMPORARY VIEW v_root_sale_relation AS
SELECT txn_id, sale_id, am_id, operation_manager_id
FROM (
    SELECT b.id AS txn_id, sr.sale_id, sr.am_id, sr.operation_manager_id,
           ROW_NUMBER() OVER (PARTITION BY b.id ORDER BY sr.relation_start_time DESC, sr.id DESC) AS rn
    FROM v_transaction_base b
    INNER JOIN source_sale_account_relation sr
        ON sr.relation_account_id = b.root_account_id
       AND sr.delete_time IS NULL
       AND b.transaction_time >= sr.relation_start_time
       AND (b.transaction_time < sr.relation_end_time OR sr.relation_end_time IS NULL)
) ranked
WHERE rn = 1;

CREATE TEMPORARY VIEW v_qbit_card_transaction_widetable AS
SELECT
    b.id, b.account_id, b.card_id, b.provider, b.business_type, b.status, b.display_status, b.currency,
    b.settle_amount, b.original_amount, b.transaction_currency, b.transaction_amount, b.fee, b.detail, b.source_id,
    b.transaction_time, b.complete_time, b.transaction_ref_id, b.related_qbit_tx_id, b.payment_label, b.platform_label,
    b.second_label, b.comments, b.authorization_code, b.is_show, b.released, b.third_complete_time, b.special_source_data,
    CAST(b.spc_authorization_time_string AS TIMESTAMP(6)) AS spc_authorization_time,
    CAST(b.spc_authorization_date_string AS DATE) AS spc_authorization_date,
    CAST(b.spc_thirdparty_settle_amount_string AS DECIMAL(20,4)) AS spc_thirdparty_settle_amount,
    CAST(b.spc_markup_fee_string AS DECIMAL(20,4)) AS spc_markup_fee,
    b.spc_qbit_card_recharge_type, b.spc_transaction_id, CAST(b.spc_merchant_source_amount_string AS DECIMAL(20,4)) AS spc_merchant_source_amount,
    CAST(b.spc_date_string AS DATE) AS spc_date, b.spc_merchant_name, b.spc_mid, b.spc_mcc, b.spc_city, b.spc_country,
    b.spc_state, b.spc_zip_code, b.business_code_list, b.spc_system_trace_audit_no, b.spc_fail_reason,
    b.card_no_last_four, b.card_provider, b.card_type_dim, b.label, b.group_id, b.balance_id, b.first_six, b.card_belong,
    b.physical_card_status, b.card_mode, b.card_status, b.group_name, b.group_status, b.acc_verified_name,
    b.parent_account_id, b.account_type, b.acc_country, b.referral_code_id, b.acc_type, b.acc_display_id, b.tenant_id,
    b.root_account_id, COALESCE(d.sale_id, r.sale_id) AS sale_id, COALESCE(d.am_id, r.am_id) AS am_id,
    COALESCE(d.operation_manager_id, r.operation_manager_id) AS operation_manager_id,
    b.create_time, b.update_time, b.delete_time, b.version
FROM v_transaction_base b
LEFT JOIN v_direct_sale_relation d ON d.txn_id = b.id
LEFT JOIN v_root_sale_relation r ON r.txn_id = b.id AND d.txn_id IS NULL;

CREATE TEMPORARY TABLE sink_qbit_card_transaction_widetable (
    id STRING, account_id STRING, card_id STRING, provider STRING, business_type STRING, status STRING, display_status STRING, currency STRING,
    settle_amount DECIMAL(20,4), original_amount DECIMAL(20,4), transaction_currency STRING, transaction_amount DECIMAL(20,4), fee DECIMAL(20,4), detail STRING,
    source_id STRING, transaction_time TIMESTAMP(6), complete_time TIMESTAMP(6), transaction_ref_id STRING, related_qbit_tx_id STRING,
    payment_label STRING, platform_label STRING, second_label STRING, comments STRING, authorization_code STRING, is_show BOOLEAN, released BOOLEAN,
    third_complete_time TIMESTAMP(6), special_source_data STRING, spc_authorization_time TIMESTAMP(6), spc_authorization_date DATE,
    spc_thirdparty_settle_amount DECIMAL(20,4), spc_markup_fee DECIMAL(20,4), spc_qbit_card_recharge_type STRING, spc_transaction_id STRING,
    spc_merchant_source_amount DECIMAL(20,4), spc_date DATE, spc_merchant_name STRING, spc_mid STRING, spc_mcc STRING, spc_city STRING,
    spc_country STRING, spc_state STRING, spc_zip_code STRING, business_code_list STRING, spc_system_trace_audit_no STRING, spc_fail_reason STRING,
    card_no_last_four STRING, card_provider STRING, card_type_dim STRING, label STRING, group_id STRING, balance_id STRING, first_six STRING,
    card_belong STRING, physical_card_status STRING, card_mode STRING, card_status STRING, group_name STRING, group_status STRING,
    acc_verified_name STRING, parent_account_id STRING, account_type STRING, acc_country STRING, referral_code_id STRING, acc_type STRING,
    acc_display_id STRING, tenant_id BIGINT, root_account_id STRING, sale_id STRING, am_id STRING, operation_manager_id STRING,
    create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version INT,
    PRIMARY KEY (id, create_time) NOT ENFORCED
) WITH (
    'connector' = 'adbpg', 'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'targetSchema' = 'dwm', 'tableName' = 'dwm_quantum_card_transaction_p', 'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}', 'writeMode' = 'upsert', 'batchSize' = '500', 'retryWaitTime' = '5000'
);

INSERT INTO sink_qbit_card_transaction_widetable
SELECT * FROM v_qbit_card_transaction_widetable;
