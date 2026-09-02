-- TODO：请有表权限的 DBA 执行
-- 用途：解决 09 / 20 Flink adbpg sink 写入 card_id 的 UUID/VARCHAR 类型不匹配。
-- 执行前请确认目标表备份及影响范围。

DO $$
DECLARE
    v_table_name TEXT;
    v_tables TEXT[] := ARRAY[
        'ods_qbit_card_2024',
        'ods_qbit_card_2025',
        'ods_qbit_card_2026',
        'ods_sale_qbit_card_2024',
        'ods_sale_qbit_card_2025',
        'ods_sale_qbit_card_2026'
    ];
BEGIN
    FOREACH v_table_name IN ARRAY v_tables LOOP
        IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = v_table_name
              AND column_name = 'card_id'
              AND udt_name = 'uuid'
        ) THEN
            EXECUTE format(
                'ALTER TABLE public.%I ALTER COLUMN card_id TYPE VARCHAR(36) USING card_id::text',
                v_table_name
            );
        END IF;
    END LOOP;
END;
$$;

-- 08 / 09 / 19 / 20 作业兼容迁移：各 ODS 表的 account_id 需要接收 Flink STRING。
DO $$
DECLARE
    v_table_name TEXT;
    v_tables TEXT[] := ARRAY[
        'ods_qbit_card_2024',
        'ods_qbit_card_2025',
        'ods_qbit_card_2026',
        'ods_sale_qbit_card_2024',
        'ods_sale_qbit_card_2025',
        'ods_sale_qbit_card_2026',
        'ods_fund_profits_2024',
        'ods_fund_profits_2025',
        'ods_fund_profits_2026',
        'ods_sale_fund_profits_2024',
        'ods_sale_fund_profits_2025',
        'ods_sale_fund_profits_2026'
    ];
BEGIN
    FOREACH v_table_name IN ARRAY v_tables LOOP
        IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = v_table_name
              AND column_name = 'account_id'
              AND udt_name = 'uuid'
        ) THEN
            EXECUTE format(
                'ALTER TABLE public.%I ALTER COLUMN account_id TYPE VARCHAR(36) USING account_id::text',
                v_table_name
            );
        END IF;
    END LOOP;
END;
$$;

-- 13 / 14 / 15 / 18 / 19 / 20 作业兼容迁移：销售关系及业务主键字段接收 Flink STRING。
DO $$
DECLARE
    v_table_name TEXT;
    v_column_name TEXT;
    v_tables TEXT[] := ARRAY[
        'dws_sale_card_transaction_2024', 'dws_sale_card_transaction_2025', 'dws_sale_card_transaction_2026',
        'dws_sale_card_transaction_extend_2024', 'dws_sale_card_transaction_extend_2025', 'dws_sale_card_transaction_extend_2026',
        'dws_sale_card_group_transaction_2024', 'dws_sale_card_group_transaction_2025', 'dws_sale_card_group_transaction_2026',
        'dws_sale_crypto_assets_transfers_2024', 'dws_sale_crypto_assets_transfers_2025', 'dws_sale_crypto_assets_transfers_2026',
        'ods_sale_fund_profits_2024', 'ods_sale_fund_profits_2025', 'ods_sale_fund_profits_2026',
        'ods_sale_qbit_card_2024', 'ods_sale_qbit_card_2025', 'ods_sale_qbit_card_2026'
    ];
    v_columns TEXT[] := ARRAY['account_id', 'sale_or_am_id', 'product_id', 'fund_id', 'card_id'];
BEGIN
    FOREACH v_table_name IN ARRAY v_tables LOOP
        FOREACH v_column_name IN ARRAY v_columns LOOP
            IF EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = v_table_name
                  AND column_name = v_column_name
                  AND udt_name = 'uuid'
            ) THEN
                EXECUTE format(
                    'ALTER TABLE public.%I ALTER COLUMN %I TYPE VARCHAR(36) USING %I::text',
                    v_table_name, v_column_name, v_column_name
                );
            END IF;
        END LOOP;
    END LOOP;
END;
$$;

-- 执行后核对：以下已迁移字段的 data_type 应为 character varying / varchar
SELECT table_name, column_name, data_type, udt_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND column_name IN ('card_id', 'account_id', 'sale_or_am_id', 'product_id', 'fund_id')
  AND table_name IN (
      'ods_qbit_card_2024', 'ods_qbit_card_2025', 'ods_qbit_card_2026',
      'ods_sale_qbit_card_2024', 'ods_sale_qbit_card_2025', 'ods_sale_qbit_card_2026',
      'ods_fund_profits_2024', 'ods_fund_profits_2025', 'ods_fund_profits_2026',
      'ods_sale_fund_profits_2024', 'ods_sale_fund_profits_2025', 'ods_sale_fund_profits_2026'
      , 'dws_sale_card_transaction_2024', 'dws_sale_card_transaction_2025', 'dws_sale_card_transaction_2026'
      , 'dws_sale_card_transaction_extend_2024', 'dws_sale_card_transaction_extend_2025', 'dws_sale_card_transaction_extend_2026'
      , 'dws_sale_card_group_transaction_2024', 'dws_sale_card_group_transaction_2025', 'dws_sale_card_group_transaction_2026'
      , 'dws_sale_crypto_assets_transfers_2024', 'dws_sale_crypto_assets_transfers_2025', 'dws_sale_crypto_assets_transfers_2026'
  )
ORDER BY table_name;

ods_qbit_card_2026
ods_sale_qbit_card_2026

  "card_id" uuid NOT NULL,
  "account_id" uuid NOT NULL
  
ods_fund_profits_2026
  "account_id" uuid NOT NULL,


GRANT ALTER ON TABLE
    public.ods_qbit_card_2024,
    public.ods_qbit_card_2025,
    public.ods_qbit_card_2026,
    public.ods_sale_qbit_card_2024,
    public.ods_sale_qbit_card_2025,
    public.ods_sale_qbit_card_2026,
    public.ods_fund_profits_2024,
    public.ods_fund_profits_2025,
    public.ods_fund_profits_2026,
    public.ods_sale_fund_profits_2024,
    public.ods_sale_fund_profits_2025,
    public.ods_sale_fund_profits_2026,

    public.dws_sale_card_group_transaction_2024,
    public.dws_sale_card_group_transaction_2025,
    public.dws_sale_card_group_transaction_2026,
    public.dws_sale_crypto_assets_transfers_2024,
    public.dws_sale_crypto_assets_transfers_2025,
    public.dws_sale_crypto_assets_transfers_2026
TO flink_cdc_user;


GRANT ALTER ON TABLE
    public.ods_sale_fund_profits_2024,
    public.ods_sale_fund_profits_2025,
    public.ods_sale_fund_profits_2026,
    public.dws_sale_card_transaction_2024,
    public.dws_sale_card_transaction_2025,
    public.dws_sale_card_transaction_2026,
    public.dws_sale_card_transaction_extend_2024,
    public.dws_sale_card_transaction_extend_2025,
    public.dws_sale_card_transaction_extend_2026,
    public.dws_sale_card_group_transaction_2024,
    public.dws_sale_card_group_transaction_2025,
    public.dws_sale_card_group_transaction_2026,
    public.dws_sale_crypto_assets_transfers_2024,
    public.dws_sale_crypto_assets_transfers_2025,
    public.dws_sale_crypto_assets_transfers_2026
TO your_user;