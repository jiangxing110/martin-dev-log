-- dws_crypto_assets_transfers DDL（IF NOT EXISTS，不重建现有表）
CREATE TABLE IF NOT EXISTS public.dws_crypto_assets_transfers_2024 (
    "id" BIGINT,,
    "account_id" STRING,,
    "status" STRING,,
    "sender_type" STRING,,
    "recipient_type" STRING,,
    "transaction_count" BIGINT,,
    "origin_amount" DECIMAL(20,4),,
    "settlement_amount" DECIMAL(20,4),,
    "fee" DECIMAL(20,4),,
    "fee2" DECIMAL(20,4),,
    "cross_chain_fee" DECIMAL(20,4),,
    "hidden" BOOLEAN,,
    "create_date" DATE,,
    "currency" STRING,,
    "action" STRING,,
    "version" BIGINT,,
    "create_time" TIMESTAMP(6),,
    "update_time" TIMESTAMP(6)
);

CREATE TABLE IF NOT EXISTS public.dws_crypto_assets_transfers_2025 (
    "id" BIGINT,,
    "account_id" STRING,,
    "status" STRING,,
    "sender_type" STRING,,
    "recipient_type" STRING,,
    "transaction_count" BIGINT,,
    "origin_amount" DECIMAL(20,4),,
    "settlement_amount" DECIMAL(20,4),,
    "fee" DECIMAL(20,4),,
    "fee2" DECIMAL(20,4),,
    "cross_chain_fee" DECIMAL(20,4),,
    "hidden" BOOLEAN,,
    "create_date" DATE,,
    "currency" STRING,,
    "action" STRING,,
    "version" BIGINT,,
    "create_time" TIMESTAMP(6),,
    "update_time" TIMESTAMP(6)
);

CREATE TABLE IF NOT EXISTS public.dws_crypto_assets_transfers_2026 (
    "id" BIGINT,,
    "account_id" STRING,,
    "status" STRING,,
    "sender_type" STRING,,
    "recipient_type" STRING,,
    "transaction_count" BIGINT,,
    "origin_amount" DECIMAL(20,4),,
    "settlement_amount" DECIMAL(20,4),,
    "fee" DECIMAL(20,4),,
    "fee2" DECIMAL(20,4),,
    "cross_chain_fee" DECIMAL(20,4),,
    "hidden" BOOLEAN,,
    "create_date" DATE,,
    "currency" STRING,,
    "action" STRING,,
    "version" BIGINT,,
    "create_time" TIMESTAMP(6),,
    "update_time" TIMESTAMP(6)
);
