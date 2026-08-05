--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-05 17:20:00
-- Description:    dim_account_analysis CDC 源 PostgreSQL 环境检查
-- Notes:
--   1. 本脚本在源业务 PostgreSQL 执行，不在目标 ADBPG 执行。
--   2. 脚本只读，不修改 publication、slot 或数据库参数。
--********************************************************************--

-- 1. 当前会话和数据库超时参数。
SELECT
    current_database() AS database_name,
    current_user AS database_user,
    current_setting('idle_in_transaction_session_timeout')
        AS idle_in_transaction_session_timeout,
    current_setting('statement_timeout') AS statement_timeout;

-- 2. account-analysis 所需的 11 张表是否都在 publication 中。
WITH expected_table(schema_name, table_name) AS (
    VALUES
        ('public', 'account'),
        ('public', 'accountExtend'),
        ('public', 'referralCode'),
        ('public', 'caas_open_api_extend'),
        ('public', 'cddRiskRating'),
        ('public', 'api_account_relation'),
        ('public', 'qbitCardWalletTransaction'),
        ('public', 'transfer'),
        ('public', 'crypto_assets_transfers'),
        ('public', 'openApiClientConfig'),
        ('public', 'fund_orders')
)
SELECT
    e.schema_name,
    e.table_name,
    CASE WHEN p.tablename IS NULL THEN 'MISSING' ELSE 'OK' END
        AS publication_status
FROM expected_table e
LEFT JOIN pg_publication_tables p
    ON p.pubname = 'flink_cdc_publication'
   AND p.schemaname = e.schema_name
   AND p.tablename = e.table_name
ORDER BY e.schema_name, e.table_name;

-- 3. 11 个 replication slot 的状态和 WAL 水位。
SELECT
    slot_name,
    active,
    active_pid,
    restart_lsn,
    confirmed_flush_lsn
FROM pg_replication_slots
WHERE slot_name LIKE 'flink_slot_account_analysis_%'
ORDER BY slot_name;

-- 如果第 1 步的 idle_in_transaction_session_timeout 太短，需要 DBA
-- 针对 CDC 用户提高或关闭该超时，并在修改后重新部署作业。例如：
-- ALTER ROLE "<cdc_user>" IN DATABASE "<source_database>"
--     SET idle_in_transaction_session_timeout = '30min';
