--********************************************************************
-- Author:         martinJiang
-- Created Time:   2026-09-01
-- Updated Time:   2026-09-01
-- Description:    dws_sale_physical_card 批处理 作业（quantum-v2 范式：确定性哈希主键 + 先清后写）
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
SET 'execution.application-management.enabled' = 'true';
SET 'execution.multi-jobs-in-application.enable' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

CREATE TEMPORARY TABLE source_delete_dws_sale_physical_card_result (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT public.fn_delete_dws_sale_physical_card_cdc(false, CAST(''${start_date}'' AS DATE), CAST(''${end_date}'' AS DATE)) AS affected_rows) AS delete_result',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

CREATE TEMPORARY TABLE source_dws_sale_physical_card (
    account_id STRING,
    sale_or_am_id STRING,
    provider STRING,
    bin STRING,
    status STRING,
    transaction_count INT,
    physical_card_fee DECIMAL(18,2),
    create_date TIMESTAMP(6),
    version INT,
    create_time TIMESTAMP(6),
    update_time TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(WITH affected AS (
        SELECT DISTINCT DATE(tr."createTime") AS scope_date, tr."accountId" AS scope_account FROM "qbitCardWalletTransaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
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
) AS ids WHERE (DATE(tr."createTime") >= CAST(''${start_date}'' AS DATE) AND DATE(tr."createTime") <= CAST(''${end_date}'' AS DATE))
    )
    SELECT CAST(tr."accountId" AS text) AS "account_id", CAST(ids."sale_or_am_id" AS text) AS "sale_or_am_id", CAST(qc."provider" AS text) AS "provider", CAST(qc."firstSix" AS text) AS "bin", CAST(tr."status" AS text) AS "status", CAST(COUNT(*) AS integer) AS "transaction_count", CAST(SUM("originAmount"::numeric) AS numeric(18,2)) AS "physical_card_fee", tr."createTime"::DATE::TIMESTAMP AS "create_date", CAST(1 AS integer) AS "version", NOW() AS "create_time", NOW() AS "update_time"
    FROM "qbitCardWalletTransaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
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
    JOIN affected a ON (DATE(tr."createTime")) = a.scope_date AND (tr."accountId") = a.scope_account
    WHERE tr."deleteTime" IS NULL
  AND tr."businessType" = ''TransferOut'' AND tr."remarks" IN (''邮寄费'', ''制卡费'', ''批量邮寄运费'')
    GROUP BY tr."accountId", ids."sale_or_am_id", qc."provider", qc."firstSix", tr."status", tr."createTime"::DATE::TIMESTAMP) AS src',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '2000'
);

CREATE TEMPORARY VIEW v_dws_sale_physical_card_base AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(COALESCE(account_id, ''), ': ', COALESCE(sale_or_am_id, ''), ': ', COALESCE(provider, ''), ': ', COALESCE(bin, ''), ': ', COALESCE(status, ''), ': ', DATE_FORMAT(create_date, 'yyyy-MM-dd')))) AS BIGINT) AS id,
    *
FROM source_dws_sale_physical_card;

