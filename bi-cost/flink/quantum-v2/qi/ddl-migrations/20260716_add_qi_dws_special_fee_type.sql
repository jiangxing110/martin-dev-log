--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-16
-- Description:    QI v2 DWS 增加特殊费用行类型字段
--********************************************************************--

ALTER TABLE "dws"."dws_qi_card_finance_daily_v2_p"
    ADD COLUMN IF NOT EXISTS "special_fee_type" varchar(64) COLLATE "pg_catalog"."default";

COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."special_fee_type"
    IS '特殊费用行类型，普通行为空；CHANNEL_FIXED_FEE=渠道固定成本特殊行';
