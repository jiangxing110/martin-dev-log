--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-16
-- Description:    Quantum v2 渠道特殊费用月度重算
-- 作业元信息：
--   作业类型：批处理
--   运行方式：按 start_time/end_time 覆盖月份删除并重算特殊费用行
--   运行参数：start_time, end_time
-- Notes:
--   1. FIXED_FEE_ALLOCATION: BB/QI/SL 渠道固定成本均摊特殊行。
--   2. BB_ACTIVE_CARD_FEE: BB 活跃卡费用特殊行，只落月初，避免按日重复。
--   3. 主渠道 DWS 脚本不再写这些费用，普通行保持 0。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';
SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';

CREATE TEMPORARY TABLE source_bi_month_tag (
    id              BIGINT,
    product_line    STRING,
    provider        STRING,
    tag             STRING,
    statistics_time TIMESTAMP(6),
    amount          DECIMAL(20, 4),
    detail          STRING,
    update_time     TIMESTAMP(6),
    delete_time     TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT id, product_line, provider, tag, statistics_time, amount, detail, update_time, delete_time FROM ods.ods_bi_month_tag WHERE delete_time IS NULL) AS bi_month_tag_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000'
);

CREATE TEMPORARY TABLE source_dws_bb_card_finance_daily_v2_p (
    id               BIGINT,
    report_date      DATE,
    account_id       STRING,
    account_type     STRING,
    account_category STRING,
    system_type      STRING,
    sale_id          STRING,
    am_id            STRING,
    remarks          STRING,
    update_time      TIMESTAMP(6),
    delete_time      TIMESTAMP(6),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_bb_card_finance_daily_v2_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY TABLE source_dws_qi_card_finance_daily_v2_p (
    id               BIGINT,
    report_date      DATE,
    account_id       STRING,
    account_type     STRING,
    account_category STRING,
    system_type      STRING,
    sale_id          STRING,
    am_id            STRING,
    remarks          STRING,
    update_time      TIMESTAMP(6),
    delete_time      TIMESTAMP(6),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_qi_card_finance_daily_v2_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY TABLE source_dws_sl_card_finance_daily_p (
    id               BIGINT,
    report_date      DATE,
    account_id       STRING,
    account_type     STRING,
    account_category STRING,
    system_type      STRING,
    sale_id          STRING,
    am_id            STRING,
    remarks          STRING,
    update_time      TIMESTAMP(6),
    delete_time      TIMESTAMP(6),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_sl_card_finance_daily_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY TABLE source_dwm_bb_card_auth_detail_v2_p (
    id               STRING,
    card_proxy       STRING,
    account_id       STRING,
    account_type     STRING,
    account_category STRING,
    system_type      STRING,
    auth_time        TIMESTAMP(6),
    sale_id          STRING,
    am_id            STRING,
    update_time      TIMESTAMP(6),
    delete_time      TIMESTAMP(6),
    PRIMARY KEY (id, auth_time) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dwm_bb_card_auth_detail_v2_p',
    'targetSchema' = 'dwm',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}'
);

CREATE TEMPORARY VIEW v_month_scope AS
SELECT DISTINCT report_month, CAST(DATE_FORMAT(CAST(DATE_ADD(report_month, 32) AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS next_month
FROM (
    SELECT CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
    FROM source_dws_bb_card_finance_daily_v2_p
    WHERE report_date >= CAST('${start_time}' AS DATE) AND report_date < CAST('${end_time}' AS DATE)
    UNION
    SELECT CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
    FROM source_dws_qi_card_finance_daily_v2_p
    WHERE report_date >= CAST('${start_time}' AS DATE) AND report_date < CAST('${end_time}' AS DATE)
    UNION
    SELECT CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
    FROM source_dws_sl_card_finance_daily_p
    WHERE report_date >= CAST('${start_time}' AS DATE) AND report_date < CAST('${end_time}' AS DATE)
    UNION
    SELECT CAST(DATE_FORMAT(CAST(auth_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month
    FROM source_dwm_bb_card_auth_detail_v2_p
    WHERE auth_time >= CAST('${start_time}' AS TIMESTAMP(6)) AND auth_time < CAST('${end_time}' AS TIMESTAMP(6))
) m
WHERE report_month IS NOT NULL;

CREATE TEMPORARY VIEW v_month_channel_cost AS
SELECT report_month, provider, amount AS month_fixed_fee
FROM (
    SELECT
        m.report_month,
        t.provider,
        t.amount,
        ROW_NUMBER() OVER (
            PARTITION BY m.report_month, t.provider
            ORDER BY
                CASE WHEN t.detail = 'DEFAULT_FALLBACK' THEN 1 ELSE 0 END,
                t.statistics_time DESC,
                t.update_time DESC,
                t.id DESC
        ) AS rn
    FROM v_month_scope m
    LEFT JOIN source_bi_month_tag t
        ON t.tag = 'CHANNEL_COST'
       AND t.delete_time IS NULL
       AND t.provider IN ('BB', 'IQ', 'LS')
       AND (
            t.statistics_time < CAST(m.next_month AS TIMESTAMP(6))
         OR t.detail = 'DEFAULT_FALLBACK'
       )
) ranked
WHERE rn = 1;

CREATE TEMPORARY VIEW v_bb_allocation_base AS
SELECT *
FROM source_dws_bb_card_finance_daily_v2_p
WHERE delete_time IS NULL
  AND (remarks IS NULL OR remarks NOT IN ('FIXED_FEE_ALLOCATION', 'BB_ACTIVE_CARD_FEE'))
  AND EXISTS (
      SELECT 1 FROM v_month_scope m
      WHERE report_date >= m.report_month AND report_date < m.next_month
  );

CREATE TEMPORARY VIEW v_qi_allocation_base AS
SELECT *
FROM source_dws_qi_card_finance_daily_v2_p
WHERE delete_time IS NULL
  AND (remarks IS NULL OR remarks <> 'FIXED_FEE_ALLOCATION')
  AND EXISTS (
      SELECT 1 FROM v_month_scope m
      WHERE report_date >= m.report_month AND report_date < m.next_month
  );

CREATE TEMPORARY VIEW v_sl_allocation_base AS
SELECT *
FROM source_dws_sl_card_finance_daily_p
WHERE delete_time IS NULL
  AND (remarks IS NULL OR remarks <> 'FIXED_FEE_ALLOCATION')
  AND EXISTS (
      SELECT 1 FROM v_month_scope m
      WHERE report_date >= m.report_month AND report_date < m.next_month
  );

CREATE TEMPORARY VIEW v_bb_month_row_count AS
SELECT CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month, COUNT(*) AS row_count
FROM v_bb_allocation_base
GROUP BY CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE);

CREATE TEMPORARY VIEW v_qi_month_row_count AS
SELECT CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month, COUNT(*) AS row_count
FROM v_qi_allocation_base
GROUP BY CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE);

CREATE TEMPORARY VIEW v_sl_month_row_count AS
SELECT CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_month, COUNT(*) AS row_count
FROM v_sl_allocation_base
GROUP BY CAST(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE);

CREATE TEMPORARY VIEW v_bb_fixed_fee_rows AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT('FIXED_FEE_ALLOCATION:', DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', b.account_id, ':', COALESCE(b.sale_id, ''), ':', COALESCE(b.am_id, '')))) AS BIGINT) AS id,
    b.report_date,
    b.account_id,
    b.account_type,
    b.account_category,
    b.system_type,
    b.sale_id,
    b.am_id,
    CAST(COALESCE(c.month_fixed_fee / NULLIF(rc.row_count, 0), 0) AS DECIMAL(20, 4)) AS cost_fixed_fee
FROM v_bb_allocation_base b
LEFT JOIN v_bb_month_row_count rc ON CAST(DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = rc.report_month
LEFT JOIN v_month_channel_cost c ON c.report_month = rc.report_month AND c.provider = 'BB';

CREATE TEMPORARY VIEW v_qi_fixed_fee_rows AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT('FIXED_FEE_ALLOCATION:', DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', b.account_id, ':', COALESCE(b.sale_id, ''), ':', COALESCE(b.am_id, '')))) AS BIGINT) AS id,
    b.report_date,
    b.account_id,
    b.account_type,
    b.account_category,
    b.system_type,
    b.sale_id,
    b.am_id,
    CAST(COALESCE(c.month_fixed_fee / NULLIF(rc.row_count, 0), 0) AS DECIMAL(20, 4)) AS cost_fixed_fee
FROM v_qi_allocation_base b
LEFT JOIN v_qi_month_row_count rc ON CAST(DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = rc.report_month
LEFT JOIN v_month_channel_cost c ON c.report_month = rc.report_month AND c.provider = 'IQ';

CREATE TEMPORARY VIEW v_sl_fixed_fee_rows AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT('FIXED_FEE_ALLOCATION:', DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', b.account_id, ':', COALESCE(b.sale_id, ''), ':', COALESCE(b.am_id, '')))) AS BIGINT) AS id,
    b.report_date,
    b.account_id,
    b.account_type,
    b.account_category,
    b.system_type,
    b.sale_id,
    b.am_id,
    CAST(COALESCE(c.month_fixed_fee / NULLIF(rc.row_count, 0), 0) AS DECIMAL(20, 4)) AS cost_fixed_fee
FROM v_sl_allocation_base b
LEFT JOIN v_sl_month_row_count rc ON CAST(DATE_FORMAT(CAST(b.report_date AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) = rc.report_month
LEFT JOIN v_month_channel_cost c ON c.report_month = rc.report_month AND c.provider = 'LS';

CREATE TEMPORARY VIEW v_bb_active_card_fee_rows AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT('BB_ACTIVE_CARD_FEE:', DATE_FORMAT(CAST(CAST(DATE_FORMAT(CAST(auth_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS TIMESTAMP(6)), 'yyyyMMdd'), ':', account_id, ':', COALESCE(sale_id, ''), ':', COALESCE(am_id, '')))) AS BIGINT) AS id,
    CAST(DATE_FORMAT(CAST(auth_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE) AS report_date,
    account_id,
    account_type,
    account_category,
    system_type,
    sale_id,
    am_id,
    CAST(COUNT(DISTINCT card_proxy) AS INT) AS active_card_count,
    CAST(COUNT(DISTINCT card_proxy) * 0.1 AS DECIMAL(20, 4)) AS active_card_account_fee
FROM source_dwm_bb_card_auth_detail_v2_p s
WHERE s.delete_time IS NULL
  AND EXISTS (
      SELECT 1 FROM v_month_scope m
      WHERE s.auth_time >= CAST(m.report_month AS TIMESTAMP(6)) AND s.auth_time < CAST(m.next_month AS TIMESTAMP(6))
  )
GROUP BY CAST(DATE_FORMAT(CAST(auth_time AS TIMESTAMP(6)), 'yyyy-MM-01') AS DATE), account_id, account_type, account_category, system_type, sale_id, am_id;

CREATE TEMPORARY TABLE sink_dws_bb_card_finance_daily_v2_p (
    id                         BIGINT,
    report_date                DATE,
    account_id                 STRING,
    account_type               STRING,
    account_category           STRING,
    system_type                STRING,
    active_card_count          INT,
    active_card_account_fee    DECIMAL(20, 4),
    cost_fixed_fee             DECIMAL(20, 4),
    sale_id                    STRING,
    am_id                      STRING,
    version                    INT,
    remarks                    STRING,
    create_time                TIMESTAMP(6),
    update_time                TIMESTAMP(6),
    delete_time                TIMESTAMP(6),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_bb_card_finance_daily_v2_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

CREATE TEMPORARY TABLE sink_dws_qi_card_finance_daily_v2_p (
    id                            BIGINT,
    report_date                   DATE,
    account_id                    STRING,
    account_type                  STRING,
    account_category              STRING,
    system_type                   STRING,
    version                       INT,
    remarks                       STRING,
    create_time                   TIMESTAMP(6),
    update_time                   TIMESTAMP(6),
    delete_time                   TIMESTAMP(6),
    sale_id                       STRING,
    am_id                         STRING,
    cost_fixed_fee                DECIMAL(20, 4),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_qi_card_finance_daily_v2_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

CREATE TEMPORARY TABLE sink_dws_sl_card_finance_daily_p (
    id               BIGINT,
    report_date      DATE,
    account_id       STRING,
    account_type     STRING,
    account_category STRING,
    system_type      STRING,
    version          INT,
    remarks          STRING,
    create_time      TIMESTAMP(6),
    update_time      TIMESTAMP(6),
    delete_time      TIMESTAMP(6),
    sale_id          STRING,
    am_id            STRING,
    cost_fixed_fee   DECIMAL(20, 4),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_sl_card_finance_daily_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

DELETE FROM sink_dws_bb_card_finance_daily_v2_p
WHERE remarks IN ('FIXED_FEE_ALLOCATION', 'BB_ACTIVE_CARD_FEE')
  AND EXISTS (SELECT 1 FROM v_month_scope m WHERE report_date >= m.report_month AND report_date < m.next_month);

DELETE FROM sink_dws_qi_card_finance_daily_v2_p
WHERE remarks = 'FIXED_FEE_ALLOCATION'
  AND EXISTS (SELECT 1 FROM v_month_scope m WHERE report_date >= m.report_month AND report_date < m.next_month);

DELETE FROM sink_dws_sl_card_finance_daily_p
WHERE remarks = 'FIXED_FEE_ALLOCATION'
  AND EXISTS (SELECT 1 FROM v_month_scope m WHERE report_date >= m.report_month AND report_date < m.next_month);

INSERT INTO sink_dws_bb_card_finance_daily_v2_p
SELECT id, report_date, account_id, account_type, account_category, system_type,
       CAST(0 AS INT), CAST(0 AS DECIMAL(20, 4)), cost_fixed_fee,
       sale_id, am_id, 1, 'FIXED_FEE_ALLOCATION',
       CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)), CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)), CAST(NULL AS TIMESTAMP(6))
FROM v_bb_fixed_fee_rows;

INSERT INTO sink_dws_bb_card_finance_daily_v2_p
SELECT id, report_date, account_id, account_type, account_category, system_type,
       active_card_count, active_card_account_fee, CAST(0 AS DECIMAL(20, 4)),
       sale_id, am_id, 1, 'BB_ACTIVE_CARD_FEE',
       CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)), CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)), CAST(NULL AS TIMESTAMP(6))
FROM v_bb_active_card_fee_rows;

INSERT INTO sink_dws_qi_card_finance_daily_v2_p
SELECT id, report_date, account_id, account_type, account_category, system_type,
       1, 'FIXED_FEE_ALLOCATION', CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)), CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)), CAST(NULL AS TIMESTAMP(6)),
       sale_id, am_id, cost_fixed_fee
FROM v_qi_fixed_fee_rows;

INSERT INTO sink_dws_sl_card_finance_daily_p
SELECT id, report_date, account_id, account_type, account_category, system_type,
       1, 'FIXED_FEE_ALLOCATION', CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)), CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)), CAST(NULL AS TIMESTAMP(6)),
       sale_id, am_id, cost_fixed_fee
FROM v_sl_fixed_fee_rows;
