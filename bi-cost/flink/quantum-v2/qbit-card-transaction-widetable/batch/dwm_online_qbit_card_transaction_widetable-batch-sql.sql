--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-25 00:00:00
-- Updated Time:   2026-08-28 00:00:00
-- Description:    量子卡交易大宽表批量初始化/回刷（多 JDBC source）
--********************************************************************--

-- 运行图诊断版本：固定为 1，与已验证可展示运行图的脚本保持一致。
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

-- 卡维度 source：只读取本次时间窗口交易涉及的卡，避免全表扫描。
CREATE TEMPORARY TABLE lookup_qbit_card (
    id STRING, card_no_last_four STRING, provider STRING, card_type STRING, label STRING,
    group_id STRING, balance_id STRING, first_six STRING, card_belong STRING,
    physical_card_status STRING, card_mode STRING, status STRING
) WITH (
    'connector' = 'jdbc', 'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT qc."id"::text AS id, qc."qbitCardNoLastFour"::text AS card_no_last_four, qc."provider"::text AS provider, qc."type"::text AS card_type, qc."label"::text AS label, qc."groupId"::text AS group_id, qc."balanceId"::text AS balance_id, qc."firstSix"::text AS first_six, qc."cardBelong"::text AS card_belong, qc."physicalCardStatus"::text AS physical_card_status, qc."cardMode"::text AS card_mode, qc."status"::text AS status FROM public."qbitCard" qc WHERE EXISTS (SELECT 1 FROM public."qbit_card_transaction" qt WHERE qt."cardId" = qc."id" AND qt."createTime" >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND qt."createTime" < CAST(''${end_time}'' AS TIMESTAMP(6)))) AS qbit_card_dim', 'username' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver'
);

-- 卡组维度 source：只读取本次时间窗口交易卡所属的卡组。
CREATE TEMPORARY TABLE lookup_qbit_card_group (
    id STRING, group_name STRING, status STRING
) WITH (
    'connector' = 'jdbc', 'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT qcg."id"::text AS id, qcg."groupName"::text AS group_name, qcg."status"::text AS status FROM public."qbitCardGroup" qcg WHERE EXISTS (SELECT 1 FROM public."qbitCard" qc INNER JOIN public."qbit_card_transaction" qt ON qt."cardId" = qc."id" WHERE qc."groupId" = qcg."id" AND qt."createTime" >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND qt."createTime" < CAST(''${end_time}'' AS TIMESTAMP(6)))) AS qbit_card_group_dim', 'username' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver'
);

-- 账户维度 source：只读取本次时间窗口交易涉及的账户。
CREATE TEMPORARY TABLE lookup_account (
    id STRING, verified_name STRING, parent_account_id STRING, account_type STRING,
    verified_name_en STRING, country STRING, referral_code_id STRING, account_type_role STRING, display_id STRING, tenant_id BIGINT
) WITH (
    'connector' = 'jdbc', 'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT acc."id"::text AS id, acc."verifiedName"::text AS verified_name, acc."parentAccountId"::text AS parent_account_id, acc."accountType"::text AS account_type, acc."verifiedNameEn"::text AS verified_name_en, acc."country"::text AS country, acc."referralCodeId"::text AS referral_code_id, acc."type"::text AS account_type_role, acc."displayId"::text AS display_id, acc."tenantId"::bigint AS tenant_id FROM public."account" acc WHERE EXISTS (SELECT 1 FROM public."qbit_card_transaction" qt WHERE qt."accountId"::text = acc."id"::text AND qt."createTime" >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND qt."createTime" < CAST(''${end_time}'' AS TIMESTAMP(6)))) AS account_dim', 'username' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver'
);

-- 账户扩展 source：只读取本次时间窗口交易涉及账户的当前 systemType。
CREATE TEMPORARY TABLE lookup_account_extend (
    account_id STRING, system_type STRING
) WITH (
    'connector' = 'jdbc', 'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT ae."accountId"::text AS account_id, ae."systemType"::text AS system_type FROM public."accountExtend" ae WHERE ae."deleteTime" IS NULL AND EXISTS (SELECT 1 FROM public."qbit_card_transaction" qt WHERE qt."accountId"::text = ae."accountId"::text AND qt."createTime" >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND qt."createTime" < CAST(''${end_time}'' AS TIMESTAMP(6)))) AS account_extend_dim', 'username' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver'
);