-- 多 Source：实体卡交易 source1，销售/AM关系 source2，匹配和聚合在 Flink 算子层完成
CREATE TEMPORARY TABLE source1_transaction (transaction_id STRING,account_id STRING,provider STRING,bin STRING,status STRING,origin_amount DECIMAL(18,2),create_time TIMESTAMP(6),delete_time TIMESTAMP(6)) WITH ('connector'='jdbc','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified','table-name'='(SELECT CAST(tr.id AS text) transaction_id,CAST(tr."accountId" AS text) account_id,CAST(qc."provider" AS text) provider,CAST(qc."firstSix" AS text) bin,CAST(tr."status" AS text) status,CAST(tr."originAmount" AS numeric(18,2)) origin_amount,tr."createTime" create_time,tr."deleteTime" delete_time FROM "qbitCardWalletTransaction" tr LEFT JOIN "qbitCard" qc ON tr."cardId"=qc."id" WHERE tr."deleteTime" IS NULL AND tr."businessType"=''TransferOut'' AND tr."remarks" IN (''邮寄费'',''制卡费'',''批量邮寄运费'') AND tr."createTime">=CAST(''${start_date}'' AS DATE) AND tr."createTime"<CAST(''${end_date}'' AS DATE)+INTERVAL ''1 day'') tx','username'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','driver'='org.postgresql.Driver','scan.fetch-size'='2000');
CREATE TEMPORARY TABLE source2_sale_relation (relation_account_id STRING,sale_id STRING,am_id STRING,relation_start_time TIMESTAMP(6),relation_end_time TIMESTAMP(6),priority INT) WITH ('connector'='jdbc','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified','table-name'='(SELECT relation_account_id::text,sale_id::text,am_id::text,relation_start_time,relation_end_time,1 FROM dim.dim_sale_account_relation_p WHERE delete_time IS NULL UNION ALL SELECT aar.account_id::text,sr.sale_id::text,sr.am_id::text,sr.relation_start_time,sr.relation_end_time,2 FROM public.api_account_relation aar JOIN dim.dim_sale_account_relation_p sr ON sr.relation_account_id::text=aar.root_id::text WHERE aar.delete_time IS NULL AND sr.delete_time IS NULL) rel','username'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','driver'='org.postgresql.Driver','scan.fetch-size'='2000');
CREATE TEMPORARY VIEW v_sale_physical_card_matched AS SELECT tr.*,sr.sale_id,sr.am_id,ROW_NUMBER() OVER (PARTITION BY tr.transaction_id ORDER BY sr.priority,sr.relation_start_time DESC) rn FROM source1_transaction tr JOIN source2_sale_relation sr ON tr.account_id=sr.relation_account_id AND tr.create_time>=sr.relation_start_time AND (tr.create_time<sr.relation_end_time OR sr.relation_end_time IS NULL);
CREATE TEMPORARY VIEW v_sale_physical_card_expanded AS SELECT transaction_id,account_id,provider,bin,status,origin_amount,create_time,sale_id sale_or_am_id FROM v_sale_physical_card_matched WHERE rn=1 AND sale_id IS NOT NULL UNION ALL SELECT transaction_id,account_id,provider,bin,status,origin_amount,create_time,am_id FROM v_sale_physical_card_matched WHERE rn=1 AND am_id IS NOT NULL;
CREATE TEMPORARY VIEW v_dws_sale_physical_card_operator AS SELECT CAST(ABS(HASH_CODE(CONCAT(COALESCE(account_id,''),': ',COALESCE(sale_or_am_id,''),': ',COALESCE(provider,''),': ',COALESCE(bin,''),': ',COALESCE(status,''),': ',DATE_FORMAT(CAST(CAST(create_time AS DATE) AS TIMESTAMP),'yyyy-MM-dd'))) AS BIGINT) id,account_id,sale_or_am_id,provider,bin,status,CAST(COUNT(*) AS INT) transaction_count,CAST(SUM(origin_amount) AS DECIMAL(18,2)) physical_card_fee,CAST(CAST(create_time AS DATE) AS TIMESTAMP) create_date,CAST(1 AS INT) version,CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) create_time,CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) update_time FROM v_sale_physical_card_expanded GROUP BY account_id,sale_or_am_id,provider,bin,status,CAST(create_time AS DATE);

CREATE TEMPORARY TABLE sink_dws_sale_physical_card_2026 (
    id BIGINT, account_id STRING, sale_or_am_id STRING, provider STRING, bin STRING, status STRING, transaction_count INT, physical_card_fee DECIMAL(18,2), create_date TIMESTAMP(6), version INT, create_time TIMESTAMP(6), update_time TIMESTAMP(6),
    PRIMARY KEY (id) NOT ENFORCED
) WITH ('connector'='adbpg','url'='jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}','tableName'='dws_sale_physical_card_2026','userName'='${secret_values.ADB_PG_USERNAME}','password'='${secret_values.ADB_PG_PASSWORD}','writeMode'='upsert','batchSize'='2000');

INSERT INTO sink_dws_sale_physical_card_2026
SELECT id, account_id, sale_or_am_id, provider, bin, status, transaction_count, physical_card_fee, create_date, version, create_time, update_time
FROM v_dws_sale_physical_card_operator
CROSS JOIN source_delete_dws_sale_physical_card_result AS del
WHERE del.affected_rows >= 0
  AND create_date >= DATE '2026-01-01' AND create_date < DATE '2027-01-01';
