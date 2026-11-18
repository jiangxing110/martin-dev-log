--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-11-18
-- Description:    销售佣金、绩效收入及合伙人利润物化视图串行刷新触发任务
-- 作业元信息：
--   作业类型：Flink JDBC触发任务
--   运行方式：沿用现有 Flink SQL Gateway / 外部调度周期
--   运行参数：无
-- Notes:
--   1. 先在 ADBPG 执行佣金、收入、合伙人单体刷新函数及串行包装函数。
--   2. PostgreSQL 包装函数内部依次刷新佣金、销售实际收入、合伙人毛利物化视图。
--   3. 本脚本不注册 pg_cron，也不改外部调度周期。
--   4. blackhole sink 不写入业务表；此文件可以替换现有同名 Flink 刷新作业。
--   5. 部署时需要 PostgreSQL JDBC driver，例如 postgresql-42.7.4.jar。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';

CREATE TEMPORARY TABLE source_refresh_mv_sales_commission_income_partner_profit_recent (
    affected_rows BIGINT
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'table-name' = '(SELECT 1::bigint AS affected_rows FROM (SELECT dws.sp_refresh_mv_sales_commission_income_partner_profit_recent() AS refresh_call) AS refresh_call_f) AS refresh_mv_sales_commission_income_partner_profit_recent_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '1'
);

CREATE TEMPORARY TABLE sink_refresh_mv_sales_commission_income_partner_profit_recent (
    affected_rows BIGINT
) WITH (
    'connector' = 'blackhole'
);

-- 单个有界 JDBC DML 调用统一包装函数，依次刷新三个数据域。
INSERT INTO sink_refresh_mv_sales_commission_income_partner_profit_recent
SELECT affected_rows
FROM source_refresh_mv_sales_commission_income_partner_profit_recent;
