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

-- 执行后核对：card_id 应为 character varying / varchar
SELECT table_name, column_name, data_type, udt_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND column_name = 'card_id'
  AND table_name IN (
      'ods_qbit_card_2024', 'ods_qbit_card_2025', 'ods_qbit_card_2026',
      'ods_sale_qbit_card_2024', 'ods_sale_qbit_card_2025', 'ods_sale_qbit_card_2026'
  )
ORDER BY table_name;
