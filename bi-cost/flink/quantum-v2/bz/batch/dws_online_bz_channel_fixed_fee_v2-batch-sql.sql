--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-27
-- Description:    BZ v2 渠道固定成本批量回刷
-- 作业元信息：
--   作业类型：批处理
--   运行方式：按 start_time/end_time 覆盖月份删除并重算 BZ 全部特殊费用行
--   运行参数：start_time, end_time
-- Notes:
--   1. 四类特殊费用行：
--      a) CHANNEL_FIXED_FEE  — BZ固定成本 (bi_month_tag CHANNEL_COST, remarks IS NULL, 按 net_consumption 分摊)
--      b) I2C_FIXED_FEE      — I2C固定成本 (bi_month_tag CHANNEL_COST, remarks='I2C', 按 card_active_count 分摊)
--      c) I2C_SUBSCRIPTION_FEE — I2C订阅费 (固定基础费 + card_active 阶梯账户文件费, 按 card_active_count 分摊)
--      d) SIGNATURE_FEE       — 签名费 (阶梯累进: 前250K@0.04 + 250K-500K@0.035 + 500K-1M@0.03 + >1M@0.025, 按 signature_count 分摊)
--   2. 依赖 dws_bz_card_finance_daily_v2_p 的最新基数表结构
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'taskmanager.memory.network.fraction' = '0.6';
SET 'taskmanager.memory.segment-size' = '8kb';
SET 'taskmanager.network.sort-shuffle.min-buffers' = '32';
SET 'pipeline.default-parallelism' = '1';
SET 'table.exec.resource.default-parallelism' = '1';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'execution.application-management.enabled' = 'true';
SET 'execution.multi-jobs-in-application.enable' = 'true';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

-- bi_month_tag 源（含 remarks 列区分 BZ / I2C 固定成本）
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

-- DWS 基数行源（主链路行，special_fee_type IS NULL）
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
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id, report_date, account_id, account_type, account_category, system_type, sale_id, am_id, total_net_amount, card_active_count, signature_count, special_fee_type, delete_time FROM dws.dws_bz_card_finance_daily_v2_p WHERE report_date >= CAST(''${start_time}'' AS date) AND report_date < CAST(''${end_time}'' AS date)) AS dws_bz_card_finance_daily_v2_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

-- DWS 已有特殊行源（用于软删除判定）
CREATE TEMPORARY TABLE source_dws_bz_existing_fee (
    id               BIGINT,
    report_date      DATE,
    account_id       STRING,
    account_type     STRING,
    account_category STRING,
    system_type      STRING,
    sale_id          STRING,
    am_id            STRING,
    special_fee_type STRING,
    delete_time      TIMESTAMP(6),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id, report_date, account_id, account_type, account_category, system_type, sale_id, am_id, special_fee_type, delete_time FROM dws.dws_bz_card_finance_daily_v2_p WHERE report_date >= CAST(''${start_time}'' AS date) AND report_date < CAST(''${end_time}'' AS date) AND special_fee_type IS NOT NULL) AS dws_bz_existing_fee_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

