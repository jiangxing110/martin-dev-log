--********************************************************************--
-- 数据同步：PG public.bi_month_tag → ADB PG ods.ods_bi_month_tag
-- 方式：全量同步（upsert），包含 account_id
-- 参数：startTime、endTime（按 update_time 左闭右开过滤；为空时覆盖全量时间范围）
--********************************************************************--

SET 'parallelism.default' = '2';
SET 'pipeline.operator-chaining' = 'false';
SET 'table.exec.sink.upsert-materialize' = 'NONE';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

-- 1. 源表：业务 PostgreSQL。无过滤条件，读取 bi_month_tag 全量数据。
CREATE TEMPORARY TABLE pg_bi_month_tag (
    id bigint,
    create_time timestamp(6),
    update_time timestamp(6),
    delete_time timestamp(6),
    version integer,
    tag varchar(255),
    statistics_time timestamp(6),
    amount numeric,
    remarks varchar(255),
    detail varchar(255),
    account_type varchar(255),
    provider varchar(255),
    product_line varchar(255),
    account_id STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.PG_TEST_HOST}:${secret_values.PG_TEST_PORT1}/${secret_values.PG_TEST_DATABASE}',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'table-name' = '(SELECT id, create_time, update_time, delete_time, version, tag, statistics_time, amount, remarks, detail, account_type, provider, product_line, account_id FROM public.bi_month_tag WHERE update_time >= COALESCE(CAST(NULLIF(''${startTime}'', '''') AS TIMESTAMP(6)), TIMESTAMP ''1970-01-01 00:00:00'') AND update_time < COALESCE(CAST(NULLIF(''${endTime}'', '''') AS TIMESTAMP(6)), TIMESTAMP ''9999-12-31 23:59:59'')) AS bi_month_tag_f',
    'source.extend-type.enabled' = 'true'
);

-- 2. 目标表：ADB PG。以 id upsert，保证重复全量执行幂等。
CREATE TEMPORARY TABLE ods_bi_month_tag (
    id bigint,
    create_time timestamp(6),
    update_time timestamp(6),
    delete_time timestamp(6),
    version integer,
    tag varchar(255),
    statistics_time timestamp(6),
    amount numeric,
    remarks varchar(255),
    detail varchar(255),
    account_type varchar(255),
    provider varchar(255),
    product_line varchar(255),
    account_id STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'ods_bi_month_tag',
    'targetSchema' = 'ods',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '3000'
);

-- 3. 显式列映射，避免源表/目标表字段顺序变化造成错位。
INSERT INTO ods_bi_month_tag (
    id,
    create_time,
    update_time,
    delete_time,
    version,
    tag,
    statistics_time,
    amount,
    remarks,
    detail,
    account_type,
    provider,
    product_line,
    account_id
)
SELECT
    id,
    create_time,
    update_time,
    delete_time,
    version,
    tag,
    statistics_time,
    amount,
    remarks,
    detail,
    account_type,
    provider,
    product_line,
    account_id
FROM pg_bi_month_tag;
