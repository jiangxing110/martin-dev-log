--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-22
-- Description:    金融渠道成本 DWM CDC初始化/回刷 V2（一次处理全部）
-- 作业元信息：
--   作业类型：流处理 CDC
--   运行方式：全量初始化 + 增量实时同步
--   运行参数：无
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑或由上游 CDC ODS/DIM 提供最新数据。
-- Notes:
--   1. V2 与 V1 的核心区别：不依赖调度参数，一次运行处理当月全部 bi_month_tag 数据。
--   2. v_param 只保留 source_month / next_month，不再有 product_line/provider/source_tag/cost_type。
--   3. v_bi_month_tag_cost 通过 CROSS JOIN v_cost_basis 的 DISTINCT (product_line, provider, cost_type)
--      自动为每条 bi_month_tag 记录匹配对应的 cost_type。
--   4. v_allocated_cost_base 不再冗余 join v_param。
--   5. 执行本 Flink SQL 前，先在 PostgreSQL 执行幂等清理:
--        UPDATE dwm.dwm_finance_channel_cost_p
--        SET delete_time = NOW(), update_time = NOW()
--        WHERE source_month = '2026-05-01'::date
--          AND delete_time IS NULL;
--   6. 2026-06-23: 修复列名 camelCase → snake_case（ODS 表统一使用 snake_case）
--      修复网络缓冲区不足: SET table.exec.batch-shuffle-mode = ALL_EXCHANGES_PIPELINED
--      原因: sort-shuffle 模式下每个 blocking result partition 预分配 2048 buffers，
--      多路 fan-out 导致 TM 上 buffer 耗尽。pipelined mode 按需分配，避免预分配耗尽。
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
SET 'table.exec.batch-shuffle-mode' = 'ALL_EXCHANGES_PIPELINED';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '1';
SET 'restart-strategy.fixed-delay.delay' = '60s';
SET 'sql-client.execution.result-mode' = 'tableau';

-- ====================================================================
-- 1. 参数（V2: 只传月份，不传 product_line/provider/source_tag/cost_type）
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

CREATE TEMPORARY TABLE source_qbit_card (
    id               STRING,
    account_id       STRING,
    provider         STRING,
    delete_card_time TIMESTAMP(6),
    delete_time      TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, account_id, provider, delete_card_time, delete_time FROM ods.ods_qbit_card WHERE delete_time IS NULL) AS qbit_card_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_idv_channel_request_record (
    id              STRING,
    account_id      STRING,
    request_channel STRING,
    request_type    STRING,
    create_time     TIMESTAMP(6),
    delete_time     TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, account_id, request_channel, request_type, create_time, delete_time FROM ods.ods_idv_channel_request_record WHERE delete_time IS NULL) AS idv_channel_request_record_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_qbit_physical_card (
    id          STRING,
    account_id  STRING,
    create_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, account_id, create_time, delete_time FROM ods.ods_qbit_physical_card WHERE delete_time IS NULL) AS qbit_physical_card_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_qbit_card_transaction (
    id               STRING,
    account_id       STRING,
    provider         STRING,
    business_type    STRING,
    status           STRING,
    settle_amount    DECIMAL(20, 4),
    transaction_time TIMESTAMP(6),
    delete_time      TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, account_id, provider, business_type, status, settle_amount, transaction_time, delete_time FROM ods.ods_qbit_card_transaction WHERE delete_time IS NULL) AS qbit_card_transaction_f',
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

