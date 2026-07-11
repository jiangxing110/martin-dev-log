--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-23
-- 历史名称：sp_init_crypto_asset_safeheron_cost.sql
-- Description:    金融渠道成本 DWM CDC 初始化 - CRYPTO_ASSET / Safeheron
-- 作业元信息：
--   作业类型：CDC
--   运行方式：默认读取昨天更新的 ods_bi_month_tag 记录
--   运行参数：无（默认读取昨天更新的 ods_bi_month_tag 记录）
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑或由上游 CDC ODS/DIM 提供最新数据。
-- 说明：按底层 provider 拆分，每个作业只加载自己需要的 source 表
-- 执行前置：
--   UPDATE dwm.dwm_finance_channel_cost_p
--   SET delete_time = NOW(), update_time = NOW()
--   WHERE source_month IN (由 update_time 窗口推导的月份集合)
--     AND product_line = 'CRYPTO_ASSET'
--     AND delete_time IS NULL;
--********************************************************************--
-- 作业类型：CDC (默认昨天)

SET 'parallelism.default' = '1';
SET 'sink.parallelism' = '1';
SET 'table.dml-sync' = 'true';
SET 'pipeline.operator-chaining' = 'true';
SET 'execution.checkpointing.interval' = '5min';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'execution.checkpointing.timeout' = '30min';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'table.optimizer.reuse-source-enabled' = 'true';
SET 'table.optimizer.reuse-sub-plan-enabled' = 'true';
SET 'table.optimizer.broadcast.join.enabled' = 'false';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '1';
SET 'restart-strategy.fixed-delay.delay' = '60s';
SET 'sql-client.execution.result-mode' = 'tableau';
-- 降低 sort-shuffle 最小 buffer 量：并行度 1，数据量小，2048 buffer/分区 过于浪费
SET 'taskmanager.network.sort-shuffle.min-buffers' = '512';
-- 降低 floating-buffers-per-gate：默认 256 × 8 个消费者 = 2048 超出 TM buffer 池
SET 'taskmanager.network.memory.floating-buffers-per-gate' = '64';
SET 'taskmanager.network.memory.fraction' = '0.20';
SET 'taskmanager.network.memory.min' = '128mb';
SET 'taskmanager.network.memory.max' = '512mb';
-- CDC 任务保持默认 shuffle 策略，避免额外放大 network buffer 占用

-- ====================================================================
-- 1. 参数
-- ====================================================================

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
    source_month    DATE,
    next_month      DATE,
    month_day_count INT,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT t.id, t.product_line, t.provider, t.tag, t.statistics_time, t.amount, t.detail, t.update_time, t.delete_time, p.source_month, p.next_month, p.month_day_count FROM ods.ods_bi_month_tag t INNER JOIN (SELECT DISTINCT DATE_TRUNC(''month'', statistics_time)::date AS source_month, (DATE_TRUNC(''month'', statistics_time)::date + INTERVAL ''1 month'')::date AS next_month, ((DATE_TRUNC(''month'', statistics_time)::date + INTERVAL ''1 month'')::date - DATE_TRUNC(''month'', statistics_time)::date) AS month_day_count FROM ods.ods_bi_month_tag WHERE delete_time IS NULL AND update_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND update_time < CURRENT_DATE::timestamp) p ON t.statistics_time >= p.source_month::timestamp AND t.statistics_time < p.next_month::timestamp WHERE t.delete_time IS NULL) AS bi_month_tag_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_cost_month_days (
    report_date     DATE,
    month_day_count INT,
    PRIMARY KEY (report_date) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT gs.report_date::date AS report_date, p.month_day_count FROM (SELECT DISTINCT DATE_TRUNC(''month'', statistics_time)::date AS source_month, (DATE_TRUNC(''month'', statistics_time)::date + INTERVAL ''1 month'')::date AS next_month, ((DATE_TRUNC(''month'', statistics_time)::date + INTERVAL ''1 month'')::date - DATE_TRUNC(''month'', statistics_time)::date) AS month_day_count FROM ods.ods_bi_month_tag WHERE delete_time IS NULL AND update_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND update_time < CURRENT_DATE::timestamp) p CROSS JOIN LATERAL generate_series(p.source_month, p.next_month - INTERVAL ''1 day'', INTERVAL ''1 day'') AS gs(report_date)) AS cost_month_days_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '100'
);

