--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-25 00:00:00
-- Updated Time:   2026-08-31 00:10:00
-- Description:    量子卡交易大宽表两小时窗口增量回刷
--
-- 口径：
--   1. 每次执行读取当前时间前 2 小时至当前时间的 qbit_card_transaction_2026q3。
--   2. INSERT 读取当时 lookup 到的卡/卡组/账户/销售字段并固化。
--   3. UPDATE 读取目标宽表已有维度字段，只替换交易主表字段。
--   4. qbitCard、account、accountExtend 使用 ODS 表做 JDBC Lookup；qbitCardGroup 直接查询物理表并将 UUID 转为 text。
--   5. business_code_list 直接来自 specialSourceData.code。
--   6. qbit_card_group_transaction 不加入本宽表，避免一对多展开。
--   7. 本脚本是按两小时调度的 JDBC 增量回刷，不使用 replication slot；调度窗口为当前时间前 2 小时至当前时间。
--
--   8. api_account_relation、dim_sale_account_relation_p 和宽表历史快照继续使用 JDBC Lookup。
--
-- 注意：qbitCard、account、accountExtend 的 ODS 同步任务需先正常运行；本脚本由平台每两小时调度一次。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'sink.parallelism' = '1';
-- 关闭算子链，便于在 VVP 运行图中分别观察 Source / LookupJoin / Calc / Sink。
SET 'pipeline.operator-chaining' = 'false';
SET 'table.exec.sink.not-null-enforcer' = 'DROP';
-- 两小时窗口一次性读取，使用 JDBC Source，不启用 MiniBatch。
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'table.dml-sync' = 'true';
SET 'execution.batch-shuffle-mode' = 'ALL_EXCHANGES_BLOCKING';
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
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.PG_TEST_HOST}:${secret_values.PG_TEST_PORT1}/${secret_values.PG_TEST_DATABASE}',
    'table-name' = '(SELECT "id"::text AS id, "accountId"::text AS accountid, "cardId"::text AS cardid, "provider" AS provider, "businessType" AS businesstype, status AS status, "displayStatus" AS displaystatus, currency AS currency, CAST("settleAmount" AS numeric(20,4)) AS settleamount, CAST("originalAmount" AS numeric(20,4)) AS originalamount, "transactionCurrency" AS transactioncurrency, CAST("transactionAmount" AS numeric(20,4)) AS transactionamount, CAST(fee AS numeric(20,4)) AS fee, detail AS detail, "sourceId" AS sourceid, "transactionTime" AS transactiontime, "completeTime" AS completetime, "transactionId"::text AS transactionid, "relatedQbitTxId"::text AS relatedqbittxid, "paymentLabel" AS paymentlabel, "platformLabel" AS platformlabel, "secondLabel" AS secondlabel, comments AS comments, "authorizationCode" AS authorizationcode, "isShow" AS isshow, released AS released, "thirdCompleteTime" AS thirdcompletetime, "specialSourceData"::text AS specialsourcedata, "createTime" AS createtime, "updateTime" AS updatetime, "deleteTime" AS deletetime, version AS version FROM public."qbit_card_transaction_2026q3" WHERE (("createTime" >= CURRENT_TIMESTAMP - INTERVAL ''2 hours'' AND "createTime" < CURRENT_TIMESTAMP) OR ("updateTime" >= CURRENT_TIMESTAMP - INTERVAL ''2 hours'' AND "updateTime" < CURRENT_TIMESTAMP))) AS qbit_card_transaction_2h_f',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000',
    'scan.auto-commit' = 'false'
);

