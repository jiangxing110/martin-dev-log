--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-06 00:20:56
-- Description:    注册 ods_crypto_blockchain_transfers v2 删除函数
-- 作业元信息：
--   作业类型：ADBPG 函数注册
--   运行方式：在目标 ADBPG 数据库执行一次；VVR SQL v2 删除作业通过 JDBC 调用本函数
--   运行参数：无
-- Notes:
--   1. 函数返回受影响行数。
--   2. p_dry_run = true 时只统计不删除。
--   3. p_end_date 为开区间。
--********************************************************************--

CREATE OR REPLACE FUNCTION ods.fn_delete_crypto_blockchain_transfers_v2(
    p_start_date DATE,
    p_end_date   DATE,
    p_dry_run    BOOLEAN DEFAULT false
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $function$
DECLARE
    affected_rows BIGINT;
BEGIN
    IF p_start_date IS NULL THEN
        RAISE EXCEPTION 'p_start_date must not be null';
    END IF;

    IF p_end_date IS NULL THEN
        RAISE EXCEPTION 'p_end_date must not be null';
    END IF;

    IF p_start_date >= p_end_date THEN
        RAISE EXCEPTION 'p_start_date must be before p_end_date, got % and %', p_start_date, p_end_date;
    END IF;

    IF p_dry_run THEN
        SELECT COUNT(*)
        INTO affected_rows
        FROM ods.ods_crypto_blockchain_transfers
        WHERE dt >= p_start_date
          AND dt < p_end_date;

        RETURN affected_rows;
    END IF;

    DELETE FROM ods.ods_crypto_blockchain_transfers
    WHERE dt >= p_start_date
      AND dt < p_end_date;

    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    RETURN affected_rows;
END;
$function$;

COMMENT ON FUNCTION ods.fn_delete_crypto_blockchain_transfers_v2(DATE, DATE, BOOLEAN)
IS '删除 ods.ods_crypto_blockchain_transfers 指定 dt 范围数据，返回受影响行数；dry_run=true 时只统计不删除';

-- dry-run 验证示例：
SELECT ods.fn_delete_crypto_blockchain_transfers_v2(DATE '2021-01-01', DATE '2027-01-01', true) AS matched_rows;
