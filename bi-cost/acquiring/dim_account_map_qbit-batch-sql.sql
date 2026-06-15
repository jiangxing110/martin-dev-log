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


CREATE TEMPORARY TABLE source_account_map_qbit (
    id           BIGINT,
    remarks      STRING,
    create_time  TIMESTAMP(6),
    update_time  TIMESTAMP(6),
    delete_time  TIMESTAMP(6),
    version      INT,
    account_id   VARCHAR(36)
    -- account_id   STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.PG_PAY_PROD_HOST_TEST}:${secret_values.PG_PAY_PROD_PORT_TEST}/${secret_values.PG_PAY_PROD_DATABASE_TEST}',
    'username' = '${secret_values.PG_PAY_PROD_USERNAME_TEST}',
    'password' = '${secret_values.PG_PAY_PROD_PWD_TEST}',
    'table-name' = '(SELECT id, remarks, create_time, update_time, delete_time, version, account_id::text AS account_id FROM public.account_map_qbit) AS account_map_qbit_text',
    -- 'table-name' = 'public.account_map_qbit',
    'scan.fetch-size' = '5000'
);

CREATE TEMPORARY VIEW v_account_map_qbit AS
SELECT
    id,
    remarks,
    create_time,
    update_time,
    delete_time,
    version,
    account_id,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS etl_time
FROM source_account_map_qbit;

CREATE TEMPORARY TABLE sink_ods_account_map_qbit (
    id           BIGINT,
    remarks      STRING,
    create_time  TIMESTAMP(6),
    update_time  TIMESTAMP(6),
    delete_time  TIMESTAMP(6),
    version      INT,
    account_id   STRING,
    etl_time     TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'table-name' = 'ods.ods_account_map_qbit',
    'driver' = 'org.postgresql.Driver',
    'sink.buffer-flush.max-rows' = '2000',
    'sink.buffer-flush.interval' = '3000'
);


CREATE TEMPORARY TABLE sink_dim_account_map_qbit (
    id           BIGINT,
    remarks      STRING,
    create_time  TIMESTAMP(6),
    update_time  TIMESTAMP(6),
    version      INT,
    account_id   STRING,
    etl_time     TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'table-name' = 'dim.dim_account_map_qbit',
    'driver' = 'org.postgresql.Driver',
    'sink.buffer-flush.max-rows' = '2000',
    'sink.buffer-flush.interval' = '3000'
);

BEGIN STATEMENT SET;


INSERT INTO sink_ods_account_map_qbit
SELECT * FROM v_account_map_qbit;


INSERT INTO sink_dim_account_map_qbit
SELECT
    id, remarks, create_time, update_time, version, account_id, etl_time
FROM v_account_map_qbit;

END;
