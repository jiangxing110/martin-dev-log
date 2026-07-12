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
--   2. DWS 粒度: account_id + report_date + sale_id + am_id。
--   3. cost_fixed_fee 由固定成本独立脚本回刷，本脚本保持 0。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';

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
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dwm_bb_card_transaction_detail_v2_p',
    'targetSchema' = 'dwm',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
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
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dwm_bb_card_auth_detail_v2_p',
    'targetSchema' = 'dwm',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY VIEW v_bb_metric_rows AS
SELECT
    CAST(transaction_time AS DATE) AS report_date,
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
    billing_amount,
    'txn_time' AS metric_basis
FROM source_dwm_bb_card_transaction_detail_v2_p
WHERE delete_time IS NULL
  AND transaction_time >= CAST('${start_date}' AS TIMESTAMP(6))
  AND transaction_time < CAST('${end_date}' AS TIMESTAMP(6))
UNION ALL
SELECT
    CAST(original_completion_time AS DATE) AS report_date,
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
    billing_amount,
    'completion_time' AS metric_basis
FROM source_dwm_bb_card_transaction_detail_v2_p
WHERE delete_time IS NULL
  AND original_completion_time >= CAST('${start_date}' AS TIMESTAMP(6))
  AND original_completion_time < CAST('${end_date}' AS TIMESTAMP(6))
UNION ALL
SELECT
    CAST(settlement_post_date AS DATE) AS report_date,
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
    billing_amount,
    'post_date' AS metric_basis
FROM source_dwm_bb_card_transaction_detail_v2_p
WHERE delete_time IS NULL
  AND settlement_post_date >= CAST('${start_date}' AS TIMESTAMP(6))
  AND settlement_post_date < CAST('${end_date}' AS TIMESTAMP(6));

CREATE TEMPORARY VIEW v_dws_bb_txn_daily_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', account_id, ':', COALESCE(sale_id, ''), ':', COALESCE(am_id, '')))) AS BIGINT) AS id,
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    CAST(COUNT(DISTINCT CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'Master' AND tx_country IN ('US', 'USA') AND resp_code = 'APPROVE' AND transaction_type IN ('authorization.clearing', 'authorization.reversal') THEN source_id END) AS INT) AS m_dom_auth_count,
    CAST(COUNT(DISTINCT CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'Master' AND tx_country NOT IN ('US', 'USA') AND resp_code = 'APPROVE' AND transaction_type IN ('authorization.clearing', 'authorization.reversal') THEN source_id END) AS INT) AS m_int_auth_count,
    CAST(COUNT(DISTINCT CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'VISA' AND tx_country IN ('US', 'USA') AND resp_code = 'APPROVE' AND transaction_type IN ('authorization.clearing', 'authorization.reversal') THEN source_id END) AS INT) AS v_dom_auth_count,
    CAST(COUNT(DISTINCT CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'VISA' AND tx_country NOT IN ('US', 'USA') AND resp_code = 'APPROVE' AND transaction_type IN ('authorization.clearing', 'authorization.reversal') THEN source_id END) AS INT) AS v_int_auth_count,
    CAST(0 AS INT) AS m_int_decline_count,
    CAST(0 AS INT) AS v_int_decline_count,
    CAST(0 AS INT) AS dom_decline_count,
    CAST(COUNT(DISTINCT CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'Master' AND tx_country NOT IN ('US', 'USA') AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND transaction_type = 'authorization.reversal' THEN source_id END) AS INT) AS m_int_reversal_count,
    CAST(COUNT(DISTINCT CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'VISA' AND tx_country NOT IN ('US', 'USA') AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND transaction_type = 'authorization.reversal' THEN source_id END) AS INT) AS v_int_reversal_count,
    CAST(COUNT(DISTINCT CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND tx_country IN ('US', 'USA') AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND transaction_type = 'authorization.reversal' THEN source_id END) AS INT) AS dom_reversal_count,
    CAST(COUNT(DISTINCT CASE WHEN metric_basis = 'post_date' AND business_type = 'Credit' AND card_org = 'Master' AND settle_country NOT IN ('US', 'USA') AND transaction_type = 'refund.clearing' AND resp_code = 'APPROVE' THEN source_id END) AS INT) AS m_int_refund_count,
    CAST(COUNT(DISTINCT CASE WHEN metric_basis = 'post_date' AND business_type = 'Credit' AND card_org = 'VISA' AND settle_country NOT IN ('US', 'USA') AND transaction_type = 'refund.clearing' AND resp_code = 'APPROVE' THEN source_id END) AS INT) AS v_int_refund_count,
    CAST(COUNT(DISTINCT CASE WHEN metric_basis = 'post_date' AND business_type = 'Credit' AND settle_country IN ('US', 'USA') AND transaction_type = 'refund.clearing' AND resp_code = 'APPROVE' THEN source_id END) AS INT) AS dom_refund_count,
    CAST(COUNT(DISTINCT CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'Master' AND tx_country IN ('US', 'USA') AND (resp_code IS NULL OR resp_code <> 'DECLINE') THEN source_id END) AS INT) AS av_m_dom_count,
    CAST(COUNT(DISTINCT CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'Master' AND tx_country NOT IN ('US', 'USA') AND (resp_code IS NULL OR resp_code <> 'DECLINE') THEN source_id END) AS INT) AS av_m_int_count,
    CAST(COUNT(DISTINCT CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'VISA' AND tx_country IN ('US', 'USA') AND (resp_code IS NULL OR resp_code <> 'DECLINE') THEN source_id END) AS INT) AS av_v_dom_count,
    CAST(COUNT(DISTINCT CASE WHEN metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'VISA' AND tx_country NOT IN ('US', 'USA') AND (resp_code IS NULL OR resp_code <> 'DECLINE') THEN source_id END) AS INT) AS av_v_int_count,
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
    'bb_v2_batch' AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_bb_metric_rows
GROUP BY report_date, account_id, account_type, account_category, system_type, sale_id, am_id;

CREATE TEMPORARY VIEW v_dws_bb_auth_daily_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(CAST(CAST(auth_time AS DATE) AS TIMESTAMP(6)), 'yyyyMMdd'), ':', account_id, ':', COALESCE(sale_id, ''), ':', COALESCE(am_id, '')))) AS BIGINT) AS id,
    CAST(auth_time AS DATE) AS report_date,
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
    CAST(COUNT(DISTINCT card_proxy) AS INT) AS active_card_count,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee,
    sale_id,
    am_id,
    1 AS version,
    'bb_v2_auth_batch' AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM source_dwm_bb_card_auth_detail_v2_p
WHERE delete_time IS NULL
  AND auth_time >= CAST('${start_date}' AS TIMESTAMP(6))
  AND auth_time < CAST('${end_date}' AS TIMESTAMP(6))
GROUP BY CAST(auth_time AS DATE), account_id, account_type, account_category, system_type, sale_id, am_id;

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
    COALESCE(t.active_card_count, 0) + COALESCE(a.active_card_count, 0) AS active_card_count,
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

CREATE TEMPORARY TABLE sink_dws_bb_card_finance_daily_p (
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
    'tableName' = 'dws_bb_card_finance_daily_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dws_bb_card_finance_daily_p
SELECT * FROM v_dws_bb_daily_base;
