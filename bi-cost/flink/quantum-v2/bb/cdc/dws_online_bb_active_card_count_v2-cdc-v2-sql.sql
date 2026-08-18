-- Notes:
--   1. v2 在同一个 Flink SQL 作业中通过 JDBC source 调用 dws.fn_delete_bb_active_card_count_v2_cdc(false) 先清理目标数据。
--   2. 部署时需要在“附加依赖文件”添加 PostgreSQL JDBC driver，例如 postgresql-42.7.4.jar。
--   3. 首次执行可将函数参数 false 改为 true 做 dry-run。
--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-16
-- Updated Time:   2026-08-06 01:03:20
-- Description:    BB v2 Active Card Count CDC 每日重算写入 v2
-- 作业元信息：
--   作业类型：批式 CDC 修复任务
--   运行方式：按 batch 口径重算当前月
--   运行参数：无
-- Notes:
--   1. 只维护 active_card_count。
--   2. 只落每月 1 号特殊行，special_fee_type = ACTIVE_CARD_ACCOUNT_FEE。
--   3. 销售归属取执行时客户最新有效关系，不按 auth_time 历史关系拆分。
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

-- ==============================================
-- 0. 【临时表】ADBPG 删除函数调用结果
-- ==============================================
CREATE TEMPORARY TABLE source_delete_bb_active_card_count_v2_cdc_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT dws.fn_delete_bb_active_card_count_v2_cdc(false) AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

