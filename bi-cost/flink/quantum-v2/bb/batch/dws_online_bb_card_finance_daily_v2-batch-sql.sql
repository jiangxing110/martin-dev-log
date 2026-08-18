--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-12
-- Updated Time:   2026-08-18 00:00:00
-- Description:    BB v2 DWS 批量初始化/回刷（report_date 逐日粒度，对齐 QI）
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性初始化/按 report_date 回刷
--   运行参数：start_date, end_date
--   源库变更响应：源库变化不会自动触发本作业。
-- ⚠️ 角色：仅用于一次性历史初始化与手动回刷工具；日常 DWS 写入由 daily CDC（唯一写入者）承担。
--   回刷前必须删除目标范围 DWS 数据（先删后插），避免与 CDC 并存。
-- Notes:
--   1. 主链路: dwm_bb_card_transaction_detail_v2_p + dwm_bb_card_auth_detail_v2_p -> dws_bb_card_finance_daily_p。
--   2. DWS 粒度: account_id + report_date(日) + sale_id + am_id；active card fee 仍按月初承载。
--   3. 固定成本和 Active Card fee 由独立特殊行脚本处理，主链路保持 0。
--********************************************************************--

SET 'parallelism.default' = '1';
-- 进程内存由平台侧配置，这里只保留较保守的网络缓冲建议。
SET 'taskmanager.memory.network.min' = '1536mb';
SET 'taskmanager.memory.network.max' = '1536mb';
SET 'taskmanager.memory.network.fraction' = '0.45';
SET 'taskmanager.network.sort-shuffle.min-buffers' = '64';
SET 'pipeline.default-parallelism' = '1';
SET 'table.exec.resource.default-parallelism' = '1';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'execution.multi-jobs-in-application.enable' = 'false';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';
-- DWM JDBC 扫描和多路聚合可能长时间占满 TM CPU，避免 JM 过早判定 TM 失联。
SET 'heartbeat.interval' = '30 s';
SET 'heartbeat.timeout' = '600 s';
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
    settlement_match_type    STRING,
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
    'table-name' = '(SELECT t.id, t.txn_id, t.settlement_id, t.settlement_match_type, t.source_id, t.card_transaction_id, t.account_id, t.account_type, t.account_category, t.system_type, t.card_id, t.transaction_time, t.original_completion_time, t.business_type, t.business_code_list, t.remarks, t.detail, t.card_org, t.tx_country, t.settle_country, t.is_dom, t.resp_code, t.reason_code, t.transaction_type, t.is_valid_settle, t.is_clearing, t.is_reversal, t.is_refund, t.billing_amount, t.settlement_post_date, t.settlement_txn_date, t.sale_id, t.am_id, t.version, t.create_time, t.update_time, t.delete_time FROM dwm.dwm_bb_card_transaction_detail_v2_p t WHERE t.delete_time IS NULL AND ((t.transaction_time >= CAST(''${start_date}'' AS TIMESTAMP(6)) + INTERVAL ''8'' HOUR AND t.transaction_time < CAST(''${end_date}'' AS TIMESTAMP(6)) + INTERVAL ''8'' HOUR) OR (t.original_completion_time >= CAST(''${start_date}'' AS TIMESTAMP(6)) AND t.original_completion_time < CAST(''${end_date}'' AS TIMESTAMP(6))) OR (t.settlement_post_date >= CAST(''${start_date}'' AS TIMESTAMP(6)) AND t.settlement_post_date < CAST(''${end_date}'' AS TIMESTAMP(6)))) ) AS dwm_bb_card_transaction_detail_v2_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
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
    'table-name' = '(SELECT t.id, t.auth_txn_guid, t.card_proxy, t.account_id, t.account_type, t.account_category, t.system_type, t.card_id, t.auth_time, t.program_name, t.merchant_country, t.request_code, t.request_description, t.response_code, t.reason_code, t.txn_amount, t.settle_amount, t.txn_currency, t.merchant_name, t.mcc, t.card_org, t.is_dom, t.is_decline, t.is_account_verification, t.is_excluded_request, t.sale_id, t.am_id, t.source_table, t.version, t.create_time, t.update_time, t.delete_time FROM generate_series(date_trunc(''day'', CAST(''${start_date}'' AS TIMESTAMP(6)) + INTERVAL ''8'' HOUR), date_trunc(''day'', CAST(''${end_date}'' AS TIMESTAMP(6)) + INTERVAL ''8'' HOUR) - INTERVAL ''1 day'', INTERVAL ''1 day'') AS gs(day_start) JOIN dwm.dwm_bb_card_auth_detail_v2_p t ON t.delete_time IS NULL AND t.auth_time >= gs.day_start AND t.auth_time < LEAST(gs.day_start + INTERVAL ''1 day'', CAST(''${end_date}'' AS TIMESTAMP(6)))) AS dwm_bb_card_auth_detail_v2_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY VIEW v_bb_txn_time_rows AS
