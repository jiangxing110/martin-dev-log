-- Notes:
--   1. BB 普通 DWS CDC 不执行目标表删除，只按 DWM 变更范围重算写入。
--   2. 部署时需要在“附加依赖文件”添加 PostgreSQL JDBC driver，例如 postgresql-42.7.4.jar。
--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-12
-- Updated Time:   2026-08-06 01:03:20
-- Description:    Quantum BB v2 DWS CDC 按月重算写入 v2
-- 作业元信息：
--   作业类型：流处理 CDC
--   运行方式：默认按昨天变更扫描，按受影响月份整月删除后重算
--   运行参数：无
--   源库变更响应：源表 update_time / delete_time 变化后，重刷对应月份
-- Notes:
--   1. 主链路: DWM transaction/auth -> DWS
--   2. 粒度: account_id + report_date(月初) + sale_id + am_id
--   3. 固定成本和 Active Card fee 由独立特殊行脚本处理，主链路保持 0。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'taskmanager.memory.network.min' = '1gb';
SET 'taskmanager.memory.network.max' = '3gb';
SET 'taskmanager.memory.network.fraction' = '0.2';
SET 'pipeline.default-parallelism' = '1';
SET 'table.exec.resource.default-parallelism' = '1';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'execution.multi-jobs-in-application.enable' = 'false';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';
SET 'heartbeat.interval' = '30 s';
SET 'heartbeat.timeout' = '600 s';

CREATE TEMPORARY TABLE source_bb_changed_keys (
    report_date DATE,
    account_id  STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT DISTINCT date_trunc(''month'', event_time)::date AS report_date, account_id FROM (SELECT transaction_time AS event_time, account_id FROM dwm.dwm_bb_card_transaction_detail_v2_p WHERE transaction_time IS NOT NULL AND account_id IS NOT NULL AND ((update_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND update_time < CURRENT_DATE::timestamp) OR (delete_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND delete_time < CURRENT_DATE::timestamp)) UNION ALL SELECT original_completion_time, account_id FROM dwm.dwm_bb_card_transaction_detail_v2_p WHERE original_completion_time IS NOT NULL AND account_id IS NOT NULL AND ((update_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND update_time < CURRENT_DATE::timestamp) OR (delete_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND delete_time < CURRENT_DATE::timestamp)) UNION ALL SELECT settlement_post_date, account_id FROM dwm.dwm_bb_card_transaction_detail_v2_p WHERE settlement_post_date IS NOT NULL AND account_id IS NOT NULL AND ((update_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND update_time < CURRENT_DATE::timestamp) OR (delete_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND delete_time < CURRENT_DATE::timestamp)) UNION ALL SELECT auth_time, account_id FROM dwm.dwm_bb_card_auth_detail_v2_p WHERE auth_time IS NOT NULL AND account_id IS NOT NULL AND ((update_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND update_time < CURRENT_DATE::timestamp) OR (delete_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND delete_time < CURRENT_DATE::timestamp))) changed) AS bb_changed_keys_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

SET 'execution.checkpointing.interval' = '10s';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'execution.checkpointing.timeout' = '30min';


