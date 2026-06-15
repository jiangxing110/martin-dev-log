--********************************************************************--
-- Author:         zhanghaoran
-- Created Time:   2026-06-09 13:46:55
-- Description:    Write your description here
-- Hints:          You can use SET statements to modify the configuration
--********************************************************************--
SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
-- SET 'pipeline.operator-chaining' = 'false'; 

-- 重启策略
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';
-- set 'source.extend-type.enabled' = 'true'; -- VVR8.0.5以上版本，设置source.extend-type.enabled为true，支持读取和映射拓展类型


SET 'table.local-time-zone' = 'UTC'; -- source时间都为utc时间


CREATE TEMPORARY TABLE source_account_qbit (
    -- id                VARCHAR(36),
    -- remarks           STRING,
    -- `createTime`      TIMESTAMP(6),
    -- `updateTime`      TIMESTAMP(6),
    -- `deleteTime`      TIMESTAMP(6),
    -- version           INT,
    -- `parentAccountId` STRING,
    -- `verifiedName`    STRING,
    -- `verifiedNameEn`  STRING,
    -- `accountType`     STRING,
    -- status            STRING,
    -- country           STRING,
    -- `referralCodeId`  STRING,
    -- `prevUserId`      STRING,
    -- `metaData`        STRING,
    -- type              STRING,
    -- `displayId`       STRING,
    -- `tenantId`        BIGINT
    id                VARCHAR(36),
    remarks           STRING,
    create_time       TIMESTAMP(6),
    update_time       TIMESTAMP(6),
    delete_time       TIMESTAMP(6),
    version           INT,
    parent_account_id STRING,
    verified_name     STRING,
    verified_name_en  STRING,
    account_type      STRING,
    status            STRING,
    country           STRING,
    referral_code_id  STRING,
    prev_user_id      STRING,
    meta_data         STRING,
    type              STRING,
    display_id        STRING,
    tenant_id         BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.PG_PAY_PROD_HOST_TEST}:${secret_values.PG_PAY_PROD_PORT_TEST}/${secret_values.PG_PAY_PROD_DATABASE_TEST}',
    'username' = '${secret_values.PG_PAY_PROD_USERNAME_TEST}',
    'password' = '${secret_values.PG_PAY_PROD_PWD_TEST}',
    -- 'table-name' = '(SELECT id::text AS id, remarks, "createTime", "updateTime", "deleteTime", version, "parentAccountId"::text AS "parentAccountId", "verifiedName", "verifiedNameEn", "accountType", status, country, "referralCodeId", "prevUserId", "metaData"::text AS "metaData", type, "displayId", "tenantId" FROM public.account_qbit) AS account_qbit_text',
    'table-name' = '(SELECT id::text AS id, remarks, "createTime" AS create_time, "updateTime" AS update_time, "deleteTime" AS delete_time, version, "parentAccountId"::text AS parent_account_id, "verifiedName" AS verified_name, "verifiedNameEn" AS verified_name_en, "accountType" AS account_type, status, country, "referralCodeId" AS referral_code_id, "prevUserId" AS prev_user_id, "metaData"::text AS meta_data, type, "displayId" AS display_id, "tenantId" AS tenant_id FROM public.account_qbit) AS account_qbit_text',
    -- 'table-name' = 'public.account_qbit',
    'scan.fetch-size' = '5000'
);



CREATE TEMPORARY VIEW v_account_qbit AS
SELECT
    -- id,
    -- remarks,
    -- `createTime` AS create_time,
    -- `updateTime` AS update_time,
    -- `deleteTime` AS delete_time,
    -- version,
    -- `parentAccountId` AS parent_account_id,
    -- `verifiedName` AS verified_name,
    -- `verifiedNameEn` AS verified_name_en,
    -- `accountType` AS account_type,
    -- status,
    -- country,
    -- `referralCodeId` AS referral_code_id,
    -- `prevUserId` AS prev_user_id,
    -- `metaData` AS meta_data,
    -- type,
    -- `displayId` AS display_id,
    -- `tenantId` AS tenant_id,
    id,
    remarks,
    create_time,
    update_time,
    delete_time,
    version,
    parent_account_id,
    verified_name,
    verified_name_en,
    account_type,
    status,
    country,
    referral_code_id,
    prev_user_id,
    meta_data,
    type,
    display_id,
    tenant_id,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS etl_time
FROM source_account_qbit;


CREATE TEMPORARY TABLE sink_ods_account_qbit (
    id                STRING,
    remarks           STRING,
    create_time       TIMESTAMP(6),
    update_time       TIMESTAMP(6),
    delete_time       TIMESTAMP(6),
    version           INT,
    parent_account_id STRING,
    verified_name     STRING,
    verified_name_en  STRING,
    account_type      STRING,
    status            STRING,
    country           STRING,
    referral_code_id  STRING,
    prev_user_id      STRING,
    meta_data         STRING,
    type              STRING,
    display_id        STRING,
    tenant_id         BIGINT,
    -- create_time_utc8  TIMESTAMP(6),
    etl_time          TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'table-name' = 'ods.ods_account_qbit',
    'driver' = 'org.postgresql.Driver',
    'sink.buffer-flush.max-rows' = '2000',
    'sink.buffer-flush.interval' = '3000'
);



CREATE TEMPORARY TABLE sink_dim_account_qbit (
    id                STRING,
    remarks           STRING,
    create_time       TIMESTAMP(6),
    update_time       TIMESTAMP(6),
    version           INT,
    parent_account_id STRING,
    verified_name     STRING,
    verified_name_en  STRING,
    account_type      STRING,
    status            STRING,
    country           STRING,
    referral_code_id  STRING,
    prev_user_id      STRING,
    meta_data         STRING,
    type              STRING,
    display_id        STRING,
    tenant_id         BIGINT,
    create_time_utc8  TIMESTAMP(6),
    etl_time          TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'table-name' = 'dim.dim_account_qbit',
    'driver' = 'org.postgresql.Driver',
    'sink.buffer-flush.max-rows' = '2000',
    'sink.buffer-flush.interval' = '3000'
);



BEGIN STATEMENT SET;

INSERT INTO sink_ods_account_qbit
SELECT 
*
FROM v_account_qbit;


INSERT INTO sink_dim_account_qbit
SELECT
    id, remarks, create_time, update_time, version, parent_account_id,
    verified_name, verified_name_en, account_type, status, country,
    referral_code_id, prev_user_id, meta_data, type, display_id, tenant_id,
    create_time + INTERVAL '8' HOUR AS create_time_utc8,
    etl_time
FROM v_account_qbit;


END;
