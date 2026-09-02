--********************************************************************
-- Author:         martinJiang
-- Created Time:   2026-09-01
-- Updated Time:   2026-09-02 10:47:50
-- Description:    dws_sale_transfer_extend 流处理(CDC) 作业（quantum-v2 范式：确定性哈希主键 + 先清后写）
-- 作业元信息：
--   作业类型：流处理(CDC)
--   运行方式：每日增量（BATCH 定时触发）：自动按昨天变更窗口(CDC 模式)精准删受影响 key 后 upsert 覆盖。
--   运行参数：（无；CDC 模式自动按昨天变更窗口）
-- Notes:
--   1. 聚合逻辑留在 PostgreSQL（JDBC source 子查询），Flink 仅算 id + upsert，类型转换最少。
--   2. 删除函数按唯一业务键 / 作用域精准删受影响 key，先清后写保证幂等。
--   3. 按 create_date 年份动态路由分表（_YYYY），跨年安全。
--   4. 上线前需对照线上 Flink catalog 校准列类型（UUID / JSON / boolean 等）。
--********************************************************************
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
SET 'execution.application-management.enabled' = 'true';
SET 'execution.multi-jobs-in-application.enable' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

-- ==============================================
-- 0. 先调用删除函数：按唯一业务键精准清空受影响分表行（先清后写，保证幂等）
-- ==============================================
CREATE TEMPORARY TABLE source_delete_dws_sale_transfer_extend_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_dws_sale_transfer_extend_cdc(false) AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

