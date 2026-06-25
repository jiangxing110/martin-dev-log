--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-15
-- Description:    Quantum SL 日增量同步: qbitCardSettlement -> DWM
-- 作业元信息：
--   作业类型：日增量批处理
--   运行方式：调度执行
--   运行参数：无
--   源库变更响应：按调度窗口回刷增量数据，不使用 CDC 常驻监听。
-- Notes:
--   1. DWM 基于 qbitCardSettlement
--   2. qbitCardSettlement.qbitCardTransactionId 仅用于补 account_id / qbit_transaction_id
--   3. 当前版本先不挂销售归属，sale_id / am_id 先写空
--   4. 当前作业为 JDBC 日增量批处理，不使用 postgres-cdc
--   5. DWS 后续只依赖 DWM 汇总 rebate_base / rebate_amt
--   6. 默认窗口为前一天 00:00:00 ~ 当天 00:00:00
--   7. 通过父表 + dt 条件触发 PostgreSQL 分区裁剪，不手工传分区表名
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
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '1';
SET 'restart-strategy.fixed-delay.delay' = '60s';
SET 'sql-client.execution.result-mode' = 'tableau';

-- 默认窗口:
-- start_time = CURRENT_DATE - INTERVAL '1' DAY
-- end_time   = CURRENT_DATE

CREATE TEMPORARY TABLE source_qbit_card_settlement (
    id                        STRING,
    dt                        DATE,
    transaction_id            STRING,
    qbit_card_transaction_id  STRING,
    provider                  STRING,
    billing_amount            DOUBLE,
    billing_currency_code     STRING,
    transaction_amount        DOUBLE,
    transaction_currency_code STRING,
    settlement_day            STRING,
    country                   STRING,
    create_time               TIMESTAMP(6),
    update_time               TIMESTAMP(6),
    delete_time               TIMESTAMP(6),
    remarks                   STRING,
    version                   INT,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, dt, transaction_id, qbit_card_transaction_id, provider, billing_amount, billing_currency_code, transaction_amount, transaction_currency_code, settlement_day, (raw_data::json->''merchantData''->''location''->>''country'') AS country, create_time, update_time, delete_time, remarks, version FROM ods.ods_qbit_card_settlement_sl WHERE dt = CURRENT_DATE - INTERVAL ''1 day'' AND create_time >= CAST(CURRENT_DATE - INTERVAL ''1 day'' AS TIMESTAMP(6)) AND create_time < CAST(CURRENT_DATE AS TIMESTAMP(6))) AS ods_qbit_card_settlement_sl_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_qbit_card_transaction (
    id                STRING,
    account_id        STRING,
    transaction_id    STRING,
    transaction_time  TIMESTAMP(6),
    delete_time       TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, account_id, transaction_id, transaction_time, delete_time FROM ods.ods_qbit_card_transaction WHERE dt = CURRENT_DATE - INTERVAL ''1 day'') AS ods_qbit_card_transaction_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_dim_account (
    id                STRING,
    account_type      STRING,
    account_category  STRING,
    system_type       STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, account_type, type AS account_category, system_type FROM dim.dim_account) AS dim_account_f',
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
    'table-name' = 'dim.dim_sale_account_relation_p',
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
    'table-name' = 'ods.ods_api_account_relation',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY VIEW v_sl_base AS
SELECT
    s.id,
    t.account_id AS account_id,
    da.account_type,
    da.account_category,
    da.system_type,
    COALESCE(s.version, 1) AS version,
    s.remarks,
    s.create_time AS create_time,
    COALESCE(s.update_time, s.create_time) AS update_time,
    s.delete_time AS delete_time,
    CAST(s.settlement_day AS DATE) AS settlement_date,
    s.transaction_id AS settlement_transaction_id,
    s.qbit_card_transaction_id AS qbit_card_transaction_id,
    t.transaction_id AS qbit_transaction_id,
    s.provider,
    CAST(COALESCE(s.billing_amount, CAST(0 AS DOUBLE)) AS DECIMAL(20, 4)) AS billing_amount,
    s.billing_currency_code AS billing_currency_code,
    CAST(COALESCE(s.transaction_amount, CAST(0 AS DOUBLE)) AS DECIMAL(20, 4)) AS transaction_amount,
    s.transaction_currency_code AS transaction_currency_code,
    s.country AS country,
    s.create_time AS sale_match_time,
    CAST(NULL AS STRING) AS raw_data,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS etl_time
FROM source_qbit_card_settlement s
INNER JOIN source_qbit_card_transaction t
    ON t.id = s.qbit_card_transaction_id
   AND t.delete_time IS NULL
