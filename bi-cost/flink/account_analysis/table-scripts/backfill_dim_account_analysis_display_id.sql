--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-09-11
-- Description:    回填客户分析维表 display_id
-- 运行方式：可手工执行，也可按周期调度执行
--********************************************************************--

UPDATE "dim"."dim_account_analysis" AS daa
SET
    "display_id" = a."displayId",
    "update_time" = CURRENT_TIMESTAMP
FROM "public"."account" AS a
WHERE daa."account_id" = a."id"::text
  AND daa."display_id" IS DISTINCT FROM a."displayId"
;