CREATE TEMPORARY TABLE source_dwm_bb_card_auth_detail_v2_p (
    id               STRING,
    card_proxy       STRING,
    account_id       STRING,
    account_type     STRING,
    account_category STRING,
    system_type      STRING,
    auth_time        TIMESTAMP(6),
    update_time      TIMESTAMP(6),
    delete_time      TIMESTAMP(6),
    PRIMARY KEY (id, auth_time) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id, card_proxy, account_id, account_type, account_category, system_type, auth_time, update_time, delete_time FROM dwm.dwm_bb_card_auth_detail_v2_p WHERE auth_time >= date_trunc(''month'', CURRENT_DATE)::timestamp AND auth_time < (date_trunc(''month'', CURRENT_DATE) + INTERVAL ''1 month'')::timestamp) AS dwm_bb_card_auth_detail_v2_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY TABLE source_dim_sale_account_relation_p (
    id                    STRING,
    relation_account_id   STRING,
    sale_id               STRING,
    am_id                 STRING,
    relation_start_time   TIMESTAMP(6),
    relation_end_time     TIMESTAMP(6),
    delete_time           TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id, relation_account_id, sale_id, am_id, relation_start_time, relation_end_time, delete_time FROM dim.dim_sale_account_relation_p WHERE delete_time IS NULL) AS dim_sale_account_relation_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY TABLE source_api_account_relation (
    account_id  STRING,
    root_id     STRING,
    delete_time TIMESTAMP(6),
    PRIMARY KEY (account_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT account_id, root_id, delete_time FROM ods.ods_api_account_relation WHERE delete_time IS NULL) AS ods_api_account_relation_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_month_scope AS
SELECT
    CAST(DATE_FORMAT(CAST(CURRENT_DATE AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month,
    CAST(DATE_FORMAT(CAST(DATE_ADD(CAST(DATE_FORMAT(CAST(CURRENT_DATE AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE), 32) AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS next_month;

CREATE TEMPORARY VIEW v_active_account_month AS
SELECT
    CAST(DATE_FORMAT(CAST(a.auth_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_date,
    a.account_id,
    a.account_type,
    a.account_category,
    a.system_type,
    CAST(COUNT(DISTINCT a.card_proxy) AS INT) AS active_card_count
FROM source_dwm_bb_card_auth_detail_v2_p a
INNER JOIN v_month_scope m
    ON a.auth_time >= CAST(m.report_month AS TIMESTAMP(6))
   AND a.auth_time < CAST(m.next_month AS TIMESTAMP(6))
WHERE a.delete_time IS NULL
  AND a.account_id IS NOT NULL
  AND a.card_proxy IS NOT NULL
GROUP BY
    CAST(DATE_FORMAT(CAST(a.auth_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE),
    a.account_id,
    a.account_type,
    a.account_category,
    a.system_type;

CREATE TEMPORARY VIEW v_latest_direct_sale_relation AS
SELECT account_id, sale_id, am_id
FROM (
    SELECT
        b.account_id,
        sr.sale_id,
        sr.am_id,
        ROW_NUMBER() OVER (
            PARTITION BY b.account_id
            ORDER BY sr.relation_start_time DESC, sr.id DESC
        ) AS rn
    FROM (SELECT DISTINCT account_id FROM v_active_account_month) b
    INNER JOIN source_dim_sale_account_relation_p sr
        ON sr.relation_account_id = b.account_id
       AND sr.delete_time IS NULL
       AND sr.relation_start_time <= CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6))
       AND (sr.relation_end_time IS NULL OR sr.relation_end_time > CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)))
) ranked_direct
WHERE rn = 1;

CREATE TEMPORARY VIEW v_latest_root_sale_relation AS
SELECT account_id, sale_id, am_id
FROM (
    SELECT
        b.account_id,
        sr.sale_id,
        sr.am_id,
        ROW_NUMBER() OVER (
            PARTITION BY b.account_id
            ORDER BY sr.relation_start_time DESC, sr.id DESC
        ) AS rn
    FROM (SELECT DISTINCT account_id FROM v_active_account_month) b
    INNER JOIN source_api_account_relation aar
        ON aar.account_id = b.account_id
       AND aar.delete_time IS NULL
    INNER JOIN source_dim_sale_account_relation_p sr
        ON sr.relation_account_id = aar.root_id
       AND sr.delete_time IS NULL
       AND sr.relation_start_time <= CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6))
       AND (sr.relation_end_time IS NULL OR sr.relation_end_time > CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)))
) ranked_root
WHERE rn = 1;

CREATE TEMPORARY VIEW v_bb_active_card_count_rows AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT('ACTIVE_CARD_ACCOUNT_FEE:', DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', b.account_id, ':', COALESCE(d.sale_id, r.sale_id, ''), ':', COALESCE(d.am_id, r.am_id, '')))) AS BIGINT) AS id,
    b.report_date,
    b.account_id,
    b.account_type,
    b.account_category,
    b.system_type,
    b.active_card_count,
    COALESCE(d.sale_id, r.sale_id) AS sale_id,
    COALESCE(d.am_id, r.am_id) AS am_id
FROM v_active_account_month b
LEFT JOIN v_latest_direct_sale_relation d
    ON d.account_id = b.account_id
LEFT JOIN v_latest_root_sale_relation r
    ON r.account_id = b.account_id
   AND d.account_id IS NULL;

CREATE TEMPORARY TABLE sink_dws_bb_card_finance_daily_v2_p (
    id                         BIGINT,
    report_date                DATE,
    account_id                 STRING,
    account_type               STRING,
    account_category           STRING,
    system_type                STRING,
    active_card_count          INT,
    cost_fixed_fee             DECIMAL(20, 4),
    special_fee_type           STRING,
    sale_id                    STRING,
    am_id                      STRING,
    version                    INT,
    remarks                    STRING,
    create_time                TIMESTAMP(6),
    update_time                TIMESTAMP(6),
    delete_time                TIMESTAMP(6),
    PRIMARY KEY (report_date, account_id, sale_id, am_id, special_fee_type) NOT ENFORCED
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
    active_card_count,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee,
    'ACTIVE_CARD_ACCOUNT_FEE' AS special_fee_type,
    COALESCE(sale_id, '') AS sale_id,
    COALESCE(am_id, '') AS am_id,
    1 AS version,
    'bb_active_card_count_v2' AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_bb_active_card_count_rows
CROSS JOIN source_delete_bb_active_card_count_v2_cdc_result AS delete_result
WHERE delete_result.affected_rows >= 0;