-- ==============================================
-- 1. 源聚合（留在 PostgreSQL 内执行，复用原版聚合逻辑；只回传受影响 key 的聚合结果）
-- ==============================================
CREATE TEMPORARY TABLE source_dws_sale_transfer_extend (
    account_id STRING,
    sale_or_am_id STRING,
    status STRING,
    dbs_receive DECIMAL(18,2),
    cl_receive DECIMAL(18,2),
    ep_receive DECIMAL(18,2),
    rd_receive DECIMAL(18,2),
    settle_fx_fee DECIMAL(18,2),
    conversion_fx_amount DECIMAL(18,2),
    conversion_fx_fee DECIMAL(18,2),
    inbound_profit DECIMAL(18,2),
    conversion_fx_profit DECIMAL(18,2),
    create_date TIMESTAMP(6),
    version INT,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(WITH affected AS (
        SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account FROM "transfer" AS tr LEFT JOIN "globalConversion" AS ta ON ta."recordId"::UUID = tr.id WHERE (tr."deleteTime" IS NULL AND ta."deleteTime" IS NULL) AND ((tr."createTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."createTime" < CURRENT_DATE) OR (tr."updateTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."updateTime" < CURRENT_DATE) OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."deleteTime" < CURRENT_DATE))
    )
    SELECT CAST("accountId" AS text) AS "account_id", CAST("sale_or_am_id" AS text) AS "sale_or_am_id", CAST("status" AS text) AS "status", CAST(COALESCE(SUM("dbsReceive"),0) AS numeric(18,2)) AS "dbs_receive", CAST(COALESCE(SUM("clReceive"),0) AS numeric(18,2)) AS "cl_receive", CAST(COALESCE(SUM("epReceive"),0) AS numeric(18,2)) AS "ep_receive", CAST(COALESCE(SUM("rdReceive"),0) AS numeric(18,2)) AS "rd_receive", CAST(COALESCE(SUM("settleFxFee"),0) AS numeric(18,2)) AS "settle_fx_fee", CAST(COALESCE(SUM("conversionFxAmount"),0) AS numeric(18,2)) AS "conversion_fx_amount", CAST(COALESCE(SUM("conversionFxFee"),0) AS numeric(18,2)) AS "conversion_fx_fee", CAST(COALESCE(SUM(CASE WHEN "businessTypeDetail" in (''OtherChannelInbound'', ''CCInbound'') and (fee - "clReceive"*0.0005 - "epReceive"*0.0005 - "rdReceive"*0.0005) > 0 THEN
               (fee - "clReceive"*0.0005 - "epReceive"*0.0005 - "rdReceive"*0.0005)  ELSE 0 END),0) AS numeric(18,2)) AS "inbound_profit", CAST(COALESCE(SUM (CASE WHEN ("conversionFxFee"-"conversionFxAmount"*0.001)>0 THEN ("conversionFxFee"-"conversionFxAmount"*0.001) ELSE 0 END ),0) AS numeric(18,2)) AS "conversion_fx_profit", create_date AS "create_date", CAST(1 AS integer) AS "version", -- 初始版本号
NOW() AS "create_time", NOW() AS "update_time"
    FROM (
SELECT
tr."accountId",
ids."sale_or_am_id",
tr."status",
tr."businessTypeDetail",
tr."settlementCurrency",
tr."fee"*"usdRate" AS "fee",
ta."fromAmount",
"usdAmount",
ta."rateDiffIncomeFromUsdAmount",
(CASE WHEN tr."businessTypeDetail" in (''OtherChannelInbound'') and UPPER((tr."rawData"::jsonb->> 0)::jsonb->>''source'') IN (''OTT'',''寻汇'',''BEEPAY'') THEN "usdAmount" ELSE 0 END ) AS "dbsReceive",
(CASE WHEN tr."businessTypeDetail" in (''OtherChannelInbound'', ''CCInbound'') and tr."provider" = ''Column'' THEN "usdAmount" ELSE 0 END) AS "clReceive",
(CASE WHEN tr."businessTypeDetail" in (''OtherChannelInbound'', ''CCInbound'') and tr."provider"  = ''EP'' THEN "usdAmount" ELSE 0 END) AS "epReceive",
(CASE WHEN tr."businessTypeDetail" in (''OtherChannelInbound'', ''CCInbound'') and tr."provider"  = ''RD'' THEN "usdAmount" ELSE 0 END) AS "rdReceive",
(CASE WHEN ta."toCurrency" = ''CNY'' and tr."status" = ''Closed'' and ta.status=''Closed'' THEN ta."rateDiffIncomeFromUsdAmount" ELSE 0 END ) AS "settleFxFee" ,
(CASE WHEN tr."settlementCurrency" != ''CNY'' and tr."status" = ''Closed'' and ta.status=''Closed''and tr."businessTypeDetail" in (''Payment'',''ConversionOut'',''InnerTransferOut'') THEN tr."usdAmount" ELSE 0 END ) AS "conversionFxAmount" ,
(CASE WHEN ta."toCurrency" != ''CNY'' and tr."status" = ''Closed'' and ta.status=''Closed'' THEN ta."rateDiffIncomeFromUsdAmount" ELSE 0 END ) AS "conversionFxFee",
CAST(DATE(tr."createTime") AS TIMESTAMP) AS create_date
FROM "transfer" as tr
LEFT JOIN "globalConversion" as ta on ta."recordId"::UUID = tr.id
LEFT JOIN LATERAL (
  SELECT sale_id, am_id
  FROM (
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 1 AS priority, sr.relation_start_time
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.delete_time IS NULL AND sr.relation_account_id::text = tr."accountId"::text
      AND tr."createTime" >= sr.relation_start_time AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
    UNION ALL
    SELECT sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, 2 AS priority, sr.relation_start_time
    FROM public.api_account_relation aar
    JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text
    WHERE aar.delete_time IS NULL AND aar.account_id::text = tr."accountId"::text
      AND sr.delete_time IS NULL AND tr."createTime" >= sr.relation_start_time
      AND (tr."createTime" < sr.relation_end_time OR sr.relation_end_time IS NULL)
  ) candidates
  ORDER BY priority, relation_start_time DESC
  LIMIT 1
) AS rel ON TRUE
CROSS JOIN LATERAL (
  SELECT DISTINCT sale_or_am_id
  FROM (VALUES (rel.sale_id), (rel.am_id)) AS v(sale_or_am_id)
  WHERE sale_or_am_id IS NOT NULL
) AS ids
WHERE
tr."deleteTime" IS NULL and ta."deleteTime" IS NULL
AND ((tr."createTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."createTime" < CURRENT_DATE)
  OR (tr."updateTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."updateTime" < CURRENT_DATE)
  OR (tr."deleteTime" >= CURRENT_DATE - INTERVAL ''1 day'' AND tr."deleteTime" < CURRENT_DATE))
) as tt
    JOIN affected a ON (DATE(tt.create_date)) = a.scope_date AND (tt."accountId") = a.scope_account
    WHERE TRUE
    GROUP BY "accountId", create_date, status, "sale_or_am_id") AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

-- ==============================================
-- 2. 聚合结果视图：计算确定性主键 id = HASH(业务键)
--    （source_dws_sale_transfer_extend 已输出聚合列，此处只补 id；列名与 DWS 表一致）
-- ==============================================
-- source2：独立销售/AM关系源，由 Flink Join 按 account_id + create_time 匹配
CREATE TEMPORARY TABLE source2_sale_relation (
    relation_account_id STRING,
    sale_id STRING,
    am_id STRING,
    relation_start_time TIMESTAMP(6),
    relation_end_time TIMESTAMP(6),
    priority INT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT sr.relation_account_id::text AS relation_account_id, sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, sr.relation_start_time, sr.relation_end_time, 1 AS priority FROM dim.dim_sale_account_relation_p sr WHERE sr.delete_time IS NULL UNION ALL SELECT aar.account_id::text AS relation_account_id, sr.sale_id::text AS sale_id, sr.am_id::text AS am_id, sr.relation_start_time, sr.relation_end_time, 2 AS priority FROM public.api_account_relation aar JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text = aar.root_id::text WHERE aar.delete_time IS NULL AND sr.delete_time IS NULL) AS rel',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);
CREATE TEMPORARY VIEW v_dws_sale_transfer_extend_source AS
SELECT DISTINCT d.*
FROM source_dws_sale_transfer_extend d
JOIN source2_sale_relation r
  ON d.account_id = r.relation_account_id
 AND (d.sale_or_am_id = r.sale_id OR d.sale_or_am_id = r.am_id)
 AND CAST(d.create_date AS TIMESTAMP) >= r.relation_start_time
 AND (CAST(d.create_date AS TIMESTAMP) < r.relation_end_time OR r.relation_end_time IS NULL);

CREATE TEMPORARY VIEW v_dws_sale_transfer_extend_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(account_id, ''), ': ', DATE_FORMAT(create_date, 'yyyy-MM-dd'), ': ', COALESCE(status, ''), ': ', COALESCE(sale_or_am_id, '')))) AS BIGINT) AS id,
    *
