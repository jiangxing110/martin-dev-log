--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-22
-- 历史名称：sp_init_qbit_physical_card_ods.sql
-- 功能：PG业务表 qbitPhysicalCard 实时同步到 ODS层 ods_qbit_physical_card
-- 作业元信息：
--   作业类型：批处理
--   运行方式：JDBC 批读 + ADBPG upsert
--   运行参数：start_time, end_time
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑。
--   ODS说明：用于初始化、补数和全量回刷 ODS 原始层。
-- 模式：JDBC 批读 + ADBPG upsert | 全量刷新
----------------------------------------------------------------------

SET 'parallelism.default' = '1';
SET 'execution.checkpointing.interval' = '10s';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'execution.checkpointing.timeout' = '30min';

SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';

-- ==============================================
-- 1. 【临时表】PG CDC 源表
-- ==============================================
CREATE TEMPORARY TABLE flink_source_qbit_physical_card (
    id                       STRING,
    createTime               TIMESTAMP(6),
    updateTime               TIMESTAMP(6),
    deleteTime               TIMESTAMP(6),
    version                  INT,
    remarks                  STRING,
    accountId                STRING,
    cardId                   STRING,
    shippingAddress          STRING,
    pin                      STRING,
    phone                    STRING,
    phonePrefix              STRING,
    firstName                STRING,
    lastName                 STRING,
    userId                   STRING,
    isHasPin                 BOOLEAN,
    realName                 STRING,
    dob                      STRING,
    expirationDate           STRING,
    realAddress              STRING,
    realFirstName            STRING,
    realLastName             STRING,
    idNumber                 STRING,
    isShow                   BOOLEAN,
    idType                   STRING,
    email                    STRING,
    addressId                STRING,
    displayStatus            STRING,
    batchNo                  STRING,
    cardStyle                STRING,
    shippingBatchNo          STRING,
    designId                 STRING,
    cardPackage              STRING,
    taxId                    STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.PG_TEST_HOST}:${secret_values.PG_TEST_PORT1}/${secret_values.PG_TEST_DATABASE}',
    'table-name' = '(SELECT "id"::text AS "id", "createTime" AS createtime, "updateTime" AS updatetime, "deleteTime" AS deletetime, "version", "remarks"::text AS "remarks", "accountId"::text AS accountid, "cardId"::text AS cardid, "shippingAddress"::text AS shippingaddress, "pin"::text AS "pin", "phone"::text AS "phone", "phonePrefix"::text AS phoneprefix, "firstName"::text AS firstname, "lastName"::text AS lastname, "userId"::text AS userid, "isHasPin" AS ishaspin, "realName"::text AS realname, "dob"::text AS "dob", "expirationDate"::text AS expirationdate, "realAddress"::text AS realaddress, "realFirstName"::text AS realfirstname, "realLastName"::text AS reallastname, "idNumber"::text AS idnumber, "isShow" AS isshow, "idType"::text AS idtype, "email"::text AS "email", "addressId"::text AS addressid, "displayStatus"::text AS displaystatus, "batchNo"::text AS batchno, "cardStyle"::text AS cardstyle, "shippingBatchNo"::text AS shippingbatchno, "designId"::text AS designid, "cardPackage"::text AS cardpackage, "taxId"::text AS taxid FROM public."qbitPhysicalCard" WHERE (("createTime" >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND "createTime" < CAST(''${end_time}'' AS TIMESTAMP(6))) OR ("updateTime" >= CAST(''${start_time}'' AS TIMESTAMP(6)) AND "updateTime" < CAST(''${end_time}'' AS TIMESTAMP(6)))) ) AS ods_online_qbit_physical_card_f',
    'username' = '${secret_values.PG_TEST_USERNAME}',
    'password' = '${secret_values.PG_TEST_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1000',
    'scan.auto-commit' = 'false'
);

-- ==============================================
-- 2. 【临时表】ADBPG 目标表 ods.ods_qbit_physical_card
-- ==============================================
CREATE TEMPORARY TABLE flink_sink_ods_qbit_physical_card (
    id                       STRING,
    dt                       DATE,
    create_time              TIMESTAMP(6),
    update_time              TIMESTAMP(6),
    delete_time              TIMESTAMP(6),
    version                  INT,
    remarks                  STRING,
    account_id               STRING,
    card_id                  STRING,
    shipping_address         STRING,
    pin                      STRING,
    phone                    STRING,
    phone_prefix             STRING,
    first_name               STRING,
    last_name                STRING,
    user_id                  STRING,
    is_has_pin               BOOLEAN,
    real_name                STRING,
    dob                      STRING,
    expiration_date          STRING,
    real_address             STRING,
    real_first_name          STRING,
    real_last_name           STRING,
    id_number                STRING,
    is_show                  BOOLEAN,
    id_type                  STRING,
    email                    STRING,
    address_id               STRING,
    display_status           STRING,
    batch_no                 STRING,
    card_style               STRING,
    shipping_batch_no        STRING,
    design_id                STRING,
    card_package             STRING,
    tax_id                   STRING,
    submit_time              TIMESTAMP(6),
    PRIMARY KEY (id, dt) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'ods_qbit_physical_card',
    'targetSchema' = 'ods',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '200'
);

-- ==============================================
-- 3. 数据同步: submit_time = create_time, dt = create_time::DATE
-- ==============================================
INSERT INTO flink_sink_ods_qbit_physical_card
SELECT
    id,
    CAST(createTime AS DATE) AS dt,
    createTime AS create_time,
    updateTime AS update_time,
    deleteTime AS delete_time,
    version,
    remarks,
    accountId AS account_id,
    cardId AS card_id,
    shippingAddress AS shipping_address,
    pin,
    phone,
    phonePrefix AS phone_prefix,
    firstName AS first_name,
    lastName AS last_name,
    userId AS user_id,
    isHasPin AS is_has_pin,
    realName AS real_name,
    dob,
    expirationDate AS expiration_date,
    realAddress AS real_address,
    realFirstName AS real_first_name,
    realLastName AS real_last_name,
    idNumber AS id_number,
    isShow AS is_show,
    idType AS id_type,
    email,
    addressId AS address_id,
    displayStatus AS display_status,
    batchNo AS batch_no,
    cardStyle AS card_style,
    shippingBatchNo AS shipping_batch_no,
    designId AS design_id,
    cardPackage AS card_package,
    taxId AS tax_id,
    createTime AS submit_time
FROM flink_source_qbit_physical_card;
