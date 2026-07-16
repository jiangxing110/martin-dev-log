--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-12
-- Description:    BB v2 DWS 批量初始化/回刷
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性初始化/按 report_date 回刷
--   运行参数：start_date, end_date
--   源库变更响应：源库变化不会自动触发本作业。
-- Notes:
--   1. 主链路: dwm_bb_card_transaction_detail_v2_p + dwm_bb_card_auth_detail_v2_p -> dws_bb_card_finance_daily_p。
--   2. DWS 粒度: account_id + report_date(月初) + sale_id + am_id。
--   3. 固定成本和 Active Card fee 由独立特殊行脚本处理，主链路保持 0。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';
-- 禁止将同源 JDBC 表扫描合并为 Expand，因 JDBC connector 不支持该物理算子
SET 'table.optimizer.union-any-expand' = 'false';

CREATE TEMPORARY TABLE source_bi_month_tag (
    id              BIGINT,
    product_line    STRING,
    provider        STRING,
    tag             STRING,
    statistics_time TIMESTAMP(6),
    amount          DECIMAL(20, 4),
    detail          STRING,
    update_time     TIMESTAMP(6),
    delete_time     TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id, product_line, provider, tag, statistics_time, amount, detail, update_time, delete_time FROM ods.ods_bi_month_tag WHERE delete_time IS NULL) AS bi_month_tag_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

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
    'table-name' = '(SELECT id, txn_id, settlement_id, source_id, card_transaction_id, account_id, account_type, account_category, system_type, card_id, transaction_time, original_completion_time, business_type, business_code_list, remarks, detail, card_org, tx_country, settle_country, is_dom, resp_code, reason_code, transaction_type, is_valid_settle, is_clearing, is_reversal, is_refund, billing_amount, settlement_post_date, settlement_txn_date, sale_id, am_id, version, create_time, update_time, delete_time FROM dwm.dwm_bb_card_transaction_detail_v2_p) AS dwm_bb_card_transaction_detail_v2_f',
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
    'table-name' = '(SELECT id, auth_txn_guid, card_proxy, account_id, account_type, account_category, system_type, card_id, auth_time, program_name, merchant_country, request_code, request_description, response_code, reason_code, txn_amount, settle_amount, txn_currency, merchant_name, mcc, card_org, is_dom, is_decline, is_account_verification, is_excluded_request, sale_id, am_id, source_table, version, create_time, update_time, delete_time FROM dwm.dwm_bb_card_auth_detail_v2_p) AS dwm_bb_card_auth_detail_v2_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_bb_txn_time_rows AS
