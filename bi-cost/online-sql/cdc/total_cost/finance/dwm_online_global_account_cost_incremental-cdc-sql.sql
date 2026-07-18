--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-23
-- Description:    金融渠道成本 DWM CDC初始化 - GLOBAL_ACCOUNT
-- 作业元信息：
--   作业类型：流处理 CDC
--   运行方式：全量初始化 + 增量实时同步
--   运行参数：无
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑或由上游 CDC ODS/DIM 提供最新数据。
-- Providers:      BZ / CL
-- 说明：按渠道拆分，每个作业只加载自己需要的 source 表
-- 执行前置：
--   UPDATE dwm.dwm_finance_channel_cost_p
--   SET delete_time = NOW(), update_time = NOW()
--   WHERE source_month = '2026-05-01'::date
--     AND product_line = 'GLOBAL_ACCOUNT'
--     AND delete_time IS NULL;
--********************************************************************--

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
SET 'table.exec.batch-shuffle-mode' = 'ALL_EXCHANGES_BLOCKING';
SET 'taskmanager.network.sort-shuffle.min-buffers' = '512';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '1';
SET 'restart-strategy.fixed-delay.delay' = '60s';
SET 'sql-client.execution.result-mode' = 'tableau';

-- ====================================================================

-- NOTE: v_param （批处理硬编码日期）已移除，CDC 版本需调整日期逻辑

CREATE TEMPORARY VIEW v_day_numbers AS
SELECT *
FROM (
    VALUES
        (1), (2), (3), (4), (5), (6), (7), (8), (9), (10),
        (11), (12), (13), (14), (15), (16), (17), (18), (19), (20),
        (21), (22), (23), (24), (25), (26), (27), (28), (29), (30), (31)
) AS t(day_no);

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

CREATE TEMPORARY TABLE source_payment_transaction_record (
    id                       STRING,
    account_id               STRING,
    channel                  STRING,
    payout_direction_type    STRING,
    status                   STRING,
    settle_amount            DECIMAL(20, 4),
    extra                    STRING,
    submit_time              TIMESTAMP(6),
    delete_time              TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, account_id, channel, payout_direction_type, status, settle_amount, extra, submit_time, delete_time FROM ods.ods_payment_transaction_record WHERE delete_time IS NULL) AS payment_transaction_record_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_global_sub_account (
    id          STRING,
    account_id  STRING,
    provider    STRING,
    status      STRING,
    delete_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, account_id, provider, status, delete_time FROM ods.ods_global_sub_account WHERE delete_time IS NULL) AS global_sub_account_f',
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