CREATE TEMPORARY TABLE source_crypto_assets_transfers (
    id             STRING,
    account_id     STRING,
    recipient_type STRING,
    status         STRING,
    action         STRING,
    currency       STRING,
    origin_amount  DECIMAL(20, 4),
    usd_rate       DECIMAL(20, 8),
    extend_field   STRING,
    create_time    TIMESTAMP(6),
    delete_time    TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, account_id, recipient_type, status, action, currency, origin_amount, usd_rate, extend_field, create_time, delete_time FROM ods.ods_crypto_assets_transfers WHERE delete_time IS NULL) AS crypto_assets_transfers_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_crypto_assets_addresses (
    id          STRING,
    account_id  STRING,
    platform    STRING,
    enable      BOOLEAN,
    delete_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, account_id, platform, enable, delete_time FROM ods.ods_crypto_assets_addresses WHERE delete_time IS NULL) AS crypto_assets_addresses_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_crypto_blockchain_transfers (
    account_id  STRING,
    action      STRING,
    create_time TIMESTAMP(6),
    status      STRING,
    platform    STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT account_id, action, create_time, status, platform FROM ods.view_crypto_assets_blockchain_transfers) AS crypto_blockchain_transfers_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_dwm_acquiring_clearing (
    account_id                   STRING,
    create_date                  DATE,
    amount_type                  STRING,
    acquiring_usd_amount_total   DECIMAL(20, 3),
    delete_time                  TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT account_id, create_date, amount_type, acquiring_usd_amount_total, delete_time FROM dwm.dwm_acquiring_clearing WHERE delete_time IS NULL) AS acquiring_clearing_f',
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

-- ====================================================================
-- 3. 各渠道分摊基础明细（只输出 detail 列，不含 month_basis_count / month_basis_amount）
-- ====================================================================

-- BPC: QI 活跃卡客户
CREATE TEMPORARY VIEW v_bpc_accounts AS
SELECT q.account_id
FROM source_qbit_card q, v_param p
WHERE q.provider LIKE '%Qbit%'
GROUP BY q.account_id;

CREATE TEMPORARY VIEW v_bpc_basis AS
SELECT
    d.report_date,
    a.account_id,
    'QUANTUM_CARD' AS product_line,
    'BPC' AS provider,
    'ACTIVE_CARD_COST' AS cost_type,
    CAST(1 AS DECIMAL(20, 4)) AS basis_count,
    CAST(0 AS DECIMAL(20, 4)) AS basis_amount,
    d.month_day_count
FROM v_bpc_accounts a
CROSS JOIN v_month_days d;

-- Sumsub: KYC 记录数，按 KYC 发生日归属
CREATE TEMPORARY VIEW v_sumsub_basis AS
SELECT
    CAST(r.create_time AS DATE) AS report_date,
    r.account_id,
    'QUANTUM_CARD' AS product_line,
    'Sumsub' AS provider,
    'KYC_FEE' AS cost_type,
    CAST(COUNT(*) AS DECIMAL(20, 4)) AS basis_count,
    CAST(0 AS DECIMAL(20, 4)) AS basis_amount,
    CAST(0 AS INT) AS month_day_count
FROM source_idv_channel_request_record r
-- NOTE: 原 INNER JOIN v_param 已移除（批处理参数）
WHERE r.request_channel = 'sumsub'
  AND r.request_type = 'POST'
  AND r.delete_time IS NULL
GROUP BY r.account_id, CAST(r.create_time AS DATE);

-- IDEMIA: 实体卡数
CREATE TEMPORARY VIEW v_idemia_accounts AS
SELECT pc.account_id, COUNT(*) AS physical_card_count
FROM source_qbit_physical_card pc
-- NOTE: 原 INNER JOIN v_param 已移除（批处理参数）
WHERE pc.delete_time IS NULL
GROUP BY pc.account_id;

CREATE TEMPORARY VIEW v_idemia_basis AS
SELECT
    d.report_date,
    a.account_id,
    'QUANTUM_CARD' AS product_line,
    'IDEMIA' AS provider,
    'CARD_PRODUCTION_FEE' AS cost_type,
    CAST(a.physical_card_count AS DECIMAL(20, 4)) AS basis_count,
    CAST(0 AS DECIMAL(20, 4)) AS basis_amount,
    d.month_day_count
FROM v_idemia_accounts a
CROSS JOIN v_month_days d;

