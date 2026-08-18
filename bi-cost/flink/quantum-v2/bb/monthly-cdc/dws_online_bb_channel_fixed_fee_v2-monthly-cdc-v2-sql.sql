--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-04
-- Updated Time:   2026-08-18 00:00:00
-- Description:    BB v2 渠道固定成本批量回刷（月固定成本按天均分，逐日分摊）
-- 作业元信息：
--   作业类型：批处理
--   运行方式：每月固定调度，按上月完整窗口重算 BB 固定成本特殊行
--   分摊口径：月固定成本 / 当月天数 = 日固定成本；每天按该日账户净额占比分摊到逐日 report_date
--   运行参数：无，自动取上月完整窗口
-- Notes:
--   1. 只写入 cost_fixed_fee 和 special_fee_type，不再使用 active_card_account_fee。
--   2. 依赖 dws_bb_card_finance_daily_v2_p 的最新基数表结构。
-- Notes:
--   1. v2 在同一个 Flink SQL 作业中通过 JDBC source 调用 dws.fn_delete_bb_channel_fixed_fee_v2_monthly_cdc(false) 先清理目标数据。
--   2. 部署时需要在“附加依赖文件”添加 PostgreSQL JDBC driver，例如 postgresql-42.7.4.jar。
--   3. 首次执行可将函数参数 false 改为 true 做 dry-run。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'taskmanager.memory.network.min' = '1536mb';
SET 'taskmanager.memory.network.max' = '1536mb';
SET 'taskmanager.memory.network.fraction' = '0.45';
SET 'taskmanager.network.sort-shuffle.min-buffers' = '64';
SET 'pipeline.default-parallelism' = '1';
SET 'table.exec.resource.default-parallelism' = '1';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'execution.application-management.enabled' = 'true';
SET 'execution.multi-jobs-in-application.enable' = 'true';

CREATE TEMPORARY TABLE source_delete_bb_channel_fixed_fee_v2_monthly_cdc_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT dws.fn_delete_bb_channel_fixed_fee_v2_monthly_cdc(false) AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

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
    total_net_amount DECIMAL(20, 4),
    special_fee_type STRING,
    delete_time      TIMESTAMP(6),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id, report_date, account_id, account_type, account_category, system_type, sale_id, am_id, total_net_amount, special_fee_type, delete_time FROM dws.dws_bb_card_finance_daily_v2_p WHERE report_date >= date_trunc(''month'', CURRENT_DATE - INTERVAL ''1 month'')::date AND report_date < date_trunc(''month'', CURRENT_DATE)::date) AS dws_bb_card_finance_daily_v2_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_month_scope AS
