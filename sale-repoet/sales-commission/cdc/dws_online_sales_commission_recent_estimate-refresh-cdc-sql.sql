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
--   4. 本任务只负责调用刷新函数，不写入任何业务表。
--   5. 部署时需要添加 PostgreSQL JDBC driver 依赖，例如 postgresql-42.7.4.jar。
--   6. 本文件是唯一需要提交到 Flink 的文件；sp_refresh_mv_sales_commission_recent_estimate.sql 只能在 ADBPG 执行。
--   7. Flink 通过 JDBC 子查询调用 void 函数，并直接 SELECT 固定 affected_rows 数值，不执行 PostgreSQL 函数 DDL。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';

CREATE TEMPORARY TABLE source_refresh_mv_sales_commission_recent_estimate (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT 1::bigint AS affected_rows FROM (SELECT dws.sp_refresh_mv_sales_commission_recent_estimate() AS refresh_call) AS refresh_call_f) AS refresh_mv_sales_commission_recent_estimate_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

SELECT affected_rows
FROM source_refresh_mv_sales_commission_recent_estimate;
