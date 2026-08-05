--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-31
-- Base Script:     dws_online_total_channel_cost_daily_v3-batch-sql.sql
-- Description:    总渠道成本 DWS 批量初始化/回刷 V4
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性初始化/回刷或调度执行
--   运行参数：start_date, end_date
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑或由上游 CDC ODS/DIM 提供最新数据。
-- Notes:
--   1. BB/QI/SL 作为量子卡卡渠道成本来源。
--   2. dwm_finance_channel_cost_p 承载所有产品线金融渠道成本。
--   3. 金融渠道成本按 product_line 分别进入 acquiring/business/quantum/crypto 成本桶。
--   4. V3 调整 QI 量子卡渠道成本口径：改用 dws_qi_card_finance_daily_v2_p。
--   5. QI v2 按 base * rate 计算成本，补齐 HK Regular/HK VIP/DCSF；返现字段不计入成本桶。
--   6. V4 调整 BB 量子卡渠道成本口径：改用 dws_bb_card_finance_daily_v2_p。
--   7. BB v2 成本对齐 query_bb_card_cost_detail_v2.sql，补齐 AC Decline 和 Volume Fee Cost。
--   8. V4 增加 BZ 量子卡渠道成本口径：改用 dws_bz_card_finance_daily_v2_p。
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


