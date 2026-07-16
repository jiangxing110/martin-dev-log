--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-16
-- Description:    BB v2 Auth DWM 批量回刷前置清理
-- 作业元信息：
--   作业类型：批处理
--   运行方式：在 dwm_online_bb_card_auth_detail_v2-batch-sql 前单独执行
--   运行参数：start_time, end_time
-- Notes:
--   1. 阿里云 VVR batch application 模式下 DELETE + INSERT 会被识别为 multiple jobs。
--   2. 所以清理和写入拆成两个可编排的单 job 脚本。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

CREATE TEMPORARY TABLE sink_dwm_bb_card_auth_detail_v2_p (
    id                      STRING,
    auth_txn_guid           STRING,
    card_proxy              STRING,
    account_id              STRING,
    account_type            STRING,
    account_category        STRING,
    system_type             STRING,
    card_id                 STRING,
    auth_time               TIMESTAMP(6),
    program_name            STRING,
    merchant_country        STRING,
    request_code            STRING,
    request_description     STRING,
    response_code           STRING,
    reason_code             STRING,
    txn_amount              STRING,
    settle_amount           STRING,
    txn_currency            STRING,
    merchant_name           STRING,
    mcc                     STRING,
    card_org                STRING,
    is_dom                  BOOLEAN,
    is_decline              BOOLEAN,
    is_account_verification BOOLEAN,
    is_excluded_request     BOOLEAN,
    sale_id                 STRING,
    am_id                   STRING,
    source_table            STRING,
    version                 INT,
    create_time             TIMESTAMP(6),
    update_time             TIMESTAMP(6),
    delete_time             TIMESTAMP(6),
    PRIMARY KEY (id, auth_time) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dwm_bb_card_auth_detail_v2_p',
    'targetSchema' = 'dwm',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

DELETE FROM sink_dwm_bb_card_auth_detail_v2_p
WHERE auth_time >= CAST('${start_time}' AS TIMESTAMP(6))
  AND auth_time < CAST('${end_time}' AS TIMESTAMP(6))
  AND source_table = CONCAT('bb_card_auth_detail_', DATE_FORMAT(CAST('${start_time}' AS TIMESTAMP(6)), 'yyyy-MM'));
