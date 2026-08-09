--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-15
-- Updated Time:   2026-08-09 11:05:08
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

SET 'parallelism.default' = '4';
SET 'pipeline.operator-chaining' = 'true';
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
    transaction_id      STRING,
    account_id          STRING,
    card_id             STRING,
    status              STRING,
    transaction_time    TIMESTAMP(6),
    business_type       STRING,
    provider            STRING,
    special_source_data STRING,
    version             INT,
    remarks             STRING,
    create_time         TIMESTAMP(6),
    update_time         TIMESTAMP(6),
    delete_time         TIMESTAMP(6),
    usd_amount          DECIMAL(20, 4),
    channel_provision   STRING,
    country             STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT t.id::text AS id, t."transactionId"::text AS transaction_id, t."accountId"::text AS account_id, t."cardId"::text AS card_id, t.status, t."transactionTime" AS transaction_time, t."businessType" AS business_type, t.provider, CAST(t."specialSourceData" AS text) AS special_source_data, t.version, t.remarks, t."createTime" AS create_time, t."updateTime" AS update_time, t."deleteTime" AS delete_time, e.usd_amount, e.channel_provision, e.country FROM public.qbit_card_transaction t INNER JOIN public.card_bin b ON b.system_provider = t.provider AND b.brand = ''QbitIssuing'' LEFT JOIN public.quantum_card_transaction_extend e ON e.transaction_id::text = t."transactionId"::text AND e.channel_provision = ''QBIT'' WHERE t."businessType" IN (''Consumption'', ''Reversal'', ''Credit'') AND ((COALESCE(t."updateTime", t."createTime") >= CAST(CURRENT_DATE - INTERVAL ''1'' DAY AS TIMESTAMP(6)) AND COALESCE(t."updateTime", t."createTime") < CAST(CURRENT_DATE AS TIMESTAMP(6))) OR (t."deleteTime" >= CAST(CURRENT_DATE - INTERVAL ''1'' DAY AS TIMESTAMP(6)) AND t."deleteTime" < CAST(CURRENT_DATE AS TIMESTAMP(6))))) AS qbit_card_transaction_f',
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
    'table-name' = '(SELECT id::text AS id, account_type, "type", system_type FROM dim.dim_account) AS dim_account_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_qi_sale_relation (
    tx_id   STRING,
    sale_id STRING,
    am_id   STRING,
    PRIMARY KEY (tx_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(WITH tx AS (SELECT t.id::text AS tx_id, t."accountId"::text AS account_id, t."transactionTime" AS transaction_time FROM public.qbit_card_transaction t INNER JOIN public.card_bin b ON b.system_provider = t.provider AND b.brand = ''QbitIssuing'' WHERE t."deleteTime" IS NULL AND t."businessType" IN (''Consumption'', ''Reversal'', ''Credit'') AND COALESCE(t."updateTime", t."createTime") >= CAST(CURRENT_DATE - INTERVAL ''1'' DAY AS TIMESTAMP(6)) AND COALESCE(t."updateTime", t."createTime") < CAST(CURRENT_DATE AS TIMESTAMP(6))), direct_rel AS (SELECT DISTINCT ON (tx.tx_id) tx.tx_id, sr.sale_id, sr.am_id FROM tx INNER JOIN dim.dim_sale_account_relation_p sr ON sr.delete_time IS NULL AND sr.relation_account_id::text = tx.account_id AND tx.transaction_time >= sr.relation_start_time AND (tx.transaction_time < sr.relation_end_time OR sr.relation_end_time IS NULL) ORDER BY tx.tx_id, sr.relation_start_time DESC), root_rel AS (SELECT DISTINCT ON (tx.tx_id) tx.tx_id, sr.sale_id, sr.am_id FROM tx INNER JOIN public.api_account_relation aar ON aar.account_id::text = tx.account_id AND aar.delete_time IS NULL INNER JOIN dim.dim_sale_account_relation_p sr ON sr.delete_time IS NULL AND sr.relation_account_id::text = aar.root_id::text AND tx.transaction_time >= sr.relation_start_time AND (tx.transaction_time < sr.relation_end_time OR sr.relation_end_time IS NULL) ORDER BY tx.tx_id, sr.relation_start_time DESC) SELECT tx.tx_id, COALESCE(direct_rel.sale_id, root_rel.sale_id)::text AS sale_id, COALESCE(direct_rel.am_id, root_rel.am_id)::text AS am_id FROM tx LEFT JOIN direct_rel ON direct_rel.tx_id = tx.tx_id LEFT JOIN root_rel ON root_rel.tx_id = tx.tx_id) AS qi_sale_relation_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY VIEW v_qi_base AS
SELECT
    t.id,
    t.transaction_id,
    t.account_id,
    da.account_type,
    da.`type` AS account_category,
    da.system_type,
    t.status,
    t.transaction_time,
    COALESCE(t.version, 1) AS version,
    t.remarks,
    t.create_time,
    COALESCE(t.update_time, t.create_time) AS update_time,
    t.delete_time,
    COALESCE(t.update_time, t.create_time) AS source_update_time,
    t.delete_time AS source_delete_time,
    t.delete_time IS NULL AS is_current_valid,
    CAST(COALESCE(t.usd_amount, CAST(0 AS DECIMAL(20, 4))) AS DECIMAL(20, 4)) AS billing_amount,
    t.channel_provision = 'QBIT' AS is_qbit_provision,
    t.country IN ('HK', 'HKG') AS is_hk_region,
    t.business_type = 'Consumption' AS is_consumption,
    t.business_type IN ('Reversal', 'Credit') AS is_reversal_or_credit,
    JSON_VALUE(t.special_source_data, '$.code.1001') IS NOT NULL
        OR JSON_VALUE(t.special_source_data, '$.code.1103') IS NOT NULL
        OR JSON_VALUE(t.special_source_data, '$.code.1105') IS NOT NULL AS has_special_code,
    FALSE AS is_vip_account,
    t.business_type,
    t.card_id
FROM source_qbit_card_transaction t
LEFT JOIN source_dim_account da
    ON da.id = t.account_id
WHERE t.delete_time IS NULL;

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
    s.sale_id,
    s.am_id
FROM v_qi_base b
LEFT JOIN source_qi_sale_relation s
    ON s.tx_id = b.id;

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