-- BZ/ZB: Payout 金额
CREATE TEMPORARY VIEW v_bz_basis AS
SELECT
    CAST(ptr.submit_time AS DATE) AS report_date,
    ptr.account_id,
    'GLOBAL_ACCOUNT' AS product_line,
    'BZ' AS provider,
    'PAYOUT_FEE' AS cost_type,
    CAST(0 AS DECIMAL(20, 4)) AS basis_count,
    CAST(SUM(COALESCE(ptr.settle_amount, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 4)) AS basis_amount,
    CAST(0 AS INT) AS month_day_count
FROM source_payment_transaction_record ptr
-- NOTE: 原 INNER JOIN v_param 已移除（批处理参数）
WHERE ptr.channel = 'ZB'
  AND ptr.payout_direction_type = 'SubToPayee'
  AND ptr.status = 'Closed'
  AND ptr.delete_time IS NULL
GROUP BY ptr.account_id, CAST(ptr.submit_time AS DATE)
HAVING CAST(SUM(COALESCE(ptr.settle_amount, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 4)) <> CAST(0 AS DECIMAL(20, 4));

-- CL: 活跃子账户客户数
CREATE TEMPORARY VIEW v_cl_accounts AS
SELECT g.account_id
FROM source_global_sub_account g
WHERE g.provider = 'Column'
  AND g.status = 'Active'
  AND g.delete_time IS NULL
GROUP BY g.account_id;

CREATE TEMPORARY VIEW v_cl_basis AS
SELECT
    d.report_date,
    a.account_id,
    'GLOBAL_ACCOUNT' AS product_line,
    'CL' AS provider,
    'ACTIVE_SUB_ACCOUNT_COST' AS cost_type,
    CAST(1 AS DECIMAL(20, 4)) AS basis_count,
    CAST(0 AS DECIMAL(20, 4)) AS basis_amount,
    d.month_day_count
FROM v_cl_accounts a
CROSS JOIN v_month_days d;

-- ====================================================================
-- 4. 合并分摊明细 + 月汇总
-- ====================================================================

CREATE TEMPORARY VIEW v_cost_basis_detail AS
SELECT * FROM v_bz_basis
UNION ALL SELECT * FROM v_cl_basis;

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
    p.source_month,
    p.next_month,
    p.month_day_count,
    CAST(SUM(COALESCE(t.amount, CAST(0 AS DECIMAL(20, 4)))) AS DECIMAL(20, 4)) AS source_amount
FROM v_param p
CROSS JOIN source_bi_month_tag t
INNER JOIN (SELECT DISTINCT product_line, provider, cost_type FROM v_cost_basis) cb
    ON cb.product_line = t.product_line
   AND cb.provider = t.provider
WHERE t.delete_time IS NULL
GROUP BY t.product_line, t.provider, t.tag, cb.cost_type, p.source_month, p.next_month, p.month_day_count;

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

CREATE TEMPORARY VIEW v_direct_sale_relation AS
SELECT cost_key, sale_id, am_id
FROM (
    SELECT
        CONCAT(
            DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':',
            b.account_id, ':', b.product_line, ':', b.provider, ':', b.cost_type
        ) AS cost_key,
        sr.sale_id,
        sr.am_id,
        ROW_NUMBER() OVER (
            PARTITION BY b.report_date, b.account_id, b.product_line, b.provider, b.cost_type
            ORDER BY sr.relation_start_time DESC
        ) AS rn
    FROM v_allocated_cost_base b
    INNER JOIN source_dim_sale_account_relation_p sr
        ON sr.relation_account_id = b.account_id
       AND sr.delete_time IS NULL
       AND CAST(b.report_date AS TIMESTAMP(6)) >= sr.relation_start_time
       AND (
            CAST(b.report_date AS TIMESTAMP(6)) < sr.relation_end_time
            OR sr.relation_end_time IS NULL
       )
) ranked_direct
WHERE rn = 1;

CREATE TEMPORARY VIEW v_root_sale_relation AS
SELECT cost_key, sale_id, am_id
FROM (
    SELECT
        CONCAT(
            DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':',
            b.account_id, ':', b.product_line, ':', b.provider, ':', b.cost_type
        ) AS cost_key,
        sr.sale_id,
        sr.am_id,
        ROW_NUMBER() OVER (
            PARTITION BY b.report_date, b.account_id, b.product_line, b.provider, b.cost_type
            ORDER BY sr.relation_start_time DESC
        ) AS rn
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
       )
) ranked_root
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
        COALESCE(d.sale_id, r.sale_id, ''), ':',
        COALESCE(d.am_id, r.am_id, '')
    ))) AS BIGINT) AS id,
    b.report_date,
    b.account_id,
    da.account_type,
    da.account_category,
    da.system_type,
    COALESCE(d.sale_id, r.sale_id) AS sale_id,
    COALESCE(d.am_id, r.am_id) AS am_id,
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
    CAST('global_account_batch' AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_allocated_cost_base b
LEFT JOIN source_dim_account da ON da.id = b.account_id
LEFT JOIN v_direct_sale_relation d
    ON d.cost_key = CONCAT(
        DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':',
        b.account_id, ':', b.product_line, ':', b.provider, ':', b.cost_type
    )
LEFT JOIN v_root_sale_relation r
    ON r.cost_key = CONCAT(
        DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':',
        b.account_id, ':', b.product_line, ':', b.provider, ':', b.cost_type
    )
   AND d.cost_key IS NULL
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
SELECT * FROM v_dwm_finance_channel_cost;