SELECT
    CAST(DATE_FORMAT(CAST(transaction_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    sale_id,
    am_id,
    source_id,
    card_id,
    card_org,
    COALESCE(tx_country, '') AS tx_country,
    COALESCE(settle_country, '') AS settle_country,
    business_type,
    COALESCE(business_code_list, '') AS business_code_list,
    COALESCE(remarks, '') AS remarks,
    resp_code,
    reason_code,
    transaction_type,
    is_dom,
    is_valid_settle,
    is_clearing,
    is_reversal,
    is_refund,
    billing_amount
FROM source_dwm_bb_card_transaction_detail_v2_p
WHERE delete_time IS NULL
  AND transaction_time >= CAST('${start_date}' AS TIMESTAMP(6))
  AND transaction_time < CAST('${end_date}' AS TIMESTAMP(6));

CREATE TEMPORARY VIEW v_bb_completion_rows AS
SELECT
    CAST(DATE_FORMAT(CAST(original_completion_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    sale_id,
    am_id,
    source_id,
    card_id,
    card_org,
    COALESCE(tx_country, '') AS tx_country,
    COALESCE(settle_country, '') AS settle_country,
    business_type,
    COALESCE(business_code_list, '') AS business_code_list,
    COALESCE(remarks, '') AS remarks,
    resp_code,
    reason_code,
    transaction_type,
    is_dom,
    is_valid_settle,
    is_clearing,
    is_reversal,
    is_refund,
    billing_amount
FROM source_dwm_bb_card_transaction_detail_v2_p
WHERE delete_time IS NULL
  AND original_completion_time >= CAST('${start_date}' AS TIMESTAMP(6))
  AND original_completion_time < CAST('${end_date}' AS TIMESTAMP(6));

CREATE TEMPORARY VIEW v_bb_post_rows AS
SELECT
    CAST(DATE_FORMAT(CAST(settlement_post_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    sale_id,
    am_id,
    source_id,
    card_id,
    card_org,
    COALESCE(tx_country, '') AS tx_country,
    COALESCE(settle_country, '') AS settle_country,
    business_type,
    COALESCE(business_code_list, '') AS business_code_list,
    COALESCE(remarks, '') AS remarks,
    resp_code,
    reason_code,
    transaction_type,
    is_dom,
    is_valid_settle,
    is_clearing,
    is_reversal,
    is_refund,
    billing_amount
FROM source_dwm_bb_card_transaction_detail_v2_p
WHERE delete_time IS NULL
  AND settlement_post_date >= CAST('${start_date}' AS TIMESTAMP(6))
  AND settlement_post_date < CAST('${end_date}' AS TIMESTAMP(6));

CREATE TEMPORARY VIEW v_bb_txn_count_metric_rows AS
SELECT
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    sale_id,
    am_id,
    source_id AS metric_key,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'Master' AND tx_country IN ('US', 'USA') AND resp_code = 'APPROVE' AND transaction_type IN ('authorization.clearing', 'authorization.reversal') THEN 1 ELSE 0 END) AS m_dom_auth_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'Master' AND tx_country NOT IN ('US', 'USA') AND resp_code = 'APPROVE' AND transaction_type IN ('authorization.clearing', 'authorization.reversal') THEN 1 ELSE 0 END) AS m_int_auth_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'VISA' AND tx_country IN ('US', 'USA') AND resp_code = 'APPROVE' AND transaction_type IN ('authorization.clearing', 'authorization.reversal') THEN 1 ELSE 0 END) AS v_dom_auth_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'VISA' AND tx_country NOT IN ('US', 'USA') AND resp_code = 'APPROVE' AND transaction_type IN ('authorization.clearing', 'authorization.reversal') THEN 1 ELSE 0 END) AS v_int_auth_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'Master' AND tx_country NOT IN ('US', 'USA') AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND transaction_type = 'authorization.reversal' THEN 1 ELSE 0 END) AS m_int_reversal_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'VISA' AND tx_country NOT IN ('US', 'USA') AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND transaction_type = 'authorization.reversal' THEN 1 ELSE 0 END) AS v_int_reversal_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND tx_country IN ('US', 'USA') AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND transaction_type = 'authorization.reversal' THEN 1 ELSE 0 END) AS dom_reversal_count,
    0 AS m_int_refund_count,
    0 AS v_int_refund_count,
    0 AS dom_refund_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'Master' AND tx_country IN ('US', 'USA') AND (resp_code IS NULL OR resp_code <> 'DECLINE') THEN 1 ELSE 0 END) AS av_m_dom_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'Master' AND tx_country NOT IN ('US', 'USA') AND (resp_code IS NULL OR resp_code <> 'DECLINE') THEN 1 ELSE 0 END) AS av_m_int_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'VISA' AND tx_country IN ('US', 'USA') AND (resp_code IS NULL OR resp_code <> 'DECLINE') THEN 1 ELSE 0 END) AS av_v_dom_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'VISA' AND tx_country NOT IN ('US', 'USA') AND (resp_code IS NULL OR resp_code <> 'DECLINE') THEN 1 ELSE 0 END) AS av_v_int_count
FROM v_bb_txn_time_rows
WHERE source_id IS NOT NULL
GROUP BY report_date, account_id, account_type, account_category, system_type, sale_id, am_id, source_id;

CREATE TEMPORARY VIEW v_bb_txn_count_metrics AS
SELECT
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    CAST(SUM(m_dom_auth_count) AS INT) AS m_dom_auth_count,
    CAST(SUM(m_int_auth_count) AS INT) AS m_int_auth_count,
    CAST(SUM(v_dom_auth_count) AS INT) AS v_dom_auth_count,
    CAST(SUM(v_int_auth_count) AS INT) AS v_int_auth_count,
    CAST(SUM(m_int_reversal_count) AS INT) AS m_int_reversal_count,
    CAST(SUM(v_int_reversal_count) AS INT) AS v_int_reversal_count,
    CAST(SUM(dom_reversal_count) AS INT) AS dom_reversal_count,
    CAST(SUM(m_int_refund_count) AS INT) AS m_int_refund_count,
    CAST(SUM(v_int_refund_count) AS INT) AS v_int_refund_count,
    CAST(SUM(dom_refund_count) AS INT) AS dom_refund_count,
    CAST(SUM(av_m_dom_count) AS INT) AS av_m_dom_count,
    CAST(SUM(av_m_int_count) AS INT) AS av_m_int_count,
    CAST(SUM(av_v_dom_count) AS INT) AS av_v_dom_count,
    CAST(SUM(av_v_int_count) AS INT) AS av_v_int_count,
    sale_id,
    am_id