-- 所有维度 JDBC Source 均在数据库侧限制到当前两小时窗口，避免普通 JOIN 扫描全表。

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
    'table-name' = '(SELECT qc.id, qc.qbit_card_no_last_four, qc.provider, qc.type, qc.label, qc.group_id, qc.balance_id, qc.first_six, qc.card_belong, qc.physical_card_status, qc.card_mode, qc.status FROM ods.ods_qbit_card qc WHERE EXISTS (SELECT 1 FROM public."qbit_card_transaction_2026q3" qt WHERE qt."cardId"::text = qc.id::text AND ((qt."createTime" >= CURRENT_TIMESTAMP - INTERVAL ''2 hours'' AND qt."createTime" < CURRENT_TIMESTAMP) OR (qt."updateTime" >= CURRENT_TIMESTAMP - INTERVAL ''2 hours'' AND qt."updateTime" < CURRENT_TIMESTAMP)))) AS qbit_card_dim_2h_f',
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
    -- 子查询先将 UUID 主键转为 text，避免 JDBC Lookup 生成 uuid = varchar。
    'table-name' = '(SELECT qcg."id"::text AS id, qcg."groupName" AS groupname, qcg.status AS status FROM public."qbitCardGroup" qcg WHERE EXISTS (SELECT 1 FROM public."qbit_card_transaction_2026q3" qt INNER JOIN ods.ods_qbit_card qc ON qt."cardId"::text = qc.id::text WHERE qc.group_id::text = qcg."id"::text AND ((qt."createTime" >= CURRENT_TIMESTAMP - INTERVAL ''2 hours'' AND qt."createTime" < CURRENT_TIMESTAMP) OR (qt."updateTime" >= CURRENT_TIMESTAMP - INTERVAL ''2 hours'' AND qt."updateTime" < CURRENT_TIMESTAMP)))) AS qbit_card_group_2h_f',
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
    'table-name' = '(SELECT acc.id, acc.verified_name, acc.parent_account_id, acc.account_type, acc.verified_name_en, acc.country, acc.referral_code_id, acc.type, acc.display_id, acc.tenant_id FROM ods.ods_account acc WHERE EXISTS (SELECT 1 FROM public."qbit_card_transaction_2026q3" qt WHERE qt."accountId"::text = acc.id::text AND ((qt."createTime" >= CURRENT_TIMESTAMP - INTERVAL ''2 hours'' AND qt."createTime" < CURRENT_TIMESTAMP) OR (qt."updateTime" >= CURRENT_TIMESTAMP - INTERVAL ''2 hours'' AND qt."updateTime" < CURRENT_TIMESTAMP)))) AS account_dim_2h_f',
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
    'table-name' = '(SELECT ae.account_id, ae.system_type FROM ods.ods_account_extend ae WHERE EXISTS (SELECT 1 FROM public."qbit_card_transaction_2026q3" qt WHERE qt."accountId"::text = ae.account_id::text AND ((qt."createTime" >= CURRENT_TIMESTAMP - INTERVAL ''2 hours'' AND qt."createTime" < CURRENT_TIMESTAMP) OR (qt."updateTime" >= CURRENT_TIMESTAMP - INTERVAL ''2 hours'' AND qt."updateTime" < CURRENT_TIMESTAMP)))) AS account_extend_2h_f',
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
    'table-name' = '(SELECT aar.account_id::text AS account_id, aar.root_id::text AS root_id FROM public.api_account_relation aar WHERE EXISTS (SELECT 1 FROM public."qbit_card_transaction_2026q3" qt WHERE qt."accountId"::text = aar.account_id::text AND ((qt."createTime" >= CURRENT_TIMESTAMP - INTERVAL ''2 hours'' AND qt."createTime" < CURRENT_TIMESTAMP) OR (qt."updateTime" >= CURRENT_TIMESTAMP - INTERVAL ''2 hours'' AND qt."updateTime" < CURRENT_TIMESTAMP)))) AS api_account_relation_2h_f',
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
    'table-name' = '(WITH tx_accounts AS (SELECT DISTINCT qt."accountId"::text AS account_id FROM public."qbit_card_transaction_2026q3" qt WHERE ("createTime" >= CURRENT_TIMESTAMP - INTERVAL ''2 hours'' AND "createTime" < CURRENT_TIMESTAMP) OR ("updateTime" >= CURRENT_TIMESTAMP - INTERVAL ''2 hours'' AND "updateTime" < CURRENT_TIMESTAMP)), relation_accounts AS (SELECT account_id FROM tx_accounts UNION SELECT aar.root_id::text FROM tx_accounts ta INNER JOIN public.api_account_relation aar ON aar.account_id::text = ta.account_id AND aar.delete_time IS NULL) SELECT sr.relation_account_id::text AS relation_account_id, sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, sr.operation_manager_id::text AS operation_manager_id FROM dim.dim_sale_account_relation_p sr INNER JOIN relation_accounts ra ON ra.account_id = sr.relation_account_id::text) AS sale_account_relation_2h_f',
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
    'table-name' = '(SELECT id::text AS id, create_time, card_no_last_four, card_provider, card_type_dim, label, group_id::text AS group_id, balance_id::text AS balance_id, first_six, card_belong, physical_card_status, card_mode, card_status, group_name, group_status, acc_verified_name, parent_account_id::text AS parent_account_id, account_type, system_type, acc_verified_name_en, acc_country, referral_code_id, acc_type, acc_display_id, tenant_id, root_account_id::text AS root_account_id, sale_id, am_id, operation_manager_id FROM dwm.dwm_quantum_card_transaction_p WHERE (create_time >= CURRENT_TIMESTAMP - INTERVAL ''2 hours'' AND create_time < CURRENT_TIMESTAMP) OR (update_time >= CURRENT_TIMESTAMP - INTERVAL ''2 hours'' AND update_time < CURRENT_TIMESTAMP)) AS dwm_qbit_card_transaction_snapshot_2h_f',
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
LEFT JOIN lookup_qbit_card qc
    ON qc.id = qt.`cardId`
LEFT JOIN lookup_qbit_card_group qcg
    ON qcg.id = qc.group_id
LEFT JOIN lookup_account acc
    ON acc.id = qt.`accountId`
LEFT JOIN lookup_account_extend ae
    ON ae.account_id = qt.`accountId`
LEFT JOIN lookup_api_account_relation aar
    ON aar.account_id = qt.`accountId`
LEFT JOIN lookup_sale_relation sr
    ON sr.relation_account_id = qt.`accountId`
LEFT JOIN lookup_sale_relation root_sr
    ON root_sr.relation_account_id = COALESCE(aar.root_id, qt.`accountId`)
LEFT JOIN lookup_wide_snapshot AS hist
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
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'tableName' = 'dwm_quantum_card_transaction_p',
    'targetSchema' = 'dwm',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '1000'
);

INSERT INTO sink_quantum_card_transaction_widetable
SELECT * FROM v_quantum_card_transaction_widetable;
