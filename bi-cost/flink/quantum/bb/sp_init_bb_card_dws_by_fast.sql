--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-15
-- Description:    Quantum BB DWS 批量初始化/回刷
-- Notes:
--   1. 主链路: DWM -> DWS
--   2. 粒度: account_id + report_date + sale_id + am_id
--   3. cost_fixed_fee 后续通过 bi_month_tag 单独更新
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

SET 'execution.checkpointing.interval' = '10s';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'pipeline.operator-chaining' = 'false';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'execution.checkpointing.timeout' = '30min';

SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';


CREATE TEMPORARY TABLE source_dwm_bb_card_transaction_detail_p (
    id                  STRING,
    account_id          STRING,
    card_id             STRING,
    transaction_time    TIMESTAMP(6),
    third_complete_time TIMESTAMP(6),
    business_type       STRING,
    status              STRING,
    remarks             STRING,
    card_org            STRING,
    is_dom              BOOLEAN,
    resp_code           STRING,
    request_code        STRING,
    reason_code         STRING,
    is_valid_settle     BOOLEAN,
    is_clearing         BOOLEAN,
    is_reversal         BOOLEAN,
    is_refund           BOOLEAN,
    billing_amount      DECIMAL(20, 4),
    version             INT,
    create_time         TIMESTAMP(6),
    update_time         TIMESTAMP(6),
    delete_time         TIMESTAMP(6),
    settle_country      STRING,
    tx_country          STRING,
    sale_id             STRING,
    am_id               STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dwm_bb_card_transaction_detail_p',
    'targetSchema' = 'dwm',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY VIEW v_dws_bb_daily_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(transaction_time, 'yyyyMMdd'), ':', account_id, ':', COALESCE(sale_id, ''), ':', COALESCE(am_id, '')))) AS BIGINT) AS id,
    CAST(transaction_time AS DATE) AS report_date,
    account_id,
    CAST(SUM(CASE WHEN business_type = 'Consumption' AND card_org = 'Master' AND is_dom = TRUE AND resp_code = 'APPROVE' AND (is_clearing = TRUE OR is_reversal = TRUE) THEN 1 ELSE 0 END) AS INT) AS m_dom_auth_count,
    CAST(SUM(CASE WHEN business_type = 'Consumption' AND card_org = 'Master' AND is_dom = FALSE AND resp_code = 'APPROVE' AND (is_clearing = TRUE OR is_reversal = TRUE) THEN 1 ELSE 0 END) AS INT) AS m_int_auth_count,
    CAST(SUM(CASE WHEN business_type = 'Consumption' AND card_org = 'VISA' AND is_dom = TRUE AND resp_code = 'APPROVE' AND (is_clearing = TRUE OR is_reversal = TRUE) THEN 1 ELSE 0 END) AS INT) AS v_dom_auth_count,
    CAST(SUM(CASE WHEN business_type = 'Consumption' AND card_org = 'VISA' AND is_dom = FALSE AND resp_code = 'APPROVE' AND (is_clearing = TRUE OR is_reversal = TRUE) THEN 1 ELSE 0 END) AS INT) AS v_int_auth_count,
    CAST(SUM(CASE WHEN business_type = 'Consumption' AND card_org = 'Master' AND tx_country NOT IN ('US', 'USA') AND is_valid_settle = TRUE AND resp_code = 'DECLINE' THEN 1 ELSE 0 END) AS INT) AS m_int_decline_count,
    CAST(SUM(CASE WHEN business_type = 'Consumption' AND card_org = 'VISA' AND tx_country NOT IN ('US', 'USA') AND is_valid_settle = TRUE AND is_dom = FALSE AND resp_code = 'DECLINE' THEN 1 ELSE 0 END) AS INT) AS v_int_decline_count,
    CAST(SUM(CASE WHEN business_type = 'Consumption' AND tx_country NOT IN ('US', 'USA') AND is_valid_settle = TRUE AND resp_code = 'DECLINE' THEN 1 ELSE 0 END) AS INT) AS dom_decline_count,
    CAST(SUM(CASE WHEN business_type = 'Consumption' AND card_org = 'Master' AND is_valid_settle = TRUE AND is_dom = FALSE AND is_reversal = TRUE AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND request_code IN ('ST-AUTH_REV', 'ST-PARTIAL_REV') THEN 1 ELSE 0 END) AS INT) AS m_int_reversal_count,
    CAST(SUM(CASE WHEN business_type = 'Consumption' AND card_org = 'VISA' AND is_valid_settle = TRUE AND tx_country NOT IN ('US', 'USA') AND is_reversal = TRUE AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND request_code IN ('ST-AUTH_REV', 'ST-PARTIAL_REV') THEN 1 ELSE 0 END) AS INT) AS v_int_reversal_count,
    CAST(SUM(CASE WHEN business_type = 'Consumption' AND is_dom = TRUE AND is_valid_settle = TRUE AND is_reversal = TRUE AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND request_code IN ('ST-AUTH_REV', 'ST-PARTIAL_REV') THEN 1 ELSE 0 END) AS INT) AS dom_reversal_count,
    CAST(SUM(CASE WHEN business_type = 'Credit' AND card_org = 'Master' AND is_valid_settle = TRUE AND settle_country NOT IN ('US', 'USA') AND is_refund = TRUE AND resp_code = 'APPROVE' THEN 1 ELSE 0 END) AS INT) AS m_int_refund_count,
    CAST(SUM(CASE WHEN business_type = 'Credit' AND card_org = 'VISA' AND is_valid_settle = TRUE AND settle_country NOT IN ('US', 'USA') AND is_refund = TRUE AND resp_code = 'APPROVE' THEN 1 ELSE 0 END) AS INT) AS v_int_refund_count,
    CAST(SUM(CASE WHEN business_type = 'Credit' AND settle_country NOT IN ('US', 'USA') AND is_refund = TRUE AND resp_code = 'APPROVE' THEN 1 ELSE 0 END) AS INT) AS dom_refund_count,
    CAST(SUM(CASE WHEN business_type = 'Fee_Consumption' AND remarks = '绑卡验证手续费' AND card_org = 'Master' AND tx_country IN ('US', 'USA') THEN 1 ELSE 0 END) AS INT) AS av_m_dom_count,
    CAST(SUM(CASE WHEN business_type = 'Fee_Consumption' AND remarks = '绑卡验证手续费' AND card_org = 'Master' AND tx_country NOT IN ('US', 'USA') THEN 1 ELSE 0 END) AS INT) AS av_m_int_count,
    CAST(SUM(CASE WHEN business_type = 'Fee_Consumption' AND remarks = '绑卡验证手续费' AND card_org = 'VISA' AND tx_country IN ('US', 'USA') THEN 1 ELSE 0 END) AS INT) AS av_v_dom_count,
    CAST(SUM(CASE WHEN business_type = 'Fee_Consumption' AND remarks = '绑卡验证手续费' AND card_org = 'VISA' AND tx_country NOT IN ('US', 'USA') THEN 1 ELSE 0 END) AS INT) AS av_v_int_count,
    CAST(SUM(CASE WHEN card_org = 'Master' AND is_dom = TRUE AND is_clearing = TRUE THEN billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS m_dom_clearing_vol,
    CAST(SUM(CASE WHEN card_org = 'Master' AND is_dom = FALSE AND is_clearing = TRUE THEN billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS m_int_clearing_vol,
    CAST(SUM(CASE WHEN card_org = 'VISA' AND is_dom = TRUE AND is_clearing = TRUE THEN billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS v_dom_clearing_vol,
    CAST(SUM(CASE WHEN card_org = 'VISA' AND is_dom = FALSE AND is_clearing = TRUE THEN billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS v_int_clearing_vol,
    CAST(SUM(CASE WHEN is_valid_settle = TRUE AND (is_clearing = TRUE OR is_refund = TRUE) THEN billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS bb_rebate_base_amt,
    CAST(SUM(CASE WHEN is_valid_settle = TRUE AND (is_clearing = TRUE OR is_refund = TRUE) THEN billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS bb_channel_cashback_comm,
    CAST(COUNT(DISTINCT card_id) AS INT) AS active_card_count,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee,
    sale_id,
    am_id,
    1 AS version,
    CAST(NULL AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM source_dwm_bb_card_transaction_detail_p
WHERE delete_time IS NULL
GROUP BY CAST(transaction_time AS DATE), account_id, sale_id, am_id;

CREATE TEMPORARY TABLE sink_dws_bb_card_finance_daily_p (
    id                       BIGINT,
    report_date              DATE,
    account_id               STRING,
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
    'password' = '${secret_values.ADB_PG_PASSWORD}'
),
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dws_bb_card_finance_daily_p
SELECT * FROM v_dws_bb_daily_base;
