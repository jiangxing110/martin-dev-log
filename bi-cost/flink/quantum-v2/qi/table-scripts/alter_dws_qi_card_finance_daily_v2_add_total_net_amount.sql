--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-23 21:42:00
-- Description:    QI v2 财务汇总表增加净消费字段
--********************************************************************--

ALTER TABLE dws.dws_qi_card_finance_daily_v2_p
    ADD COLUMN IF NOT EXISTS total_net_amount NUMERIC(20, 4) DEFAULT 0;

COMMENT ON COLUMN dws.dws_qi_card_finance_daily_v2_p.total_net_amount
    IS '净消费金额：Closed/Pending 的 Consumption 加金额，Reversal/Credit 减金额';
