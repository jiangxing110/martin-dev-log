--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-27
-- Description:    BZ v2 渠道固定成本 CDC 每日维护
-- 作业元信息：
--   作业类型：批式 CDC 修复任务
--   运行方式：默认重算当前月；如昨天 bi_month_tag 有变更，也重算对应月份
--   运行参数：无
-- Notes:
--   1. 四类特殊费用行：CHANNEL_FIXED_FEE / I2C_FIXED_FEE / I2C_SUBSCRIPTION_FEE / SIGNATURE_FEE
--   2. BZ固定成本按 net_consumption 分摊，I2C固定成本/订阅费按 card_active_count 分摊
--   3. 签名费为阶梯计算后按 signature_count 分摊
--********************************************************************--

SET 'parallelism.default' = '4';
SET 'taskmanager.memory.network.min' = '1gb';
SET 'taskmanager.memory.network.max' = '3gb';
SET 'taskmanager.memory.network.fraction' = '0.2';
SET 'pipeline.default-parallelism' = '4';
SET 'table.exec.resource.default-parallelism' = '4';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'execution.multi-jobs-in-application.enable' = 'false';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

CREATE TEMPORARY TABLE source_bi_month_tag (
    id              BIGINT,
    provider        STRING,
    tag             STRING,
    remarks         STRING,
    statistics_time TIMESTAMP(6),
    amount          DECIMAL(20, 4),
    detail          STRING,
    update_time     TIMESTAMP(6),
    delete_time     TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id, provider, tag, remarks, statistics_time, amount, detail, update_time, delete_time FROM ods.ods_bi_month_tag WHERE delete_time IS NULL AND provider = ''BZ'') AS bi_month_tag_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_dws_bz_card_finance_daily_v2_p (
    id               BIGINT,
    report_date      DATE,
    account_id       STRING,
    account_type     STRING,
    account_category STRING,
    system_type      STRING,
    sale_id          STRING,
    am_id            STRING,
    total_net_amount DECIMAL(20, 4),
    card_active_count INT,
    signature_count  INT,
    special_fee_type STRING,
    delete_time      TIMESTAMP(6),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_bz_card_finance_daily_v2_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

-- 月份范围：当前月 + 昨天 bi_month_tag 变更月
CREATE TEMPORARY VIEW v_month_scope AS
SELECT DISTINCT report_month, CAST(DATE_FORMAT(CAST(DATE_ADD(report_month, 32) AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS next_month
FROM (
    SELECT CAST(DATE_FORMAT(CAST(CURRENT_DATE AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
    UNION
    SELECT CAST(DATE_FORMAT(CAST(statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
    FROM source_bi_month_tag
    WHERE tag = 'CHANNEL_COST'
      AND update_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6))
      AND update_time < CAST(CURRENT_DATE AS TIMESTAMP(6))
) m
WHERE report_month IS NOT NULL;

-- CHANNEL_COST 月度金额（按 remarks 拆分 BZ / I2C）
CREATE TEMPORARY VIEW v_month_channel_cost AS
SELECT
    report_month,
    MAX(CASE WHEN remarks IS NULL THEN amount END) AS bz_fixed_fee,
    MAX(CASE WHEN remarks = 'I2C' THEN amount END) AS i2c_fixed_fee
FROM (
    SELECT m.report_month, t.remarks, t.amount,
        ROW_NUMBER() OVER (
            PARTITION BY m.report_month, t.remarks
            ORDER BY CASE WHEN t.detail = 'DEFAULT_FALLBACK' THEN 1 ELSE 0 END, t.statistics_time DESC, t.update_time DESC, t.id DESC
        ) AS rn
    FROM v_month_scope m
    LEFT JOIN source_bi_month_tag t
        ON t.tag = 'CHANNEL_COST'
       AND t.delete_time IS NULL
       AND (
              CAST(DATE_FORMAT(CAST(t.statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = m.report_month
           OR CAST(DATE_FORMAT(CAST(t.statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = DATE '2099-01-01'
           OR t.detail = 'DEFAULT_FALLBACK'
       )
) ranked
WHERE rn = 1
GROUP BY report_month;

-- DWS 基数行
CREATE TEMPORARY VIEW v_allocation_base AS
SELECT *
FROM source_dws_bz_card_finance_daily_v2_p
WHERE delete_time IS NULL
  AND special_fee_type IS NULL
  AND EXISTS (
      SELECT 1 FROM v_month_scope m
      WHERE report_date >= m.report_month AND report_date < m.next_month
  );

CREATE TEMPORARY VIEW v_month_net_amount AS
SELECT
    CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month,
    SUM(COALESCE(total_net_amount, CAST(0 AS DECIMAL(20, 4)))) AS month_total_net_amount
FROM v_allocation_base
GROUP BY CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE);

-- 月度活跃卡合计 + I2C订阅费（固定基础费 + card_active 阶梯账户文件费）
CREATE TEMPORARY VIEW v_month_card_active AS
SELECT
    report_month,
    month_card_active,
    CAST(
          1800  -- API_Pull_Subscription_Fee
        + 4500  -- Authorization_Subscription_Fee
        + 3000  -- API_Push_Subscription_Fee
        + 2000  -- Administrative_Portal_Maintenance_Fee
        + 2700  -- Networkbased_Authentication_3DSecure_Subscription_Fee
        + 1800  -- Fraud_Service_Subscription_Charges
        + CASE WHEN month_card_active <= 50000 THEN 0 WHEN month_card_active <= 250000 THEN 2500 ELSE 2500 + CAST(CEIL(CAST(month_card_active - 250000 AS DOUBLE) / 100000.0) AS INT) * 1500 END  -- Authorization_Account_File
        + CASE WHEN month_card_active <= 50000 THEN 0 WHEN month_card_active <= 100000 THEN 1000 ELSE 1000 + CAST(CEIL(CAST(month_card_active - 100000 AS DOUBLE) / 100000.0) AS INT) * 1000 END  -- API_Pull_Account_File
        + CASE WHEN month_card_active <= 50000 THEN 0 WHEN month_card_active <= 100000 THEN 1500 ELSE 1500 + CAST(CEIL(CAST(month_card_active - 100000 AS DOUBLE) / 100000.0) AS INT) * 1500 END  -- Push_API_Account_File
        + CASE WHEN month_card_active <= 100000 THEN 0 ELSE CAST(CEIL(CAST(month_card_active - 100000 AS DOUBLE) / 100000.0) AS INT) * 1500 END  -- Networkbased_3DSecure_Account_File
        + CASE WHEN month_card_active <= 100000 THEN 0 ELSE CAST(CEIL(CAST(month_card_active - 100000 AS DOUBLE) / 100000.0) AS INT) * 1000 END  -- Fraud_Account_File
    AS DECIMAL(20, 4)) AS month_subscription_fee
FROM (
    SELECT
        CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month,
        SUM(COALESCE(card_active_count, 0)) AS month_card_active
    FROM v_allocation_base
    GROUP BY CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE)
) agg;

CREATE TEMPORARY VIEW v_month_signature_fee AS
SELECT
    report_month,
    total_signature_count,
    CAST(total_signature_count * sig_rate AS DECIMAL(20, 4)) AS month_signature_fee
FROM (
    SELECT
        report_month,
        total_signature_count,
        CASE
            WHEN total_signature_count <= 10000 THEN 0.04
            WHEN total_signature_count <= 50000 THEN 0.035
            WHEN total_signature_count <= 100000 THEN 0.03
            ELSE 0.025
        END AS sig_rate
    FROM (
        SELECT
            CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month,
            SUM(COALESCE(signature_count, 0)) AS total_signature_count
        FROM v_allocation_base
        GROUP BY CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE)
    ) sig_total
) sig_tiered;

-- BZ固定成本行
CREATE TEMPORARY VIEW v_bz_fixed_fee_rows AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT('CHANNEL_FIXED_FEE:BZ:', CAST(b.id AS STRING), ':', DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', b.account_id, ':', COALESCE(b.sale_id, ''), ':', COALESCE(b.am_id, '')))) AS BIGINT) AS id,
    b.report_date, b.account_id, b.account_type, b.account_category, b.system_type, b.sale_id, b.am_id,
    CAST(c.bz_fixed_fee * COALESCE(b.total_net_amount, CAST(0 AS DECIMAL(20, 4))) / NULLIF(na.month_total_net_amount, 0) AS DECIMAL(20, 4)) AS cost_fixed_fee,
    'CHANNEL_FIXED_FEE' AS special_fee_type
FROM v_allocation_base b
INNER JOIN v_month_net_amount na ON CAST(DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = na.report_month
INNER JOIN v_month_channel_cost c ON c.report_month = na.report_month
WHERE c.bz_fixed_fee IS NOT NULL AND c.bz_fixed_fee <> CAST(0 AS DECIMAL(20, 4)) AND na.month_total_net_amount <> CAST(0 AS DECIMAL(20, 4));

-- I2C固定成本行
CREATE TEMPORARY VIEW v_i2c_fixed_fee_rows AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT('I2C_FIXED_FEE:BZ:', CAST(b.id AS STRING), ':', DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', b.account_id, ':', COALESCE(b.sale_id, ''), ':', COALESCE(b.am_id, '')))) AS BIGINT) AS id,
    b.report_date, b.account_id, b.account_type, b.account_category, b.system_type, b.sale_id, b.am_id,
    CAST(c.i2c_fixed_fee * COALESCE(b.card_active_count, 0) / NULLIF(ca.month_card_active, 0) AS DECIMAL(20, 4)) AS cost_fixed_fee,
    'I2C_FIXED_FEE' AS special_fee_type
FROM v_allocation_base b
INNER JOIN v_month_card_active ca ON CAST(DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = ca.report_month
INNER JOIN v_month_channel_cost c ON c.report_month = ca.report_month
WHERE c.i2c_fixed_fee IS NOT NULL AND c.i2c_fixed_fee <> CAST(0 AS DECIMAL(20, 4)) AND ca.month_card_active <> 0;

-- I2C订阅费行（固定基础费 + 阶梯账户文件费, 按 card_active_count 分摊）
CREATE TEMPORARY VIEW v_i2c_subscription_fee_rows AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT('I2C_SUBSCRIPTION_FEE:BZ:', CAST(b.id AS STRING), ':', DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', b.account_id, ':', COALESCE(b.sale_id, ''), ':', COALESCE(b.am_id, '')))) AS BIGINT) AS id,
    b.report_date, b.account_id, b.account_type, b.account_category, b.system_type, b.sale_id, b.am_id,
    CAST(ca.month_subscription_fee * COALESCE(b.card_active_count, 0) / NULLIF(ca.month_card_active, 0) AS DECIMAL(20, 4)) AS cost_fixed_fee,
    'I2C_SUBSCRIPTION_FEE' AS special_fee_type
FROM v_allocation_base b
INNER JOIN v_month_card_active ca ON CAST(DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = ca.report_month
WHERE ca.month_subscription_fee IS NOT NULL AND ca.month_subscription_fee <> CAST(0 AS DECIMAL(20, 4)) AND ca.month_card_active <> 0;

-- 签名费行
CREATE TEMPORARY VIEW v_signature_fee_rows AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT('SIGNATURE_FEE:BZ:', CAST(b.id AS STRING), ':', DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', b.account_id, ':', COALESCE(b.sale_id, ''), ':', COALESCE(b.am_id, '')))) AS BIGINT) AS id,
    b.report_date, b.account_id, b.account_type, b.account_category, b.system_type, b.sale_id, b.am_id,
    CAST(sf.month_signature_fee * COALESCE(b.signature_count, 0) / NULLIF(sf.total_signature_count, 0) AS DECIMAL(20, 4)) AS cost_fixed_fee,
    'SIGNATURE_FEE' AS special_fee_type
FROM v_allocation_base b
INNER JOIN v_month_signature_fee sf ON CAST(DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = sf.report_month
WHERE sf.month_signature_fee IS NOT NULL AND sf.month_signature_fee <> CAST(0 AS DECIMAL(20, 4)) AND sf.total_signature_count <> 0;

CREATE TEMPORARY VIEW v_all_fresh_fee_rows AS
SELECT id, report_date, account_id, account_type, account_category, system_type, sale_id, am_id, cost_fixed_fee, special_fee_type FROM v_bz_fixed_fee_rows
UNION ALL
SELECT id, report_date, account_id, account_type, account_category, system_type, sale_id, am_id, cost_fixed_fee, special_fee_type FROM v_i2c_fixed_fee_rows
UNION ALL
SELECT id, report_date, account_id, account_type, account_category, system_type, sale_id, am_id, cost_fixed_fee, special_fee_type FROM v_i2c_subscription_fee_rows
UNION ALL
SELECT id, report_date, account_id, account_type, account_category, system_type, sale_id, am_id, cost_fixed_fee, special_fee_type FROM v_signature_fee_rows;

CREATE TEMPORARY TABLE sink_dws_bz_card_finance_daily_v2_p (
    id               BIGINT,
    report_date      DATE,
    account_id       STRING,
    account_type     STRING,
    account_category STRING,
    system_type      STRING,
    cost_fixed_fee   DECIMAL(20, 4),
    special_fee_type STRING,
    sale_id          STRING,
    am_id            STRING,
    version          INT,
    remarks          STRING,
    create_time      TIMESTAMP(6),
    update_time      TIMESTAMP(6),
    delete_time      TIMESTAMP(6),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_bz_card_finance_daily_v2_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

DELETE FROM sink_dws_bz_card_finance_daily_v2_p
WHERE special_fee_type IN ('CHANNEL_FIXED_FEE', 'I2C_FIXED_FEE', 'I2C_SUBSCRIPTION_FEE', 'SIGNATURE_FEE')
  AND EXISTS (SELECT 1 FROM v_month_scope m WHERE report_date >= m.report_month AND report_date < m.next_month);

INSERT INTO sink_dws_bz_card_finance_daily_v2_p
SELECT
    id,
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    cost_fixed_fee,
    special_fee_type,
    sale_id,
    am_id,
    1 AS version,
    'bz_channel_fixed_fee_v2_cdc' AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_all_fresh_fee_rows;