FROM v_dws_sale_transfer_extend_source;

-- ==============================================
-- 3. 分表 SINK（每个 _YYYY 一个，upsert 按 key 幂等）
-- ==============================================
CREATE TEMPORARY TABLE sink_dws_sale_transfer_extend_2024 (
    id BIGINT, account_id STRING, sale_or_am_id STRING, status STRING, dbs_receive DECIMAL(18,2), cl_receive DECIMAL(18,2), ep_receive DECIMAL(18,2), rd_receive DECIMAL(18,2), settle_fx_fee DECIMAL(18,2), conversion_fx_amount DECIMAL(18,2), conversion_fx_fee DECIMAL(18,2), inbound_profit DECIMAL(18,2), conversion_fx_profit DECIMAL(18,2), create_date TIMESTAMP(6), version INT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='dws_sale_transfer_extend_2024','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_sale_transfer_extend_2025 (
    id BIGINT, account_id STRING, sale_or_am_id STRING, status STRING, dbs_receive DECIMAL(18,2), cl_receive DECIMAL(18,2), ep_receive DECIMAL(18,2), rd_receive DECIMAL(18,2), settle_fx_fee DECIMAL(18,2), conversion_fx_amount DECIMAL(18,2), conversion_fx_fee DECIMAL(18,2), inbound_profit DECIMAL(18,2), conversion_fx_profit DECIMAL(18,2), create_date TIMESTAMP(6), version INT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='dws_sale_transfer_extend_2025','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_sale_transfer_extend_2026 (
    id BIGINT, account_id STRING, sale_or_am_id STRING, status STRING, dbs_receive DECIMAL(18,2), cl_receive DECIMAL(18,2), ep_receive DECIMAL(18,2), rd_receive DECIMAL(18,2), settle_fx_fee DECIMAL(18,2), conversion_fx_amount DECIMAL(18,2), conversion_fx_fee DECIMAL(18,2), inbound_profit DECIMAL(18,2), conversion_fx_profit DECIMAL(18,2), create_date TIMESTAMP(6), version INT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='dws_sale_transfer_extend_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

-- ==============================================
-- 4. 写入（CROSS JOIN 确保删除函数先执行；upsert 覆盖同 key / 新增异 key）
-- ==============================================
INSERT INTO sink_dws_sale_transfer_extend_2024
SELECT id, account_id, sale_or_am_id, status, dbs_receive, cl_receive, ep_receive, rd_receive, settle_fx_fee, conversion_fx_amount, conversion_fx_fee, inbound_profit, conversion_fx_profit, create_date, version, create_time, update_time
FROM v_dws_sale_transfer_extend_base
CROSS JOIN source_delete_dws_sale_transfer_extend_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2024-01-01' AND create_date < DATE '2025-01-01';
INSERT INTO sink_dws_sale_transfer_extend_2025
SELECT id, account_id, sale_or_am_id, status, dbs_receive, cl_receive, ep_receive, rd_receive, settle_fx_fee, conversion_fx_amount, conversion_fx_fee, inbound_profit, conversion_fx_profit, create_date, version, create_time, update_time
FROM v_dws_sale_transfer_extend_base
CROSS JOIN source_delete_dws_sale_transfer_extend_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2025-01-01' AND create_date < DATE '2026-01-01';
INSERT INTO sink_dws_sale_transfer_extend_2026
SELECT id, account_id, sale_or_am_id, status, dbs_receive, cl_receive, ep_receive, rd_receive, settle_fx_fee, conversion_fx_amount, conversion_fx_fee, inbound_profit, conversion_fx_profit, create_date, version, create_time, update_time
FROM v_dws_sale_transfer_extend_base
CROSS JOIN source_delete_dws_sale_transfer_extend_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2026-01-01' AND create_date < DATE '2027-01-01';
