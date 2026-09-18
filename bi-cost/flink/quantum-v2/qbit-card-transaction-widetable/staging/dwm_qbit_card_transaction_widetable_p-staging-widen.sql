--********************************************************************--
-- Description: STAGING 量子卡交易宽表超长字段修复
-- Usage: 在 STAGING 数据库执行一次后，再执行每日全量同步脚本。
-- Reason: 全量数据中存在超过目标 varchar 长度的历史值，不能通过截断解决。
--********************************************************************--

BEGIN;

ALTER TABLE dwm.dwm_quantum_card_transaction_p
    ALTER COLUMN source_id TYPE text,
    ALTER COLUMN spc_transaction_id TYPE text,
    ALTER COLUMN spc_merchant_name TYPE text,
    ALTER COLUMN label TYPE text,
    ALTER COLUMN group_name TYPE text,
    ALTER COLUMN acc_verified_name TYPE text,
    ALTER COLUMN acc_verified_name_en TYPE text,
    ALTER COLUMN status TYPE text,
    ALTER COLUMN display_status TYPE text,
    ALTER COLUMN currency TYPE text,
    ALTER COLUMN transaction_currency TYPE text,
    ALTER COLUMN spc_mcc TYPE text,
    ALTER COLUMN spc_zip_code TYPE text,
    ALTER COLUMN card_type_dim TYPE text,
    ALTER COLUMN physical_card_status TYPE text,
    ALTER COLUMN card_mode TYPE text,
    ALTER COLUMN card_status TYPE text,
    ALTER COLUMN group_status TYPE text,
    ALTER COLUMN account_type TYPE text;

COMMIT;