-- HZ_BANK: QI 净消费量，按消费日加权
CREATE TEMPORARY VIEW v_hz_bank_basis AS
SELECT
    CAST(tr.transaction_time AS DATE) AS report_date,
    tr.account_id,
    'QUANTUM_CARD' AS product_line,
    'HZ_BANK' AS provider,
    'CONSUME_BANK_FEE' AS cost_type,
    CAST(0 AS DECIMAL(20, 4)) AS basis_count,
    CAST(
        SUM(CASE WHEN tr.business_type = 'Consumption' AND tr.status IN ('Closed', 'Pending') THEN COALESCE(tr.settle_amount, CAST(0 AS DECIMAL(20, 4))) ELSE CAST(0 AS DECIMAL(20, 4)) END)
      - SUM(CASE WHEN tr.business_type = 'Reversal' AND tr.status IN ('Closed', 'Pending') THEN COALESCE(tr.settle_amount, CAST(0 AS DECIMAL(20, 4))) ELSE CAST(0 AS DECIMAL(20, 4)) END)
      - SUM(CASE WHEN tr.business_type = 'Credit' AND tr.status = 'Closed' THEN COALESCE(tr.settle_amount, CAST(0 AS DECIMAL(20, 4))) ELSE CAST(0 AS DECIMAL(20, 4)) END)
      AS DECIMAL(20, 4)
    ) AS basis_amount,
    CAST(0 AS INT) AS month_day_count
FROM source_qbit_card_transaction tr
-- NOTE: 原 INNER JOIN v_param 已移除（批处理参数）
WHERE tr.delete_time IS NULL
  AND tr.provider LIKE '%Qbit%'
  AND tr.business_type IN ('Credit', 'Consumption', 'Reversal')
GROUP BY tr.account_id, CAST(tr.transaction_time AS DATE)
HAVING CAST(
    SUM(CASE WHEN tr.business_type = 'Consumption' AND tr.status IN ('Closed', 'Pending') THEN COALESCE(tr.settle_amount, CAST(0 AS DECIMAL(20, 4))) ELSE CAST(0 AS DECIMAL(20, 4)) END)
  - SUM(CASE WHEN tr.business_type = 'Reversal' AND tr.status IN ('Closed', 'Pending') THEN COALESCE(tr.settle_amount, CAST(0 AS DECIMAL(20, 4))) ELSE CAST(0 AS DECIMAL(20, 4)) END)
  - SUM(CASE WHEN tr.business_type = 'Credit' AND tr.status = 'Closed' THEN COALESCE(tr.settle_amount, CAST(0 AS DECIMAL(20, 4))) ELSE CAST(0 AS DECIMAL(20, 4)) END)
  AS DECIMAL(20, 4)
) <> CAST(0 AS DECIMAL(20, 4));

-- BZ/ZB: Payout 金额，按 submitTime 日加权
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

-- Thunes wire 手续费: 按代付发生日金额加权
CREATE TEMPORARY VIEW v_th_wire_fee_basis AS
SELECT
    CAST(t.create_time AS DATE) AS report_date,
    t.account_id,
    'CRYPTO_ASSET' AS product_line,
    'TH' AS provider,
    'WIRE_BANK_FEE' AS cost_type,
    CAST(0 AS DECIMAL(20, 4)) AS basis_count,
    CAST(SUM(COALESCE(t.origin_amount, CAST(0 AS DECIMAL(20, 4))) * COALESCE(t.usd_rate, CAST(0 AS DECIMAL(20, 8)))) AS DECIMAL(20, 4)) AS basis_amount,
    CAST(0 AS INT) AS month_day_count
FROM source_crypto_assets_transfers t
-- NOTE: 原 INNER JOIN v_param 已移除（批处理参数）
WHERE t.recipient_type = 'wire'
  AND t.status = 'Closed'
  AND t.delete_time IS NULL
  AND JSON_VALUE(t.extend_field, '$.platform') = 'THUNES'
GROUP BY t.account_id, CAST(t.create_time AS DATE)
HAVING CAST(SUM(COALESCE(t.origin_amount, CAST(0 AS DECIMAL(20, 4))) * COALESCE(t.usd_rate, CAST(0 AS DECIMAL(20, 8)))) AS DECIMAL(20, 4)) <> CAST(0 AS DECIMAL(20, 4));

