--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-16
-- Description:    BB v2 渠道固定成本 CDC 每日维护
-- 作业元信息：
--   作业类型：批式 CDC 修复任务
--   运行方式：默认重算当前月；如昨天 CHANNEL_COST 有变更，也重算对应月份
--   运行参数：无
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

CREATE TEMPORARY TABLE source_dws_bb_card_finance_daily_v2_p (
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
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_bb_card_finance_daily_v2_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY VIEW v_month_scope AS
SELECT DISTINCT report_month, CAST(DATE_FORMAT(CAST(DATE_ADD(report_month, 32) AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS next_month
FROM (
    SELECT CAST(DATE_FORMAT(CAST(CURRENT_DATE AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
    UNION
    SELECT CAST(DATE_FORMAT(CAST(statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
    FROM source_bi_month_tag
    WHERE tag = 'CHANNEL_COST'
      AND provider = 'BB'
      AND update_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP(6))
      AND update_time < CAST(CURRENT_DATE AS TIMESTAMP(6))
) m
WHERE report_month IS NOT NULL;

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
       AND t.delete_time IS NULL
       AND t.provider = 'BB'
       AND (t.statistics_time < CAST(m.next_month AS TIMESTAMP(6)) OR t.detail = 'DEFAULT_FALLBACK')
) ranked
WHERE rn = 1;

CREATE TEMPORARY VIEW v_allocation_base AS
SELECT *
FROM source_dws_bb_card_finance_daily_v2_p
WHERE delete_time IS NULL
  AND (special_fee_type IS NULL OR special_fee_type <> 'CHANNEL_FIXED_FEE')
  AND EXISTS (
      SELECT 1 FROM v_month_scope m
      WHERE report_date >= m.report_month AND report_date < m.next_month
  );

CREATE TEMPORARY VIEW v_month_row_count AS
SELECT CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month, COUNT(*) AS row_count
FROM v_allocation_base
GROUP BY CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE);

CREATE TEMPORARY VIEW v_fixed_fee_rows AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT('CHANNEL_FIXED_FEE:BB:', DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', b.account_id, ':', COALESCE(b.sale_id, ''), ':', COALESCE(b.am_id, '')))) AS BIGINT) AS id,
    b.report_date,
    b.account_id,
    b.account_type,
    b.account_category,
    b.system_type,
    b.sale_id,
    b.am_id,
    CAST(COALESCE(c.month_fixed_fee / NULLIF(rc.row_count, 0), 0) AS DECIMAL(20, 4)) AS cost_fixed_fee
FROM v_allocation_base b
LEFT JOIN v_month_row_count rc
    ON CAST(DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = rc.report_month
LEFT JOIN v_month_channel_cost c
    ON c.report_month = rc.report_month;

CREATE TEMPORARY TABLE sink_dws_bb_card_finance_daily_v2_p (
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
    'tableName' = 'dws_bb_card_finance_daily_v2_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

DELETE FROM sink_dws_bb_card_finance_daily_v2_p
WHERE special_fee_type = 'CHANNEL_FIXED_FEE'
  AND EXISTS (SELECT 1 FROM v_month_scope m WHERE report_date >= m.report_month AND report_date < m.next_month);

INSERT INTO sink_dws_bb_card_finance_daily_v2_p
SELECT
    id,
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    cost_fixed_fee,
    'CHANNEL_FIXED_FEE' AS special_fee_type,
    sale_id,
    am_id,
    1 AS version,
    'bb_channel_fixed_fee_v2' AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_fixed_fee_rows;
