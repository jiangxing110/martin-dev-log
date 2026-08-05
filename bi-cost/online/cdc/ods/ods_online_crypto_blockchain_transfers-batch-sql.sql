--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-22
-- Updated Time:   2026-08-05 14:54:40
-- 历史名称：sp_init_crypto_blockchain_transfers_ods.sql
-- 功能：PG视图 view_crypto_assets_blockchain_transfers 同步到 ODS层 ods_crypto_blockchain_transfers
-- 作业元信息：
--   作业类型：批处理
--   运行方式：定期调度执行
--   运行参数：无
--   源库变更响应：源为派生视图 view_crypto_assets_blockchain_transfers，不能直接 CDC；源数据变化需依赖上游 ODS/MV 刷新后重跑。
--   ODS说明：本脚本同步派生视图结果；原始表变更需先进入上游 ODS/MV，再调度重跑本脚本。
-- 模式：JDBC 批读（视图不支持 CDC），全量刷新
-- 说明：每天调度执行；先运行 delete-table-data JAR 作业清理目标表，
--       JAR 作业成功后再运行本脚本全量拉取视图数据写入。
-- JAR 业务参数：--schema ods --table-name ods_crypto_blockchain_transfers
--               --start-date 2021-01-01 --end-date 2027-01-01
-- 注意：本脚本必须作为独立 VVR Draft/Deployment 运行，并通过工作流依赖 JAR 删除作业。
----------------------------------------------------------------------

SET 'parallelism.default' = '1';
SET 'sink.parallelism' = '1';
SET 'table.dml-sync' = 'true';
SET 'pipeline.operator-chaining' = 'true';
SET 'execution.checkpointing.interval' = '5min';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'execution.checkpointing.timeout' = '30min';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '1';
SET 'restart-strategy.fixed-delay.delay' = '60s';

-- ==============================================
-- 1. 【临时表】PG 视图源（JDBC 批读）
-- ==============================================
CREATE TEMPORARY TABLE source_view_crypto_blockchain_transfers (
    id                       STRING,
    transaction_display_id   STRING,
    account_id               STRING,
    wallet_id                STRING,
    balance_id               STRING,
    action                   STRING,
    currency                 STRING,
    chain                    STRING,
    source_address           STRING,
    destination_address      STRING,
    amount                   STRING,
    gas_fee                  STRING,
    cross_chain_fee          STRING,
    status                   STRING,
    transaction_hash         STRING,
    risk_level               STRING,
    create_time              TIMESTAMP(6),
    third_party_create_time  TIMESTAMP(6),
    completion_time          TIMESTAMP(6),
    third_party_id           STRING,
    platform                 STRING,
    usd_rate                 DECIMAL(20, 8),
    fees                     STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.PG_TEST_HOST}:${secret_values.PG_TEST_PORT1}/${secret_values.PG_TEST_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id::text AS id, transaction_display_id::text AS transaction_display_id, account_id::text AS account_id, wallet_id::text AS wallet_id, balance_id::text AS balance_id, action::text AS action, currency::text AS currency, chain::text AS chain, source_address::text AS source_address, destination_address::text AS destination_address, amount::text AS amount, gas_fee::text AS gas_fee, cross_chain_fee::text AS cross_chain_fee, status::text AS status, transaction_hash::text AS transaction_hash, risk_level::text AS risk_level, NULLIF(create_time::text, '''')::timestamp AS create_time, NULLIF(third_party_create_time::text, '''')::timestamp AS third_party_create_time, NULLIF(completion_time::text, '''')::timestamp AS completion_time, third_party_id::text AS third_party_id, platform::text AS platform, usd_rate, fees::text AS fees FROM public.view_crypto_assets_blockchain_transfers WHERE NULLIF(create_time::text, '''') IS NOT NULL) AS view_crypto_assets_blockchain_transfers_f',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

-- ==============================================
-- 2. 【临时表】ADBPG 目标表 ods.ods_crypto_blockchain_transfers
-- ==============================================
CREATE TEMPORARY TABLE sink_ods_crypto_blockchain_transfers (
    id                       STRING,
    dt                       DATE,
    transaction_display_id   STRING,
    account_id               STRING,
    wallet_id                STRING,
    balance_id               STRING,
    action                   STRING,
    currency                 STRING,
    chain                    STRING,
    source_address           STRING,
    destination_address      STRING,
    amount                   STRING,
    gas_fee                  STRING,
    cross_chain_fee          STRING,
    status                   STRING,
    transaction_hash         STRING,
    risk_level               STRING,
    create_time              TIMESTAMP(6),
    third_party_create_time  TIMESTAMP(6),
    completion_time          TIMESTAMP(6),
    third_party_id           STRING,
    platform                 STRING,
    usd_rate                 DECIMAL(20, 8),
    fees                     STRING,
    submit_time              TIMESTAMP(6),
    PRIMARY KEY (id, dt) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'ods_crypto_blockchain_transfers',
    'targetSchema' = 'ods',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '200'
);

-- ==============================================
-- 3. 数据同步: dt = create_time::DATE, submit_time = 当前时间
-- ==============================================
INSERT INTO sink_ods_crypto_blockchain_transfers
SELECT
    id,
    CAST(create_time AS DATE) AS dt,
    transaction_display_id,
    account_id,
    wallet_id,
    balance_id,
    action,
    currency,
    chain,
    source_address,
    destination_address,
    amount,
    gas_fee,
    cross_chain_fee,
    status,
    transaction_hash,
    risk_level,
    create_time,
    third_party_create_time,
    completion_time,
    third_party_id,
    platform,
    usd_rate,
    fees,
    CURRENT_TIMESTAMP AS submit_time
FROM source_view_crypto_blockchain_transfers;