-- Thunes 固定成本: 用过 Thunes wire 的客户
CREATE TEMPORARY VIEW v_th_fixed_accounts AS
SELECT t.account_id
FROM source_crypto_assets_transfers t
-- NOTE: 原 INNER JOIN v_param 已移除（批处理参数）
WHERE t.recipient_type = 'wire'
  AND t.status = 'Closed'
  AND t.delete_time IS NULL
  AND JSON_VALUE(t.extend_field, '$.platform') = 'THUNES'
GROUP BY t.account_id;

CREATE TEMPORARY VIEW v_th_fixed_fee_basis AS
SELECT
    d.report_date,
    a.account_id,
    'CRYPTO_ASSET' AS product_line,
    'TH' AS provider,
    'FIXED_FEE' AS cost_type,
    CAST(1 AS DECIMAL(20, 4)) AS basis_count,
    CAST(0 AS DECIMAL(20, 4)) AS basis_amount,
    d.month_day_count
FROM v_th_fixed_accounts a
CROSS JOIN v_month_days d;

-- Cregis 固定成本: 有 Cregis 地址客户
CREATE TEMPORARY VIEW v_cregis_accounts AS
SELECT ca.account_id
FROM source_crypto_assets_addresses ca
WHERE ca.platform = 'CREGIS'
  AND ca.enable = TRUE
  AND ca.delete_time IS NULL
GROUP BY ca.account_id;

CREATE TEMPORARY VIEW v_cregis_basis AS
SELECT
    d.report_date,
    a.account_id,
    'CRYPTO_ASSET' AS product_line,
    'Cregis' AS provider,
    'FIXED_FEE' AS cost_type,
    CAST(1 AS DECIMAL(20, 4)) AS basis_count,
    CAST(0 AS DECIMAL(20, 4)) AS basis_amount,
    d.month_day_count
FROM v_cregis_accounts a
CROSS JOIN v_month_days d;

-- TZ-wire 手续费: 按代付金额加权
CREATE TEMPORARY VIEW v_tz_wire_fee_basis AS
SELECT
    CAST(t.create_time AS DATE) AS report_date,
    t.account_id,
    'CRYPTO_ASSET' AS product_line,
    'TZ-wire' AS provider,
    'WIRE_FEE' AS cost_type,
    CAST(0 AS DECIMAL(20, 4)) AS basis_count,
    CAST(SUM(COALESCE(t.origin_amount, CAST(0 AS DECIMAL(20, 4))) * COALESCE(t.usd_rate, CAST(0 AS DECIMAL(20, 8)))) AS DECIMAL(20, 4)) AS basis_amount,
    CAST(0 AS INT) AS month_day_count
FROM source_crypto_assets_transfers t
-- NOTE: 原 INNER JOIN v_param 已移除（批处理参数）
WHERE t.recipient_type = 'wire'
  AND t.status = 'Closed'
  AND t.delete_time IS NULL
  AND JSON_VALUE(t.extend_field, '$.platform') = 'TZ'
GROUP BY t.account_id, CAST(t.create_time AS DATE)
HAVING CAST(SUM(COALESCE(t.origin_amount, CAST(0 AS DECIMAL(20, 4))) * COALESCE(t.usd_rate, CAST(0 AS DECIMAL(20, 8)))) AS DECIMAL(20, 4)) <> CAST(0 AS DECIMAL(20, 4));

-- TZ-wire 固定成本: 用过 TZ wire 的客户
CREATE TEMPORARY VIEW v_tz_wire_fixed_accounts AS
SELECT t.account_id
FROM source_crypto_assets_transfers t
-- NOTE: 原 INNER JOIN v_param 已移除（批处理参数）
WHERE t.recipient_type = 'wire'
  AND t.status = 'Closed'
  AND t.delete_time IS NULL
  AND JSON_VALUE(t.extend_field, '$.platform') = 'TZ'
GROUP BY t.account_id;

