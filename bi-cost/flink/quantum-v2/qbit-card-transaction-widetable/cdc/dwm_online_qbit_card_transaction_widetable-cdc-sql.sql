--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-25 00:00:00
-- Updated Time:   2026-08-25 00:00:00
-- Description:    量子卡交易大宽表 CDC
--
-- 口径：
--   1. 只有 qbit_card_transaction 是驱动 CDC 源。
--   2. INSERT 读取当时 lookup 到的卡/卡组/账户/销售字段并固化。
--   3. UPDATE 读取目标宽表已有维度字段，只替换交易主表字段。
--   4. 维度表不注册为普通 CDC JOIN，维度变更不会反向更新历史交易。
--   5. business_code_list 直接来自 specialSourceData.code。
--   6. qbit_card_group_transaction 不加入本宽表，避免一对多展开。
--
-- 注意：JDBC lookup 表需要配置主键字段；执行前请按线上 Flink catalog 校准 JSON/UUID 类型。
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

CREATE TEMPORARY TABLE source_qbit_card_transaction (
    id                    STRING,
    `accountId`            STRING,
    `cardId`               STRING,
    provider               STRING,
    `businessType`         STRING,
    status                 STRING,
    `displayStatus`        STRING,
    currency               STRING,
    `settleAmount`         DECIMAL(20, 4),
    `originalAmount`       DECIMAL(20, 4),
    `transactionCurrency`  STRING,
    `transactionAmount`    DECIMAL(20, 4),
    fee                    DECIMAL(20, 4),
    detail                 STRING,
    `sourceId`             STRING,
    `transactionTime`      TIMESTAMP(6),
    `completeTime`         TIMESTAMP(6),
    `transactionId`        STRING,
    `relatedQbitTxId`      STRING,
    `paymentLabel`         STRING,
    `platformLabel`        STRING,
    `secondLabel`          STRING,
    comments               STRING,
    `authorizationCode`    STRING,
    `isShow`               BOOLEAN,
    released               BOOLEAN,
    `thirdCompleteTime`    TIMESTAMP(6),
    `specialSourceData`    STRING,
    `createTime`            TIMESTAMP(6),
    `updateTime`            TIMESTAMP(6),
    `deleteTime`            TIMESTAMP(6),
    version                INT,
    proc_time AS PROCTIME(),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'postgres-cdc',
    'hostname' = '${secret_values.PG_TEST_HOST}',
    'port' = '${secret_values.PG_TEST_PORT1}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'database-name' = '${secret_values.PG_TEST_DATABASE}',
    'schema-name' = 'public',
    'table-name' = 'qbit_card_transaction',
    'slot.name' = 'flink_slot_quantum_card_transaction_widetable',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.connector.pgout.publication.autocreate' = 'false',
    'debezium.slot.drop.on.stop' = 'false',
    'scan.startup.mode' = 'initial',
    'scan.incremental.snapshot.enabled' = 'true',
    'scan.snapshot.fetch.size' = '4096'
);

-- 当前维度 lookup：只由交易事件触发读取，不作为 CDC 驱动源。
CREATE TEMPORARY TABLE lookup_qbit_card (
    id STRING,
    `qbitCardNoLastFour` STRING,
    provider STRING,
    `type` STRING,
    label STRING,
    `groupId` STRING,
    `balanceId` STRING,
    `firstSix` STRING,
    `cardBelong` STRING,
    `physicalCardStatus` STRING,
    `cardMode` STRING,
    status STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'qbitCard',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'lookup.cache.max-rows' = '100000',
    'lookup.cache.ttl' = '10 min'
);

CREATE TEMPORARY TABLE lookup_qbit_card_group (
    id STRING,
    `groupName` STRING,
    status STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'qbitCardGroup',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'lookup.cache.max-rows' = '100000',
    'lookup.cache.ttl' = '10 min'
);

CREATE TEMPORARY TABLE lookup_account (
    id STRING,
    `verifiedName` STRING,
    `parentAccountId` STRING,
    `accountType` STRING,
    `verifiedNameEn` STRING,
    country STRING,
    `referralCodeId` STRING,
    `type` STRING,
    `displayId` STRING,
    `tenantId` BIGINT,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'account',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver'
);

CREATE TEMPORARY TABLE lookup_account_extend (
    `accountId` STRING,
    `systemType` STRING,
    PRIMARY KEY (`accountId`) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'accountExtend',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'lookup.cache.max-rows' = '100000',
    'lookup.cache.ttl' = '10 min'
);