-- 根账户关系 source：转换 UUID 为 STRING，并限制为本次交易涉及的账户。
CREATE TEMPORARY TABLE lookup_api_account_relation (
    account_id STRING, root_id STRING, delete_time TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc', 'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT aar.account_id::text AS account_id, aar.root_id::text AS root_id, aar.delete_time FROM public.api_account_relation aar WHERE EXISTS (SELECT 1 FROM public."qbit_card_transaction" qt WHERE qt."accountId"::text = aar.account_id::text AND qt."createTime" >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND qt."createTime" < CAST(''${end_time}'' AS TIMESTAMP(6)))) AS api_account_relation_dim', 'username' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver'
);

-- 销售关系 source：仅读取本切片交易账户及其 root 账户的关系记录。
-- 不按 createTime 限制 relation 生效时间，避免 transactionTime 与 createTime 不一致时漏匹配。
CREATE TEMPORARY TABLE source_sale_account_relation (
    id STRING, relation_account_id STRING, sale_id STRING, am_id STRING, operation_manager_id STRING,
    relation_start_time TIMESTAMP(6), relation_end_time TIMESTAMP(6), delete_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc', 'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(WITH filtered_txn AS (SELECT DISTINCT "accountId"::text AS account_id FROM public."qbit_card_transaction" WHERE "createTime" >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND "createTime" < CAST(''${end_time}'' AS TIMESTAMP(6))), related_account AS (SELECT account_id FROM filtered_txn UNION SELECT aar.root_id::text FROM filtered_txn ft INNER JOIN public.api_account_relation aar ON aar.account_id::text = ft.account_id AND aar.delete_time IS NULL) SELECT sr.id::text AS id, sr.relation_account_id::text AS relation_account_id, sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, sr.operation_manager_id::text AS operation_manager_id, sr.relation_start_time, sr.relation_end_time, sr.delete_time FROM dim.dim_sale_account_relation_p sr INNER JOIN related_account ra ON ra.account_id = sr.relation_account_id::text WHERE sr.delete_time IS NULL) AS sale_account_relation_f', 'username' = '${secret_values.ADB_PG_USERNAME}', 'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver', 'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_transaction_base AS
SELECT
    qt.*,
    qc.card_no_last_four, qc.provider AS card_provider, qc.card_type AS card_type_dim,
    qc.label, qc.group_id, qc.balance_id, qc.first_six,
    qc.card_belong, qc.physical_card_status, qc.card_mode,
    qc.status AS card_status, qcg.group_name, qcg.status AS group_status,
    acc.verified_name AS acc_verified_name, acc.verified_name_en AS acc_verified_name_en, acc.parent_account_id,
    acc.account_type, ae.system_type, acc.country AS acc_country, acc.referral_code_id,
    acc.account_type_role AS acc_type, acc.display_id AS acc_display_id, acc.tenant_id,
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
LEFT JOIN lookup_qbit_card qc ON qc.id = qt.card_id
LEFT JOIN lookup_qbit_card_group qcg ON qcg.id = qc.group_id
LEFT JOIN lookup_account acc ON acc.id = qt.account_id
LEFT JOIN lookup_account_extend ae ON ae.account_id = qt.account_id
LEFT JOIN lookup_api_account_relation aar ON aar.account_id = qt.account_id AND aar.delete_time IS NULL;

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
    b.parent_account_id, b.account_type, b.system_type, b.acc_verified_name_en, b.acc_country, b.referral_code_id, b.acc_type, b.acc_display_id, b.tenant_id,
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
    acc_verified_name STRING, parent_account_id STRING, account_type STRING, system_type STRING, acc_verified_name_en STRING, acc_country STRING, referral_code_id STRING, acc_type STRING,
    acc_display_id STRING, tenant_id BIGINT, root_account_id STRING, sale_id STRING, am_id STRING, operation_manager_id STRING,
    create_time TIMESTAMP(6), update_time TIMESTAMP(6), delete_time TIMESTAMP(6), version INT,
    PRIMARY KEY (id, create_time) NOT ENFORCED
) WITH (
    'connector' = 'adbpg', 'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'targetSchema' = 'dwm', 'tableName' = 'dwm_quantum_card_transaction_p', 'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}', 'writeMode' = 'upsert', 'batchSize' = '2000', 'retryWaitTime' = '5000'
);

INSERT INTO sink_qbit_card_transaction_widetable
SELECT * FROM v_qbit_card_transaction_widetable;
