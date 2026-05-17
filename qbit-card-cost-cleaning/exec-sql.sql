-- base 基础数据清洗
-- 1.清洗settlement_bb表，清洗2026-04-26到2026-05-01的数据，分8小时跑一次
CALL "public"."sp_init_qbit_card_settlement_bb_clean_2026"('2026-04-26 00:00:00','2026-05-01 00:00:00',  '8 hours');
-- 2.清洗transaction表，清洗2026-04-28到2026-05-01的数据，分8小时跑一次
CALL sp_init_qbit_card_transaction_clean_2026('2026-04-28 00:00:00','2026-05-01 00:00:00');
-- 3.清洗settlement_bb表，清洗2026-04-01到2026-04-06的数据，分6小时跑一次
call sp_init_qbit_card_settlement_bb_clean_2026_V2('2026-04-01 00:00:00','2026-04-06 00:00:00','6 hours');


-- 1. 初始化 DWM 明细 (2026-01-01 到 2026-03-01)
CALL sp_init_qi_card_dwm_by_fast('2026-03-21 00:00:00', '2026-04-01 00:00:00');
-- 2. 初始化 DWS 汇总 (2026-01-01 到 2026-03-01)
CALL sp_init_qi_card_dws_by_fast('2026-03-01', '2026-04-01');
-- 这里建议分段跑，比如先跑 1 月
CALL sp_init_bb_card_dwm_history_fast('2026-03-01 00:00:00', '2026-03-02 00:00:00');
--第二步：根据明细生成 1 月的财务汇总 (DWS)
CALL sp_init_bb_card_dws_fast('2026-01-01', '2026-02-01');

--4.2 日常增量同步
-- 自动扫描过去 25 小时的变更 (updateTime)
CALL sp_sync_qi_card_incremental();
-- 场景 B：针对特定日期的 ODS 补录进行修补
CALL sp_sync_qi_card_incremental('2026-02-20 00:00:00', '2026-02-21 00:00:00');
--场景 A：日常自动运行 (Airflow/Cron)
CALL sp_sync_bb_card_incremental();
--场景 B：手动补数 / 修正
--如果发现 2026-02-10 的数据有问题，或者在 ODS 刷了大量的历史更新，可以手动执行该时间段：
-- 手动扫描 2026-02-10 全天发生变动的数据
CALL sp_sync_bb_card_incremental('2026-02-10 00:00:00', '2026-02-11 00:00:00');

