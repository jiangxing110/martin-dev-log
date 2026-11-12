--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-12 19:42:18
-- Updated Time:   2026-11-12 20:00:02
-- Description:    合伙人客户毛利物化视图手动补刷任务
-- 作业元信息：
--   作业类型：Flink JDBC触发任务
--   运行方式：由 Flink SQL Gateway 人工调用或临时调度
--   运行参数：无
-- Notes:
--   1. 先在 ADBPG 客户端执行 cdc/sp_refresh_mv_partner_account_profit_recent_estimate.sql 创建刷新函数。
--   2. 本脚本只通过 JDBC 调用 dws.sp_refresh_mv_partner_account_profit_recent_estimate()，供合伙人视图单独补刷。
--   3. 本脚本不注册数据库内置定时任务。
--   4. 部署平台要求 INSERT SQL，因此使用 blackhole sink 承接刷新函数调用结果。
--   5. 部署时需要添加 PostgreSQL JDBC driver 依赖，例如 postgresql-42.7.4.jar。
--   6. 定时刷新主流程已并入 sale-repoet 销售刷新任务，本文件不要另设重复的周期调度。
--   7. sp_refresh_mv_partner_account_profit_recent_estimate.sql 只能在 ADBPG 执行。
--   8. Flink 通过 JDBC 子查询调用 void 函数，并返回固定 affected_rows 数值，不执行 PostgreSQL 函数 DDL。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';

CREATE TEMPORARY TABLE source_refresh_mv_partner_account_profit_recent_estimate (
  affected_rows BIGINT
) WITH (
  'connector' = 'jdbc',
  'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
  'table-name' = '(SELECT 1::bigint AS affected_rows FROM (SELECT dws.sp_refresh_mv_partner_account_profit_recent_estimate() AS refresh_call) AS refresh_call_f) AS refresh_mv_partner_account_profit_recent_estimate_f',
  'username' = '${secret_values.ADB_PG_USERNAME}',
  'password' = '${secret_values.ADB_PG_PASSWORD}',
  'driver' = 'org.postgresql.Driver',
  'scan.fetch-size' = '1'
);

CREATE TEMPORARY TABLE sink_refresh_mv_partner_account_profit_recent_estimate (
  affected_rows BIGINT
) WITH (
  'connector' = 'blackhole'
);

INSERT INTO sink_refresh_mv_partner_account_profit_recent_estimate
SELECT affected_rows
FROM source_refresh_mv_partner_account_profit_recent_estimate;
