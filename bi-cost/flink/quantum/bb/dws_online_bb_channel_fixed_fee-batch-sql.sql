--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-07-16
-- Description:    Quantum BB 老表固定渠道成本批量回刷
-- 作业元信息：
--   作业类型：批处理
--   运行方式：按 start_date/end_date 覆盖月份重算 cost_fixed_fee
--   运行参数：start_date, end_date
-- Notes:
--   1. 老表没有 special_fee_type，固定成本直接回写已有 DWS 明细行的 cost_fixed_fee。
--   2. 不新增额外特殊费用行；只更新已有 (id, report_date)。
--   3. 固定成本来源 ods.ods_bi_month_tag，tag = CHANNEL_COST，provider = BB。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';

CREATE TEMPORARY TABLE source_bi_month_tag (
    id              BIGINT,
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
    'table-name' = '(SELECT id, provider, tag, statistics_time, amount, detail, update_time, delete_time FROM ods.ods_bi_month_tag WHERE delete_time IS NULL) AS bi_month_tag_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_dws_bb_card_finance_daily_p (
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
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id, report_date, account_id, account_type, account_category, system_type, m_dom_auth_count, m_int_auth_count, v_dom_auth_count, v_int_auth_count, m_int_decline_count, v_int_decline_count, dom_decline_count, m_int_reversal_count, v_int_reversal_count, dom_reversal_count, m_int_refund_count, v_int_refund_count, dom_refund_count, av_m_dom_count, av_m_int_count, av_v_dom_count, av_v_int_count, m_dom_clearing_vol, m_int_clearing_vol, v_dom_clearing_vol, v_int_clearing_vol, bb_rebate_base_amt, bb_channel_cashback_comm, active_card_count, cost_fixed_fee, sale_id, am_id, version, remarks, create_time, update_time, delete_time FROM dws.dws_bb_card_finance_daily_p WHERE report_date >= CAST(''${start_date}'' AS date) AND report_date < CAST(''${end_date}'' AS date)) AS dws_bb_card_finance_daily_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_month_scope AS
SELECT DISTINCT
    CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month,
    CAST(DATE_FORMAT(CAST(DATE_ADD(CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE), 32) AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS next_month
FROM source_dws_bb_card_finance_daily_p
WHERE report_date >= CAST('${start_date}' AS DATE)
  AND report_date < CAST('${end_date}' AS DATE)
  AND delete_time IS NULL;

CREATE TEMPORARY VIEW v_month_channel_cost AS
SELECT report_month, amount AS month_fixed_fee
FROM (
    SELECT
        m.report_month,
        t.amount,
        ROW_NUMBER() OVER (
            PARTITION BY m.report_month
            ORDER BY
                CASE WHEN t.detail = 'DEFAULT_FALLBACK' THEN 1 ELSE 0 END,
                t.statistics_time DESC,
                t.update_time DESC,
                t.id DESC
        ) AS rn
    FROM v_month_scope m
    LEFT JOIN source_bi_month_tag t
        ON t.tag = 'CHANNEL_COST'
       AND t.provider = 'BB'
       AND t.delete_time IS NULL
       AND (t.statistics_time < CAST(m.next_month AS TIMESTAMP(6)) OR t.detail = 'DEFAULT_FALLBACK')
) ranked
WHERE rn = 1;

CREATE TEMPORARY VIEW v_month_row_count AS
SELECT
    CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month,
    COUNT(*) AS row_count
FROM source_dws_bb_card_finance_daily_p
WHERE delete_time IS NULL
GROUP BY CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE);

CREATE TEMPORARY VIEW v_fixed_fee_update_rows AS
SELECT
    d.id,
    d.report_date,
    d.account_id,
    d.account_type,
    d.account_category,
    d.system_type,
    d.m_dom_auth_count,
    d.m_int_auth_count,
    d.v_dom_auth_count,
    d.v_int_auth_count,
    d.m_int_decline_count,
    d.v_int_decline_count,
    d.dom_decline_count,
    d.m_int_reversal_count,
    d.v_int_reversal_count,
    d.dom_reversal_count,
    d.m_int_refund_count,
    d.v_int_refund_count,
    d.dom_refund_count,
    d.av_m_dom_count,
    d.av_m_int_count,
    d.av_v_dom_count,
    d.av_v_int_count,
    d.m_dom_clearing_vol,
    d.m_int_clearing_vol,
    d.v_dom_clearing_vol,
    d.v_int_clearing_vol,
    d.bb_rebate_base_amt,
    d.bb_channel_cashback_comm,
    d.active_card_count,
    CAST(COALESCE(c.month_fixed_fee / NULLIF(rc.row_count, 0), 0) AS DECIMAL(20, 4)) AS cost_fixed_fee,
    d.sale_id,
    d.am_id,
    d.version,
    d.remarks,
    d.create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    d.delete_time
FROM source_dws_bb_card_finance_daily_p d
LEFT JOIN v_month_row_count rc
    ON CAST(DATE_FORMAT(CAST(d.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = rc.report_month
LEFT JOIN v_month_channel_cost c
    ON c.report_month = rc.report_month
WHERE d.delete_time IS NULL;

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
    cost_fixed_fee,
    sale_id,
    am_id,
    version,
    remarks,
    create_time,
    update_time,
    delete_time
FROM v_fixed_fee_update_rows;
