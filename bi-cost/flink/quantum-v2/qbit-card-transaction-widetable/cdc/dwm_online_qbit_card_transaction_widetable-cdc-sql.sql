--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-25 00:00:00
-- Updated Time:   2026-08-30 03:50:00
-- Description:    量子卡交易大宽表 CDC
--
-- 口径：
--   1. 只有当前交易子分区 qbit_card_transaction_2026q3 是驱动 CDC 源。
--   2. INSERT 读取当时 lookup 到的卡/卡组/账户/销售字段并固化。
--   3. UPDATE 读取目标宽表已有维度字段，只替换交易主表字段。
--   4. qbitCard、account、accountExtend 使用 ODS 表做 JDBC Lookup；qbitCardGroup 直接查询 ADB PG public."qbitCardGroup"。
--   5. business_code_list 直接来自 specialSourceData.code。
--   6. qbit_card_group_transaction 不加入本宽表，避免一对多展开。
--   7. CDC 使用 latest-offset，仅处理任务进入 RUNNING 后的交易变更；历史缺口由 Batch 补齐至该时刻。
--
--   8. api_account_relation、dim_sale_account_relation_p 和宽表历史快照继续使用 JDBC Lookup。
--
-- 注意：qbitCard、account、accountExtend 的 ODS 同步任务需先正常运行；当前 JDBC 用户需具备 public."qbitCardGroup" 查询权限。
--********************************************************************--

SET 'parallelism.default' = '2';
SET 'sink.parallelism' = '1';
-- 关闭算子链，便于在 VVP 运行图中分别观察 Source / LookupJoin / Calc / Sink。
SET 'pipeline.operator-chaining' = 'false';
SET 'table.exec.sink.not-null-enforcer' = 'DROP';
-- CDC 逐条处理，不启用 MiniBatch，避免下游批量缓冲造成观测延迟。
SET 'table.exec.mini-batch.enabled' = 'false';
-- JDBC Lookup 右表不等待完整快照，避免处理时间 Temporal Join 在启动阶段被拒绝。
-- 交易到达而维度 Lookup 尚未就绪时，对应维度字段可能为 NULL；应先确保 ODS 维表已可查询。
SET 'table.exec.proc-time-temporal-join.no-wait' = 'true';
SET 'table.dml-sync' = 'true';
SET 'execution.checkpointing.interval' = '60s';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'execution.checkpointing.timeout' = '10min';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

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
    -- CDC 源恢复使用已验证具备 replication 权限的 PG_TEST 配置。
    'hostname' = '${secret_values.PG_TEST_HOST}',
    'port' = '${secret_values.PG_TEST_PORT1}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'database-name' = '${secret_values.PG_TEST_DATABASE}',
    'schema-name' = 'public',
    -- 源表为当前实际写入的 2026 Q3 子分区；无需创建专用 Publication。
    'table-name' = 'qbit_card_transaction_2026q3',
    -- 子分区独立 Slot；进入 RUNNING 的时刻即为 Batch 补数截止点。
    'slot.name' = 'flink_slot_quantum_card_transaction_widetable_2026q3_v1',
    'decoding.plugin.name' = 'pgoutput',
    'debezium.publication.name' = 'flink_cdc_publication',
    'debezium.connector.pgout.publication.autocreate' = 'false',
    'debezium.slot.drop.on.stop' = 'false',
    -- Batch 补齐交接时刻之前的历史数据；CDC 从该 Slot 建立后的最新位点接收增量。
    'scan.startup.mode' = 'latest-offset',
    -- 当前 Flink CDC 版本要求 latest-offset 配合增量快照开关开启。
    'scan.incremental.snapshot.enabled' = 'true',
    'scan.incremental.snapshot.chunk.size' = '50000',
    'debezium.database.jdbc.max.size' = '3',
    'debezium.database.jdbc.idle.timeout.ms' = '60000',
    'heartbeat.interval.ms' = '30000'
);

-- CDC 不按 createTime 过滤：历史交易在交接后发生 UPDATE 时也应更新宽表交易字段。

-- qbitCard 已由独立 ODS CDC 作业同步为 snake_case，宽表使用 JDBC Lookup。
CREATE TEMPORARY TABLE lookup_qbit_card (
    id STRING,
    qbit_card_no_last_four STRING,
    provider STRING,
    `type` STRING,
    label STRING,
    group_id STRING,
    balance_id STRING,
    first_six STRING,
    card_belong STRING,
    physical_card_status STRING,
    card_mode STRING,
    status STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'ods.ods_qbit_card',
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
    -- 物理表和字段使用驼峰命名，必须保留 PostgreSQL 双引号大小写。
    'table-name' = 'public."qbitCardGroup"',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'lookup.cache.max-rows' = '100000',
    'lookup.cache.ttl' = '10 min'
);

