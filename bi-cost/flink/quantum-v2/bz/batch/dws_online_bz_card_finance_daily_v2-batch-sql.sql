--********************************************************************--
-- Author:         weifanyi
-- Created Time:   2026-07-29 16:26:17
-- Description:    Write your description here
-- Hints:          You can use SET statements to modify the configuration
--********************************************************************--
-- Description:    BZ v2 DWS 批量初始化/回刷
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性初始化/按业务时间回刷
--   运行参数：start_time, end_time
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑或由 CDC 脚本同步。
-- Notes:
--   1. 主链路: DWM settlement + DWM transaction + i2c_iso_message + i2c_iso_token_message + qbitCard -> DWS
--   2. DWS 粒度: account_id + report_date(月初) + sale_id + am_id
--   3. DWM 已含 sale_id / am_id，非 DWM 源在 Flink 侧匹配销售关系
--   4. 固定成本由独立脚本回刷，主链路 cost_fixed_fee = 0
--   5. Rate 列使用硬编码默认值
--********************************************************************--


SET 'parallelism.default' = '1';
SET 'taskmanager.memory.network.min' = '1536mb';
SET 'taskmanager.memory.network.max' = '1536mb';
SET 'taskmanager.memory.network.fraction' = '0.45';
SET 'taskmanager.network.sort-shuffle.min-buffers' = '64';
SET 'pipeline.default-parallelism' = '1';
SET 'table.exec.resource.default-parallelism' = '1';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'execution.batch-shuffle-mode' = 'ALL_EXCHANGES_BLOCKING';
SET 'execution.multi-jobs-in-application.enable' = 'false';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';
SET 'execution.application-management.enabled' = 'true';
SET 'heartbeat.interval' = '30 s';
SET 'heartbeat.timeout' = '600 s';
SET 'table.optimizer.union-any-expand' = 'false';

-- DWM 结算明细源（已含 sale_id / am_id）
CREATE TEMPORARY TABLE source_dwm_bz_settlement (
    id               STRING,
    account_id       STRING,
    account_type     STRING,
    account_category STRING,
    system_type      STRING,
    transaction_time TIMESTAMP(6),
    billing_amount   DECIMAL(20, 4),
    is_clearing      BOOLEAN,
    is_refund        BOOLEAN,
    is_us            BOOLEAN,
    sale_id          STRING,
    am_id            STRING,
    delete_time      TIMESTAMP(6),
    PRIMARY KEY (id, transaction_time) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT t.id, t.account_id, t.account_type, t.account_category, t.system_type, t.transaction_time, t.billing_amount, t.is_clearing, t.is_refund, t.is_us, t.sale_id, t.am_id, t.delete_time FROM dwm.dwm_bz_card_settlement_detail_v2_p t WHERE t.delete_time IS NULL AND t.transaction_time >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND t.transaction_time < CAST(''${end_time}'' AS TIMESTAMP(6))) AS dwm_bz_set_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

-- DWM 交易明细源（已含 sale_id / am_id）
CREATE TEMPORARY TABLE source_dwm_bz_transaction (
    id               STRING,
    account_id       STRING,
    account_type     STRING,
    account_category STRING,
    system_type      STRING,
    transaction_time TIMESTAMP(6),
    business_type    STRING,
    billing_amount   DECIMAL(20, 4),
    is_consumption   BOOLEAN,
    is_reversal      BOOLEAN,
    has_special_code BOOLEAN,
    sale_id          STRING,
    am_id            STRING,
    delete_time      TIMESTAMP(6),
    PRIMARY KEY (id, transaction_time) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT t.id, t.account_id, t.account_type, t.account_category, t.system_type, t.transaction_time, t.business_type, t.billing_amount, t.is_consumption, t.is_reversal, t.has_special_code, t.sale_id, t.am_id, t.delete_time FROM dwm.dwm_bz_card_transaction_detail_v2_p t WHERE t.delete_time IS NULL AND t.transaction_time >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND t.transaction_time < CAST(''${end_time}'' AS TIMESTAMP(6))) AS dwm_bz_txn_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

