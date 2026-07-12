--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-12
-- Description:    QI DWS 新增显式基数字段
-- Notes:
--   1. 不直接修改原始建表脚本，使用独立迁移 SQL
--   2. 旧的 *_vol 字段继续保留兼容
--********************************************************************--

ALTER TABLE "dws"."dws_qi_card_finance_daily_p"
    ADD COLUMN IF NOT EXISTS "cost_reimbursement_base_amt" numeric(20,4) DEFAULT 0;

ALTER TABLE "dws"."dws_qi_card_finance_daily_p"
    ADD COLUMN IF NOT EXISTS "cost_service_base_amt" numeric(20,4) DEFAULT 0;

ALTER TABLE "dws"."dws_qi_card_finance_daily_p"
    ADD COLUMN IF NOT EXISTS "cost_acs_regular_base_cnt" bigint DEFAULT 0;

ALTER TABLE "dws"."dws_qi_card_finance_daily_p"
    ADD COLUMN IF NOT EXISTS "cost_acs_vip_base_cnt" bigint DEFAULT 0;

ALTER TABLE "dws"."dws_qi_card_finance_daily_p"
    ADD COLUMN IF NOT EXISTS "cost_vrm_base_cnt" bigint DEFAULT 0;

ALTER TABLE "dws"."dws_qi_card_finance_daily_p"
    ADD COLUMN IF NOT EXISTS "rebate_interchange_base_amt" numeric(20,4) DEFAULT 0;

ALTER TABLE "dws"."dws_qi_card_finance_daily_p"
    ADD COLUMN IF NOT EXISTS "rebate_incentive_base_amt" numeric(20,4) DEFAULT 0;

COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."cost_reimbursement_base_amt" IS 'Reimbursement费用基数(显式字段，兼容原 cost_reimbursement_vol)';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."cost_service_base_amt" IS 'Service Fee费用基数(显式字段，兼容原 cost_service_vol)';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."cost_acs_regular_base_cnt" IS 'ACS普通笔数基数(显式字段，兼容原 cost_acs_regular_count)';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."cost_acs_vip_base_cnt" IS 'ACS VIP笔数基数(显式字段，兼容原 cost_acs_vip_count)';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."cost_vrm_base_cnt" IS 'VRM验证笔数基数(显式字段，兼容原 cost_vrm_count)';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."rebate_interchange_base_amt" IS 'Interchange返现基数(显式字段，兼容原 rebate_interchange_vol)';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_p"."rebate_incentive_base_amt" IS 'Incentive返现基数(显式字段，兼容原 rebate_incentive_vol)';
