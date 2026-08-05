--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-05 16:00:00
-- Description:    public.account -> dim_account_analysis CDC 数量核对
-- Notes:
--   1. 第 1 段在源业务库执行，第 2 段在目标 ADBPG 库执行。
--   2. 账户类型及逻辑删除口径与 CDC 脚本保持一致。
--********************************************************************--

-- 1. 源业务库：public.account
SELECT
    CASE WHEN GROUPING("type") = 1 THEN 'TOTAL' ELSE "type" END AS category,
    COUNT(*) AS source_count,
    COUNT(*) FILTER (WHERE "deleteTime" IS NOT NULL) AS deleted_count,
    MAX("createTime") AS max_create_time,
    MAX(COALESCE("updateTime", "createTime")) AS max_update_time
FROM public.account
WHERE "type" IN ('ApiClient', 'MasterAccount', 'Merchant', 'TestAccount')
GROUP BY GROUPING SETS (("type"), ())
ORDER BY category;

-- 2. 目标 ADBPG 库：dim.dim_account_analysis
SELECT
    CASE
        WHEN GROUPING(account_category) = 1 THEN 'TOTAL'
        ELSE account_category
    END AS category,
    COUNT(*) AS target_count,
    COUNT(*) FILTER (WHERE delete_time IS NOT NULL) AS deleted_count,
    MAX(create_time) AS max_create_time,
    MAX(update_time) AS max_update_time
FROM dim.dim_account_analysis
GROUP BY GROUPING SETS ((account_category), ())
ORDER BY category;
