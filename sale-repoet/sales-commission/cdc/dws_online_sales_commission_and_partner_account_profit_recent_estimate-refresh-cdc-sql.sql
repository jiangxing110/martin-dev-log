--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-12 20:17:49
-- Updated Time:   2026-11-12 20:21:27
-- Description:    销售佣金与合伙人毛利预估物化视图串行刷新触发任务
-- 作业元信息：
--   作业类型：Flink JDBC触发任务
--   运行方式：由 Flink SQL Gateway / 外部调度周期执行
--   运行参数：无
-- Notes:
--   1. 先在 ADBPG 客户端执行 cdc/sp_refresh_mv_sales_commission_recent_estimate.sql 创建销售刷新函数。
--   2. 再在 ADBPG 客户端执行 parter-account-profit/cdc/sp_refresh_mv_partner_account_profit_recent_estimate.sql 创建合伙人刷新函数。
--   3. 再执行 cdc/sp_refresh_mv_sales_and_partner_recent_estimate.sql 创建串行刷新包装函数。
--   4. 本脚本不注册数据库内置定时任务。
--   5. 本任务通过一个 PostgreSQL 包装函数先刷新销售视图，再刷新合伙人视图；blackhole sink 不写入业务表。
--   6. 部署时需要添加 PostgreSQL JDBC driver 依赖，例如 postgresql-42.7.4.jar。
--   7. 本文件是需要提交到 Flink 的刷新作业；三个 sp_refresh 函数定义只能在 ADBPG 执行。
--   8. Flink 通过 JDBC 子查询调用 void 函数，并用固定 affected_rows 触发单个有界 INSERT；无需开启 Batch 多作业配置。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';

CREATE TEMPORARY TABLE source_refresh_mv_sales_and_partner_recent_estimate (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT 1::bigint AS affected_rows FROM (SELECT dws.sp_refresh_mv_sales_and_partner_recent_estimate() AS refresh_call) AS refresh_call_f) AS refresh_mv_sales_and_partner_recent_estimate_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

CREATE TEMPORARY TABLE sink_refresh_mv_sales_and_partner_recent_estimate (
    affected_rows BIGINT
) WITH (
    'connector' = 'blackhole'
);

-- 单个有界 JDBC DML 调用数据库包装函数，包装函数内部串行刷新销售视图和合伙人视图。
INSERT INTO sink_refresh_mv_sales_and_partner_recent_estimate
SELECT affected_rows
FROM source_refresh_mv_sales_and_partner_recent_estimate;
