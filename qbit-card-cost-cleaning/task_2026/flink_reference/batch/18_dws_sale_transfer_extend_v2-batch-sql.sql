--********************************************************************
-- Author:         martinJiang
-- Created Time:   2026-08-18
-- Updated Time:   2026-08-18
-- Description:    dws_sale_transfer_extend 批处理 作业（quantum-v2 范式：确定性哈希主键 + 先清后写）
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性修复/补数：VVR 作业参数 start_date/end_date 指定回刷区间（含两端，YYYY-MM-DD）；删除函数走修复模式按 create_date 跨分表清理，再由重算 upsert 覆盖（幂等）。
--   运行参数：start_date, end_date（YYYY-MM-DD，含两端）
-- Notes:
--   1. 一次性修复/补数作业：通过 VVR 作业参数 start_date/end_date 指定回刷区间（YYYY-MM-DD，含两端）。
--   2. 删除函数走“修复模式”，按 create_date 区间跨分表整段清理。
--   3. 源聚合仅重算该区间内受影响 key 的当前有效行，upsert 覆盖（幂等）。
--   4. 删除与重算必须严格共用同一 start_date/end_date，否则出现区间缺口或越界残留。
--   5. 上线前需对照线上 Flink catalog 校准列类型（UUID / JSON / boolean 等）。
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
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

CREATE TEMPORARY TABLE source_delete_dws_sale_transfer_extend_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_dws_sale_transfer_extend_cdc(false, CAST(''${start_date}'' AS DATE), CAST(''${end_date}'' AS DATE)) AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

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
        SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account FROM "transfer" as tr 
LEFT JOIN "globalConversion" as ta on ta."recordId"::UUID = tr.id
LEFT JOIN "ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
WHERE
tr."deleteTime" IS NULL and ta."deleteTime" IS NULL
AND tr."createTime" >= CURRENT_DATE - INTERVAL ''1 day'' 
AND tr."createTime" < CURRENT_DATE
) as tt WHERE (DATE(tr."createTime") >= CAST(''${start_date}'' AS DATE) AND DATE(tr."createTime") <= CAST(''${end_date}'' AS DATE))
    )
    SELECT "accountId" AS "account_id", "sale_or_am_id" AS "sale_or_am_id", "status" AS "status", COALESCE(SUM("dbsReceive"),0) AS "dbsReceive" AS "dbs_receive", COALESCE(SUM("clReceive"),0) AS "clReceive" AS "cl_receive", COALESCE(SUM("epReceive"),0) AS "epReceive" AS "ep_receive", COALESCE(SUM("rdReceive"),0) AS "rdReceive" AS "rd_receive", COALESCE(SUM("settleFxFee"),0) AS "settleFxFee" AS "settle_fx_fee", COALESCE(SUM("conversionFxAmount"),0) AS "conversionFxAmount" AS "conversion_fx_amount", COALESCE(SUM("conversionFxFee"),0) AS "conversionFxFee" AS "conversion_fx_fee", COALESCE(SUM(CASE WHEN "businessTypeDetail" in (''OtherChannelInbound'', ''CCInbound'') and (fee - "clReceive"*0.0005 - "epReceive"*0.0005 - "rdReceive"*0.0005) > 0 THEN 
               (fee - "clReceive"*0.0005 - "epReceive"*0.0005 - "rdReceive"*0.0005)  ELSE 0 END),0) AS "inboundProfit" AS "inbound_profit", COALESCE(SUM (CASE WHEN ("conversionFxFee"-"conversionFxAmount"*0.001)>0 THEN ("conversionFxFee"-"conversionFxAmount"*0.001) ELSE 0 END ),0) AS "conversionFxProfit" AS "conversion_fx_profit", create_date AS "create_date", 1 AS version, -- 初始版本号
NOW() AS create_time, NOW() AS update_time
from (  
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
TO_CHAR(tr."createTime", ''YYYY-MM-DD'')::DATE AS create_date AS "update_time"
    FROM "transfer" as tr 
LEFT JOIN "globalConversion" as ta on ta."recordId"::UUID = tr.id
LEFT JOIN "ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
WHERE
tr."deleteTime" IS NULL and ta."deleteTime" IS NULL
AND tr."createTime" >= CURRENT_DATE - INTERVAL ''1 day'' 
AND tr."createTime" < CURRENT_DATE
) as tt
    JOIN affected a ON (DATE(tr."createTime")) = a.scope_date AND (tr."accountId") = a.scope_account
    WHERE TRUE
    GROUP BY "accountId",create_date, status,"sale_or_am_id") AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

CREATE TEMPORARY VIEW v_dws_sale_transfer_extend_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(account_id, ''), ': ', DATE_FORMAT(create_date, 'yyyy-MM-dd'), ': ', COALESCE(status, ''), ': ', COALESCE(sale_or_am_id, '')))) AS BIGINT) AS id,
    *
FROM source_dws_sale_transfer_extend;

CREATE TEMPORARY TABLE sink_dws_sale_transfer_extend_2024 (
    id BIGINT, account_id STRING, sale_or_am_id STRING, status STRING, dbs_receive DECIMAL(18,2), cl_receive DECIMAL(18,2), ep_receive DECIMAL(18,2), rd_receive DECIMAL(18,2), settle_fx_fee DECIMAL(18,2), conversion_fx_amount DECIMAL(18,2), conversion_fx_fee DECIMAL(18,2), inbound_profit DECIMAL(18,2), conversion_fx_profit DECIMAL(18,2), create_date TIMESTAMP(6), version INT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_sale_transfer_extend_2024','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_sale_transfer_extend_2025 (
    id BIGINT, account_id STRING, sale_or_am_id STRING, status STRING, dbs_receive DECIMAL(18,2), cl_receive DECIMAL(18,2), ep_receive DECIMAL(18,2), rd_receive DECIMAL(18,2), settle_fx_fee DECIMAL(18,2), conversion_fx_amount DECIMAL(18,2), conversion_fx_fee DECIMAL(18,2), inbound_profit DECIMAL(18,2), conversion_fx_profit DECIMAL(18,2), create_date TIMESTAMP(6), version INT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_sale_transfer_extend_2025','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');
CREATE TEMPORARY TABLE sink_dws_sale_transfer_extend_2026 (
    id BIGINT, account_id STRING, sale_or_am_id STRING, status STRING, dbs_receive DECIMAL(18,2), cl_receive DECIMAL(18,2), ep_receive DECIMAL(18,2), rd_receive DECIMAL(18,2), settle_fx_fee DECIMAL(18,2), conversion_fx_amount DECIMAL(18,2), conversion_fx_fee DECIMAL(18,2), inbound_profit DECIMAL(18,2), conversion_fx_profit DECIMAL(18,2), create_date TIMESTAMP(6), version INT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='public.dws_sale_transfer_extend_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

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
