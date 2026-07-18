--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-12
-- Description:    QI DWS 新增显式 rate 字段
-- Notes:
--   1. 不直接修改原始建表脚本，使用独立迁移 SQL
--   2. 旧的 *_vol 字段继续保留兼容
--********************************************************************--

ALTER TABLE "dws"."dws_qi_card_finance_daily_p"
    ADD COLUMN IF NOT EXISTS "cost_reimbursement_rate" numeric(20,4) DEFAULT 0;

ALTER TABLE "dws"."dws_qi_card_finance_daily_p"
    ADD COLUMN IF NOT EXISTS "cost_service_rate" numeric(20,4) DEFAULT 0;

ALTER TABLE "dws"."dws_qi_card_finance_daily_p"
    ADD COLUMN IF NOT EXISTS "cost_acs_regular_rate" numeric(20,4) DEFAULT 0;

ALTER TABLE "dws"."dws_qi_card_finance_daily_p"
    ADD COLUMN IF NOT EXISTS "cost_acs_vip_rate" numeric(20,4) DEFAULT 0;

ALTER TABLE "dws"."dws_qi_card_finance_daily_p"
    ADD COLUMN IF NOT EXISTS "cost_vrm_rate" numeric(20,4) DEFAULT 0;

ALTER TABLE "dws"."dws_qi_card_finance_daily_p"
    ADD COLUMN IF NOT EXISTS "rebate_interchange_rate" numeric(20,4) DEFAULT 0;

ALTER TABLE "dws"."dws_qi_card_finance_daily_p"
    ADD COLUMN IF NOT EXISTS "rebate_incentive_rate" numeric(20,4) DEFAULT 0;

COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."cost_reimbursement_rate" IS 'Reimbursement费用系数(显式字段，兼容原 cost_reimbursement_vol)';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."cost_service_rate" IS 'Service Fee费用系数(显式字段，兼容原 cost_service_vol)';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."cost_acs_regular_rate" IS 'ACS普通笔数系数(显式字段，兼容原 cost_acs_regular_count)';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."cost_acs_vip_rate" IS 'ACS VIP笔数系数(显式字段，兼容原 cost_acs_vip_count)';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."cost_vrm_rate" IS 'VRM验证笔数系数(显式字段，兼容原 cost_vrm_count)';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."rebate_interchange_rate" IS 'Interchange返现系数(显式字段，兼容原 rebate_interchange_vol)';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."rebate_incentive_rate" IS 'Incentive返现系数(显式字段，兼容原 rebate_incentive_vol)';
