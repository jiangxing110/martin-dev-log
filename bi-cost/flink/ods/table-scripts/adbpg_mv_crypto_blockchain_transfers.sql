--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-06-23
-- 功能：ADBPG ODS物化视图，等价于 PG public.view_crypto_assets_blockchain_transfers
-- 作业元信息：
--   作业类型：DDL建表/视图脚本
--   运行方式：非运行作业
--   运行参数：无
--   源库变更响应：不涉及源库变更同步；用于创建 ADBPG 目标表、分区、索引或视图。
-- 说明：基表 ods_crypto_assets_transfers / ods_balance / ods_crypto_assets_transactions
--       均已通过 CDC 同步到 ODS，在 ADBPG 内建物化视图无需处理 UUID 问题
--********************************************************************--

-- ==============================================
-- 1. 创建物化视图
-- ==============================================
CREATE MATERIALIZED VIEW "ods"."view_crypto_assets_blockchain_transfers" AS
SELECT
    tr.id,
    tr.transaction_display_id,
    tr.account_id,
    CASE
        WHEN bal.wallet_type = 'VirtualUSD' THEN NULL
        ELSE bal.system_unique_id
    END AS wallet_id,
    tr.balance_id,
    tr.action,
    tr.currency,
    tr.chain,
    tx.source_address,
    COALESCE(tr.address, tx.destination_address) AS destination_address,
    tr.origin_amount::varchar AS amount,
    tr.fee::varchar AS gas_fee,
    tr.cross_chain_fee::varchar AS cross_chain_fee,
    tr.display_status AS status,
    tx.transaction_hash,
    tr.risk_level,
    tr.create_time,
    tx.create_time AS third_party_create_time,
    COALESCE(tr.close_time, tr.update_time) AS completion_time,
    replace(tx.trade_id, 'wd-', '') AS third_party_id,
    tx.platform,
    tr.usd_rate,
    tr.fees
FROM ods.ods_crypto_assets_transfers tr
LEFT JOIN ods.ods_balance bal ON bal.id::varchar = tr.balance_id
LEFT JOIN ods.ods_crypto_assets_transactions tx ON tx.trade_id = tr.trade_id
WHERE tr.delete_time IS NULL
  AND (
    (tr.sender_type = 'wallet' AND tr.recipient_type = 'chain')
    OR (tr.sender_type = 'chain' AND tr.recipient_type = 'wallet')
  )
WITH DATA
DISTRIBUTED BY (id);

ALTER MATERIALIZED VIEW "ods"."view_crypto_assets_blockchain_transfers" OWNER TO "qbit_admin";

-- 唯一索引：用于 CONCURRENTLY 刷新
CREATE UNIQUE INDEX IF NOT EXISTS "idx_view_crypto_assets_blockchain_transfers_id"
    ON "ods"."view_crypto_assets_blockchain_transfers" ("id");

COMMENT ON MATERIALIZED VIEW "ods"."view_crypto_assets_blockchain_transfers" IS
    'ODS物化视图：base on ods_crypto_assets_transfers / ods_balance / ods_crypto_assets_transactions';

-- ==============================================
-- 2. 定时刷新（每 5 分钟）
-- ==============================================
-- 手动刷新：
-- REFRESH MATERIALIZED VIEW CONCURRENTLY ods.view_crypto_assets_blockchain_transfers;

-- pg_cron 定时任务（每 5 分钟刷新一次）：
SELECT cron.schedule(
    'refresh_mv_crypto_blockchain_transfers',  -- 任务名称
    '*/5 * * * *',                              -- 每 5 分钟
    $$REFRESH MATERIALIZED VIEW CONCURRENTLY ods.view_crypto_assets_blockchain_transfers$$
);

-- 查看已创建的定时任务：
-- SELECT * FROM cron.job;

-- 删除定时任务：
-- SELECT cron.unschedule('refresh_mv_crypto_blockchain_transfers');
