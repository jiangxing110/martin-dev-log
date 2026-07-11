--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-11
-- Description:    金融渠道成本原始表 / 目标表月份对账脚本
-- 作业元信息：
--   作业类型：批处理
--   运行方式：对账检查
--   运行参数：start_month, end_month
--   用途：
--     1. 识别软删除 / 硬删除影响的月份
--     2. 对比 ods_bi_month_tag 与 dwm_finance_channel_cost_p 的月度金额
--     3. 输出存在差异的月份、产品线、provider、source_tag
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'table.optimizer.reuse-source-enabled' = 'true';
SET 'table.optimizer.reuse-sub-plan-enabled' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '1';
SET 'restart-strategy.fixed-delay.delay' = '60s';
SET 'sql-client.execution.result-mode' = 'tableau';

-- ====================================================================
-- 1. 参数
-- ====================================================================

CREATE TEMPORARY VIEW v_param AS
SELECT
    CAST(COALESCE(NULLIF('${start_month}', ''), '1900-01-01') AS DATE) AS start_month,
    CAST(COALESCE(NULLIF('${end_month}', ''), '2999-12-01') AS DATE) AS end_month;

-- ====================================================================
-- 2. Source 表
-- ====================================================================

CREATE TEMPORARY TABLE source_bi_month_tag (
    id              BIGINT,
    product_line    STRING,
    provider        STRING,
    tag             STRING,
    statistics_time TIMESTAMP(6),
    amount          DECIMAL(20, 4),
    detail          STRING,
    delete_time     TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, product_line, provider, tag, statistics_time, amount, detail, delete_time FROM ods.ods_bi_month_tag WHERE delete_time IS NULL) AS bi_month_tag_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_dwm_finance_channel_cost_p (
    id                   BIGINT,
    report_date          DATE,
    account_id           STRING,
    account_type         STRING,
    account_category     STRING,
    system_type          STRING,
    sale_id              STRING,
    am_id                STRING,
    product_line         STRING,
    provider             STRING,
    cost_type            STRING,
    source_month         DATE,
    source_tag           STRING,
    source_amount        DECIMAL(20, 4),
    month_day_count      INT,
    basis_count          DECIMAL(20, 4),
    month_basis_count    DECIMAL(20, 4),
    basis_amount         DECIMAL(20, 4),
    month_basis_amount   DECIMAL(20, 4),
    allocation_rate      DECIMAL(20, 10),
    cost_amount          DECIMAL(20, 4),
    version              INT,
    remarks              STRING,
    create_time          TIMESTAMP(6),
    update_time          TIMESTAMP(6),
    delete_time          TIMESTAMP(6),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, report_date, account_id, account_type, account_category, system_type, sale_id, am_id, product_line, provider, cost_type, source_month, source_tag, source_amount, month_day_count, basis_count, month_basis_count, basis_amount, month_basis_amount, allocation_rate, cost_amount, version, remarks, create_time, update_time, delete_time FROM dwm.dwm_finance_channel_cost_p WHERE delete_time IS NULL) AS dwm_finance_channel_cost_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

-- ====================================================================
-- 3. 月对账
-- ====================================================================

CREATE TEMPORARY VIEW v_month_diff_union AS
SELECT
    CAST(DATE_FORMAT(CAST(t.statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS source_month,
    t.product_line,
    t.provider,
    t.tag AS source_tag,
    CAST(COUNT(1) AS BIGINT) AS source_row_count,
    CAST(0 AS BIGINT) AS target_row_count,
    CAST(SUM(COALESCE(t.amount, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 4)) AS source_amount,
    CAST(0 AS DECIMAL(20, 4)) AS target_amount
FROM source_bi_month_tag t
CROSS JOIN v_param p
WHERE CAST(DATE_FORMAT(CAST(t.statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) >= p.start_month
  AND CAST(DATE_FORMAT(CAST(t.statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) <= p.end_month
GROUP BY CAST(DATE_FORMAT(CAST(t.statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE), t.product_line, t.provider, t.tag

UNION ALL

SELECT
    c.source_month,
    c.product_line,
    c.provider,
    c.source_tag,
    CAST(0 AS BIGINT) AS source_row_count,
    CAST(COUNT(1) AS BIGINT) AS target_row_count,
    CAST(0 AS DECIMAL(20, 4)) AS source_amount,
    CAST(SUM(COALESCE(c.cost_amount, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 4)) AS target_amount
FROM source_dwm_finance_channel_cost_p c
CROSS JOIN v_param p
WHERE c.source_month >= p.start_month
  AND c.source_month <= p.end_month
GROUP BY c.source_month, c.product_line, c.provider, c.source_tag;

CREATE TEMPORARY VIEW v_month_diff AS
SELECT
    source_month,
    product_line,
    provider,
    source_tag,
    CAST(SUM(source_row_count) AS BIGINT) AS source_row_count,
    CAST(SUM(target_row_count) AS BIGINT) AS target_row_count,
    CAST(SUM(source_amount) AS DECIMAL(20, 4)) AS source_amount,
    CAST(SUM(target_amount) AS DECIMAL(20, 4)) AS target_amount,
    CAST(SUM(target_amount) - SUM(source_amount) AS DECIMAL(20, 4)) AS amount_delta,
    CASE
        WHEN ABS(SUM(target_amount) - SUM(source_amount)) <= CAST(0.01 AS DECIMAL(20, 4)) THEN 'MATCH'
        WHEN SUM(source_row_count) = 0 THEN 'TARGET_ONLY'
        WHEN SUM(target_row_count) = 0 THEN 'SOURCE_ONLY'
        ELSE 'MISMATCH'
    END AS compare_status
FROM v_month_diff_union
GROUP BY source_month, product_line, provider, source_tag;

SELECT
    source_month,
    product_line,
    provider,
    source_tag,
    source_row_count,
    target_row_count,
    source_amount,
    target_amount,
    amount_delta,
    compare_status
FROM v_month_diff
WHERE compare_status <> 'MATCH'
ORDER BY source_month, product_line, provider, source_tag;