CREATE TEMPORARY TABLE source_dwm_bb_card_transaction_detail_v2_p (
    id                       STRING,
    txn_id                   BIGINT,
    settlement_id            STRING,
    source_id                STRING,
    card_transaction_id      STRING,
    account_id               STRING,
    account_type             STRING,
    account_category         STRING,
    system_type              STRING,
    card_id                  STRING,
    transaction_time         TIMESTAMP(6),
    original_completion_time TIMESTAMP(6),
    business_type            STRING,
    business_code_list       STRING,
    remarks                  STRING,
    detail                   STRING,
    card_org                 STRING,
    tx_country               STRING,
    settle_country           STRING,
    is_dom                   BOOLEAN,
    resp_code                STRING,
    reason_code              STRING,
    transaction_type         STRING,
    is_valid_settle          BOOLEAN,
    is_clearing              BOOLEAN,
    is_reversal              BOOLEAN,
    is_refund                BOOLEAN,
    billing_amount           DECIMAL(20, 4),
    settlement_post_date     TIMESTAMP(6),
    settlement_txn_date      TIMESTAMP(6),
    sale_id                  STRING,
    am_id                    STRING,
    version                  INT,
    create_time              TIMESTAMP(6),
    update_time              TIMESTAMP(6),
    delete_time              TIMESTAMP(6),
    PRIMARY KEY (id, transaction_time) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(WITH changed_keys AS (SELECT DISTINCT date_trunc(''month'', event_time)::date AS report_date, account_id FROM (SELECT transaction_time AS event_time, account_id FROM dwm.dwm_bb_card_transaction_detail_v2_p WHERE transaction_time IS NOT NULL AND account_id IS NOT NULL AND ((update_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND update_time < CURRENT_DATE::timestamp) OR (delete_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND delete_time < CURRENT_DATE::timestamp)) UNION ALL SELECT original_completion_time, account_id FROM dwm.dwm_bb_card_transaction_detail_v2_p WHERE original_completion_time IS NOT NULL AND account_id IS NOT NULL AND ((update_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND update_time < CURRENT_DATE::timestamp) OR (delete_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND delete_time < CURRENT_DATE::timestamp)) UNION ALL SELECT settlement_post_date, account_id FROM dwm.dwm_bb_card_transaction_detail_v2_p WHERE settlement_post_date IS NOT NULL AND account_id IS NOT NULL AND ((update_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND update_time < CURRENT_DATE::timestamp) OR (delete_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND delete_time < CURRENT_DATE::timestamp)) UNION ALL SELECT auth_time, account_id FROM dwm.dwm_bb_card_auth_detail_v2_p WHERE auth_time IS NOT NULL AND account_id IS NOT NULL AND ((update_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND update_time < CURRENT_DATE::timestamp) OR (delete_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND delete_time < CURRENT_DATE::timestamp))) changed) SELECT t.id, t.txn_id, t.settlement_id, t.source_id, t.card_transaction_id, t.account_id, t.account_type, t.account_category, t.system_type, t.card_id, t.transaction_time, t.original_completion_time, t.business_type, t.business_code_list, t.remarks, t.detail, t.card_org, t.tx_country, t.settle_country, t.is_dom, t.resp_code, t.reason_code, t.transaction_type, t.is_valid_settle, t.is_clearing, t.is_reversal, t.is_refund, t.billing_amount, t.settlement_post_date, t.settlement_txn_date, t.sale_id, t.am_id, t.version, t.create_time, t.update_time, t.delete_time FROM dwm.dwm_bb_card_transaction_detail_v2_p t WHERE t.delete_time IS NULL AND EXISTS (SELECT 1 FROM changed_keys k WHERE t.account_id = k.account_id AND (date_trunc(''month'', t.transaction_time)::date = k.report_date OR date_trunc(''month'', t.original_completion_time)::date = k.report_date OR date_trunc(''month'', t.settlement_post_date)::date = k.report_date))) AS dwm_bb_card_transaction_detail_v2_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY TABLE source_dwm_bb_card_auth_detail_v2_p (
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
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(WITH changed_keys AS (SELECT DISTINCT date_trunc(''month'', event_time)::date AS report_date, account_id FROM (SELECT transaction_time AS event_time, account_id FROM dwm.dwm_bb_card_transaction_detail_v2_p WHERE transaction_time IS NOT NULL AND account_id IS NOT NULL AND ((update_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND update_time < CURRENT_DATE::timestamp) OR (delete_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND delete_time < CURRENT_DATE::timestamp)) UNION ALL SELECT original_completion_time, account_id FROM dwm.dwm_bb_card_transaction_detail_v2_p WHERE original_completion_time IS NOT NULL AND account_id IS NOT NULL AND ((update_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND update_time < CURRENT_DATE::timestamp) OR (delete_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND delete_time < CURRENT_DATE::timestamp)) UNION ALL SELECT settlement_post_date, account_id FROM dwm.dwm_bb_card_transaction_detail_v2_p WHERE settlement_post_date IS NOT NULL AND account_id IS NOT NULL AND ((update_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND update_time < CURRENT_DATE::timestamp) OR (delete_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND delete_time < CURRENT_DATE::timestamp)) UNION ALL SELECT auth_time, account_id FROM dwm.dwm_bb_card_auth_detail_v2_p WHERE auth_time IS NOT NULL AND account_id IS NOT NULL AND ((update_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND update_time < CURRENT_DATE::timestamp) OR (delete_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND delete_time < CURRENT_DATE::timestamp))) changed) SELECT t.id, t.auth_txn_guid, t.card_proxy, t.account_id, t.account_type, t.account_category, t.system_type, t.card_id, t.auth_time, t.program_name, t.merchant_country, t.request_code, t.request_description, t.response_code, t.reason_code, t.txn_amount, t.settle_amount, t.txn_currency, t.merchant_name, t.mcc, t.card_org, t.is_dom, t.is_decline, t.is_account_verification, t.is_excluded_request, t.sale_id, t.am_id, t.source_table, t.version, t.create_time, t.update_time, t.delete_time FROM dwm.dwm_bb_card_auth_detail_v2_p t WHERE t.delete_time IS NULL AND EXISTS (SELECT 1 FROM changed_keys k WHERE t.account_id = k.account_id AND date_trunc(''month'', t.auth_time)::date = k.report_date)) AS dwm_bb_card_auth_detail_v2_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_bb_changed_keys AS
SELECT DISTINCT
    report_date,
    account_id
FROM source_bb_changed_keys;

CREATE TEMPORARY VIEW v_bb_metric_rows AS
SELECT
    CAST(DATE_FORMAT(CAST(s.transaction_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_date,
    s.*,
    'txn_time' AS metric_basis
FROM source_dwm_bb_card_transaction_detail_v2_p s
INNER JOIN v_bb_changed_keys k
    ON CAST(DATE_FORMAT(CAST(s.transaction_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = k.report_date
   AND s.account_id = k.account_id
WHERE s.delete_time IS NULL
UNION ALL
SELECT
    CAST(DATE_FORMAT(CAST(s.original_completion_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_date,
    s.*,
    'completion_time' AS metric_basis
FROM source_dwm_bb_card_transaction_detail_v2_p s
INNER JOIN v_bb_changed_keys k
    ON CAST(DATE_FORMAT(CAST(s.original_completion_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = k.report_date
   AND s.account_id = k.account_id
WHERE s.delete_time IS NULL
UNION ALL
SELECT
    CAST(DATE_FORMAT(CAST(s.settlement_post_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_date,
    s.*,
    'post_date' AS metric_basis
FROM source_dwm_bb_card_transaction_detail_v2_p s
INNER JOIN v_bb_changed_keys k
    ON CAST(DATE_FORMAT(CAST(s.settlement_post_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = k.report_date
   AND s.account_id = k.account_id
WHERE s.delete_time IS NULL;

CREATE TEMPORARY VIEW v_bb_auth_scope_rows AS
SELECT s.*
FROM source_dwm_bb_card_auth_detail_v2_p s
INNER JOIN v_bb_changed_keys k
    ON CAST(DATE_FORMAT(CAST(s.auth_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = k.report_date
   AND s.account_id = k.account_id
WHERE s.delete_time IS NULL;

CREATE TEMPORARY VIEW v_dws_bb_txn_daily_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', account_id, ':', COALESCE(sale_id, ''), ':', COALESCE(am_id, '')))) AS BIGINT) AS id,
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    CAST(COUNT(DISTINCT CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND card_org = 'Master' AND is_dom = TRUE AND resp_code = 'APPROVE' AND (is_clearing = TRUE OR is_reversal = TRUE) THEN source_id END) AS INT) AS m_dom_auth_count,
    CAST(COUNT(DISTINCT CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND card_org = 'Master' AND is_dom = FALSE AND resp_code = 'APPROVE' AND (is_clearing = TRUE OR is_reversal = TRUE) THEN source_id END) AS INT) AS m_int_auth_count,
    CAST(COUNT(DISTINCT CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND card_org = 'VISA' AND is_dom = TRUE AND resp_code = 'APPROVE' AND (is_clearing = TRUE OR is_reversal = TRUE) THEN source_id END) AS INT) AS v_dom_auth_count,
    CAST(COUNT(DISTINCT CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND card_org = 'VISA' AND is_dom = FALSE AND resp_code = 'APPROVE' AND (is_clearing = TRUE OR is_reversal = TRUE) THEN source_id END) AS INT) AS v_int_auth_count,
    CAST(SUM(CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND card_org = 'Master' AND tx_country NOT IN ('US', 'USA') AND is_valid_settle = TRUE AND resp_code = 'DECLINE' THEN 1 ELSE 0 END) AS INT) AS m_int_decline_count,
    CAST(SUM(CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND card_org = 'VISA' AND tx_country NOT IN ('US', 'USA') AND is_valid_settle = TRUE AND is_dom = FALSE AND resp_code = 'DECLINE' THEN 1 ELSE 0 END) AS INT) AS v_int_decline_count,
    CAST(SUM(CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND tx_country NOT IN ('US', 'USA') AND is_valid_settle = TRUE AND resp_code = 'DECLINE' THEN 1 ELSE 0 END) AS INT) AS dom_decline_count,
    CAST(0 AS INT) AS ac_m_int_decline_count,
    CAST(0 AS INT) AS ac_v_int_decline_count,
    CAST(0 AS INT) AS ac_dom_decline_count,
    CAST(SUM(CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'Master' AND tx_country NOT IN ('US', 'USA') AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND transaction_type = 'authorization.reversal' THEN 1 ELSE 0 END) AS INT) AS m_int_reversal_count,
    CAST(SUM(CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'VISA' AND tx_country NOT IN ('US', 'USA') AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND transaction_type = 'authorization.reversal' THEN 1 ELSE 0 END) AS INT) AS v_int_reversal_count,
    CAST(SUM(CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND tx_country IN ('US', 'USA') AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND transaction_type = 'authorization.reversal' THEN 1 ELSE 0 END) AS INT) AS dom_reversal_count,
    CAST(SUM(CASE WHEN metric_basis = 'post_date' AND business_type = 'Credit' AND card_org = 'Master' AND is_valid_settle = TRUE AND settle_country NOT IN ('US', 'USA') AND is_refund = TRUE AND resp_code = 'APPROVE' THEN 1 ELSE 0 END) AS INT) AS m_int_refund_count,
    CAST(SUM(CASE WHEN metric_basis = 'post_date' AND business_type = 'Credit' AND card_org = 'VISA' AND is_valid_settle = TRUE AND settle_country NOT IN ('US', 'USA') AND is_refund = TRUE AND resp_code = 'APPROVE' THEN 1 ELSE 0 END) AS INT) AS v_int_refund_count,
    CAST(SUM(CASE WHEN metric_basis = 'post_date' AND business_type = 'Credit' AND settle_country NOT IN ('US', 'USA') AND is_refund = TRUE AND resp_code = 'APPROVE' THEN 1 ELSE 0 END) AS INT) AS dom_refund_count,
    CAST(SUM(CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'Master' AND tx_country IN ('US', 'USA') AND (resp_code IS NULL OR resp_code <> 'DECLINE') THEN 1 ELSE 0 END) AS INT) AS av_m_dom_count,
    CAST(SUM(CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'Master' AND tx_country NOT IN ('US', 'USA') AND (resp_code IS NULL OR resp_code <> 'DECLINE') THEN 1 ELSE 0 END) AS INT) AS av_m_int_count,
    CAST(SUM(CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'VISA' AND tx_country IN ('US', 'USA') AND (resp_code IS NULL OR resp_code <> 'DECLINE') THEN 1 ELSE 0 END) AS INT) AS av_v_dom_count,
    CAST(SUM(CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'VISA' AND tx_country NOT IN ('US', 'USA') AND (resp_code IS NULL OR resp_code <> 'DECLINE') THEN 1 ELSE 0 END) AS INT) AS av_v_int_count,
    CAST(SUM(CASE WHEN metric_basis = 'completion_time' AND business_type IN ('Credit', 'Consumption') AND card_org = 'Master' AND settle_country IN ('US', 'USA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND resp_code = 'APPROVE' THEN -billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS m_dom_clearing_vol,
    CAST(SUM(CASE WHEN metric_basis = 'completion_time' AND business_type IN ('Credit', 'Consumption') AND card_org = 'Master' AND settle_country NOT IN ('US', 'USA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND resp_code = 'APPROVE' THEN -billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS m_int_clearing_vol,
    CAST(SUM(CASE WHEN metric_basis = 'completion_time' AND business_type IN ('Credit', 'Consumption') AND card_org = 'VISA' AND settle_country IN ('US', 'USA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND resp_code = 'APPROVE' THEN -billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS v_dom_clearing_vol,
    CAST(SUM(CASE WHEN metric_basis = 'completion_time' AND business_type IN ('Credit', 'Consumption') AND card_org = 'VISA' AND settle_country NOT IN ('US', 'USA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND resp_code = 'APPROVE' THEN -billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS v_int_clearing_vol,
    CAST(SUM(CASE WHEN metric_basis = 'completion_time' AND business_type IN ('Credit', 'Consumption') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND resp_code = 'APPROVE' THEN -billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS bb_rebate_base_amt,
    CAST(SUM(CASE WHEN metric_basis = 'completion_time' AND business_type IN ('Credit', 'Consumption') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND resp_code = 'APPROVE' THEN -billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS bb_channel_cashback_comm,
    CAST(0 AS INT) AS active_card_count,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee,
    sale_id,
    am_id,
    1 AS version,
    'bb_v2_cdc' AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_bb_metric_rows
GROUP BY report_date, account_id, account_type, account_category, system_type, sale_id, am_id;

CREATE TEMPORARY VIEW v_bb_auth_month_rows AS
SELECT
    CAST(DATE_FORMAT(CAST(auth_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    card_org,
    is_dom,
    is_decline,
    is_account_verification,
    is_excluded_request,
    auth_txn_guid,
    sale_id,
    am_id
FROM v_bb_auth_scope_rows;

CREATE TEMPORARY VIEW v_dws_bb_auth_daily_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', account_id, ':', COALESCE(sale_id, ''), ':', COALESCE(am_id, '')))) AS BIGINT) AS id,
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    CAST(0 AS INT) AS m_dom_auth_count,
    CAST(0 AS INT) AS m_int_auth_count,
    CAST(0 AS INT) AS v_dom_auth_count,
    CAST(0 AS INT) AS v_int_auth_count,
    CAST(COUNT(DISTINCT CASE WHEN is_decline = TRUE AND is_account_verification = FALSE AND is_excluded_request = FALSE AND card_org = 'Master' AND is_dom = FALSE THEN auth_txn_guid END) AS INT) AS m_int_decline_count,
    CAST(COUNT(DISTINCT CASE WHEN is_decline = TRUE AND is_account_verification = FALSE AND is_excluded_request = FALSE AND card_org = 'VISA' AND is_dom = FALSE THEN auth_txn_guid END) AS INT) AS v_int_decline_count,
    CAST(COUNT(DISTINCT CASE WHEN is_decline = TRUE AND is_account_verification = FALSE AND is_excluded_request = FALSE AND is_dom = TRUE THEN auth_txn_guid END) AS INT) AS dom_decline_count,
    CAST(COUNT(DISTINCT CASE WHEN is_decline = TRUE AND is_account_verification = TRUE AND is_excluded_request = FALSE AND card_org = 'Master' AND is_dom = FALSE THEN auth_txn_guid END) AS INT) AS ac_m_int_decline_count,
    CAST(COUNT(DISTINCT CASE WHEN is_decline = TRUE AND is_account_verification = TRUE AND is_excluded_request = FALSE AND card_org = 'VISA' AND is_dom = FALSE THEN auth_txn_guid END) AS INT) AS ac_v_int_decline_count,
    CAST(COUNT(DISTINCT CASE WHEN is_decline = TRUE AND is_account_verification = TRUE AND is_excluded_request = FALSE AND is_dom = TRUE THEN auth_txn_guid END) AS INT) AS ac_dom_decline_count,
    CAST(0 AS INT) AS m_int_reversal_count,
    CAST(0 AS INT) AS v_int_reversal_count,
    CAST(0 AS INT) AS dom_reversal_count,
    CAST(0 AS INT) AS m_int_refund_count,
    CAST(0 AS INT) AS v_int_refund_count,
    CAST(0 AS INT) AS dom_refund_count,
    CAST(0 AS INT) AS av_m_dom_count,
    CAST(0 AS INT) AS av_m_int_count,
    CAST(0 AS INT) AS av_v_dom_count,
    CAST(0 AS INT) AS av_v_int_count,
    CAST(0 AS DECIMAL(20, 4)) AS m_dom_clearing_vol,
    CAST(0 AS DECIMAL(20, 4)) AS m_int_clearing_vol,
    CAST(0 AS DECIMAL(20, 4)) AS v_dom_clearing_vol,
    CAST(0 AS DECIMAL(20, 4)) AS v_int_clearing_vol,
    CAST(0 AS DECIMAL(20, 4)) AS bb_rebate_base_amt,
    CAST(0 AS DECIMAL(20, 4)) AS bb_channel_cashback_comm,
    CAST(0 AS INT) AS active_card_count,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee,
    sale_id,
    am_id,
    1 AS version,
    'bb_v2_cdc' AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_bb_auth_month_rows
GROUP BY report_date, account_id, account_type, account_category, system_type, sale_id, am_id;

CREATE TEMPORARY VIEW v_dws_bb_daily_base AS
SELECT
    COALESCE(t.id, a.id) AS id,
    COALESCE(t.report_date, a.report_date) AS report_date,
    COALESCE(t.account_id, a.account_id) AS account_id,
    COALESCE(t.account_type, a.account_type) AS account_type,
    COALESCE(t.account_category, a.account_category) AS account_category,
    COALESCE(t.system_type, a.system_type) AS system_type,
    COALESCE(t.m_dom_auth_count, 0) + COALESCE(a.m_dom_auth_count, 0) AS m_dom_auth_count,
    COALESCE(t.m_int_auth_count, 0) + COALESCE(a.m_int_auth_count, 0) AS m_int_auth_count,
    COALESCE(t.v_dom_auth_count, 0) + COALESCE(a.v_dom_auth_count, 0) AS v_dom_auth_count,
    COALESCE(t.v_int_auth_count, 0) + COALESCE(a.v_int_auth_count, 0) AS v_int_auth_count,
    COALESCE(t.m_int_decline_count, 0) + COALESCE(a.m_int_decline_count, 0) AS m_int_decline_count,
    COALESCE(t.v_int_decline_count, 0) + COALESCE(a.v_int_decline_count, 0) AS v_int_decline_count,
    COALESCE(t.dom_decline_count, 0) + COALESCE(a.dom_decline_count, 0) AS dom_decline_count,
    COALESCE(t.ac_m_int_decline_count, 0) + COALESCE(a.ac_m_int_decline_count, 0) AS ac_m_int_decline_count,
    COALESCE(t.ac_v_int_decline_count, 0) + COALESCE(a.ac_v_int_decline_count, 0) AS ac_v_int_decline_count,
    COALESCE(t.ac_dom_decline_count, 0) + COALESCE(a.ac_dom_decline_count, 0) AS ac_dom_decline_count,
    COALESCE(t.m_int_reversal_count, 0) + COALESCE(a.m_int_reversal_count, 0) AS m_int_reversal_count,
    COALESCE(t.v_int_reversal_count, 0) + COALESCE(a.v_int_reversal_count, 0) AS v_int_reversal_count,
    COALESCE(t.dom_reversal_count, 0) + COALESCE(a.dom_reversal_count, 0) AS dom_reversal_count,
    COALESCE(t.m_int_refund_count, 0) + COALESCE(a.m_int_refund_count, 0) AS m_int_refund_count,
    COALESCE(t.v_int_refund_count, 0) + COALESCE(a.v_int_refund_count, 0) AS v_int_refund_count,
    COALESCE(t.dom_refund_count, 0) + COALESCE(a.dom_refund_count, 0) AS dom_refund_count,
    COALESCE(t.av_m_dom_count, 0) + COALESCE(a.av_m_dom_count, 0) AS av_m_dom_count,
    COALESCE(t.av_m_int_count, 0) + COALESCE(a.av_m_int_count, 0) AS av_m_int_count,
    COALESCE(t.av_v_dom_count, 0) + COALESCE(a.av_v_dom_count, 0) AS av_v_dom_count,
    COALESCE(t.av_v_int_count, 0) + COALESCE(a.av_v_int_count, 0) AS av_v_int_count,
    COALESCE(t.m_dom_clearing_vol, CAST(0 AS DECIMAL(20, 4))) + COALESCE(a.m_dom_clearing_vol, CAST(0 AS DECIMAL(20, 4))) AS m_dom_clearing_vol,
    COALESCE(t.m_int_clearing_vol, CAST(0 AS DECIMAL(20, 4))) + COALESCE(a.m_int_clearing_vol, CAST(0 AS DECIMAL(20, 4))) AS m_int_clearing_vol,
    COALESCE(t.v_dom_clearing_vol, CAST(0 AS DECIMAL(20, 4))) + COALESCE(a.v_dom_clearing_vol, CAST(0 AS DECIMAL(20, 4))) AS v_dom_clearing_vol,
    COALESCE(t.v_int_clearing_vol, CAST(0 AS DECIMAL(20, 4))) + COALESCE(a.v_int_clearing_vol, CAST(0 AS DECIMAL(20, 4))) AS v_int_clearing_vol,
    COALESCE(t.bb_rebate_base_amt, CAST(0 AS DECIMAL(20, 4))) + COALESCE(a.bb_rebate_base_amt, CAST(0 AS DECIMAL(20, 4))) AS bb_rebate_base_amt,
    COALESCE(t.bb_channel_cashback_comm, CAST(0 AS DECIMAL(20, 4))) + COALESCE(a.bb_channel_cashback_comm, CAST(0 AS DECIMAL(20, 4))) AS bb_channel_cashback_comm,
    CAST(0 AS INT) AS active_card_count,
    CAST(
        COALESCE(t.m_dom_clearing_vol, CAST(0 AS DECIMAL(20, 4)))
      + COALESCE(a.m_dom_clearing_vol, CAST(0 AS DECIMAL(20, 4)))
      + COALESCE(t.m_int_clearing_vol, CAST(0 AS DECIMAL(20, 4)))
      + COALESCE(a.m_int_clearing_vol, CAST(0 AS DECIMAL(20, 4)))
      + COALESCE(t.v_dom_clearing_vol, CAST(0 AS DECIMAL(20, 4)))
      + COALESCE(a.v_dom_clearing_vol, CAST(0 AS DECIMAL(20, 4)))
      + COALESCE(t.v_int_clearing_vol, CAST(0 AS DECIMAL(20, 4)))
      + COALESCE(a.v_int_clearing_vol, CAST(0 AS DECIMAL(20, 4)))
      AS DECIMAL(20, 4)
    ) AS total_net_amount,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee,
    COALESCE(t.sale_id, a.sale_id) AS sale_id,
    COALESCE(t.am_id, a.am_id) AS am_id,
    1 AS version,
    'bb_v2_cdc' AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_dws_bb_txn_daily_base t
FULL OUTER JOIN v_dws_bb_auth_daily_base a
    ON t.report_date = a.report_date
   AND t.account_id = a.account_id
   AND COALESCE(t.sale_id, '') = COALESCE(a.sale_id, '')
   AND COALESCE(t.am_id, '') = COALESCE(a.am_id, '');

CREATE TEMPORARY TABLE sink_dws_bb_card_finance_daily_v2_p (
    id                       BIGINT,
    report_date              DATE,
    account_id               STRING,
    account_type             STRING,
    account_category         STRING,
    system_type              STRING,
    m_dom_auth_count         INT,
    m_int_auth_count         INT,
    v_dom_auth_count         INT,
    v_int_auth_count         INT,
    m_int_decline_count      INT,
    v_int_decline_count      INT,
    dom_decline_count        INT,
    ac_m_int_decline_count   INT,
    ac_v_int_decline_count   INT,
    ac_dom_decline_count     INT,
    m_int_reversal_count     INT,
    v_int_reversal_count     INT,
    dom_reversal_count       INT,
    m_int_refund_count       INT,
    v_int_refund_count       INT,
    dom_refund_count         INT,
    av_m_dom_count           INT,
    av_m_int_count           INT,
    av_v_dom_count           INT,
    av_v_int_count           INT,
    m_dom_clearing_vol       DECIMAL(20, 4),
    m_int_clearing_vol       DECIMAL(20, 4),
    v_dom_clearing_vol       DECIMAL(20, 4),
    v_int_clearing_vol       DECIMAL(20, 4),
    bb_rebate_base_amt       DECIMAL(20, 4),
    bb_channel_cashback_comm DECIMAL(20, 4),
    active_card_count        INT,
    total_net_amount         DECIMAL(20, 4),
    cost_fixed_fee           DECIMAL(20, 4),
    special_fee_type         STRING,
    sale_id                  STRING,
    am_id                    STRING,
    version                  INT,
    remarks                  STRING,
    create_time              TIMESTAMP(6),
    update_time              TIMESTAMP(6),
    delete_time              TIMESTAMP(6),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_bb_card_finance_daily_v2_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'insert',
    'batchSize' = '2000'
);

INSERT INTO sink_dws_bb_card_finance_daily_v2_p
SELECT
    id,
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    m_dom_auth_count,
    m_int_auth_count,
    v_dom_auth_count,
    v_int_auth_count,
    m_int_decline_count,
    v_int_decline_count,
    dom_decline_count,
    ac_m_int_decline_count,
    ac_v_int_decline_count,
    ac_dom_decline_count,
    m_int_reversal_count,
    v_int_reversal_count,
    dom_reversal_count,
    m_int_refund_count,
    v_int_refund_count,
    dom_refund_count,
    av_m_dom_count,
    av_m_int_count,
    av_v_dom_count,
    av_v_int_count,
    m_dom_clearing_vol,
    m_int_clearing_vol,
    v_dom_clearing_vol,
    v_int_clearing_vol,
    bb_rebate_base_amt,
    bb_channel_cashback_comm,
    active_card_count,
    total_net_amount,
    cost_fixed_fee,
    CAST(NULL AS STRING) AS special_fee_type,
    sale_id,
    am_id,
    version,
    remarks,
    create_time,
    update_time,
    delete_time
FROM v_dws_bb_daily_base;