CREATE TEMPORARY VIEW v_month_days AS
SELECT report_date, month_day_count
FROM source_cost_month_days;

CREATE TEMPORARY TABLE source_crypto_blockchain_transfers (
    account_id  STRING,
    action      STRING,
    create_time TIMESTAMP(6),
    status      STRING,
    platform    STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT bt.account_id, bt.action, bt.create_time, bt.status, bt.platform FROM ods.view_crypto_assets_blockchain_transfers bt WHERE EXISTS (SELECT 1 FROM (SELECT DISTINCT DATE_TRUNC(''month'', statistics_time)::date AS source_month, (DATE_TRUNC(''month'', statistics_time)::date + INTERVAL ''1 month'')::date AS next_month FROM ods.ods_bi_month_tag WHERE delete_time IS NULL AND update_time >= (CURRENT_DATE - INTERVAL ''1 day'')::timestamp AND update_time < CURRENT_DATE::timestamp) p WHERE bt.create_time >= p.source_month::timestamp AND bt.create_time < p.next_month::timestamp)) AS crypto_blockchain_transfers_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_api_account_relation (
    account_id  STRING,
    root_id     STRING,
    delete_time TIMESTAMP(6),
    PRIMARY KEY (account_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT account_id, root_id, delete_time FROM ods.ods_api_account_relation WHERE delete_time IS NULL) AS api_account_relation_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_dim_sale_account_relation_p (
    id                    STRING,
    relation_account_id   STRING,
    sale_id               STRING,
    am_id                 STRING,
    operation_manager_id  STRING,
    relation_start_time   TIMESTAMP(6),
    relation_end_time     TIMESTAMP(6),
    delete_time           TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, relation_account_id, sale_id, am_id, operation_manager_id, relation_start_time, relation_end_time, delete_time FROM dim.dim_sale_account_relation_p WHERE delete_time IS NULL) AS dim_sale_account_relation_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_dim_account (
    id                  VARCHAR,
    account_type        STRING,
    account_category    STRING,
    system_type         STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, account_type, type AS account_category, system_type FROM dim.dim_account) AS dim_account_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

-- ====================================================================
-- 3. 分摊基础明细
-- ====================================================================

-- Safeheron 固定成本: 用过 Safeheron 出账的客户
CREATE TEMPORARY VIEW v_safeheron_fixed_accounts AS
SELECT bt.account_id
FROM source_crypto_blockchain_transfers bt
WHERE bt.action = 'out'
  AND bt.status = 'Closed'
  AND bt.platform = 'SAFEHERON'
GROUP BY bt.account_id;

CREATE TEMPORARY VIEW v_safeheron_fixed_basis AS
SELECT
    d.report_date,
    a.account_id,
    'CRYPTO_ASSET' AS product_line,
    'Safeheron' AS provider,
    'FIXED_FEE' AS cost_type,
    CAST(1 AS DECIMAL(20, 4)) AS basis_count,
    CAST(0 AS DECIMAL(20, 4)) AS basis_amount,
    d.month_day_count
FROM v_safeheron_fixed_accounts a
CROSS JOIN v_month_days d;

-- ====================================================================
-- 4. 合并分摊明细 + 月汇总
-- ====================================================================

CREATE TEMPORARY VIEW v_cost_basis_detail AS
SELECT * FROM v_safeheron_fixed_basis;

CREATE TEMPORARY VIEW v_cost_basis_month_total AS
SELECT
    product_line,
    provider,
    cost_type,
    CAST(SUM(basis_count) AS DECIMAL(20, 4)) AS sum_basis_count,
    CAST(SUM(basis_amount) AS DECIMAL(20, 4)) AS sum_basis_amount,
    CAST(MAX(month_day_count) AS INT) AS max_month_day_count
FROM v_cost_basis_detail
GROUP BY product_line, provider, cost_type;

CREATE TEMPORARY VIEW v_cost_basis AS
SELECT
    d.report_date,
    d.account_id,
    d.product_line,
    d.provider,
    d.cost_type,
    d.basis_count,
    CAST(
        CASE
            WHEN t.max_month_day_count > 0 THEN t.sum_basis_count / CAST(t.max_month_day_count AS DECIMAL(20, 4))
            ELSE t.sum_basis_count
        END AS DECIMAL(20, 4)
    ) AS month_basis_count,
    d.basis_amount,
    t.sum_basis_amount AS month_basis_amount,
    d.month_day_count
FROM v_cost_basis_detail d
INNER JOIN v_cost_basis_month_total t
    ON t.product_line = d.product_line
   AND t.provider = d.provider
   AND t.cost_type = d.cost_type;

-- ====================================================================
-- 5. bi_month_tag 月度金额
-- ====================================================================

CREATE TEMPORARY VIEW v_bi_month_tag_cost AS
SELECT
    t.product_line,
    t.provider,
    t.tag AS source_tag,
    cb.cost_type,
    MAX(t.source_month) AS source_month,
    MAX(t.next_month) AS next_month,
    MAX(t.month_day_count) AS month_day_count,
    CAST(SUM(COALESCE(t.amount, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 4)) AS source_amount
FROM source_bi_month_tag t
INNER JOIN (SELECT DISTINCT product_line, provider, cost_type FROM v_cost_basis) cb
    ON cb.product_line = t.product_line
   AND cb.provider = t.provider
WHERE t.delete_time IS NULL
GROUP BY t.product_line, t.provider, t.tag, cb.cost_type;

-- ====================================================================
-- 6. 金额分摊
-- ====================================================================

CREATE TEMPORARY VIEW v_allocated_cost_base AS
SELECT
    b.report_date,
    b.account_id,
    b.product_line,
    b.provider,
    b.cost_type,
    mt.source_month,
    mt.source_tag,
    mt.source_amount,
    b.month_day_count,
    b.basis_count,
    b.month_basis_count,
    b.basis_amount,
    b.month_basis_amount,
    CAST(
        CASE
            WHEN b.month_basis_amount <> CAST(0 AS DECIMAL(20, 4))
                THEN b.basis_amount / b.month_basis_amount
            WHEN b.month_basis_count <> CAST(0 AS DECIMAL(20, 4)) AND b.month_day_count > 0
                THEN b.basis_count / b.month_basis_count / CAST(b.month_day_count AS DECIMAL(20, 4))
            WHEN b.month_basis_count <> CAST(0 AS DECIMAL(20, 4))
                THEN b.basis_count / b.month_basis_count
            ELSE CAST(0 AS DECIMAL(20, 10))
        END AS DECIMAL(20, 10)
    ) AS allocation_rate,
    CAST(
        mt.source_amount
        *
        CASE
            WHEN b.month_basis_amount <> CAST(0 AS DECIMAL(20, 4))
                THEN b.basis_amount / b.month_basis_amount
            WHEN b.month_basis_count <> CAST(0 AS DECIMAL(20, 4)) AND b.month_day_count > 0
                THEN b.basis_count / b.month_basis_count / CAST(b.month_day_count AS DECIMAL(20, 4))
            WHEN b.month_basis_count <> CAST(0 AS DECIMAL(20, 4))
                THEN b.basis_count / b.month_basis_count
            ELSE CAST(0 AS DECIMAL(20, 10))
        END AS DECIMAL(20, 4)
    ) AS cost_amount
FROM v_cost_basis b
INNER JOIN v_bi_month_tag_cost mt
    ON mt.product_line = b.product_line
   AND mt.provider = b.provider
   AND mt.cost_type = b.cost_type
WHERE mt.source_amount <> CAST(0 AS DECIMAL(20, 4));

-- ====================================================================
-- 7. 销售关系
-- ====================================================================

CREATE TEMPORARY VIEW v_sale_relation_candidates AS
SELECT
    CONCAT(
        DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':',
        b.account_id, ':', b.product_line, ':', b.provider, ':', b.cost_type
    ) AS cost_key,
    sr.sale_id,
    sr.am_id,
    sr.relation_start_time,
    1 AS sale_priority
FROM v_allocated_cost_base b
INNER JOIN source_dim_sale_account_relation_p sr
    ON sr.relation_account_id = b.account_id
   AND sr.delete_time IS NULL
   AND CAST(b.report_date AS TIMESTAMP(6)) >= sr.relation_start_time
   AND (
        CAST(b.report_date AS TIMESTAMP(6)) < sr.relation_end_time
        OR sr.relation_end_time IS NULL
   )
UNION ALL
SELECT
    CONCAT(
        DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':',
        b.account_id, ':', b.product_line, ':', b.provider, ':', b.cost_type
    ) AS cost_key,
    sr.sale_id,
    sr.am_id,
    sr.relation_start_time,
    2 AS sale_priority
FROM v_allocated_cost_base b
INNER JOIN source_api_account_relation aar
    ON aar.account_id = b.account_id
   AND aar.delete_time IS NULL
INNER JOIN source_dim_sale_account_relation_p sr
    ON sr.relation_account_id = aar.root_id
   AND sr.delete_time IS NULL
   AND CAST(b.report_date AS TIMESTAMP(6)) >= sr.relation_start_time
   AND (
        CAST(b.report_date AS TIMESTAMP(6)) < sr.relation_end_time
        OR sr.relation_end_time IS NULL
   );

CREATE TEMPORARY VIEW v_sale_relation AS
SELECT cost_key, sale_id, am_id
FROM (
    SELECT
        cost_key,
        sale_id,
        am_id,
        ROW_NUMBER() OVER (
            PARTITION BY cost_key
            ORDER BY sale_priority ASC, relation_start_time DESC
        ) AS rn
    FROM v_sale_relation_candidates
) ranked_sale
WHERE rn = 1;


CREATE TEMPORARY VIEW v_dwm_finance_channel_cost AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(
        DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':',
        b.account_id, ':',
        b.product_line, ':',
        b.provider, ':',
        b.cost_type, ':',
        DATE_FORMAT(CAST(b.source_month AS TIMESTAMP(6)), 'yyyyMMdd'), ':',
        b.source_tag, ':',
        COALESCE(sr.sale_id, ''), ':',
        COALESCE(sr.am_id, '')
    ))) AS BIGINT) AS id,
    b.report_date,
    b.account_id,
    da.account_type,
    da.account_category,
    da.system_type,
    sr.sale_id,
    sr.am_id,
    b.product_line,
    b.provider,
    b.cost_type,
    b.source_month,
    b.source_tag,
    b.source_amount,
    b.month_day_count,
    b.basis_count,
    b.month_basis_count,
    b.basis_amount,
    b.month_basis_amount,
    b.allocation_rate,
    b.cost_amount,
    1 AS version,
    CAST('crypto_asset_safeheron_batch' AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_allocated_cost_base b
LEFT JOIN source_dim_account da ON da.id = b.account_id
LEFT JOIN v_sale_relation sr
    ON sr.cost_key = CONCAT(
        DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':',
        b.account_id, ':', b.product_line, ':', b.provider, ':', b.cost_type
    )
WHERE b.cost_amount <> CAST(0 AS DECIMAL(20, 4));

-- ====================================================================
-- 8. Sink
-- ====================================================================

CREATE TEMPORARY TABLE sink_dwm_finance_channel_cost_p (
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
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dwm_finance_channel_cost_p',
    'targetSchema' = 'dwm',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'insert',
    'batchSize' = '2000'
);

INSERT INTO sink_dwm_finance_channel_cost_p
SELECT *
FROM v_dwm_finance_channel_cost;