SELECT
    -- Count/Reversal 采用自然日窗口 [start_date, end_date)，与 report_date、CDC、QI 口径一致
    CAST(transaction_time AS DATE) AS report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    sale_id,
    am_id,
    source_id,
    card_transaction_id,
    settlement_id,
    settlement_match_type,
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
    COALESCE(settlement_id IN (
        '234e26db-0e1d-424f-952b-053ab2e42d30',
        '82ff7fa6-8035-4c7b-8c18-ace860c3dfae',
        '711e7995-ea26-499f-a1c5-9e4faf15f31f',
        '5e974989-8792-401f-93b6-b107e0b46e51',
        '0af98098-eb5e-4d5b-a5ad-76c1b1c0ae72',
        'a97006e9-2609-4e70-a165-2ae6b9f49689',
        'ad861604-ff4f-4cd1-997e-fe613c67970e',
        '37959ee2-880f-49ea-8d74-976a69382c90',
        'bebf7744-ed33-46cd-8ca6-40bc43d928eb',
        'ece578c8-e8c1-46ec-83b9-116ea049a2e8',
        '69e04460-0cb4-4d9d-9001-2b786cfc3d7b',
        '7fa7ea4f-40fa-4153-9ec1-426f4b2c5470',
        'cff4d9c4-ee01-43fa-9518-62872afbbe91',
        '160b403b-2a16-4b43-afac-a3b37916c968',
        '0fd4e8ed-e208-44e5-b463-ece053a915f3',
        '4a63f4ec-637e-4627-a668-5339fe64b9be'
    ), FALSE) AS is_excluded_settlement,
    billing_amount
FROM source_dwm_bb_card_transaction_detail_v2_p
WHERE delete_time IS NULL
  AND transaction_time >= CAST('${start_date}' AS TIMESTAMP(6))
  AND transaction_time < CAST('${end_date}' AS TIMESTAMP(6));

CREATE TEMPORARY VIEW v_bb_completion_rows AS
SELECT
    CAST(original_completion_time AS DATE) AS report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    sale_id,
    am_id,
    source_id,
    card_transaction_id,
    settlement_id,
    settlement_match_type,
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
    COALESCE(settlement_id IN (
        '234e26db-0e1d-424f-952b-053ab2e42d30',
        '82ff7fa6-8035-4c7b-8c18-ace860c3dfae',
        '711e7995-ea26-499f-a1c5-9e4faf15f31f',
        '5e974989-8792-401f-93b6-b107e0b46e51',
        '0af98098-eb5e-4d5b-a5ad-76c1b1c0ae72',
        'a97006e9-2609-4e70-a165-2ae6b9f49689',
        'ad861604-ff4f-4cd1-997e-fe613c67970e',
        '37959ee2-880f-49ea-8d74-976a69382c90',
        'bebf7744-ed33-46cd-8ca6-40bc43d928eb',
        'ece578c8-e8c1-46ec-83b9-116ea049a2e8',
        '69e04460-0cb4-4d9d-9001-2b786cfc3d7b',
        '7fa7ea4f-40fa-4153-9ec1-426f4b2c5470',
        'cff4d9c4-ee01-43fa-9518-62872afbbe91',
        '160b403b-2a16-4b43-afac-a3b37916c968',
        '0fd4e8ed-e208-44e5-b463-ece053a915f3',
        '4a63f4ec-637e-4627-a668-5339fe64b9be'
    ), FALSE) AS is_excluded_settlement,
    billing_amount
