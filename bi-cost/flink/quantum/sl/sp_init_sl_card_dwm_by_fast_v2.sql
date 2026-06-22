--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-15
-- Description:    Quantum SL DWM 批量初始化/回刷
-- Notes:
--   1. Batch 主源: PostgreSQL 侧先完成 settlement + qbit_transaction join
--   2. Flink 只消费 join 后的基础结果，减少 TaskManager 内部 hash join 压力
--   3. 当前版本先不挂销售归属，sale_id / am_id 先写空
--   4. 按 settlement_date 回刷 DWM 分区数据
--   5. init 脚本用于历史回刷，必须传入 start_time / end_time
--   6. 通过父表 + dt 条件触发 PostgreSQL 分区裁剪
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

-- 传参示例:
-- start_time = 2026-06-01 00:00:00
-- end_time   = 2026-07-01 00:00:00
-- 要求:
-- 1. start_time / end_time 必传
-- 2. 建议按自然月回刷，以便 PostgreSQL 更充分利用 dt 分区裁剪

CREATE TEMPORARY TABLE source_sl_joined_base (
    id                        STRING,
    account_id                STRING,
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
    'table-name' = '(SELECT s.id, t.account_id, COALESCE(s.version, 1) AS version, s.remarks, s.create_time, COALESCE(s.update_time, s.create_time) AS update_time, s.delete_time, CAST(s.settlement_day AS DATE) AS settlement_date, s.transaction_id AS settlement_transaction_id, s.qbit_card_transaction_id, t.transaction_id AS qbit_transaction_id, s.provider, CAST(COALESCE(s.billing_amount, 0) AS DECIMAL(20,4)) AS billing_amount, s.billing_currency_code, CAST(COALESCE(s.transaction_amount, 0) AS DECIMAL(20,4)) AS transaction_amount, s.transaction_currency_code, (s.raw_data::json->''merchantData''->''location''->>''country'') AS country FROM ods.ods_qbit_card_settlement_sl s INNER JOIN ods.ods_qbit_card_transaction t ON t.id = s.qbit_card_transaction_id AND t.delete_time IS NULL WHERE s.dt >= CAST(''${start_time}'' AS DATE) AND s.dt < CAST(''${end_time}'' AS DATE) AND s.create_time >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND s.create_time < CAST(''${end_time}'' AS TIMESTAMP(6)) AND s.delete_time IS NULL) AS sl_joined_base_f',
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

CREATE TEMPORARY VIEW v_sl_base AS
SELECT
    s.id,
    s.account_id,
    da.account_type,
    da.account_category,
    da.system_type,
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
FROM source_sl_joined_base s
LEFT JOIN source_dim_account da ON da.id = s.account_id;

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
    CAST(NULL AS STRING) AS sale_id,
    CAST(NULL AS STRING) AS am_id,
    b.raw_data,
    b.etl_time
FROM v_sl_base b
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