-- i2c_iso_message 源（通过 qbitCard.token = primary_account_number 获取 accountId）
CREATE TEMPORARY TABLE source_bz_iso_message (
    msg_id            STRING,
    account_id        STRING,
    account_type      STRING,
    account_category  STRING,
    system_type       STRING,
    created_at        TIMESTAMP(6),
    transaction_amount STRING,
    mti               STRING,
    PRIMARY KEY (msg_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT m."id"::text AS msg_id, c."accountId"::text AS account_id, da.account_type, da."type" AS account_category, da.system_type, m."create_time" AS created_at, m."transaction_amount" AS transaction_amount, m."mti" AS mti FROM "i2c_iso_message" m INNER JOIN "qbitCard" c ON m."primary_account_number" = c."token" LEFT JOIN dim.dim_account da ON da.id = c."accountId"::text WHERE c.provider LIKE ''I2c%'' AND m."delete_time" IS NULL AND m."create_time" >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND m."create_time" < CAST(''${end_time}'' AS TIMESTAMP(6))) AS bz_iso_msg_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

-- i2c_iso_token_message 源（通过 qbitCard.token = primary_account_number 获取 accountId）
CREATE TEMPORARY TABLE source_bz_iso_token_message (
    msg_id            STRING,
    account_id        STRING,
    account_type      STRING,
    account_category  STRING,
    system_type       STRING,
    created_at        TIMESTAMP(6),
    mti               STRING,
    PRIMARY KEY (msg_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT m."id"::text AS msg_id, c."accountId"::text AS account_id, da.account_type, da."type" AS account_category, da.system_type, m."create_time" AS created_at, m."mti" AS mti FROM "i2c_iso_token_message" m INNER JOIN "qbitCard" c ON m."primary_account_number" = c."token" LEFT JOIN dim.dim_account da ON da.id = c."accountId"::text WHERE c.provider LIKE ''I2c%'' AND m."delete_time" IS NULL AND m."create_time" >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND m."create_time" < CAST(''${end_time}'' AS TIMESTAMP(6))) AS bz_iso_token_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

-- 卡指标按日汇总（JDBC CTE 下推：card_create + card_active 合一 + 销售关系匹配）
-- card_create_count: 当月新建卡数，按实际 createTime 日期统计
-- card_active_count: 当月活跃卡数；历史月份创建的卡统一记在月初1号，当月新建的卡按实际 createTime 日期统计
CREATE TEMPORARY TABLE source_bz_card_daily (
    account_id        STRING,
    account_type      STRING,
    account_category  STRING,
    system_type       STRING,
    report_date       DATE,
    card_create_count INT,
    card_active_count INT,
    sale_id           STRING,
    am_id             STRING,
    PRIMARY KEY (account_id, report_date, sale_id, am_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(WITH months AS (SELECT date_trunc(''month'', gs) AS month_start, date_trunc(''month'', gs) + INTERVAL ''1 month'' AS month_end FROM generate_series(date_trunc(''month'', CAST(''${start_time}'' AS TIMESTAMP)), date_trunc(''month'', CAST(''${end_time}'' AS TIMESTAMP) - INTERVAL ''1 second''), INTERVAL ''1 month'') AS gs), card_events AS (SELECT m.month_start, c."createTime"::date AS report_date, c."accountId"::text AS account_id, 1 AS card_create, 0 AS card_active FROM "qbitCard" c CROSS JOIN months m WHERE c.provider LIKE ''I2c%'' AND c."deleteTime" IS NULL AND c."createTime" >= m.month_start AND c."createTime" < m.month_end UNION ALL SELECT m.month_start, CASE WHEN c."createTime" >= m.month_start THEN c."createTime"::date ELSE m.month_start::date END AS report_date, c."accountId"::text AS account_id, 0 AS card_create, 1 AS card_active FROM "qbitCard" c CROSS JOIN months m WHERE c.provider LIKE ''I2c%'' AND c."deleteTime" IS NULL AND c."createTime" < m.month_end AND (c."deleteCardTime" IS NULL OR c."deleteCardTime" >= m.month_start)), card_daily AS (SELECT month_start, report_date, account_id, SUM(card_create)::int AS card_create_count, SUM(card_active)::int AS card_active_count FROM card_events GROUP BY month_start, report_date, account_id), direct_rel AS (SELECT DISTINCT ON (cd.account_id, cd.month_start) cd.account_id, cd.month_start, sr.sale_id, sr.am_id FROM card_daily cd INNER JOIN dim.dim_sale_account_relation_p sr ON sr.delete_time IS NULL AND sr.relation_account_id::text = cd.account_id AND cd.month_start >= sr.relation_start_time AND (cd.month_start < sr.relation_end_time OR sr.relation_end_time IS NULL) ORDER BY cd.account_id, cd.month_start, sr.relation_start_time DESC), root_rel AS (SELECT DISTINCT ON (cd.account_id, cd.month_start) cd.account_id, cd.month_start, sr.sale_id, sr.am_id FROM card_daily cd INNER JOIN public.api_account_relation aar ON aar.account_id::text = cd.account_id AND aar.delete_time IS NULL INNER JOIN dim.dim_sale_account_relation_p sr ON sr.delete_time IS NULL AND sr.relation_account_id::text = aar.root_id::text AND cd.month_start >= sr.relation_start_time AND (cd.month_start < sr.relation_end_time OR sr.relation_end_time IS NULL) ORDER BY cd.account_id, cd.month_start, sr.relation_start_time DESC) SELECT cd.account_id, da.account_type, da."type" AS account_category, da.system_type, cd.report_date, cd.card_create_count, cd.card_active_count, COALESCE(dr.sale_id, rr.sale_id)::text AS sale_id, COALESCE(dr.am_id, rr.am_id)::text AS am_id FROM card_daily cd LEFT JOIN direct_rel dr ON dr.account_id = cd.account_id AND dr.month_start = cd.month_start LEFT JOIN root_rel rr ON rr.account_id = cd.account_id AND rr.month_start = cd.month_start LEFT JOIN dim.dim_account da ON da.id = cd.account_id) AS bz_card_daily_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

-- 非 DWM 事件销售关系（JDBC CTE 下推：direct 优先、root 兜底）
-- 统一处理 iso_message + iso_token_message 两种事件的销售关系匹配（qbitCard 已由 source_bz_card_daily 独立处理）
CREATE TEMPORARY TABLE source_bz_non_dwm_sale_relation (
    event_id   STRING,
    sale_id    STRING,
    am_id      STRING,
    PRIMARY KEY (event_id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(WITH base AS (SELECT m."id"::text AS event_id, c."accountId"::text AS account_id, m."create_time" AS business_time FROM "i2c_iso_message" m INNER JOIN "qbitCard" c ON m."primary_account_number" = c."token" WHERE c.provider LIKE ''I2c%'' AND m."delete_time" IS NULL AND m."create_time" >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND m."create_time" < CAST(''${end_time}'' AS TIMESTAMP(6)) UNION ALL SELECT m."id"::text AS event_id, c."accountId"::text AS account_id, m."create_time" AS business_time FROM "i2c_iso_token_message" m INNER JOIN "qbitCard" c ON m."primary_account_number" = c."token" WHERE c.provider LIKE ''I2c%'' AND m."delete_time" IS NULL AND m."create_time" >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND m."create_time" < CAST(''${end_time}'' AS TIMESTAMP(6))), direct_rel AS (SELECT DISTINCT ON (base.event_id) base.event_id, sr.sale_id, sr.am_id FROM base INNER JOIN dim.dim_sale_account_relation_p sr ON sr.delete_time IS NULL AND sr.relation_account_id::text = base.account_id AND base.business_time >= sr.relation_start_time AND (base.business_time < sr.relation_end_time OR sr.relation_end_time IS NULL) ORDER BY base.event_id, sr.relation_start_time DESC), root_rel AS (SELECT DISTINCT ON (base.event_id) base.event_id, sr.sale_id, sr.am_id FROM base INNER JOIN public.api_account_relation aar ON aar.account_id::text = base.account_id AND aar.delete_time IS NULL INNER JOIN dim.dim_sale_account_relation_p sr ON sr.delete_time IS NULL AND sr.relation_account_id::text = aar.root_id::text AND base.business_time >= sr.relation_start_time AND (base.business_time < sr.relation_end_time OR sr.relation_end_time IS NULL) ORDER BY base.event_id, sr.relation_start_time DESC) SELECT base.event_id, COALESCE(direct_rel.sale_id, root_rel.sale_id)::text AS sale_id, COALESCE(direct_rel.am_id, root_rel.am_id)::text AS am_id FROM base LEFT JOIN direct_rel ON direct_rel.event_id = base.event_id LEFT JOIN root_rel ON root_rel.event_id = base.event_id) AS bz_non_dwm_sale_rel_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

-- 结算指标按日汇总（clearing / refund / net_consumption / visa_charges）
CREATE TEMPORARY VIEW v_bz_settlement_month AS
SELECT
    CAST(DATE_FORMAT(CAST(transaction_time AS TIMESTAMP(6)), 'yyyy-MM-dd') AS DATE) AS report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    sale_id,
    am_id,
    CAST(SUM(CASE WHEN is_clearing THEN 1 ELSE 0 END) AS INT) AS clearing_count,
    CAST(SUM(CASE WHEN is_refund THEN 1 ELSE 0 END) AS INT) AS refund_count,
    CAST(SUM(CASE WHEN is_clearing THEN billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS clearing_base_amt,
    CAST(SUM(CASE WHEN is_refund THEN billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS refund_base_amt,
    CAST(SUM(CASE WHEN is_clearing THEN billing_amount ELSE -billing_amount END) AS DECIMAL(20, 4)) AS net_consumption,
    CAST(SUM(CASE WHEN is_us THEN 0 ELSE billing_amount END) AS DECIMAL(20, 4)) AS visa_charges_base_amt
FROM source_dwm_bz_settlement
WHERE delete_time IS NULL
GROUP BY CAST(DATE_FORMAT(CAST(transaction_time AS TIMESTAMP(6)), 'yyyy-MM-dd') AS DATE),
    account_id, account_type, account_category, system_type, sale_id, am_id;

-- 交易指标按日汇总（auth / reversal / settlement_volume）
CREATE TEMPORARY VIEW v_bz_transaction_month AS
SELECT
    CAST(DATE_FORMAT(CAST(transaction_time AS TIMESTAMP(6)), 'yyyy-MM-dd') AS DATE) AS report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    sale_id,
    am_id,
    CAST(SUM(CASE WHEN is_consumption AND  has_special_code THEN 1 ELSE 0 END) AS INT) AS auth_count,
    CAST(SUM(CASE WHEN is_reversal AND billing_amount <> 0 THEN 1 ELSE 0 END) AS INT) AS reversal_count,
    CAST(SUM(CASE WHEN is_consumption THEN billing_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS settlement_volume
FROM source_dwm_bz_transaction
WHERE delete_time IS NULL
GROUP BY CAST(DATE_FORMAT(CAST(transaction_time AS TIMESTAMP(6)), 'yyyy-MM-dd') AS DATE),
    account_id, account_type, account_category, system_type, sale_id, am_id;

-- DWM 按日合并（UNION ALL + GROUP BY 求和，避免 FULL OUTER JOIN 产生重复 id 被 upsert 覆盖）
CREATE TEMPORARY VIEW v_bz_dwm_month AS
SELECT
    report_date,
    account_id,
    MAX(account_type) AS account_type,
    MAX(account_category) AS account_category,
    MAX(system_type) AS system_type,
    sale_id,
    am_id,
    CAST(SUM(clearing_count) AS INT) AS clearing_count,
    CAST(SUM(refund_count) AS INT) AS refund_count,
    CAST(SUM(clearing_base_amt) AS DECIMAL(20, 4)) AS clearing_base_amt,
    CAST(SUM(refund_base_amt) AS DECIMAL(20, 4)) AS refund_base_amt,
    CAST(SUM(net_consumption) AS DECIMAL(20, 4)) AS net_consumption,
    CAST(SUM(visa_charges_base_amt) AS DECIMAL(20, 4)) AS visa_charges_base_amt,
    CAST(SUM(auth_count) AS INT) AS auth_count,
    CAST(SUM(reversal_count) AS INT) AS reversal_count,
    CAST(SUM(settlement_volume) AS DECIMAL(20, 4)) AS settlement_volume
FROM (
    SELECT report_date, account_id, account_type, account_category, system_type, sale_id, am_id,
           clearing_count, refund_count, clearing_base_amt, refund_base_amt, net_consumption, visa_charges_base_amt,
           0 AS auth_count, 0 AS reversal_count, CAST(0 AS DECIMAL(20, 4)) AS settlement_volume
    FROM v_bz_settlement_month
    UNION ALL
    SELECT report_date, account_id, account_type, account_category, system_type, sale_id, am_id,
           0 AS clearing_count, 0 AS refund_count, CAST(0 AS DECIMAL(20, 4)) AS clearing_base_amt,
           CAST(0 AS DECIMAL(20, 4)) AS refund_base_amt, CAST(0 AS DECIMAL(20, 4)) AS net_consumption,
           CAST(0 AS DECIMAL(20, 4)) AS visa_charges_base_amt,
           auth_count, reversal_count, settlement_volume
    FROM v_bz_transaction_month
) combined
GROUP BY report_date, account_id, sale_id, am_id;

-- 非 DWM 事件统一视图（iso_message / token_message），LEFT JOIN JDBC 下推的销售关系
-- 卡指标（card_create / card_active）由 source_bz_card_daily 独立提供，不走事件流
CREATE TEMPORARY VIEW v_bz_all_events AS
SELECT
    e.event_id,
    e.account_id,
    e.account_type,
    e.account_category,
    e.system_type,
    e.business_time,
    e.verify_count,
    e.signature_count,
    e.card_create_count,
    e.card_active_count,
    sr.sale_id,
    sr.am_id
FROM (
    SELECT
        msg_id AS event_id,
        account_id,
        account_type,
        account_category,
        system_type,
        created_at AS business_time,
        CASE WHEN transaction_amount = '000000000000' AND mti <> '0620' THEN 1 ELSE 0 END AS verify_count,
        CASE WHEN mti <> '0620' THEN 1 ELSE 0 END AS signature_count,
        CAST(0 AS INT) AS card_create_count,
        CAST(0 AS INT) AS card_active_count
    FROM source_bz_iso_message
    UNION ALL
    SELECT
        msg_id AS event_id,
        account_id,
        account_type,
        account_category,
        system_type,
        created_at AS business_time,
        CAST(0 AS INT) AS verify_count,
        CASE WHEN mti <> '0620' THEN 1 ELSE 0 END AS signature_count,
        CAST(0 AS INT) AS card_create_count,
        CAST(0 AS INT) AS card_active_count
    FROM source_bz_iso_token_message
) e
LEFT JOIN source_bz_non_dwm_sale_relation sr
    ON sr.event_id = e.event_id;

-- 非 DWM 指标按日汇总
CREATE TEMPORARY VIEW v_bz_non_dwm_month AS
SELECT
    CAST(DATE_FORMAT(CAST(business_time AS TIMESTAMP(6)), 'yyyy-MM-dd') AS DATE) AS report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    sale_id,
    am_id,
    CAST(SUM(verify_count) AS INT) AS verify_count,
    CAST(SUM(signature_count) AS INT) AS signature_count,
    CAST(SUM(card_create_count) AS INT) AS card_create_count,
    CAST(SUM(card_active_count) AS INT) AS card_active_count
FROM v_bz_all_events
GROUP BY CAST(DATE_FORMAT(CAST(business_time AS TIMESTAMP(6)), 'yyyy-MM-dd') AS DATE),
    account_id, account_type, account_category, system_type, sale_id, am_id;

-- 非 DWM 按日合并（UNION ALL + GROUP BY 求和，避免 FULL OUTER JOIN 产生重复 id 被 upsert 覆盖）
CREATE TEMPORARY VIEW v_bz_non_dwm_month_full AS
SELECT
    report_date,
    account_id,
    MAX(account_type) AS account_type,
    MAX(account_category) AS account_category,
    MAX(system_type) AS system_type,
    sale_id,
    am_id,
    CAST(SUM(verify_count) AS INT) AS verify_count,
    CAST(SUM(signature_count) AS INT) AS signature_count,
    CAST(SUM(card_create_count) AS INT) AS card_create_count,
    CAST(SUM(card_active_count) AS INT) AS card_active_count
FROM (
    SELECT report_date, account_id, account_type, account_category, system_type, sale_id, am_id,
           verify_count, signature_count, 0 AS card_create_count, 0 AS card_active_count
    FROM v_bz_non_dwm_month
    UNION ALL
    SELECT report_date, account_id, account_type, account_category, system_type, sale_id, am_id,
           0 AS verify_count, 0 AS signature_count, card_create_count, card_active_count
    FROM source_bz_card_daily
) combined
GROUP BY report_date, account_id, sale_id, am_id;

-- DWM + 非 DWM UNION ALL + GROUP BY 求和（避免 FULL OUTER JOIN 产生重复 id 被 upsert 覆盖）
CREATE TEMPORARY VIEW v_dws_bz_daily_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', account_id, ':', COALESCE(sale_id, ''), ':', COALESCE(am_id, '')))) AS BIGINT) AS id,
    report_date,
    account_id,
    MAX(account_type) AS account_type,
    MAX(account_category) AS account_category,
    MAX(system_type) AS system_type,
    sale_id,
    am_id,
    CAST(SUM(clearing_count) AS INT) AS clearing_count,
    CAST(SUM(refund_count) AS INT) AS refund_count,
    CAST(SUM(clearing_base_amt) AS DECIMAL(20, 4)) AS clearing_base_amt,
    CAST(SUM(refund_base_amt) AS DECIMAL(20, 4)) AS refund_base_amt,
    CAST(SUM(net_consumption) AS DECIMAL(20, 4)) AS net_consumption,
    CAST(SUM(visa_charges_base_amt) AS DECIMAL(20, 4)) AS visa_charges_base_amt,
    CAST(SUM(auth_count) AS INT) AS auth_count,
    CAST(SUM(reversal_count) AS INT) AS reversal_count,
    CAST(SUM(settlement_volume) AS DECIMAL(20, 4)) AS settlement_volume,
    CAST(SUM(verify_count) AS INT) AS verify_count,
    CAST(SUM(card_create_count) AS INT) AS card_create_count,
    CAST(SUM(card_active_count) AS INT) AS card_active_count,
    CAST(SUM(signature_count) AS INT) AS signature_count,
    CAST(0.016 AS DECIMAL(20, 8)) AS reimbursement_rate,
    CAST(0.01 AS DECIMAL(20, 8)) AS visa_charges_rate,
    CAST(0.1 AS DECIMAL(20, 8)) AS clearing_fee_rate,
    CAST(0.2 AS DECIMAL(20, 8)) AS refund_fee_rate,
    CAST(0.1 AS DECIMAL(20, 8)) AS auth_fee_rate,
    CAST(0.1 AS DECIMAL(20, 8)) AS reversal_fee_rate,
    CAST(0.0001 AS DECIMAL(20, 8)) AS service_fee_rate,
    CAST(0.09 AS DECIMAL(20, 8)) AS verify_fee_rate,
    CAST(0.12 AS DECIMAL(20, 8)) AS card_setup_rate,
    CAST(0.055 AS DECIMAL(20, 8)) AS account_activation_rate,
    CAST(0.095 AS DECIMAL(20, 8)) AS account_on_file_rate,
    CAST(SUM(net_consumption) AS DECIMAL(20, 4)) AS total_net_amount,
    CAST(0 AS DECIMAL(20, 4)) AS cost_fixed_fee,
    CAST(NULL AS STRING) AS special_fee_type,
    1 AS version,
    'bz_v2_batch' AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM (
    SELECT report_date, account_id, account_type, account_category, system_type, sale_id, am_id,
           clearing_count, refund_count, clearing_base_amt, refund_base_amt, net_consumption, visa_charges_base_amt,
           auth_count, reversal_count, settlement_volume,
           0 AS verify_count, 0 AS card_create_count, 0 AS card_active_count, 0 AS signature_count
    FROM v_bz_dwm_month
    UNION ALL
    SELECT report_date, account_id, account_type, account_category, system_type, sale_id, am_id,
           0 AS clearing_count, 0 AS refund_count, CAST(0 AS DECIMAL(20, 4)) AS clearing_base_amt,
           CAST(0 AS DECIMAL(20, 4)) AS refund_base_amt, CAST(0 AS DECIMAL(20, 4)) AS net_consumption,
           CAST(0 AS DECIMAL(20, 4)) AS visa_charges_base_amt,
           0 AS auth_count, 0 AS reversal_count, CAST(0 AS DECIMAL(20, 4)) AS settlement_volume,
           verify_count, card_create_count, card_active_count, signature_count
    FROM v_bz_non_dwm_month_full
) combined
GROUP BY report_date, account_id, sale_id, am_id;

CREATE TEMPORARY TABLE sink_dws_bz_card_finance_daily_v2_p (
    id                    BIGINT,
    report_date           DATE,
    account_id            STRING,
    account_type          STRING,
    account_category      STRING,
    system_type           STRING,
    version               INT,
    remarks               STRING,
    create_time           TIMESTAMP(6),
    update_time           TIMESTAMP(6),
    delete_time           TIMESTAMP(6),
    sale_id               STRING,
    am_id                 STRING,
    clearing_count        INT,
    refund_count          INT,
    clearing_base_amt     DECIMAL(20, 4),
    refund_base_amt       DECIMAL(20, 4),
    net_consumption       DECIMAL(20, 4),
    visa_charges_base_amt DECIMAL(20, 4),
    auth_count            INT,
    reversal_count        INT,
    settlement_volume     DECIMAL(20, 4),
    verify_count          INT,
    card_create_count     INT,
    card_active_count     INT,
    signature_count       INT,
    reimbursement_rate    DECIMAL(20, 8),
    visa_charges_rate     DECIMAL(20, 8),
    clearing_fee_rate     DECIMAL(20, 8),
    refund_fee_rate       DECIMAL(20, 8),
    auth_fee_rate         DECIMAL(20, 8),
    reversal_fee_rate     DECIMAL(20,8),
    service_fee_rate      DECIMAL(20, 8),
    verify_fee_rate       DECIMAL(20,8),
    card_setup_rate       DECIMAL(20, 8),
    account_activation_rate DECIMAL(20, 8),
    account_on_file_rate  DECIMAL(20, 8),
    total_net_amount      DECIMAL(20, 4),
    cost_fixed_fee        DECIMAL(20,4),
    special_fee_type      STRING,
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_bz_card_finance_daily_v2_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dws_bz_card_finance_daily_v2_p
SELECT
    id,
    report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    version,
    remarks,
    create_time,
    update_time,
    delete_time,
    sale_id,
    am_id,
    clearing_count,
    refund_count,
    clearing_base_amt,
    refund_base_amt,
    net_consumption,
    visa_charges_base_amt,
    auth_count,
    reversal_count,
    settlement_volume,
    verify_count,
    card_create_count,
    card_active_count,
    signature_count,
    reimbursement_rate,
    visa_charges_rate,
    clearing_fee_rate,
    refund_fee_rate,
    auth_fee_rate,
    reversal_fee_rate,
    service_fee_rate,
    verify_fee_rate,
    card_setup_rate,
    account_activation_rate,
    account_on_file_rate,
    total_net_amount,
    cost_fixed_fee,
    special_fee_type
FROM v_dws_bz_daily_base;