-- dws_crypto_assets_transfers DDL（IF NOT EXISTS，不重建现有表）
CREATE TABLE IF NOT EXISTS public.dws_crypto_assets_transfers_2024 (
    "id" BIGINT,,
    "account_id" STRING,,
    "status" STRING,,
    "sender_type" STRING,,
    "recipient_type" STRING,,
    "transaction_count" INT,,
    "origin_amount" DECIMAL(18,2),,
    "settlement_amount" DECIMAL(18,2),,
    "fee" DECIMAL(18,2),,
    "fee2" DECIMAL(18,2),,
    "cross_chain_fee" DECIMAL(18,2),,
    "hidden" BOOLEAN,,
    "create_date" TIMESTAMP(6),,
    "currency" STRING,,
    "action" STRING,,
    "version" INT,,
    "create_time" TIMESTAMP(6),,
    "update_time" TIMESTAMP(6)
);

CREATE TABLE IF NOT EXISTS public.dws_crypto_assets_transfers_2025 (
    "id" BIGINT,,
    "account_id" STRING,,
    "status" STRING,,
    "sender_type" STRING,,
    "recipient_type" STRING,,
    "transaction_count" INT,,
    "origin_amount" DECIMAL(18,2),,
    "settlement_amount" DECIMAL(18,2),,
    "fee" DECIMAL(18,2),,
    "fee2" DECIMAL(18,2),,
    "cross_chain_fee" DECIMAL(18,2),,
    "hidden" BOOLEAN,,
    "create_date" TIMESTAMP(6),,
    "currency" STRING,,
    "action" STRING,,
    "version" INT,,
    "create_time" TIMESTAMP(6),,
    "update_time" TIMESTAMP(6)
);

CREATE TABLE IF NOT EXISTS public.dws_crypto_assets_transfers_2026 (
    "id" BIGINT,,
    "account_id" STRING,,
    "status" STRING,,
    "sender_type" STRING,,
    "recipient_type" STRING,,
    "transaction_count" INT,,
    "origin_amount" DECIMAL(18,2),,
    "settlement_amount" DECIMAL(18,2),,
    "fee" DECIMAL(18,2),,
    "fee2" DECIMAL(18,2),,
    "cross_chain_fee" DECIMAL(18,2),,
    "hidden" BOOLEAN,,
    "create_date" TIMESTAMP(6),,
    "currency" STRING,,
    "action" STRING,,
    "version" INT,,
    "create_time" TIMESTAMP(6),,
    "update_time" TIMESTAMP(6)
);