SELECT DISTINCT report_month, CAST(DATE_FORMAT(CAST(DATE_ADD(report_month, 32) AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS next_month
FROM (
    SELECT CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
    FROM source_dws_bb_card_finance_daily_v2_p
    WHERE report_date >= CAST(DATE_FORMAT(CAST(CURRENT_DATE - INTERVAL '1' MONTH AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE)
      AND report_date < CAST(DATE_FORMAT(CAST(CURRENT_DATE AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE)
    UNION
    SELECT CAST(DATE_FORMAT(CAST(statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
    FROM source_bi_month_tag
    WHERE tag = 'CHANNEL_COST' AND provider = 'BB'
      AND statistics_time >= CAST(DATE_FORMAT(CAST(CURRENT_DATE - INTERVAL '1' MONTH AS TIMESTAMP(6)), 'yyyy-MM-01') AS TIMESTAMP(6)) AND statistics_time < CAST(DATE_FORMAT(CAST(CURRENT_DATE AS TIMESTAMP(6)), 'yyyy-MM-01') AS TIMESTAMP(6))
) m
WHERE report_month IS NOT NULL;

CREATE TEMPORARY VIEW v_month_channel_cost AS
SELECT report_month, next_month, amount AS month_fixed_fee
FROM (
    SELECT m.report_month, m.next_month, t.amount,
        ROW_NUMBER() OVER (
            PARTITION BY m.report_month
            ORDER BY CASE WHEN t.detail = 'DEFAULT_FALLBACK' THEN 1 ELSE 0 END, t.statistics_time DESC, t.update_time DESC, t.id DESC
        ) AS rn
    FROM v_month_scope m
    LEFT JOIN source_bi_month_tag t
        ON t.tag = 'CHANNEL_COST'
       AND t.delete_time IS NULL
       AND t.provider = 'BB'
       AND (
              CAST(DATE_FORMAT(CAST(t.statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = m.report_month
           OR CAST(DATE_FORMAT(CAST(t.statistics_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = DATE '2099-01-01'
           OR t.detail = 'DEFAULT_FALLBACK'
       )
) ranked
WHERE rn = 1;

-- 月固定成本按当月天数均分 → 日固定成本
CREATE TEMPORARY VIEW v_day_channel_cost AS
SELECT
    report_month,
    next_month,
    month_fixed_fee,
    month_fixed_fee / DATEDIFF(next_month, report_month) AS day_fixed_fee
FROM v_month_channel_cost;

CREATE TEMPORARY VIEW v_allocation_base AS
SELECT *
FROM source_dws_bb_card_finance_daily_v2_p
WHERE delete_time IS NULL
  AND special_fee_type IS NULL
  AND EXISTS (
      SELECT 1 FROM v_month_scope m
      WHERE report_date >= m.report_month AND report_date < m.next_month
  );

CREATE TEMPORARY VIEW v_day_net_amount AS
SELECT
    CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month,
    report_date,
    SUM(COALESCE(total_net_amount, CAST(0 AS DECIMAL(20, 4)))) AS day_total_net_amount
FROM v_allocation_base
GROUP BY CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE), report_date;

CREATE TEMPORARY VIEW v_fixed_fee_rows AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT('CHANNEL_FIXED_FEE:BB:', CAST(b.id AS STRING), ':', DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', b.account_id, ':', COALESCE(b.sale_id, ''), ':', COALESCE(b.am_id, '')))) AS BIGINT) AS id,
    b.report_date,
    b.account_id,
    b.account_type,
    b.account_category,
    b.system_type,
    b.sale_id,
    b.am_id,
    CAST(c.day_fixed_fee * COALESCE(b.total_net_amount, CAST(0 AS DECIMAL(20, 4))) / NULLIF(na.day_total_net_amount, 0) AS DECIMAL(20, 4)) AS cost_fixed_fee
FROM v_allocation_base b
INNER JOIN v_day_net_amount na
    ON b.report_date = na.report_date
INNER JOIN v_day_channel_cost c
    ON c.report_month = na.report_month
WHERE c.month_fixed_fee IS NOT NULL
  AND c.month_fixed_fee <> CAST(0 AS DECIMAL(20, 4))
  AND na.day_total_net_amount <> CAST(0 AS DECIMAL(20, 4));

CREATE TEMPORARY VIEW v_obsolete_fixed_fee_rows AS
SELECT
    existing_row.id,
    existing_row.report_date,
    existing_row.account_id,
    existing_row.account_type,
    existing_row.account_category,
    existing_row.system_type,
    existing_row.sale_id,
    existing_row.am_id
FROM source_dws_bb_card_finance_daily_v2_p existing_row
LEFT JOIN v_fixed_fee_rows fresh
    ON fresh.id = existing_row.id
   AND fresh.report_date = existing_row.report_date
WHERE existing_row.special_fee_type = 'CHANNEL_FIXED_FEE'
  AND existing_row.delete_time IS NULL
  AND EXISTS (SELECT 1 FROM v_month_scope m WHERE existing_row.report_date >= m.report_month AND existing_row.report_date < m.next_month)
  AND fresh.id IS NULL;

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
    'writeMode' = 'insert',
    'batchSize' = '2000'
);

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
FROM v_fixed_fee_rows
CROSS JOIN source_delete_bb_channel_fixed_fee_v2_monthly_cdc_result AS delete_result
WHERE delete_result.affected_rows >= 0
UNION ALL
SELECT
    id,
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee,
    'CHANNEL_FIXED_FEE' AS special_fee_type,
    sale_id,
    am_id,
    1 AS version,
    'bb_channel_fixed_fee_v2_soft_delete' AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS delete_time
FROM v_obsolete_fixed_fee_rows
CROSS JOIN source_delete_bb_channel_fixed_fee_v2_monthly_cdc_result AS delete_result
WHERE delete_result.affected_rows >= 0;
