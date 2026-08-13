--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-13 00:00:00
-- Updated Time:   2026-08-13 00:00:00
-- Description:    销售佣金8号前预估物化视图刷新触发任务
-- 作业元信息：
--   作业类型：Flink JDBC触发任务
--   运行方式：由 Flink SQL Gateway / 外部调度周期执行
--   运行参数：无
-- Notes:
--   1. 先在 ADBPG 客户端执行 cdc/sp_refresh_mv_sales_commission_recent_estimate.sql 创建刷新函数。
--   2. 本脚本只通过 JDBC 调用 dws.sp_refresh_mv_sales_commission_recent_estimate()。
--   3. 本脚本不注册数据库内置定时任务。
--   4. 部署平台要求 INSERT SQL，因此使用 blackhole sink 承接刷新函数调用结果。
--   5. 部署时需要添加 PostgreSQL JDBC driver 依赖，例如 postgresql-42.7.4.jar。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';

CREATE TEMPORARY TABLE source_refresh_mv_sales_commission_recent_estimate (
    refresh_result STRING
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT CAST("dws"."sp_refresh_mv_sales_commission_recent_estimate"() AS text) AS refresh_result) AS refresh_mv_sales_commission_recent_estimate_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

CREATE TEMPORARY TABLE sink_refresh_mv_sales_commission_recent_estimate (
    refresh_result STRING
) WITH (
    'connector' = 'blackhole'
);

INSERT INTO sink_refresh_mv_sales_commission_recent_estimate
SELECT refresh_result
FROM source_refresh_mv_sales_commission_recent_estimate;