LEFT JOIN source_dim_account da
    ON da.id = t.account_id
WHERE s.delete_time IS NULL
  AND s.create_time >= CAST(CURRENT_DATE - INTERVAL '1' DAY AS TIMESTAMP)
  AND s.create_time < CAST(CURRENT_DATE AS TIMESTAMP);

CREATE TEMPORARY VIEW v_sl_direct_sale_relation AS
SELECT tx_id, sale_id, am_id
FROM (
    SELECT
        b.id AS tx_id,
        sr.sale_id,
        sr.am_id,
        ROW_NUMBER() OVER (
            PARTITION BY b.id
            ORDER BY sr.relation_start_time DESC
        ) AS rn
    FROM v_sl_base b
    INNER JOIN source_dim_sale_account_relation_p sr
        ON sr.relation_account_id = b.account_id
       AND sr.delete_time IS NULL
       AND b.sale_match_time >= sr.relation_start_time
       AND (b.sale_match_time < sr.relation_end_time OR sr.relation_end_time IS NULL)
) ranked_direct
WHERE rn = 1;

CREATE TEMPORARY VIEW v_sl_root_sale_relation AS
SELECT tx_id, sale_id, am_id
FROM (
    SELECT
        b.id AS tx_id,
        sr.sale_id,
        sr.am_id,
        ROW_NUMBER() OVER (
            PARTITION BY b.id
            ORDER BY sr.relation_start_time DESC
        ) AS rn
    FROM v_sl_base b
    INNER JOIN source_api_account_relation aar
        ON aar.account_id = b.account_id
       AND aar.delete_time IS NULL
    INNER JOIN source_dim_sale_account_relation_p sr
        ON sr.relation_account_id = aar.root_id
       AND sr.delete_time IS NULL
       AND b.sale_match_time >= sr.relation_start_time
       AND (b.sale_match_time < sr.relation_end_time OR sr.relation_end_time IS NULL)
) ranked_root
WHERE rn = 1;

CREATE TEMPORARY VIEW v_dwm_sl_card_transaction_detail AS
SELECT
    b.id,
    b.account_id,
    b.account_type,
    b.account_category,
    b.system_type,
    b.version,
    b.remarks,
    b.create_time,
    b.update_time,
    b.delete_time,
    b.settlement_date,
    b.settlement_transaction_id,
    b.qbit_card_transaction_id,
    b.qbit_transaction_id,
    b.provider,
    b.billing_amount,
    b.billing_currency_code,
    b.transaction_amount,
    b.transaction_currency_code,
    b.country,
    COALESCE(d.sale_id, r.sale_id) AS sale_id,
    COALESCE(d.am_id, r.am_id) AS am_id,
    b.raw_data,
    b.etl_time
FROM v_sl_base b
LEFT JOIN v_sl_direct_sale_relation d ON d.tx_id = b.id
LEFT JOIN v_sl_root_sale_relation r ON r.tx_id = b.id AND d.tx_id IS NULL
;

CREATE TEMPORARY TABLE sink_dwm_sl_card_transaction_detail_p (
    id                         STRING,
    account_id                 STRING,
    account_type               STRING,
    account_category           STRING,
    system_type                STRING,
    version                    INT,
    remarks                    STRING,
    create_time                TIMESTAMP(6),
    update_time                TIMESTAMP(6),
    delete_time                TIMESTAMP(6),
    settlement_date            DATE,
    settlement_transaction_id  STRING,
    qbit_card_transaction_id   STRING,
    qbit_transaction_id        STRING,
    provider                   STRING,
    billing_amount             DECIMAL(20, 4),
    billing_currency_code      STRING,
    transaction_amount         DECIMAL(20, 4),
    transaction_currency_code  STRING,
    country                    STRING,
    sale_id                    STRING,
    am_id                      STRING,
    raw_data                   STRING,
    etl_time                   TIMESTAMP(6),
    PRIMARY KEY (id, settlement_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'targetSchema' = 'dwm',
    'tableName' = 'dwm_sl_card_transaction_detail_p',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '200',
    'retryWaitTime' = '5000'
);

INSERT INTO sink_dwm_sl_card_transaction_detail_p
SELECT
    id,
    account_id,
    account_type,
    account_category,
    system_type,
    version,
    remarks,
    create_time,
    update_time,
    delete_time,
    settlement_date,
    settlement_transaction_id,
    qbit_card_transaction_id,
    qbit_transaction_id,
    provider,
    billing_amount,
    billing_currency_code,
    transaction_amount,
    transaction_currency_code,
    country,
    sale_id,
    am_id,
    raw_data,
    etl_time
FROM v_dwm_sl_card_transaction_detail;