CREATE TEMPORARY VIEW v_tz_wire_fixed_basis AS
SELECT
    d.report_date,
    a.account_id,
    'CRYPTO_ASSET' AS product_line,
    'TZ-wire' AS provider,
    'FIXED_FEE' AS cost_type,
    CAST(1 AS DECIMAL(20, 4)) AS basis_count,
    CAST(0 AS DECIMAL(20, 4)) AS basis_amount,
    d.month_day_count
FROM v_tz_wire_fixed_accounts a
CROSS JOIN v_month_days d;

-- TZ-sell: USDT/USDC 换汇费，按承兑量加权
CREATE TEMPORARY VIEW v_tz_sell_basis AS
SELECT
    CAST(t.create_time AS DATE) AS report_date,
    t.account_id,
    'CRYPTO_ASSET' AS product_line,
    CASE WHEN t.currency = 'USDT' THEN 'TZ-usdt' ELSE 'TZ-usdc' END AS provider,
    'FX_FEE' AS cost_type,
    CAST(0 AS DECIMAL(20, 4)) AS basis_count,
    CAST(SUM(COALESCE(t.origin_amount, CAST(0 AS DECIMAL(20, 4))) * COALESCE(t.usd_rate, CAST(0 AS DECIMAL(20, 8)))) AS DECIMAL(20, 4)) AS basis_amount,
    CAST(0 AS INT) AS month_day_count
FROM source_crypto_assets_transfers t
-- NOTE: 原 INNER JOIN v_param 已移除（批处理参数）
WHERE t.action = 'sell'
  AND t.status = 'Closed'
  AND t.delete_time IS NULL
  AND t.currency IN ('USDT', 'USDC')
GROUP BY t.account_id, t.currency, CAST(t.create_time AS DATE)
HAVING CAST(SUM(COALESCE(t.origin_amount, CAST(0 AS DECIMAL(20, 4))) * COALESCE(t.usd_rate, CAST(0 AS DECIMAL(20, 8)))) AS DECIMAL(20, 4)) <> CAST(0 AS DECIMAL(20, 4));

-- Safeheron 固定成本: 用过 Safeheron 出账的客户
CREATE TEMPORARY VIEW v_safeheron_fixed_accounts AS
SELECT bt.account_id
FROM source_crypto_blockchain_transfers bt
-- NOTE: 原 INNER JOIN v_param 已移除（批处理参数）
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

-- Bitstamp: 按加密承兑量加权
CREATE TEMPORARY VIEW v_bitstamp_basis AS
SELECT
    CAST(t.create_time AS DATE) AS report_date,
    t.account_id,
    'CRYPTO_ASSET' AS product_line,
    'BS' AS provider,
    'TRADING_FEE' AS cost_type,
    CAST(0 AS DECIMAL(20, 4)) AS basis_count,
    CAST(SUM(COALESCE(t.origin_amount, CAST(0 AS DECIMAL(20, 4))) * COALESCE(t.usd_rate, CAST(0 AS DECIMAL(20, 8)))) AS DECIMAL(20, 4)) AS basis_amount,
    CAST(0 AS INT) AS month_day_count
FROM source_crypto_assets_transfers t
-- NOTE: 原 INNER JOIN v_param 已移除（批处理参数）
WHERE t.action = 'sell'
  AND t.status = 'Closed'
  AND t.delete_time IS NULL
  AND t.currency = 'USDT'
GROUP BY t.account_id, CAST(t.create_time AS DATE)
HAVING CAST(SUM(COALESCE(t.origin_amount, CAST(0 AS DECIMAL(20, 4))) * COALESCE(t.usd_rate, CAST(0 AS DECIMAL(20, 8)))) AS DECIMAL(20, 4)) <> CAST(0 AS DECIMAL(20, 4));

