--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-09-11
-- Description:    dim_account_analysis 增加客户展示 ID
--********************************************************************--

ALTER TABLE "dim"."dim_account_analysis"
  ADD COLUMN IF NOT EXISTS "display_id" varchar(128) COLLATE "pg_catalog"."default";

COMMENT ON COLUMN "dim"."dim_account_analysis"."display_id"
  IS '客户展示ID，来源 dim_account.displayId';
