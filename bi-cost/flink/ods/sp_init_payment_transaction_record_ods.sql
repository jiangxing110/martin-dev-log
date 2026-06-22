--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-22
-- 功能：public.payment_transaction_record 批量初始化到 ODS 层 ods_payment_transaction_record
-- 模式：全量 + 按月回刷 | JDBC 批处理
-- 说明：
--   1. 源表 public.payment_transaction_record 已在 ADBPG，无 CDC 需求时走 JDBC batch
--   2. submit_time 取 create_time 作为提交时间
--   3. dt 取 create_time::DATE
--   4. 支持传入 start_time / end_time 控制回刷范围
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
-- start_time = 2024-01-01 00:00:00
-- end_time   = 2026-07-01 00:00:00

-- ====================================================================
-- 1. Source: public.payment_transaction_record
-- ====================================================================

CREATE TEMPORARY TABLE source_payment_transaction_record (
    id                       BIGINT,
    create_time              TIMESTAMP(6),
    update_time              TIMESTAMP(6),
    delete_time              TIMESTAMP(6),
    version                  INT,
    remarks                  STRING,
    source_transaction_id    STRING,
    inquiry_id               BIGINT,
    business_type            STRING,
    account_id               STRING,
    status                   STRING,
    channel                  STRING,
    third_party_payment_id   STRING,
    from_amount              DECIMAL(20, 8),
    from_currency            STRING,
    to_amount                DECIMAL(20, 8),
    to_currency              STRING,
    settle_amount            DECIMAL(20, 8),
    rate                     DECIMAL(20, 8),
    payee_id                 BIGINT,
    parent_id                BIGINT,
    same_name_payment        BOOLEAN,
    balance_id               STRING,
    settle_currency          STRING,
    fee                      DECIMAL(20, 8),
    balance_channel          STRING,
    payout_direction_type    STRING,
    third_party_reason       STRING,
    refund_amount            DECIMAL(20, 8),
    refund_rate              DECIMAL(20, 8),
    transaction_display_id   STRING,
    webhook_status           STRING,
    payout_mode              STRING,
    extra                    STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, create_time, update_time, delete_time, version, remarks, source_transaction_id, inquiry_id, business_type, account_id::text, status, channel, third_party_payment_id, from_amount, from_currency, to_amount, to_currency, settle_amount, rate, payee_id, parent_id, same_name_payment, balance_id, settle_currency, fee, balance_channel, payout_direction_type, third_party_reason, refund_amount, refund_rate, transaction_display_id, webhook_status, payout_mode, extra::text FROM public.payment_transaction_record WHERE create_time >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND create_time < CAST(''${end_time}'' AS TIMESTAMP(6))) AS ptr_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

-- ====================================================================
-- 2. Sink: ods.ods_payment_transaction_record
-- ====================================================================

CREATE TEMPORARY TABLE sink_ods_payment_transaction_record (
    id                       STRING,
    dt                       DATE,
    create_time              TIMESTAMP(6),
    update_time              TIMESTAMP(6),
    delete_time              TIMESTAMP(6),
    version                  INT,
    remarks                  STRING,
    source_transaction_id    STRING,
    inquiry_id               BIGINT,
    business_type            STRING,
    account_id               STRING,
    status                   STRING,
    channel                  STRING,
    third_party_payment_id   STRING,
    from_amount              DECIMAL(20, 8),
    from_currency            STRING,
    to_amount                DECIMAL(20, 8),
    to_currency              STRING,
    settle_amount            DECIMAL(20, 8),
    rate                     DECIMAL(20, 8),
    payee_id                 BIGINT,
    parent_id                BIGINT,
    same_name_payment        BOOLEAN,
    balance_id               STRING,
    settle_currency          STRING,
    fee                      DECIMAL(20, 8),
    balance_channel          STRING,
    payout_direction_type    STRING,
    third_party_reason       STRING,
    refund_amount            DECIMAL(20, 8),
    refund_rate              DECIMAL(20, 8),
    transaction_display_id   STRING,
    webhook_status           STRING,
    payout_mode              STRING,
    extra                    STRING,
    submit_time              TIMESTAMP(6),
    PRIMARY KEY (id, dt) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'ods_payment_transaction_record',
    'targetSchema' = 'ods',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '200'
);

-- ====================================================================
-- 3. INSERT: 全量同步，submit_time = create_time
-- ====================================================================

INSERT INTO sink_ods_payment_transaction_record
SELECT
    CAST(id AS STRING) AS id,
    CAST(create_time AS DATE) AS dt,
    create_time,
    update_time,
    delete_time,
    version,
    remarks,
    source_transaction_id,
    inquiry_id,
    business_type,
    account_id,
    status,
    channel,
    third_party_payment_id,
    from_amount,
    from_currency,
    to_amount,
    to_currency,
    settle_amount,
    rate,
    payee_id,
    parent_id,
    same_name_payment,
    balance_id,
    settle_currency,
    fee,
    balance_channel,
    payout_direction_type,
    third_party_reason,
    refund_amount,
    refund_rate,
    transaction_display_id,
    webhook_status,
    payout_mode,
    extra,
    create_time AS submit_time
FROM source_payment_transaction_record;
