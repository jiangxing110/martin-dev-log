--********************************************************************
-- Author:         martinJiang
-- Created Time:   2026-08-19
-- Description:    根据日期范围自动生成分区表 UNION ALL 查询的辅助函数
-- Usage:
--   SELECT generate_partition_union('2026-01-15', '2026-03-20');
--********************************************************************

-- 生成分区表名称的函数（YYYYqN 格式）
CREATE OR REPLACE FUNCTION get_partition_table_name(date_part DATE)
RETURNS TEXT AS $$
DECLARE
    year INT;
    quarter INT;
BEGIN
    year := EXTRACT(YEAR FROM date_part);
    quarter := EXTRACT(QUARTER FROM date_part);
    RETURN 'qbit_card_transaction_' || year || 'q' || quarter;
END;
$$ LANGUAGE plpgsql;

-- 生成日期范围内的分区表 UNION ALL 查询（去重）
CREATE OR REPLACE FUNCTION generate_partition_union(start_date DATE, end_date DATE)
RETURNS TEXT AS $$
DECLARE
    current_date DATE := start_date;
    table_name TEXT;
    tables TEXT[] := '{}';
    found BOOLEAN;
    result TEXT := '';
BEGIN
    -- 遍历日期范围内的每个季度
    WHILE current_date <= end_date LOOP
        -- 获取当前季度的分区表名
        table_name := get_partition_table_name(current_date);

        -- 检查是否已存在（去重）
        found := FALSE;
        FOR i IN 1..array_length(tables, 1) LOOP
            IF tables[i] = table_name THEN
                found := TRUE;
                EXIT;
            END IF;
        END LOOP;

        -- 如果不存在，添加到数组
        IF NOT found THEN
            tables := array_append(tables, table_name);
        END IF;

        -- 跳转到下一个季度的第一天
        current_date := DATE_TRUNC('QUARTER', current_date + INTERVAL '3 months');
    END LOOP;

    -- 生成 UNION ALL 查询
    FOR i IN 1..array_length(tables, 1) LOOP
        IF result = '' THEN
            result := '-- ' || tables[i] || CHR(10) || 'SELECT * FROM "' || tables[i] || '"';
        ELSE
            result := result || CHR(10) || 'UNION ALL' || CHR(10) || '-- ' || tables[i] || CHR(10) || 'SELECT * FROM "' || tables[i] || '"';
        END IF;
    END LOOP;

    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 使用示例
-- SELECT generate_partition_union('2026-01-15', '2026-06-20');
-- 输出格式：
-- -- qbit_card_transaction_2026q1
-- SELECT * FROM "qbit_card_transaction_2026q1"
-- UNION ALL
-- -- qbit_card_transaction_2026q2
-- SELECT * FROM "qbit_card_transaction_2026q2"

-- 查看某个日期范围内的所有涉及分区表（仅显示表名）
CREATE OR REPLACE FUNCTION get_partition_tables(start_date DATE, end_date DATE)
RETURNS TABLE(partition_table TEXT) AS $$
DECLARE
    current_date DATE := start_date;
    table_name TEXT;
    tables TEXT[] := '{}';
    found BOOLEAN;
BEGIN
    WHILE current_date <= end_date LOOP
        table_name := get_partition_table_name(current_date);

        found := FALSE;
        FOR i IN 1..array_length(tables, 1) LOOP
            IF tables[i] = table_name THEN
                found := TRUE;
                EXIT;
            END IF;
        END LOOP;

        IF NOT found THEN
            tables := array_append(tables, table_name);
        END IF;

        current_date := DATE_TRUNC('QUARTER', current_date + INTERVAL '3 months');
    END LOOP;

    FOR i IN 1..array_length(tables, 1) LOOP
        partition_table := tables[i];
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 使用示例：查看 2026-01-15 到 2026-12-31 涉及的所有分区表
-- SELECT * FROM get_partition_tables('2026-01-15', '2026-12-31');
-- 输出：
-- partition_table
-- -------------------------------
-- qbit_card_transaction_2026q1
-- qbit_card_transaction_2026q2
-- qbit_card_transaction_2026q3
-- qbit_card_transaction_2026q4

-- 快速生成 Flink SQL 中的分区 UNION 片段
CREATE OR REPLACE FUNCTION generate_flink_partition_union(start_date DATE, end_date DATE)
RETURNS TEXT AS $$
DECLARE
    current_date DATE := start_date;
    table_name TEXT;
    tables TEXT[] := '{}';
    found BOOLEAN;
    result TEXT := '';
BEGIN
    WHILE current_date <= end_date LOOP
        table_name := get_partition_table_name(current_date);

        found := FALSE;
        FOR i IN 1..array_length(tables, 1) LOOP
            IF tables[i] = table_name THEN
                found := TRUE;
                EXIT;
            END IF;
        END LOOP;

        IF NOT found THEN
            tables := array_append(tables, table_name);
        END IF;

        current_date := DATE_TRUNC('QUARTER', current_date + INTERVAL '3 months');
    END LOOP;

    FOR i IN 1..array_length(tables, 1) LOOP
        result := result || '            -- ' || substring(tables[i], 23, 4) || CHR(10) ||
                   '            SELECT * FROM "' || tables[i] || '"' || CHR(10);
        IF i < array_length(tables, 1) THEN
            result := result || '            UNION ALL' || CHR(10);
        END IF;
    END LOOP;

    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 使用示例：生成 Flink SQL 格式的分区 UNION
-- SELECT generate_flink_partition_union('2026-01-15', '2026-06-20');
-- 输出：
--             -- 2026q1
--             SELECT * FROM "qbit_card_transaction_2026q1"
--             UNION ALL
--             -- 2026q2
--             SELECT * FROM "qbit_card_transaction_2026q2"