-- 月份范围
CREATE TEMPORARY VIEW v_month_scope AS
SELECT DISTINCT report_month, CAST(DATE_FORMAT(CAST(DATE_ADD(report_month, 32) AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS next_month
FROM (
    SELECT CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
    FROM source_dws_bz_card_finance_daily_v2_p
    WHERE report_date >= CAST('${start_time}' AS DATE)
      AND report_date < CAST('${end_time}' AS DATE)
    UNION
    SELECT CAST(DATE_FORMAT(CAST(statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
    FROM source_bi_month_tag
    WHERE statistics_time >= CAST('${start_time}' AS TIMESTAMP(6)) AND statistics_time < CAST('${end_time}' AS TIMESTAMP(6))
) m
WHERE report_month IS NOT NULL;

-- 月度固定成本（CHANNEL_COST 按 remarks 拆分 BZ / I2C）
CREATE TEMPORARY VIEW v_month_costs AS
SELECT
    report_month,
    MAX(CASE WHEN remarks IS NULL THEN amount END) AS bz_fixed_fee,
    MAX(CASE WHEN remarks = 'I2C' THEN amount END) AS i2c_fixed_fee
FROM (
    SELECT m.report_month, t.remarks, t.amount,
        ROW_NUMBER() OVER (
            PARTITION BY m.report_month, COALESCE(t.remarks, '')
            ORDER BY CASE WHEN t.detail = 'DEFAULT_FALLBACK' THEN 1 ELSE 0 END, t.statistics_time DESC, t.update_time DESC, t.id DESC
        ) AS rn
    FROM v_month_scope m
    LEFT JOIN source_bi_month_tag t
        ON t.tag = 'CHANNEL_COST'
       AND t.delete_time IS NULL
       AND t.provider = 'BZ'
       AND (
              CAST(DATE_FORMAT(CAST(t.statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = m.report_month
           OR CAST(DATE_FORMAT(CAST(t.statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = DATE '2099-01-01'
           OR t.detail = 'DEFAULT_FALLBACK'
       )
) ranked
WHERE rn = 1
GROUP BY report_month;

-- DWS 基数行（主链路行，用于分摊）
CREATE TEMPORARY VIEW v_allocation_base AS
SELECT *
FROM source_dws_bz_card_finance_daily_v2_p
WHERE delete_time IS NULL
  AND special_fee_type IS NULL
  AND EXISTS (
      SELECT 1 FROM v_month_scope m
      WHERE report_date >= m.report_month AND report_date < m.next_month
  );

-- 月度汇总合并（净消费 + 活跃卡 + 签名数 + 阶梯累进签名费 + I2C订阅费阶梯计算）
-- 签名费为阶梯累进：前250K@0.04, 250K-500K@0.035, 500K-1M@0.03, >1M@0.025
-- I2C订阅费 = 6项固定基础费 + 5项基于 card_active 的阶梯账户文件费
CREATE TEMPORARY VIEW v_month_totals AS
SELECT
    report_month,
    month_total_net_amount,
    month_card_active,
    total_signature_count,
    CAST(
        CASE
            WHEN total_signature_count <= 250000 THEN total_signature_count * 0.04
            WHEN total_signature_count <= 500000 THEN 250000 * 0.04 + (total_signature_count - 250000) * 0.035
            WHEN total_signature_count <= 1000000 THEN 250000 * 0.04 + 250000 * 0.035 + (total_signature_count - 500000) * 0.03
            ELSE 250000 * 0.04 + 250000 * 0.035 + 500000 * 0.03 + (total_signature_count - 1000000) * 0.025
        END AS DECIMAL(20, 4)
    ) AS month_signature_fee,
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
        SUM(COALESCE(total_net_amount, CAST(0 AS DECIMAL(20, 4)))) AS month_total_net_amount,
        SUM(COALESCE(card_active_count, 0)) AS month_card_active,
        SUM(COALESCE(signature_count, 0)) AS total_signature_count
    FROM v_allocation_base
    GROUP BY CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE)
) agg;

-- BZ固定成本行（按 net_consumption 分摊）
CREATE TEMPORARY VIEW v_bz_fixed_fee_rows AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT('CHANNEL_FIXED_FEE:BZ:', CAST(b.id AS STRING), ':', DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', b.account_id, ':', COALESCE(b.sale_id, ''), ':', COALESCE(b.am_id, '')))) AS BIGINT) AS id,
    b.report_date,
    b.account_id,
    b.account_type,
    b.account_category,
    b.system_type,
    b.sale_id,
    b.am_id,
    CAST(c.bz_fixed_fee * COALESCE(b.total_net_amount, CAST(0 AS DECIMAL(20, 4))) / NULLIF(t.month_total_net_amount, 0) AS DECIMAL(20, 4)) AS cost_fixed_fee,
    'CHANNEL_FIXED_FEE' AS special_fee_type
FROM v_allocation_base b
INNER JOIN v_month_totals t
    ON CAST(DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = t.report_month
INNER JOIN v_month_costs c
    ON c.report_month = t.report_month
WHERE c.bz_fixed_fee IS NOT NULL
  AND c.bz_fixed_fee <> CAST(0 AS DECIMAL(20, 4))
  AND t.month_total_net_amount <> CAST(0 AS DECIMAL(20, 4));

-- I2C固定成本行（按 card_active_count 分摊）
CREATE TEMPORARY VIEW v_i2c_fixed_fee_rows AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT('I2C_FIXED_FEE:BZ:', CAST(b.id AS STRING), ':', DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', b.account_id, ':', COALESCE(b.sale_id, ''), ':', COALESCE(b.am_id, '')))) AS BIGINT) AS id,
    b.report_date,
    b.account_id,
    b.account_type,
    b.account_category,
    b.system_type,
    b.sale_id,
    b.am_id,
    CAST(c.i2c_fixed_fee * COALESCE(b.card_active_count, 0) / NULLIF(t.month_card_active, 0) AS DECIMAL(20, 4)) AS cost_fixed_fee,
    'I2C_FIXED_FEE' AS special_fee_type
FROM v_allocation_base b
INNER JOIN v_month_totals t
    ON CAST(DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = t.report_month
INNER JOIN v_month_costs c
    ON c.report_month = t.report_month
WHERE c.i2c_fixed_fee IS NOT NULL
  AND c.i2c_fixed_fee <> CAST(0 AS DECIMAL(20, 4))
  AND t.month_card_active <> 0;

-- I2C订阅费行（固定基础费 + 阶梯账户文件费, 按 card_active_count 分摊）
CREATE TEMPORARY VIEW v_i2c_subscription_fee_rows AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT('I2C_SUBSCRIPTION_FEE:BZ:', CAST(b.id AS STRING), ':', DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', b.account_id, ':', COALESCE(b.sale_id, ''), ':', COALESCE(b.am_id, '')))) AS BIGINT) AS id,
    b.report_date,
    b.account_id,
    b.account_type,
    b.account_category,
    b.system_type,
    b.sale_id,
    b.am_id,
    CAST(t.month_subscription_fee * COALESCE(b.card_active_count, 0) / NULLIF(t.month_card_active, 0) AS DECIMAL(20, 4)) AS cost_fixed_fee,
    'I2C_SUBSCRIPTION_FEE' AS special_fee_type
FROM v_allocation_base b
INNER JOIN v_month_totals t
    ON CAST(DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = t.report_month
WHERE t.month_subscription_fee IS NOT NULL
  AND t.month_subscription_fee <> CAST(0 AS DECIMAL(20, 4))
  AND t.month_card_active <> 0;

-- 签名费行（阶梯计算 + 按 signature_count 分摊）
CREATE TEMPORARY VIEW v_signature_fee_rows AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT('SIGNATURE_FEE:BZ:', CAST(b.id AS STRING), ':', DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', b.account_id, ':', COALESCE(b.sale_id, ''), ':', COALESCE(b.am_id, '')))) AS BIGINT) AS id,
    b.report_date,
    b.account_id,
    b.account_type,
    b.account_category,
    b.system_type,
    b.sale_id,
    b.am_id,
    CAST(t.month_signature_fee * COALESCE(b.signature_count, 0) / NULLIF(t.total_signature_count, 0) AS DECIMAL(20, 4)) AS cost_fixed_fee,
    'SIGNATURE_FEE' AS special_fee_type
FROM v_allocation_base b
INNER JOIN v_month_totals t
    ON CAST(DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = t.report_month
WHERE t.month_signature_fee IS NOT NULL
  AND t.month_signature_fee <> CAST(0 AS DECIMAL(20, 4))
  AND t.total_signature_count <> 0;

-- 全部新鲜费用行
CREATE TEMPORARY VIEW v_all_fresh_fee_rows AS
SELECT id, report_date, account_id, account_type, account_category, system_type, sale_id, am_id, cost_fixed_fee, special_fee_type
FROM v_bz_fixed_fee_rows
UNION ALL
SELECT id, report_date, account_id, account_type, account_category, system_type, sale_id, am_id, cost_fixed_fee, special_fee_type
FROM v_i2c_fixed_fee_rows
UNION ALL
SELECT id, report_date, account_id, account_type, account_category, system_type, sale_id, am_id, cost_fixed_fee, special_fee_type
FROM v_i2c_subscription_fee_rows
UNION ALL
SELECT id, report_date, account_id, account_type, account_category, system_type, sale_id, am_id, cost_fixed_fee, special_fee_type
FROM v_signature_fee_rows;

-- 过期行软删除（存在于 DWS 但不在新鲜行中）
CREATE TEMPORARY VIEW v_obsolete_fee_rows AS
SELECT
    existing.id,
    existing.report_date,
    existing.account_id,
    existing.account_type,
    existing.account_category,
    existing.system_type,
    existing.sale_id,
    existing.am_id,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee,
    existing.special_fee_type
FROM source_dws_bz_existing_fee existing
LEFT JOIN v_all_fresh_fee_rows fresh
    ON fresh.id = existing.id
   AND fresh.report_date = existing.report_date
WHERE existing.delete_time IS NULL
  AND EXISTS (SELECT 1 FROM v_month_scope m WHERE existing.report_date >= m.report_month AND existing.report_date < m.next_month)
  AND fresh.id IS NULL;

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
    'bz_channel_fixed_fee_v2' AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_all_fresh_fee_rows
UNION ALL
SELECT
    id,
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee,
    special_fee_type,
    sale_id,
    am_id,
    1 AS version,
    'bz_channel_fixed_fee_v2_soft_delete' AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS delete_time
FROM v_obsolete_fee_rows;