CREATE TEMPORARY TABLE lookup_account (
    id STRING,
    verified_name STRING,
    parent_account_id STRING,
    account_type STRING,
    verified_name_en STRING,
    country STRING,
    referral_code_id STRING,
    `type` STRING,
    display_id STRING,
    tenant_id BIGINT,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'ods.ods_account',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'lookup.cache.max-rows' = '100000',
    'lookup.cache.ttl' = '10 min'
);

CREATE TEMPORARY TABLE lookup_account_extend (
    account_id STRING,
    system_type STRING,
    PRIMARY KEY (account_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'ods.ods_account_extend',
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
    'table-name' = 'public.api_account_relation',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver'
);

-- 销售关系是按账户展开的历史时间线，不能直接作为 Temporal Join 主键表；
-- 它保持 JDBC Lookup，仅由交易事件触发查询。
CREATE TEMPORARY TABLE lookup_sale_relation (
    relation_account_id STRING,
    sale_id STRING,
    am_id STRING,
    operation_manager_id STRING,
    PRIMARY KEY (relation_account_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = 'dim.dim_sale_account_relation_p',
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
    -- 直接读取目标宽表已有记录，用于 UPDATE 时保留已固化维度。
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
    CASE WHEN hist.id IS NOT NULL THEN hist.card_no_last_four ELSE qc.qbit_card_no_last_four END AS card_no_last_four,
    CASE WHEN hist.id IS NOT NULL THEN hist.card_provider ELSE qc.provider END AS card_provider,
    CASE WHEN hist.id IS NOT NULL THEN hist.card_type_dim ELSE qc.`type` END AS card_type_dim,
    CASE WHEN hist.id IS NOT NULL THEN hist.label ELSE qc.label END AS label,
    CASE WHEN hist.id IS NOT NULL THEN hist.group_id ELSE qc.group_id END AS group_id,
    CASE WHEN hist.id IS NOT NULL THEN hist.balance_id ELSE qc.balance_id END AS balance_id,
    CASE WHEN hist.id IS NOT NULL THEN hist.first_six ELSE qc.first_six END AS first_six,
    CASE WHEN hist.id IS NOT NULL THEN hist.card_belong ELSE qc.card_belong END AS card_belong,
    CASE WHEN hist.id IS NOT NULL THEN hist.physical_card_status ELSE qc.physical_card_status END AS physical_card_status,
    CASE WHEN hist.id IS NOT NULL THEN hist.card_mode ELSE qc.card_mode END AS card_mode,
    CASE WHEN hist.id IS NOT NULL THEN hist.card_status ELSE qc.status END AS card_status,
    CASE WHEN hist.id IS NOT NULL THEN hist.group_name ELSE qcg.`groupName` END AS group_name,
    CASE WHEN hist.id IS NOT NULL THEN hist.group_status ELSE qcg.status END AS group_status,
    CASE WHEN hist.id IS NOT NULL THEN hist.acc_verified_name ELSE acc.verified_name END AS acc_verified_name,
    CASE WHEN hist.id IS NOT NULL THEN hist.parent_account_id ELSE acc.parent_account_id END AS parent_account_id,
    CASE WHEN hist.id IS NOT NULL THEN hist.account_type ELSE acc.account_type END AS account_type,
    CASE WHEN hist.id IS NOT NULL THEN hist.system_type ELSE ae.system_type END AS system_type,
    CASE WHEN hist.id IS NOT NULL THEN hist.acc_verified_name_en ELSE acc.verified_name_en END AS acc_verified_name_en,
    CASE WHEN hist.id IS NOT NULL THEN hist.acc_country ELSE acc.country END AS acc_country,
    CASE WHEN hist.id IS NOT NULL THEN hist.referral_code_id ELSE acc.referral_code_id END AS referral_code_id,
    CASE WHEN hist.id IS NOT NULL THEN hist.acc_type ELSE acc.`type` END AS acc_type,
    CASE WHEN hist.id IS NOT NULL THEN hist.acc_display_id ELSE acc.display_id END AS acc_display_id,
    CASE WHEN hist.id IS NOT NULL THEN hist.tenant_id ELSE acc.tenant_id END AS tenant_id,
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
    ON qcg.id = qc.group_id
LEFT JOIN lookup_account FOR SYSTEM_TIME AS OF qt.proc_time acc
    ON acc.id = qt.`accountId`
LEFT JOIN lookup_account_extend FOR SYSTEM_TIME AS OF qt.proc_time ae
    ON ae.account_id = qt.`accountId`
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