CREATE TEMPORARY TABLE source_dws_bb_card_finance_daily_v2_p (
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
    active_card_count        INT,
    total_net_amount         DECIMAL(20, 4),
    cost_fixed_fee           DECIMAL(20, 4),
    sale_id                  STRING,
    am_id                    STRING,
    delete_time              TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, report_date, account_id, m_dom_auth_count, m_int_auth_count, v_dom_auth_count, v_int_auth_count, m_int_decline_count, v_int_decline_count, dom_decline_count, ac_m_int_decline_count, ac_v_int_decline_count, ac_dom_decline_count, m_int_reversal_count, v_int_reversal_count, dom_reversal_count, m_int_refund_count, v_int_refund_count, dom_refund_count, av_m_dom_count, av_m_int_count, av_v_dom_count, av_v_int_count, m_dom_clearing_vol, m_int_clearing_vol, v_dom_clearing_vol, v_int_clearing_vol, active_card_count, total_net_amount, cost_fixed_fee, sale_id, am_id, delete_time FROM dws.dws_bb_card_finance_daily_v2_p WHERE report_date >= CAST(''${start_date}'' AS date) AND report_date < CAST(''${end_date}'' AS date)) AS dws_bb_card_finance_daily_v2_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_dws_qi_card_finance_daily_v2_p (
    id                           BIGINT,
    report_date                  DATE,
    account_id                   STRING,
    sale_id                      STRING,
    am_id                        STRING,
    cost_reimbursement_base_amt  DECIMAL(20, 4),
    cost_service_base_amt        DECIMAL(20, 4),
    cost_acs_regular_base_amt    DECIMAL(20, 4),
    cost_acs_vip_base_amt        DECIMAL(20, 4),
    cost_vrm_base_amt            DECIMAL(20, 4),
    cost_hk_regular_base_amt     DECIMAL(20, 4),
    cost_hk_vip_base_amt         DECIMAL(20, 4),
    cost_dcsf_base_amt           DECIMAL(20, 4),
    cost_reimbursement_rate      DECIMAL(20, 8),
    cost_service_rate            DECIMAL(20, 8),
    cost_acs_regular_rate        DECIMAL(20, 8),
    cost_acs_vip_rate            DECIMAL(20, 8),
    cost_vrm_rate                DECIMAL(20, 8),
    cost_hk_regular_rate         DECIMAL(20, 8),
    cost_hk_vip_rate             DECIMAL(20, 8),
    cost_dcsf_rate               DECIMAL(20, 8),
    cost_fixed_fee               DECIMAL(20, 4),
    delete_time                  TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, report_date, account_id, sale_id, am_id, cost_reimbursement_base_amt, cost_service_base_amt, cost_acs_regular_base_amt, cost_acs_vip_base_amt, cost_vrm_base_amt, cost_hk_regular_base_amt, cost_hk_vip_base_amt, cost_dcsf_base_amt, cost_reimbursement_rate, cost_service_rate, cost_acs_regular_rate, cost_acs_vip_rate, cost_vrm_rate, cost_hk_regular_rate, cost_hk_vip_rate, cost_dcsf_rate, cost_fixed_fee, delete_time FROM dws.dws_qi_card_finance_daily_v2_p WHERE report_date >= CAST(''${start_date}'' AS date) AND report_date < CAST(''${end_date}'' AS date)) AS dws_qi_card_finance_daily_v2_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_dws_bz_card_finance_daily_v2_p (
    id                         BIGINT,
    report_date                DATE,
    account_id                 STRING,
    sale_id                    STRING,
    am_id                      STRING,
    clearing_count             INT,
    refund_count               INT,
    clearing_base_amt          DECIMAL(20, 4),
    refund_base_amt            DECIMAL(20, 4),
    visa_charges_base_amt      DECIMAL(20, 4),
    auth_count                 INT,
    reversal_count             INT,
    settlement_volume          DECIMAL(20, 4),
    verify_count               INT,
    card_create_count          INT,
    card_active_count          INT,
    reimbursement_rate         DECIMAL(20, 8),
    visa_charges_rate          DECIMAL(20, 8),
    clearing_fee_rate          DECIMAL(20, 8),
    refund_fee_rate            DECIMAL(20, 8),
    auth_fee_rate              DECIMAL(20, 8),
    reversal_fee_rate          DECIMAL(20, 8),
    service_fee_rate           DECIMAL(20, 8),
    verify_fee_rate            DECIMAL(20, 8),
    card_setup_rate            DECIMAL(20, 8),
    account_activation_rate    DECIMAL(20, 8),
    account_on_file_rate       DECIMAL(20, 8),
    cost_fixed_fee             DECIMAL(20, 4),
    delete_time                TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, report_date, account_id, sale_id, am_id, clearing_count, refund_count, clearing_base_amt, refund_base_amt, visa_charges_base_amt, auth_count, reversal_count, settlement_volume, verify_count, card_create_count, card_active_count, reimbursement_rate, visa_charges_rate, clearing_fee_rate, refund_fee_rate, auth_fee_rate, reversal_fee_rate, service_fee_rate, verify_fee_rate, card_setup_rate, account_activation_rate, account_on_file_rate, cost_fixed_fee, delete_time FROM dws.dws_bz_card_finance_daily_v2_p WHERE report_date >= CAST(''${start_date}'' AS date) AND report_date < CAST(''${end_date}'' AS date)) AS dws_bz_card_finance_daily_v2_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_dws_sl_card_finance_daily_p (
    id              BIGINT,
    report_date     DATE,
    account_id      STRING,
    sale_id         STRING,
    am_id           STRING,
    rebate_base     DECIMAL(20, 4),
    rebate_amt      DECIMAL(20, 4),
    cost_fixed_fee  DECIMAL(20, 4),
    delete_time     TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, report_date, account_id, sale_id, am_id, rebate_base, rebate_amt, cost_fixed_fee, delete_time FROM dws.dws_sl_card_finance_daily_p WHERE report_date >= CAST(''${start_date}'' AS date) AND report_date < CAST(''${end_date}'' AS date)) AS dws_sl_card_finance_daily_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_dwm_finance_channel_cost_p (
    id               BIGINT,
    report_date      DATE,
    account_id       STRING,
    product_line      STRING,
    provider         STRING,
    cost_type        STRING,
    cost_amount      DECIMAL(20, 4),
    sale_id          STRING,
    am_id            STRING,
    delete_time      TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, report_date, account_id, product_line, provider, cost_type, cost_amount, sale_id, am_id, delete_time FROM dwm.dwm_finance_channel_cost_p WHERE report_date >= CAST(''${start_date}'' AS date) AND report_date < CAST(''${end_date}'' AS date)) AS dwm_finance_channel_cost_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY VIEW v_bb_month_net_amount AS
