--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-09-11
-- Description:    回填客户分析维表中的 OpenAPI 属性
-- 运行方式：可手工执行，也可按分钟级周期调度执行
-- 说明：
--   1. 用数仓 public.caas_open_api_extend 当前有效记录覆盖 DIM 中的 API 属性。
--   2. 仅更新发生差异的行，避免无变化数据反复更新 update_time。
--   3. 该脚本用于补偿 OpenAPI 记录晚于账户维表记录生成、或 CDC 漏消费的情况。
--********************************************************************--

UPDATE "dim"."dim_account_analysis" AS daa
SET
    "business_mode" = cae."business_mode",
    "access_type" = cae."access_type",
    "mor_type" = cae."mor_type",
    "mor_type_extra" = cae."mor_type_extra",
    "update_time" = CURRENT_TIMESTAMP
FROM "public"."caas_open_api_extend" AS cae
WHERE daa."account_id" = cae."account_id"::text
  AND cae."delete_time" IS NULL
  AND (
      daa."business_mode" IS DISTINCT FROM cae."business_mode"
      OR daa."access_type" IS DISTINCT FROM cae."access_type"
      OR daa."mor_type" IS DISTINCT FROM cae."mor_type"
      OR daa."mor_type_extra" IS DISTINCT FROM cae."mor_type_extra"
  );