-- Orenda: raw_cost = acquiring_usd_amount * 0.0025，按 raw cost 占比缩放到账单金额
CREATE TEMPORARY VIEW v_orenda_basis AS
SELECT
    ac.create_date AS report_date,
    ac.account_id,
    'ACQUIRING' AS product_line,
    'OD' AS provider,
    'ACQUIRING_FEE' AS cost_type,
    CAST(0 AS DECIMAL(20, 4)) AS basis_count,
    CAST(SUM(COALESCE(ac.acquiring_usd_amount_total, CAST(0 AS DECIMAL(20, 3))) * CAST(0.0025 AS DECIMAL(20, 4))) AS DECIMAL(20, 4)) AS basis_amount,
    CAST(0 AS INT) AS month_day_count
FROM source_dwm_acquiring_clearing ac
-- NOTE: 原 INNER JOIN v_param 已移除（批处理参数）
WHERE ac.amount_type = 'income'
  AND ac.delete_time IS NULL
GROUP BY ac.account_id, ac.create_date
HAVING CAST(SUM(COALESCE(ac.acquiring_usd_amount_total, CAST(0 AS DECIMAL(20, 3))) * CAST(0.0025 AS DECIMAL(20, 4))) AS DECIMAL(20, 4)) <> CAST(0 AS DECIMAL(20, 4));

-- World Pay: 按收单金额加权
CREATE TEMPORARY VIEW v_wp_basis AS
SELECT
    ac.create_date AS report_date,
    ac.account_id,
    'ACQUIRING' AS product_line,
    'WP' AS provider,
    'ACQUIRING_FEE' AS cost_type,
    CAST(0 AS DECIMAL(20, 4)) AS basis_count,
    CAST(SUM(COALESCE(ac.acquiring_usd_amount_total, CAST(0 AS DECIMAL(20, 3)))) AS DECIMAL(20, 4)) AS basis_amount,
    CAST(0 AS INT) AS month_day_count
FROM source_dwm_acquiring_clearing ac
-- NOTE: 原 INNER JOIN v_param 已移除（批处理参数）
WHERE ac.amount_type = 'cost'
  AND ac.delete_time IS NULL
GROUP BY ac.account_id, ac.create_date
HAVING CAST(SUM(COALESCE(ac.acquiring_usd_amount_total, CAST(0 AS DECIMAL(20, 3)))) AS DECIMAL(20, 4)) <> CAST(0 AS DECIMAL(20, 4));

-- ====================================================================
-- 3b. 合并分摊明细 + 月汇总
-- ====================================================================

CREATE TEMPORARY VIEW v_cost_basis_detail AS
SELECT * FROM v_bpc_basis
UNION ALL SELECT * FROM v_sumsub_basis
UNION ALL SELECT * FROM v_idemia_basis
UNION ALL SELECT * FROM v_hz_bank_basis
UNION ALL SELECT * FROM v_bz_basis
UNION ALL SELECT * FROM v_cl_basis
UNION ALL SELECT * FROM v_th_wire_fee_basis
UNION ALL SELECT * FROM v_th_fixed_fee_basis
UNION ALL SELECT * FROM v_cregis_basis
UNION ALL SELECT * FROM v_tz_wire_fee_basis
UNION ALL SELECT * FROM v_tz_wire_fixed_basis
UNION ALL SELECT * FROM v_tz_sell_basis
UNION ALL SELECT * FROM v_safeheron_fixed_basis
UNION ALL SELECT * FROM v_bitstamp_basis
UNION ALL SELECT * FROM v_orenda_basis
UNION ALL SELECT * FROM v_wp_basis;

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
-- 4. bi_month_tag 月度金额（V2: 在 v_cost_basis 之后，自动匹配 cost_type）
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
-- 5. 金额分摊（V2: 不再冗余 join v_param）
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
-- 6. 销售关系
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
    CAST('finance_channel_cost_batch_v2' AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_allocated_cost_base b
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
-- 7. Sink
-- ====================================================================

CREATE TEMPORARY TABLE sink_dwm_finance_channel_cost_p (
    id                   BIGINT,
    report_date          DATE,
    account_id           STRING,
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
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dwm_finance_channel_cost_p
SELECT * FROM v_dwm_finance_channel_cost;
