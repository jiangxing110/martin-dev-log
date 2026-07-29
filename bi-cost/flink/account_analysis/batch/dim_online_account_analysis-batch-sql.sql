--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-28
-- Description:    客户分析维表 dim_account_analysis 批量初始化/回刷
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性初始化/回刷或调度执行
--   运行参数：无（全量初始化）
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑或由 CDC 增量脚本刷新。
-- Notes:
--   1. 客户主数据来源 dim.dim_account，只保留最上层客户数据。
--   2. 激活时间按 ods.ods_api_account_relation 归并到 root account 后计算。
--   3. 仓库中未提供部分 ODS DDL，字段按业务字段命名书写，执行前需核对真实字段。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'sink.parallelism' = '1';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';
SET 'table.dml-sync' = 'true';
SET 'execution.checkpointing.interval' = '5min';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'execution.checkpointing.timeout' = '30min';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

CREATE TEMPORARY TABLE source_dim_account (
    id               STRING,
    verified_name    STRING,
    account_category STRING,
    status           STRING,
    system_type      STRING,
    create_time      TIMESTAMP(6),
    update_time      TIMESTAMP(6),
    delete_time      TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id::text AS id, verified_name, "type" AS account_category, status, system_type, CURRENT_TIMESTAMP AS create_time, CURRENT_TIMESTAMP AS update_time, CAST(NULL AS TIMESTAMP(6)) AS delete_time FROM dim.dim_account WHERE "type" IN (''ApiClient'', ''MasterAccount'', ''Merchant'', ''TestAccount'')) AS dim_account_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_api_account_relation (
    account_id  STRING,
    root_id     STRING,
    delete_time TIMESTAMP(6),
    PRIMARY KEY (account_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT account_id::text AS account_id, root_id::text AS root_id, delete_time FROM ods.ods_api_account_relation WHERE delete_time IS NULL) AS api_account_relation_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_caas_open_api_extend (
    account_id     STRING,
    business_mode  STRING,
    access_type    STRING,
    mor_type       STRING,
    mor_type_extra STRING,
    delete_time    TIMESTAMP(6),
    PRIMARY KEY (account_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT account_id::text AS account_id, business_mode, access_type, mor_type, mor_type_extra::text AS mor_type_extra, delete_time FROM public.caas_open_api_extend WHERE delete_time IS NULL) AS caas_open_api_extend_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_cdd_risk_rating (
    account_id         STRING,
    account_risk_level STRING,
    update_time         TIMESTAMP(6),
    delete_time         TIMESTAMP(6),
    PRIMARY KEY (account_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT "accountId"::text AS account_id, "accountRiskLevel" AS account_risk_level, "updateTime" AS update_time, "deleteTime" AS delete_time FROM public."cddRiskRating" WHERE "deleteTime" IS NULL) AS cdd_risk_rating_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_account_referral (
    account_id       STRING,
    referral_code_id STRING,
    delete_time      TIMESTAMP(6),
    PRIMARY KEY (account_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id::text AS account_id, "referralCodeId"::text AS referral_code_id, "deleteTime" AS delete_time FROM public.account WHERE "deleteTime" IS NULL) AS account_referral_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_referral_code (
    id          STRING,
    user_id     STRING,
    delete_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id::text AS id, "userId"::text AS user_id, "deleteTime" AS delete_time FROM public."referralCode" WHERE "deleteTime" IS NULL) AS referral_code_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_qbit_card_wallet_transaction (
    id               STRING,
    account_id       STRING,
    business_type    STRING,
    status           STRING,
    origin_amount    DECIMAL(20, 4),
    transaction_time TIMESTAMP(6),
    delete_time      TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id::text AS id, "accountId"::text AS account_id, "businessType" AS business_type, status, CAST("originAmount" AS numeric(20,4)) AS origin_amount, "transactionTime" AS transaction_time, "deleteTime" AS delete_time FROM public."qbitCardWalletTransaction" WHERE "deleteTime" IS NULL) AS qbit_card_wallet_transaction_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_transfer (
    id               STRING,
    account_id       STRING,
    transaction_time TIMESTAMP(6),
    delete_time      TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id::text AS id, "accountId"::text AS account_id, "transactionTime" AS transaction_time, "deleteTime" AS delete_time FROM public.transfer WHERE "deleteTime" IS NULL) AS transfer_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_crypto_assets_transfers (
    id            STRING,
    account_id    STRING,
    action        STRING,
    status        STRING,
    hidden        BOOLEAN,
    origin_amount DECIMAL(20, 4),
    usd_rate      DECIMAL(20, 8),
    create_time   TIMESTAMP(6),
    delete_time   TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id::text AS id, account_id::text AS account_id, action, status, hidden, origin_amount, usd_rate, create_time, delete_time FROM public.crypto_assets_transfers WHERE delete_time IS NULL) AS crypto_assets_transfers_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_open_api_client_config (
    id          STRING,
    account_id  STRING,
    online_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id::text AS id, "clientId"::text AS account_id, online_time, "deleteTime" AS delete_time FROM public."openApiClientConfig" WHERE "deleteTime" IS NULL) AS open_api_client_config_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_fund_orders (
    id          STRING,
    account_id  STRING,
    `type`      STRING,
    status      STRING,
    create_time TIMESTAMP(6),
    delete_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id::text AS id, account_id::text AS account_id, "type" AS type, status, create_time, delete_time FROM public.fund_orders WHERE delete_time IS NULL) AS fund_orders_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '5000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY VIEW v_account_root AS
SELECT
    da.id AS account_id,
    COALESCE(aar.root_id, da.id) AS root_account_id
FROM source_dim_account da
LEFT JOIN source_api_account_relation aar
    ON aar.account_id = da.id
   AND aar.delete_time IS NULL;

CREATE TEMPORARY VIEW v_card_recharge_ranked AS
SELECT
    root_account_id,
    transaction_time,
    SUM(origin_amount) OVER (
        PARTITION BY root_account_id
        ORDER BY transaction_time, id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_amount
FROM (
    SELECT
        COALESCE(aar.root_id, t.account_id) AS root_account_id,
        t.id,
        t.transaction_time,
        COALESCE(t.origin_amount, CAST(0 AS DECIMAL(20, 4))) AS origin_amount
    FROM source_qbit_card_wallet_transaction t
    LEFT JOIN source_api_account_relation aar
        ON aar.account_id = t.account_id
       AND aar.delete_time IS NULL
    WHERE t.business_type IN (
        'TransferInFromIPeakoin',
        'QbitCryptoToQbitCardWallet',
        'TransferInFromQbitGlobal',
        'Deposit',
        'TransferInFromFinancing',
        'TransferInFromCryptoAssets',
        'AccountDepositCNY'
    )
      AND t.status = 'Closed'
      AND t.delete_time IS NULL
) recharge_base;

CREATE TEMPORARY VIEW v_card_active AS
SELECT
    root_account_id,
    MIN(transaction_time) AS card_active_time
FROM v_card_recharge_ranked
WHERE cumulative_amount > CAST(5000 AS DECIMAL(20, 4))
GROUP BY root_account_id;

CREATE TEMPORARY VIEW v_global_active AS
SELECT
    COALESCE(aar.root_id, t.account_id) AS root_account_id,
    MIN(t.transaction_time) AS global_active_time
FROM source_transfer t
LEFT JOIN source_api_account_relation aar
    ON aar.account_id = t.account_id
   AND aar.delete_time IS NULL
WHERE t.delete_time IS NULL
GROUP BY COALESCE(aar.root_id, t.account_id);

CREATE TEMPORARY VIEW v_crypto_sell_ranked AS
SELECT
    root_account_id,
    create_time,
    SUM(usd_amount) OVER (
        PARTITION BY root_account_id
        ORDER BY create_time, id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_usd_amount
FROM (
    SELECT
        COALESCE(aar.root_id, t.account_id) AS root_account_id,
        t.id,
        t.create_time,
        CAST(COALESCE(t.origin_amount, CAST(0 AS DECIMAL(20, 4))) * COALESCE(t.usd_rate, CAST(0 AS DECIMAL(20, 8))) AS DECIMAL(20, 4)) AS usd_amount
    FROM source_crypto_assets_transfers t
    LEFT JOIN source_api_account_relation aar
        ON aar.account_id = t.account_id
       AND aar.delete_time IS NULL
    WHERE t.action = 'sell'
      AND t.status = 'Closed'
      AND COALESCE(t.hidden, FALSE) = FALSE
      AND t.delete_time IS NULL
) crypto_base;

CREATE TEMPORARY VIEW v_crypto_active AS
SELECT
    root_account_id,
    MIN(create_time) AS crypto_active_time
FROM v_crypto_sell_ranked
WHERE cumulative_usd_amount > CAST(200000 AS DECIMAL(20, 4))
GROUP BY root_account_id;

CREATE TEMPORARY VIEW v_api_active AS
SELECT
    COALESCE(aar.root_id, c.account_id) AS root_account_id,
    MIN(c.online_time) AS api_active_time
FROM source_open_api_client_config c
LEFT JOIN source_api_account_relation aar
    ON aar.account_id = c.account_id
   AND aar.delete_time IS NULL
WHERE c.online_time IS NOT NULL
  AND c.delete_time IS NULL
GROUP BY COALESCE(aar.root_id, c.account_id);

CREATE TEMPORARY VIEW v_treasury_active AS
SELECT
    COALESCE(aar.root_id, f.account_id) AS root_account_id,
    MIN(f.create_time) AS treasury_active_time
FROM source_fund_orders f
LEFT JOIN source_api_account_relation aar
    ON aar.account_id = f.account_id
   AND aar.delete_time IS NULL
WHERE f.`type` = 'purchase'
  AND f.status = 'complete'
  AND f.delete_time IS NULL
GROUP BY COALESCE(aar.root_id, f.account_id);

CREATE TEMPORARY VIEW v_dim_account_analysis AS
SELECT
    da.id AS account_id,
    da.verified_name,
    da.account_category,
    da.status,
    da.system_type,
    cae.business_mode,
    cae.access_type,
    cae.mor_type,
    cae.mor_type_extra,
    crr.account_risk_level,
    rc.user_id AS referral_user_id,
    ca.card_active_time,
    ga.global_active_time,
    cra.crypto_active_time,
    aa.api_active_time,
    ta.treasury_active_time,
    COALESCE(da.create_time, CURRENT_TIMESTAMP) AS create_time,
    CURRENT_TIMESTAMP AS update_time,
    da.delete_time
FROM source_dim_account da
LEFT JOIN source_caas_open_api_extend cae
    ON cae.account_id = da.id
LEFT JOIN source_cdd_risk_rating crr
    ON crr.account_id = da.id
LEFT JOIN source_account_referral ar
    ON ar.account_id = da.id
   AND ar.delete_time IS NULL
LEFT JOIN source_referral_code rc
    ON rc.id = ar.referral_code_id
   AND rc.delete_time IS NULL
LEFT JOIN v_card_active ca
    ON ca.root_account_id = da.id
LEFT JOIN v_global_active ga
    ON ga.root_account_id = da.id
LEFT JOIN v_crypto_active cra
    ON cra.root_account_id = da.id
LEFT JOIN v_api_active aa
    ON aa.root_account_id = da.id
LEFT JOIN v_treasury_active ta
    ON ta.root_account_id = da.id;

CREATE TEMPORARY TABLE sink_dim_account_analysis (
    account_id           STRING,
    verified_name        STRING,
    account_category     STRING,
    status               STRING,
    system_type          STRING,
    business_mode        STRING,
    access_type          STRING,
    mor_type             STRING,
    mor_type_extra       STRING,
    account_risk_level   STRING,
    referral_user_id     STRING,
    card_active_time     TIMESTAMP(6),
    global_active_time   TIMESTAMP(6),
    crypto_active_time   TIMESTAMP(6),
    api_active_time      TIMESTAMP(6),
    treasury_active_time TIMESTAMP(6),
    create_time          TIMESTAMP(6),
    update_time          TIMESTAMP(6),
    delete_time          TIMESTAMP(6),
    PRIMARY KEY (account_id) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dim_account_analysis',
    'targetSchema' = 'dim',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dim_account_analysis
SELECT * FROM v_dim_account_analysis;