CREATE TEMPORARY TABLE lookup_api_account_relation (
    account_id STRING,
    root_id STRING,
    PRIMARY KEY (account_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'api_account_relation',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver'
);

-- 销售关系按当前生效关系预聚合为 account lookup；维度变化不触发本作业。
CREATE TEMPORARY TABLE lookup_sale_relation (
    relation_account_id STRING,
    sale_id STRING,
    am_id STRING,
    operation_manager_id STRING,
    PRIMARY KEY (relation_account_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT relation_account_id, sale_id, am_id, operation_manager_id FROM dim.dim_sale_account_relation_p WHERE delete_time IS NULL AND relation_start_time <= CURRENT_TIMESTAMP AND (relation_end_time IS NULL OR relation_end_time > CURRENT_TIMESTAMP)) AS sale_relation_lookup',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver'
);

-- 目标宽表已有记录 lookup。UPDATE 时从这里取回冻结的维度字段。
CREATE TEMPORARY TABLE lookup_wide_snapshot (
    id STRING,
    create_time TIMESTAMP(6),
    card_no_last_four STRING,
    card_provider STRING,
    card_type_dim STRING,
    label STRING,
    group_id STRING,
    balance_id STRING,
    first_six STRING,
    card_belong STRING,
    physical_card_status STRING,
    card_mode STRING,
    card_status STRING,
    group_name STRING,
    group_status STRING,
    acc_verified_name STRING,
    parent_account_id STRING,
    account_type STRING,
    system_type STRING,
    acc_verified_name_en STRING,
    acc_country STRING,
    referral_code_id STRING,
    acc_type STRING,
    acc_display_id STRING,
    tenant_id BIGINT,
    root_account_id STRING,
    sale_id STRING,
    am_id STRING,
    operation_manager_id STRING,
    PRIMARY KEY (id, create_time) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'dwm.dwm_quantum_card_transaction_p',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'lookup.cache.max-rows' = '200000',
    'lookup.cache.ttl' = '10 min'
);

-- 交易字段始终来自 qt；维度字段只有新记录才使用 lookup，已有记录保留 hist 快照。
CREATE TEMPORARY VIEW v_quantum_card_transaction_widetable AS
SELECT
    qt.id,
    qt.`accountId` AS account_id,
    qt.`cardId` AS card_id,
    qt.provider,
    qt.`businessType` AS business_type,
    qt.status,
    qt.`displayStatus` AS display_status,
    qt.currency,
    qt.`settleAmount` AS settle_amount,
    qt.`originalAmount` AS original_amount,
    qt.`transactionCurrency` AS transaction_currency,
    qt.`transactionAmount` AS transaction_amount,
    qt.fee,
    qt.detail,
    qt.`sourceId` AS source_id,
    qt.`transactionTime` AS transaction_time,
    qt.`completeTime` AS complete_time,
    qt.`transactionId` AS transaction_ref_id,
    qt.`relatedQbitTxId` AS related_qbit_tx_id,
    qt.`paymentLabel` AS payment_label,
    qt.`platformLabel` AS platform_label,
    qt.`secondLabel` AS second_label,
    qt.comments,
    qt.`authorizationCode` AS authorization_code,
    qt.`isShow` AS is_show,
    qt.released,
    qt.`thirdCompleteTime` AS third_complete_time,
    qt.`specialSourceData` AS special_source_data,
    CAST(JSON_VALUE(qt.`specialSourceData`, '$.authorizationTime') AS TIMESTAMP(6)) AS spc_authorization_time,
    CAST(JSON_VALUE(qt.`specialSourceData`, '$.authorizationDate') AS DATE) AS spc_authorization_date,
    CAST(JSON_VALUE(qt.`specialSourceData`, '$.thirdpartySettleAmount') AS DECIMAL(20,4)) AS spc_thirdparty_settle_amount,
    CAST(COALESCE(JSON_VALUE(qt.`specialSourceData`, '$.markupFee'), JSON_VALUE(qt.`specialSourceData`, '$.markUpFee')) AS DECIMAL(20,4)) AS spc_markup_fee,
    JSON_VALUE(qt.`specialSourceData`, '$.qbitCardRechargeType') AS spc_qbit_card_recharge_type,
    JSON_VALUE(qt.`specialSourceData`, '$.transactionId') AS spc_transaction_id,
    CAST(JSON_VALUE(qt.`specialSourceData`, '$.merchantSourceAmount') AS DECIMAL(20,4)) AS spc_merchant_source_amount,
    CAST(JSON_VALUE(qt.`specialSourceData`, '$.date') AS DATE) AS spc_date,
    COALESCE(JSON_VALUE(qt.`specialSourceData`, '$.card_acceptor.name'), JSON_VALUE(qt.`specialSourceData`, '$.name'), JSON_VALUE(qt.`specialSourceData`, '$.merchName')) AS spc_merchant_name,
    COALESCE(JSON_VALUE(qt.`specialSourceData`, '$.card_acceptor.mid'), JSON_VALUE(qt.`specialSourceData`, '$.mid')) AS spc_mid,
    COALESCE(JSON_VALUE(qt.`specialSourceData`, '$.card_acceptor.mcc'), JSON_VALUE(qt.`specialSourceData`, '$.mcc')) AS spc_mcc,
    COALESCE(JSON_VALUE(qt.`specialSourceData`, '$.card_acceptor.city'), JSON_VALUE(qt.`specialSourceData`, '$.city')) AS spc_city,
    COALESCE(JSON_VALUE(qt.`specialSourceData`, '$.card_acceptor.country'), JSON_VALUE(qt.`specialSourceData`, '$.country')) AS spc_country,
    COALESCE(JSON_VALUE(qt.`specialSourceData`, '$.card_acceptor.state'), JSON_VALUE(qt.`specialSourceData`, '$.state')) AS spc_state,
    COALESCE(JSON_VALUE(qt.`specialSourceData`, '$.card_acceptor.zip_code'), JSON_VALUE(qt.`specialSourceData`, '$.zipCode'), JSON_VALUE(qt.`specialSourceData`, '$.merchPostCode')) AS spc_zip_code,
    JSON_QUERY(qt.`specialSourceData`, '$.code') AS business_code_list,
    JSON_VALUE(qt.`specialSourceData`, '$.systemTraceAuditNumber') AS spc_system_trace_audit_no,
    JSON_VALUE(qt.`specialSourceData`, '$.failReason') AS spc_fail_reason,
    CASE WHEN hist.id IS NOT NULL THEN hist.card_no_last_four ELSE qc.`qbitCardNoLastFour` END AS card_no_last_four,
    CASE WHEN hist.id IS NOT NULL THEN hist.card_provider ELSE qc.provider END AS card_provider,
    CASE WHEN hist.id IS NOT NULL THEN hist.card_type_dim ELSE qc.`type` END AS card_type_dim,
    CASE WHEN hist.id IS NOT NULL THEN hist.label ELSE qc.label END AS label,
    CASE WHEN hist.id IS NOT NULL THEN hist.group_id ELSE qc.`groupId` END AS group_id,
    CASE WHEN hist.id IS NOT NULL THEN hist.balance_id ELSE qc.`balanceId` END AS balance_id,
    CASE WHEN hist.id IS NOT NULL THEN hist.first_six ELSE qc.`firstSix` END AS first_six,
    CASE WHEN hist.id IS NOT NULL THEN hist.card_belong ELSE qc.`cardBelong` END AS card_belong,
    CASE WHEN hist.id IS NOT NULL THEN hist.physical_card_status ELSE qc.`physicalCardStatus` END AS physical_card_status,
    CASE WHEN hist.id IS NOT NULL THEN hist.card_mode ELSE qc.`cardMode` END AS card_mode,
    CASE WHEN hist.id IS NOT NULL THEN hist.card_status ELSE qc.status END AS card_status,
    CASE WHEN hist.id IS NOT NULL THEN hist.group_name ELSE qcg.`groupName` END AS group_name,
    CASE WHEN hist.id IS NOT NULL THEN hist.group_status ELSE qcg.status END AS group_status,
    CASE WHEN hist.id IS NOT NULL THEN hist.acc_verified_name ELSE acc.`verifiedName` END AS acc_verified_name,
    CASE WHEN hist.id IS NOT NULL THEN hist.parent_account_id ELSE acc.`parentAccountId` END AS parent_account_id,
    CASE WHEN hist.id IS NOT NULL THEN hist.account_type ELSE acc.`accountType` END AS account_type,
    CASE WHEN hist.id IS NOT NULL THEN hist.system_type ELSE ae.`systemType` END AS system_type,
    CASE WHEN hist.id IS NOT NULL THEN hist.acc_verified_name_en ELSE acc.`verifiedNameEn` END AS acc_verified_name_en,
    CASE WHEN hist.id IS NOT NULL THEN hist.acc_country ELSE acc.country END AS acc_country,
    CASE WHEN hist.id IS NOT NULL THEN hist.referral_code_id ELSE acc.`referralCodeId` END AS referral_code_id,
    CASE WHEN hist.id IS NOT NULL THEN hist.acc_type ELSE acc.`type` END AS acc_type,
    CASE WHEN hist.id IS NOT NULL THEN hist.acc_display_id ELSE acc.`displayId` END AS acc_display_id,
    CASE WHEN hist.id IS NOT NULL THEN hist.tenant_id ELSE acc.`tenantId` END AS tenant_id,
    CASE WHEN hist.id IS NOT NULL THEN hist.root_account_id ELSE COALESCE(aar.root_id, qt.`accountId`) END AS root_account_id,
    CASE WHEN hist.id IS NOT NULL THEN hist.sale_id ELSE COALESCE(sr.sale_id, root_sr.sale_id) END AS sale_id,
    CASE WHEN hist.id IS NOT NULL THEN hist.am_id ELSE COALESCE(sr.am_id, root_sr.am_id) END AS am_id,
    CASE WHEN hist.id IS NOT NULL THEN hist.operation_manager_id ELSE COALESCE(sr.operation_manager_id, root_sr.operation_manager_id) END AS operation_manager_id,
    qt.`createTime` AS create_time,
    qt.`updateTime` AS update_time,
    qt.`deleteTime` AS delete_time,
    COALESCE(qt.version, 1) AS version
FROM source_qbit_card_transaction qt
LEFT JOIN lookup_qbit_card FOR SYSTEM_TIME AS OF qt.proc_time qc
    ON qc.id = qt.`cardId`
LEFT JOIN lookup_qbit_card_group FOR SYSTEM_TIME AS OF qt.proc_time qcg
    ON qcg.id = qc.`groupId`
LEFT JOIN lookup_account FOR SYSTEM_TIME AS OF qt.proc_time acc
    ON acc.id = qt.`accountId`
LEFT JOIN lookup_account_extend FOR SYSTEM_TIME AS OF qt.proc_time ae
    ON ae.`accountId` = qt.`accountId`
LEFT JOIN lookup_api_account_relation FOR SYSTEM_TIME AS OF qt.proc_time aar
    ON aar.account_id = qt.`accountId`
LEFT JOIN lookup_sale_relation FOR SYSTEM_TIME AS OF qt.proc_time sr
    ON sr.relation_account_id = qt.`accountId`
LEFT JOIN lookup_sale_relation FOR SYSTEM_TIME AS OF qt.proc_time root_sr
    ON root_sr.relation_account_id = COALESCE(aar.root_id, qt.`accountId`)
LEFT JOIN lookup_wide_snapshot FOR SYSTEM_TIME AS OF qt.proc_time AS hist
    ON hist.id = qt.id AND hist.create_time = qt.`createTime`;

-- 目标 schema 需与 design-docs/qbit-widetable-ddl.sql 的 77 列保持一致。
-- 这里使用显式列清单，避免维度列顺序变化导致误写。
CREATE TEMPORARY TABLE sink_quantum_card_transaction_widetable (
    id STRING, account_id STRING, card_id STRING, provider STRING, business_type STRING, status STRING,
    display_status STRING, currency STRING, settle_amount DECIMAL(20,4), original_amount DECIMAL(20,4),
    transaction_currency STRING, transaction_amount DECIMAL(20,4), fee DECIMAL(20,4), detail STRING,
    source_id STRING, transaction_time TIMESTAMP(6), complete_time TIMESTAMP(6), transaction_ref_id STRING,
    related_qbit_tx_id STRING, payment_label STRING, platform_label STRING, second_label STRING, comments STRING,
    authorization_code STRING, is_show BOOLEAN, released BOOLEAN, third_complete_time TIMESTAMP(6), special_source_data STRING,
    spc_authorization_time TIMESTAMP(6), spc_authorization_date DATE, spc_thirdparty_settle_amount DECIMAL(20,4), spc_markup_fee DECIMAL(20,4),
    spc_qbit_card_recharge_type STRING, spc_transaction_id STRING, spc_merchant_source_amount DECIMAL(20,4), spc_date DATE,
    spc_merchant_name STRING, spc_mid STRING, spc_mcc STRING, spc_city STRING, spc_country STRING, spc_state STRING, spc_zip_code STRING,
    business_code_list STRING, spc_system_trace_audit_no STRING, spc_fail_reason STRING,
    card_no_last_four STRING, card_provider STRING, card_type_dim STRING, label STRING, group_id STRING, balance_id STRING,
    first_six STRING, card_belong STRING, physical_card_status STRING, card_mode STRING, card_status STRING, group_name STRING, group_status STRING,
    acc_verified_name STRING, parent_account_id STRING, account_type STRING, system_type STRING, acc_verified_name_en STRING, acc_country STRING, referral_code_id STRING, acc_type STRING,
    acc_display_id STRING, tenant_id BIGINT, root_account_id STRING, sale_id STRING, am_id STRING, operation_manager_id STRING,
    create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version INT,
    PRIMARY KEY (id, create_time) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dwm_quantum_card_transaction_p',
    'targetSchema' = 'dwm',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '1000'
);

INSERT INTO sink_quantum_card_transaction_widetable
SELECT * FROM v_quantum_card_transaction_widetable;
