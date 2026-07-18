--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-15
-- 历史名称：sp_init_sl_card_dwm_by_fast_v2.sql
-- Description:    Quantum SL v2 DWM 批量初始化/回刷
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性初始化/回刷或调度执行
--   运行参数：start_time, end_time
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑或由上游 CDC ODS/DIM 提供最新数据。
-- Notes:
--   1. Batch 主源: PostgreSQL 侧先完成 settlement + qbit_transaction join
--   2. Flink 只消费 join 后的基础结果，减少 TaskManager 内部 hash join 压力
--   3. 当前版本挂销售归属，输出 sale_id / am_id
--   4. 按 settlement_date 回刷 DWM 分区数据
--   5. batch 脚本用于历史回刷，必须传入 start_time / end_time
--   6. 通过父表 + dt 条件触发 PostgreSQL 分区裁剪
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'sink.parallelism' = '1';
SET 'table.dml-sync' = 'true';
SET 'execution.checkpointing.interval' = '5min';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'execution.checkpointing.timeout' = '30min';
SET 'table.optimizer.reuse-source-enabled' = 'true';
SET 'table.optimizer.reuse-sub-plan-enabled' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '1';
SET 'restart-strategy.fixed-delay.delay' = '60s';
SET 'sql-client.execution.result-mode' = 'tableau';

-- 传参示例:
-- start_time = 2026-06-01 00:00:00
-- end_time   = 2026-07-01 00:00:00
-- 要求:
-- 1. start_time / end_time 必传
-- 2. 建议按自然月回刷，以便 PostgreSQL 更充分利用 dt 分区裁剪

CREATE TEMPORARY TABLE source_sl_joined_base (
    id                        STRING,
    account_id                STRING,
    account_type              STRING,
    account_category          STRING,
    system_type               STRING,
    version                   INT,
    remarks                   STRING,
    create_time               TIMESTAMP(6),
    update_time               TIMESTAMP(6),
    delete_time               TIMESTAMP(6),
    settlement_date           DATE,
    settlement_transaction_id STRING,
    qbit_card_transaction_id  STRING,
    qbit_transaction_id       STRING,
    provider                  STRING,
    billing_amount            DECIMAL(20, 4),
    billing_currency_code     STRING,
    transaction_amount        DECIMAL(20, 4),
    transaction_currency_code STRING,
    country                   STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT s.id, t.account_id, da.account_type, da.type AS account_category, da.system_type, COALESCE(s.version, 1) AS version, s.remarks, s.create_time, COALESCE(s.update_time, s.create_time) AS update_time, s.delete_time, CAST(s.settlement_day AS DATE) AS settlement_date, s.transaction_id AS settlement_transaction_id, s.qbit_card_transaction_id, t.transaction_id AS qbit_transaction_id, s.provider, CAST(COALESCE(s.billing_amount, 0) AS DECIMAL(20,4)) AS billing_amount, s.billing_currency_code, CAST(COALESCE(s.transaction_amount, 0) AS DECIMAL(20,4)) AS transaction_amount, s.transaction_currency_code, (s.raw_data::json->''merchantData''->''location''->>''country'') AS country FROM ods.ods_qbit_card_settlement_sl s INNER JOIN ods.ods_qbit_card_transaction t ON t.id = s.qbit_card_transaction_id AND t.delete_time IS NULL LEFT JOIN dim.dim_account da ON da.id = t.account_id WHERE s.dt >= CAST(''${start_time}'' AS DATE) AND s.dt < CAST(''${end_time}'' AS DATE) AND s.create_time >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND s.create_time < CAST(''${end_time}'' AS TIMESTAMP(6)) AND s.delete_time IS NULL) AS sl_joined_base_f',
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
    s.account_id,
    s.account_type,
    s.account_category,
    s.system_type,
    s.version,
    s.remarks,
    s.create_time,
    s.update_time,
    s.delete_time,
    s.settlement_date,
    s.settlement_transaction_id,
    s.qbit_card_transaction_id,
    s.qbit_transaction_id,
    s.provider,
    s.billing_amount,
    s.billing_currency_code,
    s.transaction_amount,
    s.transaction_currency_code,
    s.country,
    s.create_time AS sale_match_time,
    CAST(NULL AS STRING) AS raw_data,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS etl_time
FROM source_sl_joined_base s;

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