FROM source_dwm_bb_card_transaction_detail_v2_p
WHERE delete_time IS NULL
  AND original_completion_time >= CAST('${start_date}' AS TIMESTAMP(6))
  AND original_completion_time < CAST('${end_date}' AS TIMESTAMP(6));

CREATE TEMPORARY VIEW v_bb_post_rows AS
SELECT
    CAST(settlement_post_date AS DATE) AS report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    sale_id,
    am_id,
    source_id,
    card_transaction_id,
    settlement_id,
    settlement_match_type,
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
    COALESCE(settlement_id IN (
        '234e26db-0e1d-424f-952b-053ab2e42d30',
        '82ff7fa6-8035-4c7b-8c18-ace860c3dfae',
        '711e7995-ea26-499f-a1c5-9e4faf15f31f',
        '5e974989-8792-401f-93b6-b107e0b46e51',
        '0af98098-eb5e-4d5b-a5ad-76c1b1c0ae72',
        'a97006e9-2609-4e70-a165-2ae6b9f49689',
        'ad861604-ff4f-4cd1-997e-fe613c67970e',
        '37959ee2-880f-49ea-8d74-976a69382c90',
        'bebf7744-ed33-46cd-8ca6-40bc43d928eb',
        'ece578c8-e8c1-46ec-83b9-116ea049a2e8',
        '69e04460-0cb4-4d9d-9001-2b786cfc3d7b',
        '7fa7ea4f-40fa-4153-9ec1-426f4b2c5470',
        'cff4d9c4-ee01-43fa-9518-62872afbbe91',
        '160b403b-2a16-4b43-afac-a3b37916c968',
        '0fd4e8ed-e208-44e5-b463-ece053a915f3',
        '4a63f4ec-637e-4627-a668-5339fe64b9be'
    ), FALSE) AS is_excluded_settlement,
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
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'Master' AND tx_country IN ('US', 'USA') AND resp_code = 'APPROVE' AND transaction_type IN ('authorization.clearing', 'authorization.reversal') AND is_excluded_settlement = FALSE THEN 1 ELSE 0 END) AS m_dom_auth_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'Master' AND tx_country NOT IN ('US', 'USA') AND resp_code = 'APPROVE' AND transaction_type IN ('authorization.clearing', 'authorization.reversal') AND is_excluded_settlement = FALSE THEN 1 ELSE 0 END) AS m_int_auth_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'VISA' AND tx_country IN ('US', 'USA') AND resp_code = 'APPROVE' AND transaction_type IN ('authorization.clearing', 'authorization.reversal') AND is_excluded_settlement = FALSE THEN 1 ELSE 0 END) AS v_dom_auth_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'VISA' AND tx_country NOT IN ('US', 'USA') AND resp_code = 'APPROVE' AND transaction_type IN ('authorization.clearing', 'authorization.reversal') AND is_excluded_settlement = FALSE THEN 1 ELSE 0 END) AS v_int_auth_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'Master' AND tx_country NOT IN ('US', 'USA') AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND transaction_type = 'authorization.reversal' AND is_excluded_settlement = FALSE THEN 1 ELSE 0 END) AS m_int_reversal_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'VISA' AND tx_country NOT IN ('US', 'USA') AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND transaction_type = 'authorization.reversal' AND is_excluded_settlement = FALSE THEN 1 ELSE 0 END) AS v_int_reversal_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND tx_country IN ('US', 'USA') AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND transaction_type = 'authorization.reversal' AND is_excluded_settlement = FALSE THEN 1 ELSE 0 END) AS dom_reversal_count,
    0 AS m_int_refund_count,
    0 AS v_int_refund_count,
    0 AS dom_refund_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'Master' AND tx_country IN ('US', 'USA') AND is_excluded_settlement = FALSE AND (resp_code IS NULL OR resp_code <> 'DECLINE') THEN 1 ELSE 0 END) AS av_m_dom_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'Master' AND tx_country NOT IN ('US', 'USA') AND is_excluded_settlement = FALSE AND (resp_code IS NULL OR resp_code <> 'DECLINE') THEN 1 ELSE 0 END) AS av_m_int_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'VISA' AND tx_country IN ('US', 'USA') AND is_excluded_settlement = FALSE AND (resp_code IS NULL OR resp_code <> 'DECLINE') THEN 1 ELSE 0 END) AS av_v_dom_count,
    MAX(CASE WHEN business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'VISA' AND tx_country NOT IN ('US', 'USA') AND is_excluded_settlement = FALSE AND (resp_code IS NULL OR resp_code <> 'DECLINE') THEN 1 ELSE 0 END) AS av_v_int_count
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
    MAX(CASE WHEN business_type = 'Credit' AND card_org = 'Master' AND settle_country NOT IN ('US', 'USA') AND transaction_type = 'refund.clearing' AND resp_code = 'APPROVE' AND is_excluded_settlement = FALSE THEN 1 ELSE 0 END) AS m_int_refund_count,
    MAX(CASE WHEN business_type = 'Credit' AND card_org = 'VISA' AND settle_country NOT IN ('US', 'USA') AND transaction_type = 'refund.clearing' AND resp_code = 'APPROVE' AND is_excluded_settlement = FALSE THEN 1 ELSE 0 END) AS v_int_refund_count,
    MAX(CASE WHEN business_type = 'Credit' AND settle_country IN ('US', 'USA') AND transaction_type = 'refund.clearing' AND resp_code = 'APPROVE' AND is_excluded_settlement = FALSE THEN 1 ELSE 0 END) AS dom_refund_count
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
FROM (
    SELECT
        report_date,
        account_id,
        account_type,
        account_category,
        system_type,
        m_dom_auth_count,
        m_int_auth_count,
        v_dom_auth_count,
        v_int_auth_count,
        m_int_reversal_count,
        v_int_reversal_count,
        dom_reversal_count,
        CAST(0 AS INT) AS m_int_refund_count,
        CAST(0 AS INT) AS v_int_refund_count,
        CAST(0 AS INT) AS dom_refund_count,
        av_m_dom_count,
        av_m_int_count,
        av_v_dom_count,
        av_v_int_count,
        sale_id,
        am_id
    FROM v_bb_txn_count_metrics
    UNION ALL
    SELECT
        report_date,
        account_id,
        account_type,
        account_category,
        system_type,
        CAST(0 AS INT) AS m_dom_auth_count,
        CAST(0 AS INT) AS m_int_auth_count,
        CAST(0 AS INT) AS v_dom_auth_count,
        CAST(0 AS INT) AS v_int_auth_count,
        CAST(0 AS INT) AS m_int_reversal_count,
        CAST(0 AS INT) AS v_int_reversal_count,
        CAST(0 AS INT) AS dom_reversal_count,
        m_int_refund_count,
        v_int_refund_count,
        dom_refund_count,
        CAST(0 AS INT) AS av_m_dom_count,
        CAST(0 AS INT) AS av_m_int_count,
        CAST(0 AS INT) AS av_v_dom_count,
        CAST(0 AS INT) AS av_v_int_count,
        sale_id,
        am_id
    FROM v_bb_post_count_metrics
) unioned
GROUP BY report_date, account_id, account_type, account_category, system_type, sale_id, am_id;