SELECT
    DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyyMM') AS report_month,
    CAST(SUM(COALESCE(total_net_amount, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 4)) AS month_total_net_amount
FROM source_dws_bb_card_finance_daily_v2_p
WHERE delete_time IS NULL
GROUP BY DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyyMM');

CREATE TEMPORARY VIEW v_bb_channel_cost_source AS
SELECT
    bb.report_date,
    bb.account_id,
    bb.sale_id,
    bb.am_id,
    'QUANTUM_CARD' AS product_line,
    'BB' AS cost_source,
    CAST(
        COALESCE(bb.m_dom_auth_count, 0) * 0.1090
      + COALESCE(bb.m_int_auth_count, 0) * 0.4845
      + COALESCE(bb.v_dom_auth_count, 0) * 0.0725
      + COALESCE(bb.v_int_auth_count, 0) * 0.4770
      + COALESCE(bb.av_m_dom_count, 0) * 0.1090
      + COALESCE(bb.av_m_int_count, 0) * 0.4845
      + COALESCE(bb.av_v_dom_count, 0) * 0.0725
      + COALESCE(bb.av_v_int_count, 0) * 0.4770
      + COALESCE(bb.m_dom_clearing_vol, CAST(0 AS DECIMAL(20, 4))) * 0.0021
      + COALESCE(bb.m_int_clearing_vol, CAST(0 AS DECIMAL(20, 4))) * 0.0111
      + COALESCE(bb.v_dom_clearing_vol, CAST(0 AS DECIMAL(20, 4))) * 0.0016
      + COALESCE(bb.v_int_clearing_vol, CAST(0 AS DECIMAL(20, 4))) * 0.0116
      + COALESCE(bb.m_int_reversal_count, 0) * 0.7190
      + COALESCE(bb.v_int_reversal_count, 0) * 0.7140
      + COALESCE(bb.dom_reversal_count, 0) * 0.1780
      + COALESCE(bb.m_int_refund_count, 0) * 0.4845
      + COALESCE(bb.v_int_refund_count, 0) * 0.4770
      + COALESCE(bb.dom_refund_count, 0) * 0.1090
      + COALESCE(bb.m_int_decline_count, 0) * 0.3595
      + COALESCE(bb.v_int_decline_count, 0) * 0.3570
      + COALESCE(bb.dom_decline_count, 0) * 0.0890
      + COALESCE(bb.ac_m_int_decline_count, 0) * 0.3595
      + COALESCE(bb.ac_v_int_decline_count, 0) * 0.3570
      + COALESCE(bb.ac_dom_decline_count, 0) * 0.0890
      + COALESCE(bb.active_card_count, 0) * 0.1000
      + CASE
            WHEN COALESCE(mn.month_total_net_amount, CAST(0 AS DECIMAL(20, 4))) = CAST(0 AS DECIMAL(20, 4)) THEN CAST(0 AS DECIMAL(20, 4))
            WHEN mn.month_total_net_amount <= CAST(5000000 AS DECIMAL(20, 4))
                THEN COALESCE(bb.total_net_amount, CAST(0 AS DECIMAL(20, 4))) * 0.0055
            WHEN mn.month_total_net_amount <= CAST(10000000 AS DECIMAL(20, 4))
                THEN COALESCE(bb.total_net_amount, CAST(0 AS DECIMAL(20, 4))) / mn.month_total_net_amount
                   * (CAST(5000000 AS DECIMAL(20, 4)) * 0.0055 + (mn.month_total_net_amount - CAST(5000000 AS DECIMAL(20, 4))) * 0.0045)
            ELSE COALESCE(bb.total_net_amount, CAST(0 AS DECIMAL(20, 4))) / mn.month_total_net_amount
               * (CAST(5000000 AS DECIMAL(20, 4)) * 0.0055 + CAST(5000000 AS DECIMAL(20, 4)) * 0.0045 + (mn.month_total_net_amount - CAST(10000000 AS DECIMAL(20, 4))) * 0.0040)
        END
      + COALESCE(bb.cost_fixed_fee, CAST(0 AS DECIMAL(20, 4)))
        AS DECIMAL(20, 4)
    ) AS cost_amount
FROM source_dws_bb_card_finance_daily_v2_p bb
LEFT JOIN v_bb_month_net_amount mn
    ON DATE_FORMAT(CAST(bb.report_date AS TIMESTAMP(6)), 'yyyyMM') = mn.report_month
WHERE bb.delete_time IS NULL;

CREATE TEMPORARY VIEW v_channel_cost_source AS
SELECT * FROM v_bb_channel_cost_source

UNION ALL

SELECT
    report_date,
    account_id,
    sale_id,
    am_id,
    'QUANTUM_CARD' AS product_line,
    'BZ' AS cost_source,
    CAST(
        COALESCE(clearing_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(reimbursement_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(refund_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(reimbursement_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(visa_charges_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(visa_charges_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(card_create_count, 0) * COALESCE(card_setup_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(card_create_count, 0) * COALESCE(account_activation_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(card_active_count, 0) * COALESCE(account_on_file_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(settlement_volume, CAST(0 AS DECIMAL(20, 4))) * COALESCE(service_fee_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(verify_count, 0) * COALESCE(verify_fee_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(auth_count, 0) * COALESCE(auth_fee_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(clearing_count, 0) * COALESCE(clearing_fee_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(refund_count, 0) * COALESCE(refund_fee_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(reversal_count, 0) * COALESCE(reversal_fee_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(cost_fixed_fee, CAST(0 AS DECIMAL(20, 4)))
        AS DECIMAL(20, 4)
    ) AS cost_amount
FROM source_dws_bz_card_finance_daily_v2_p
WHERE delete_time IS NULL

UNION ALL

SELECT
    report_date,
    account_id,
    sale_id,
    am_id,
    'QUANTUM_CARD' AS product_line,
    'QI' AS cost_source,
    CAST(
        COALESCE(cost_reimbursement_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(cost_reimbursement_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(cost_service_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(cost_service_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(cost_acs_regular_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(cost_acs_regular_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(cost_acs_vip_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(cost_acs_vip_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(cost_vrm_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(cost_vrm_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(cost_hk_regular_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(cost_hk_regular_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(cost_hk_vip_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(cost_hk_vip_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(cost_dcsf_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(cost_dcsf_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(cost_fixed_fee, CAST(0 AS DECIMAL(20, 4)))
        AS DECIMAL(20, 4)
    ) AS cost_amount
FROM source_dws_qi_card_finance_daily_v2_p
WHERE delete_time IS NULL

UNION ALL

SELECT
    report_date,
    account_id,
    sale_id,
    am_id,
    'QUANTUM_CARD' AS product_line,
    'SL' AS cost_source,
    CAST(COALESCE(cost_fixed_fee, CAST(0 AS DECIMAL(20, 4))) AS DECIMAL(20, 4)) AS cost_amount
FROM source_dws_sl_card_finance_daily_p
WHERE delete_time IS NULL

UNION ALL

SELECT
    report_date,
    account_id,
    sale_id,
    am_id,
    UPPER(TRIM(product_line)) AS product_line,
    CONCAT('FINANCE:', COALESCE(provider, ''), ':', COALESCE(cost_type, '')) AS cost_source,
    CAST(COALESCE(cost_amount, CAST(0 AS DECIMAL(20, 4))) AS DECIMAL(20, 4)) AS cost_amount
FROM source_dwm_finance_channel_cost_p
WHERE delete_time IS NULL;

CREATE TEMPORARY VIEW v_total_channel_cost_daily AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', account_id, ':', COALESCE(sale_id, ''), ':', COALESCE(am_id, '')))) AS BIGINT) AS id,
    report_date,
    account_id,
    sale_id,
    am_id,
    CAST(SUM(CASE WHEN UPPER(TRIM(product_line)) = 'ACQUIRING' THEN cost_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS acquiring_cost,
    CAST(SUM(CASE WHEN UPPER(TRIM(product_line)) = 'GLOBAL_ACCOUNT' THEN cost_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS business_cost,
    CAST(SUM(CASE WHEN UPPER(TRIM(product_line)) = 'QUANTUM_CARD' THEN cost_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS quantum_cost,
    CAST(SUM(CASE WHEN UPPER(TRIM(product_line)) = 'CRYPTO_ASSET' THEN cost_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS crypto_cost,
    CAST(SUM(cost_amount) AS DECIMAL(20, 4)) AS total_channel_cost,
    1 AS version,
    CAST(NULL AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_channel_cost_source
GROUP BY report_date, account_id, sale_id, am_id;

CREATE TEMPORARY TABLE sink_dws_total_channel_cost_daily_v2_p (
    id                            BIGINT,
    report_date                   DATE,
    account_id                    STRING,
    sale_id                       STRING,
    am_id                         STRING,
    acquiring_cost                DECIMAL(20, 4),
    business_cost                 DECIMAL(20, 4),
    quantum_cost                  DECIMAL(20, 4),
    crypto_cost                   DECIMAL(20, 4),
    total_channel_cost            DECIMAL(20, 4),
    version                       INT,
    remarks                       STRING,
    create_time                   TIMESTAMP(6),
    update_time                   TIMESTAMP(6),
    delete_time                   TIMESTAMP(6),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_total_channel_cost_daily_v2_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dws_total_channel_cost_daily_v2_p
SELECT * FROM v_total_channel_cost_daily;