FROM v_bb_txn_count_metric_rows
GROUP BY report_date, account_id, account_type, account_category, system_type, sale_id, am_id;

CREATE TEMPORARY VIEW v_bb_post_count_metric_rows AS
SELECT
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    sale_id,
    am_id,
    source_id AS metric_key,
    MAX(CASE WHEN business_type = 'Credit' AND card_org = 'Master' AND settle_country NOT IN ('US', 'USA') AND transaction_type = 'refund.clearing' AND resp_code = 'APPROVE' THEN 1 ELSE 0 END) AS m_int_refund_count,
    MAX(CASE WHEN business_type = 'Credit' AND card_org = 'VISA' AND settle_country NOT IN ('US', 'USA') AND transaction_type = 'refund.clearing' AND resp_code = 'APPROVE' THEN 1 ELSE 0 END) AS v_int_refund_count,
    MAX(CASE WHEN business_type = 'Credit' AND settle_country IN ('US', 'USA') AND transaction_type = 'refund.clearing' AND resp_code = 'APPROVE' THEN 1 ELSE 0 END) AS dom_refund_count
FROM v_bb_post_rows
WHERE source_id IS NOT NULL
GROUP BY report_date, account_id, account_type, account_category, system_type, sale_id, am_id, source_id;

CREATE TEMPORARY VIEW v_bb_post_count_metrics AS
SELECT
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    CAST(SUM(m_int_refund_count) AS INT) AS m_int_refund_count,
    CAST(SUM(v_int_refund_count) AS INT) AS v_int_refund_count,
    CAST(SUM(dom_refund_count) AS INT) AS dom_refund_count,
    sale_id,
    am_id
FROM v_bb_post_count_metric_rows
GROUP BY report_date, account_id, account_type, account_category, system_type, sale_id, am_id;

CREATE TEMPORARY VIEW v_bb_count_metrics AS
SELECT
    COALESCE(t.report_date, p.report_date) AS report_date,
    COALESCE(t.account_id, p.account_id) AS account_id,
    COALESCE(t.account_type, p.account_type) AS account_type,
    COALESCE(t.account_category, p.account_category) AS account_category,
    COALESCE(t.system_type, p.system_type) AS system_type,
    COALESCE(t.m_dom_auth_count, 0) AS m_dom_auth_count,
    COALESCE(t.m_int_auth_count, 0) AS m_int_auth_count,
    COALESCE(t.v_dom_auth_count, 0) AS v_dom_auth_count,
    COALESCE(t.v_int_auth_count, 0) AS v_int_auth_count,
    COALESCE(t.m_int_reversal_count, 0) AS m_int_reversal_count,
    COALESCE(t.v_int_reversal_count, 0) AS v_int_reversal_count,
    COALESCE(t.dom_reversal_count, 0) AS dom_reversal_count,
    COALESCE(p.m_int_refund_count, 0) AS m_int_refund_count,
    COALESCE(p.v_int_refund_count, 0) AS v_int_refund_count,
    COALESCE(p.dom_refund_count, 0) AS dom_refund_count,
    COALESCE(t.av_m_dom_count, 0) AS av_m_dom_count,
    COALESCE(t.av_m_int_count, 0) AS av_m_int_count,
    COALESCE(t.av_v_dom_count, 0) AS av_v_dom_count,
    COALESCE(t.av_v_int_count, 0) AS av_v_int_count,
    COALESCE(t.sale_id, p.sale_id) AS sale_id,
    COALESCE(t.am_id, p.am_id) AS am_id
FROM v_bb_txn_count_metrics t
FULL OUTER JOIN v_bb_post_count_metrics p
    ON t.report_date = p.report_date
   AND t.account_id = p.account_id
   AND COALESCE(t.sale_id, '') = COALESCE(p.sale_id, '')
   AND COALESCE(t.am_id, '') = COALESCE(p.am_id, '');