CREATE TEMPORARY VIEW v_bb_txn_amount_metrics AS
SELECT
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    -- 对齐 bb-202605.sql q3：authorization.clearing 与 refund.clearing 共同形成净金额。
    CAST(SUM(CASE WHEN business_type IN ('Credit', 'Consumption') AND card_org = 'Master' AND settle_country IN ('US', 'USA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND settlement_match_type = 'card_transaction_id' AND resp_code = 'APPROVE' AND is_excluded_settlement = FALSE THEN -billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS m_dom_clearing_vol,
    CAST(SUM(CASE WHEN business_type IN ('Credit', 'Consumption') AND card_org = 'Master' AND settle_country NOT IN ('US', 'USA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND settlement_match_type = 'card_transaction_id' AND resp_code = 'APPROVE' AND is_excluded_settlement = FALSE THEN -billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS m_int_clearing_vol,
    CAST(SUM(CASE WHEN business_type IN ('Credit', 'Consumption') AND card_org = 'VISA' AND settle_country IN ('US', 'USA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND settlement_match_type = 'card_transaction_id' AND resp_code = 'APPROVE' AND is_excluded_settlement = FALSE THEN -billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS v_dom_clearing_vol,
    CAST(SUM(CASE WHEN business_type IN ('Credit', 'Consumption') AND card_org = 'VISA' AND settle_country NOT IN ('US', 'USA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND settlement_match_type = 'card_transaction_id' AND resp_code = 'APPROVE' AND is_excluded_settlement = FALSE THEN -billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS v_int_clearing_vol,
    CAST(SUM(CASE WHEN business_type IN ('Credit', 'Consumption') AND card_org IN ('Master', 'VISA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND settlement_match_type = 'card_transaction_id' AND resp_code = 'APPROVE' AND is_excluded_settlement = FALSE THEN -billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS bb_rebate_base_amt,
    CAST(SUM(CASE WHEN business_type IN ('Credit', 'Consumption') AND card_org IN ('Master', 'VISA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND settlement_match_type = 'card_transaction_id' AND resp_code = 'APPROVE' AND is_excluded_settlement = FALSE THEN -billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS bb_channel_cashback_comm,
    sale_id,
    am_id
FROM v_bb_completion_rows
GROUP BY report_date, account_id, account_type, account_category, system_type, sale_id, am_id;

CREATE TEMPORARY VIEW v_dws_bb_txn_daily_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', account_id, ':', COALESCE(sale_id, ''), ':', COALESCE(am_id, '')))) AS BIGINT) AS id,
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    CAST(SUM(m_dom_auth_count) AS INT) AS m_dom_auth_count,
    CAST(SUM(m_int_auth_count) AS INT) AS m_int_auth_count,
    CAST(SUM(v_dom_auth_count) AS INT) AS v_dom_auth_count,
    CAST(SUM(v_int_auth_count) AS INT) AS v_int_auth_count,
    CAST(SUM(m_int_decline_count) AS INT) AS m_int_decline_count,
    CAST(SUM(v_int_decline_count) AS INT) AS v_int_decline_count,
    CAST(SUM(dom_decline_count) AS INT) AS dom_decline_count,
    CAST(0 AS INT) AS ac_m_int_decline_count,
    CAST(0 AS INT) AS ac_v_int_decline_count,
    CAST(0 AS INT) AS ac_dom_decline_count,
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
    CAST(SUM(m_dom_clearing_vol) AS DECIMAL(20, 4)) AS m_dom_clearing_vol,
    CAST(SUM(m_int_clearing_vol) AS DECIMAL(20, 4)) AS m_int_clearing_vol,
    CAST(SUM(v_dom_clearing_vol) AS DECIMAL(20, 4)) AS v_dom_clearing_vol,
    CAST(SUM(v_int_clearing_vol) AS DECIMAL(20, 4)) AS v_int_clearing_vol,
    CAST(SUM(bb_rebate_base_amt) AS DECIMAL(20, 4)) AS bb_rebate_base_amt,
    CAST(SUM(bb_channel_cashback_comm) AS DECIMAL(20, 4)) AS bb_channel_cashback_comm,
    CAST(0 AS INT) AS active_card_count,
    sale_id,
    am_id,
    1 AS version,
    'bb_v2_batch_q3_refund_net_20260721' AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM (
    SELECT
        report_date,
        account_id,
        account_type,
        account_category,
        system_type,
        m_dom_auth_count,
        m_int_auth_count,
        v_dom_auth_count,
        v_int_auth_count,
        CAST(0 AS INT) AS m_int_decline_count,
        CAST(0 AS INT) AS v_int_decline_count,
        CAST(0 AS INT) AS dom_decline_count,
        CAST(0 AS INT) AS ac_m_int_decline_count,
        CAST(0 AS INT) AS ac_v_int_decline_count,
        CAST(0 AS INT) AS ac_dom_decline_count,
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
        CAST(0 AS DECIMAL(20, 4)) AS m_dom_clearing_vol,
        CAST(0 AS DECIMAL(20, 4)) AS m_int_clearing_vol,
        CAST(0 AS DECIMAL(20, 4)) AS v_dom_clearing_vol,
        CAST(0 AS DECIMAL(20, 4)) AS v_int_clearing_vol,
        CAST(0 AS DECIMAL(20, 4)) AS bb_rebate_base_amt,
        CAST(0 AS DECIMAL(20, 4)) AS bb_channel_cashback_comm,
        sale_id,
        am_id
    FROM v_bb_count_metrics
    UNION ALL
    SELECT
        report_date,
        account_id,
        account_type,
        account_category,
        system_type,
        CAST(0 AS INT) AS m_dom_auth_count,
        CAST(0 AS INT) AS m_int_auth_count,
        CAST(0 AS INT) AS v_dom_auth_count,
        CAST(0 AS INT) AS v_int_auth_count,
        CAST(0 AS INT) AS m_int_decline_count,
        CAST(0 AS INT) AS v_int_decline_count,
        CAST(0 AS INT) AS dom_decline_count,
        CAST(0 AS INT) AS ac_m_int_decline_count,
        CAST(0 AS INT) AS ac_v_int_decline_count,
        CAST(0 AS INT) AS ac_dom_decline_count,
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
        m_dom_clearing_vol,
        m_int_clearing_vol,
        v_dom_clearing_vol,
        v_int_clearing_vol,
        bb_rebate_base_amt,
        bb_channel_cashback_comm,
        sale_id,
        am_id
    FROM v_bb_txn_amount_metrics
) unioned
GROUP BY report_date, account_id, account_type, account_category, system_type, sale_id, am_id;

CREATE TEMPORARY VIEW v_bb_auth_month_rows AS
SELECT
    CAST(auth_time AS DATE) AS report_date,
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
    CAST(SUM(ac_m_int_decline_count) AS INT) AS ac_m_int_decline_count,
    CAST(SUM(ac_v_int_decline_count) AS INT) AS ac_v_int_decline_count,
    CAST(SUM(ac_dom_decline_count) AS INT) AS ac_dom_decline_count,
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
        MAX(CASE WHEN is_decline = TRUE AND is_account_verification = FALSE AND is_excluded_request = FALSE AND is_dom = TRUE THEN 1 ELSE 0 END) AS dom_decline_count,
        MAX(CASE WHEN is_decline = TRUE AND is_account_verification = TRUE AND is_excluded_request = FALSE AND card_org = 'Master' AND is_dom = FALSE THEN 1 ELSE 0 END) AS ac_m_int_decline_count,
        MAX(CASE WHEN is_decline = TRUE AND is_account_verification = TRUE AND is_excluded_request = FALSE AND card_org = 'VISA' AND is_dom = FALSE THEN 1 ELSE 0 END) AS ac_v_int_decline_count,
        MAX(CASE WHEN is_decline = TRUE AND is_account_verification = TRUE AND is_excluded_request = FALSE AND is_dom = TRUE THEN 1 ELSE 0 END) AS ac_dom_decline_count
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
    ac_m_int_decline_count,
    ac_v_int_decline_count,
    ac_dom_decline_count,
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
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', account_id, ':', COALESCE(sale_id, ''), ':', COALESCE(am_id, '')))) AS BIGINT) AS id,
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
    CAST(0 AS INT) AS active_card_count,
    CAST(
        COALESCE(m_dom_clearing_vol, CAST(0 AS DECIMAL(20, 4)))
      + COALESCE(m_int_clearing_vol, CAST(0 AS DECIMAL(20, 4)))
      + COALESCE(v_dom_clearing_vol, CAST(0 AS DECIMAL(20, 4)))
      + COALESCE(v_int_clearing_vol, CAST(0 AS DECIMAL(20, 4)))
      AS DECIMAL(20, 4)
    ) AS total_net_amount,
    sale_id,
    am_id,
    1 AS version,
    'bb_v2_batch_q3_refund_net_20260721' AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM (
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
        CAST(SUM(m_int_decline_count) AS INT) AS m_int_decline_count,
        CAST(SUM(v_int_decline_count) AS INT) AS v_int_decline_count,
        CAST(SUM(dom_decline_count) AS INT) AS dom_decline_count,
        CAST(SUM(ac_m_int_decline_count) AS INT) AS ac_m_int_decline_count,
        CAST(SUM(ac_v_int_decline_count) AS INT) AS ac_v_int_decline_count,
        CAST(SUM(ac_dom_decline_count) AS INT) AS ac_dom_decline_count,
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
        CAST(SUM(m_dom_clearing_vol) AS DECIMAL(20, 4)) AS m_dom_clearing_vol,
        CAST(SUM(m_int_clearing_vol) AS DECIMAL(20, 4)) AS m_int_clearing_vol,
        CAST(SUM(v_dom_clearing_vol) AS DECIMAL(20, 4)) AS v_dom_clearing_vol,
        CAST(SUM(v_int_clearing_vol) AS DECIMAL(20, 4)) AS v_int_clearing_vol,
        CAST(SUM(bb_rebate_base_amt) AS DECIMAL(20, 4)) AS bb_rebate_base_amt,
        CAST(SUM(bb_channel_cashback_comm) AS DECIMAL(20, 4)) AS bb_channel_cashback_comm,
        sale_id,
        am_id
    FROM (
        SELECT
            report_date,
            account_id,
        account_type,
        account_category,
        system_type,
        m_dom_auth_count,
        m_int_auth_count,
        v_dom_auth_count,
        v_int_auth_count,
        CAST(0 AS INT) AS m_int_decline_count,
        CAST(0 AS INT) AS v_int_decline_count,
        CAST(0 AS INT) AS dom_decline_count,
        CAST(0 AS INT) AS ac_m_int_decline_count,
        CAST(0 AS INT) AS ac_v_int_decline_count,
        CAST(0 AS INT) AS ac_dom_decline_count,
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
        sale_id,
        am_id
    FROM v_dws_bb_txn_daily_base
    UNION ALL
    SELECT
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
        ac_m_int_decline_count,
        ac_v_int_decline_count,
        ac_dom_decline_count,
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
        sale_id,
        am_id
    FROM v_dws_bb_auth_daily_base
    ) unioned
    GROUP BY report_date, account_id, account_type, account_category, system_type, sale_id, am_id
) aggregated;

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
    cashback_rate            DECIMAL(20, 8),
    cashback_income          DECIMAL(20, 4),
    cost_fixed_fee           DECIMAL(20, 4),
    special_fee_type         STRING,
    sale_id                  STRING,
    am_id                    STRING,
    version                  INT,
    remarks                  STRING,
    create_time              TIMESTAMP(6),
    update_time              TIMESTAMP(6),
    delete_time              TIMESTAMP(6),
    PRIMARY KEY (report_date, account_id, sale_id, am_id, special_fee_type) NOT ENFORCED
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
    b.ac_m_int_decline_count,
    b.ac_v_int_decline_count,
    b.ac_dom_decline_count,
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
    b.total_net_amount,
    CAST(0.02057316 AS DECIMAL(20, 8)) AS cashback_rate,
    CAST(b.bb_rebate_base_amt * CAST(0.02057316 AS DECIMAL(20, 8)) AS DECIMAL(20, 4)) AS cashback_income,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee,
    CAST('NORMAL' AS STRING) AS special_fee_type,
    COALESCE(b.sale_id, '') AS sale_id,
    COALESCE(b.am_id, '') AS am_id,
    b.version,
    b.remarks,
    b.create_time,
    b.update_time,
    b.delete_time
FROM v_dws_bb_daily_base b;
