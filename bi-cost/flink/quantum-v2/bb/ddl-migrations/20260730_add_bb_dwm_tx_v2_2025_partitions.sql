--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-30 22:00:21
-- Description:    BB v2 交易 DWM 补充 2025 年 5 个月 transaction_time 分区
-- Notes:
--   1. dwm_bb_card_transaction_detail_v2_p 按 transaction_time 分区。
--   2. batch 按 original_completion_time / refund postDate 回刷时，可能写入历史 transaction_time。
--   3. 2026 回刷已出现 transaction_time = 2025-11-14 的记录，因此补充 2025-08 至 2025-12 分区。
--********************************************************************--

CREATE TABLE IF NOT EXISTS "dwm"."dwm_bb_card_tx_v2_2025_08" PARTITION OF "dwm"."dwm_bb_card_transaction_detail_v2_p" FOR VALUES FROM ('2025-08-01 00:00:00') TO ('2025-09-01 00:00:00');
CREATE TABLE IF NOT EXISTS "dwm"."dwm_bb_card_tx_v2_2025_09" PARTITION OF "dwm"."dwm_bb_card_transaction_detail_v2_p" FOR VALUES FROM ('2025-09-01 00:00:00') TO ('2025-10-01 00:00:00');
CREATE TABLE IF NOT EXISTS "dwm"."dwm_bb_card_tx_v2_2025_10" PARTITION OF "dwm"."dwm_bb_card_transaction_detail_v2_p" FOR VALUES FROM ('2025-10-01 00:00:00') TO ('2025-11-01 00:00:00');
CREATE TABLE IF NOT EXISTS "dwm"."dwm_bb_card_tx_v2_2025_11" PARTITION OF "dwm"."dwm_bb_card_transaction_detail_v2_p" FOR VALUES FROM ('2025-11-01 00:00:00') TO ('2025-12-01 00:00:00');
CREATE TABLE IF NOT EXISTS "dwm"."dwm_bb_card_tx_v2_2025_12" PARTITION OF "dwm"."dwm_bb_card_transaction_detail_v2_p" FOR VALUES FROM ('2025-12-01 00:00:00') TO ('2026-01-01 00:00:00');