CREATE TEMPORARY VIEW v_bb_txn_amount_metrics AS
SELECT
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    CAST(SUM(CASE WHEN business_type IN ('Credit', 'Consumption') AND card_org = 'Master' AND settle_country IN ('US', 'USA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND resp_code = 'APPROVE' THEN -billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS m_dom_clearing_vol,
    CAST(SUM(CASE WHEN business_type IN ('Credit', 'Consumption') AND card_org = 'Master' AND settle_country NOT IN ('US', 'USA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND resp_code = 'APPROVE' THEN -billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS m_int_clearing_vol,
    CAST(SUM(CASE WHEN business_type IN ('Credit', 'Consumption') AND card_org = 'VISA' AND settle_country IN ('US', 'USA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND resp_code = 'APPROVE' THEN -billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS v_dom_clearing_vol,
    CAST(SUM(CASE WHEN business_type IN ('Credit', 'Consumption') AND card_org = 'VISA' AND settle_country NOT IN ('US', 'USA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND resp_code = 'APPROVE' THEN -billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS v_int_clearing_vol,
    CAST(SUM(CASE WHEN business_type IN ('Credit', 'Consumption') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND resp_code = 'APPROVE' THEN -billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS bb_rebate_base_amt,
    CAST(SUM(CASE WHEN business_type IN ('Credit', 'Consumption') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND resp_code = 'APPROVE' THEN -billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS bb_channel_cashback_comm,
    sale_id,
    am_id
FROM v_bb_completion_rows
GROUP BY report_date, account_id, account_type, account_category, system_type, sale_id, am_id;

CREATE TEMPORARY VIEW v_dws_bb_txn_daily_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(CAST(COALESCE(c.report_date, a.report_date) AS TIMESTAMP(6)), 'yyyyMMdd'), ':', COALESCE(c.account_id, a.account_id), ':', COALESCE(c.sale_id, a.sale_id, ''), ':', COALESCE(c.am_id, a.am_id, '')))) AS BIGINT) AS id,
    COALESCE(c.report_date, a.report_date) AS report_date,
    COALESCE(c.account_id, a.account_id) AS account_id,
    COALESCE(c.account_type, a.account_type) AS account_type,
    COALESCE(c.account_category, a.account_category) AS account_category,
    COALESCE(c.system_type, a.system_type) AS system_type,
    COALESCE(c.m_dom_auth_count, 0) AS m_dom_auth_count,
    COALESCE(c.m_int_auth_count, 0) AS m_int_auth_count,
    COALESCE(c.v_dom_auth_count, 0) AS v_dom_auth_count,
    COALESCE(c.v_int_auth_count, 0) AS v_int_auth_count,
    CAST(0 AS INT) AS m_int_decline_count,
    CAST(0 AS INT) AS v_int_decline_count,
    CAST(0 AS INT) AS dom_decline_count,
    COALESCE(c.m_int_reversal_count, 0) AS m_int_reversal_count,
    COALESCE(c.v_int_reversal_count, 0) AS v_int_reversal_count,
    COALESCE(c.dom_reversal_count, 0) AS dom_reversal_count,
    COALESCE(c.m_int_refund_count, 0) AS m_int_refund_count,
    COALESCE(c.v_int_refund_count, 0) AS v_int_refund_count,
    COALESCE(c.dom_refund_count, 0) AS dom_refund_count,
    COALESCE(c.av_m_dom_count, 0) AS av_m_dom_count,
    COALESCE(c.av_m_int_count, 0) AS av_m_int_count,
    COALESCE(c.av_v_dom_count, 0) AS av_v_dom_count,
    COALESCE(c.av_v_int_count, 0) AS av_v_int_count,
    COALESCE(a.m_dom_clearing_vol, CAST(0 AS DECIMAL(20, 4))) AS m_dom_clearing_vol,
    COALESCE(a.m_int_clearing_vol, CAST(0 AS DECIMAL(20, 4))) AS m_int_clearing_vol,
    COALESCE(a.v_dom_clearing_vol, CAST(0 AS DECIMAL(20, 4))) AS v_dom_clearing_vol,
    COALESCE(a.v_int_clearing_vol, CAST(0 AS DECIMAL(20, 4))) AS v_int_clearing_vol,
    COALESCE(a.bb_rebate_base_amt, CAST(0 AS DECIMAL(20, 4))) AS bb_rebate_base_amt,
    COALESCE(a.bb_channel_cashback_comm, CAST(0 AS DECIMAL(20, 4))) AS bb_channel_cashback_comm,
    CAST(0 AS INT) AS active_card_count,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee,
    COALESCE(c.sale_id, a.sale_id) AS sale_id,
    COALESCE(c.am_id, a.am_id) AS am_id,
    1 AS version,
    'bb_v2_batch' AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_bb_count_metrics c
FULL OUTER JOIN v_bb_txn_amount_metrics a
    ON c.report_date = a.report_date
   AND c.account_id = a.account_id
   AND COALESCE(c.sale_id, '') = COALESCE(a.sale_id, '')
   AND COALESCE(c.am_id, '') = COALESCE(a.am_id, '');

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
FROM source_dwm_bb_card_auth_detail_v2_p
WHERE delete_time IS NULL
  AND auth_time >= CAST('${start_date}' AS TIMESTAMP(6))
  AND auth_time < CAST('${end_date}' AS TIMESTAMP(6));

CREATE TEMPORARY VIEW v_bb_auth_count_metrics AS
SELECT
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    CAST(SUM(m_int_decline_count) AS INT) AS m_int_decline_count,
    CAST(SUM(v_int_decline_count) AS INT) AS v_int_decline_count,
    CAST(SUM(dom_decline_count) AS INT) AS dom_decline_count,
    sale_id,
    am_id
FROM (
    SELECT
        report_date,
        account_id,
        account_type,
        account_category,
        system_type,
        sale_id,
        am_id,
        auth_txn_guid,
        MAX(CASE WHEN is_decline = TRUE AND is_account_verification = FALSE AND is_excluded_request = FALSE AND card_org = 'Master' AND is_dom = FALSE THEN 1 ELSE 0 END) AS m_int_decline_count,
        MAX(CASE WHEN is_decline = TRUE AND is_account_verification = FALSE AND is_excluded_request = FALSE AND card_org = 'VISA' AND is_dom = FALSE THEN 1 ELSE 0 END) AS v_int_decline_count,
        MAX(CASE WHEN is_decline = TRUE AND is_account_verification = FALSE AND is_excluded_request = FALSE AND is_dom = TRUE THEN 1 ELSE 0 END) AS dom_decline_count
    FROM v_bb_auth_month_rows
    WHERE auth_txn_guid IS NOT NULL
    GROUP BY report_date, account_id, account_type, account_category, system_type, sale_id, am_id, auth_txn_guid
) dedup
GROUP BY report_date, account_id, account_type, account_category, system_type, sale_id, am_id;

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
    m_int_decline_count,
    v_int_decline_count,
    dom_decline_count,
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
    'bb_v2_auth_batch' AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_bb_auth_count_metrics;

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
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee,
    COALESCE(t.sale_id, a.sale_id) AS sale_id,
    COALESCE(t.am_id, a.am_id) AS am_id,
    1 AS version,
    'bb_v2_batch' AS remarks,
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
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dws_bb_card_finance_daily_v2_p
SELECT
    b.id,
    b.report_date,
    b.account_id,
    b.account_type,
    b.account_category,
    b.system_type,
    b.m_dom_auth_count,
    b.m_int_auth_count,
    b.v_dom_auth_count,
    b.v_int_auth_count,
    b.m_int_decline_count,
    b.v_int_decline_count,
    b.dom_decline_count,
    b.m_int_reversal_count,
    b.v_int_reversal_count,
    b.dom_reversal_count,
    b.m_int_refund_count,
    b.v_int_refund_count,
    b.dom_refund_count,
    b.av_m_dom_count,
    b.av_m_int_count,
    b.av_v_dom_count,
    b.av_v_int_count,
    b.m_dom_clearing_vol,
    b.m_int_clearing_vol,
    b.v_dom_clearing_vol,
    b.v_int_clearing_vol,
    b.bb_rebate_base_amt,
    b.bb_channel_cashback_comm,
    b.active_card_count,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee,
    CAST(NULL AS STRING) AS special_fee_type,
    b.sale_id,
    b.am_id,
    b.version,
    b.remarks,
    b.create_time,
    b.update_time,
    b.delete_time
FROM v_dws_bb_daily_base b;
