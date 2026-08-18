-- =============================================================
-- 重新清洗 dws_qbit_card_transaction 全部分表数据
-- 用途：清空 DWS 聚合表，随后重跑 batch 作业重新聚合
-- 说明：事务内执行，确认无误后再 COMMIT；若删错用 ROLLBACK 回滚
-- =============================================================

-- 0) 删除前：核对各分表当前行数（确认要清空的规模）
SELECT '2024' AS shard, COUNT(*) AS rows FROM public.dws_qbit_card_transaction_2024
UNION ALL SELECT '2025', COUNT(*) FROM public.dws_qbit_card_transaction_2025
UNION ALL SELECT '2026', COUNT(*) FROM public.dws_qbit_card_transaction_2026
UNION ALL SELECT '2027', COUNT(*) FROM public.dws_qbit_card_transaction_2027;

-- 1) 在事务中清空全部 4 个分表
--    （若只想洗 2026，删掉 2024/2025/2027 那三行即可）
BEGIN;
DELETE FROM public.dws_qbit_card_transaction_2024;
DELETE FROM public.dws_qbit_card_transaction_2025;
DELETE FROM public.dws_qbit_card_transaction_2026;
DELETE FROM public.dws_qbit_card_transaction_2027;

-- 2) 确认已删空（应全部为 0）
SELECT '2024' AS shard, COUNT(*) AS rows FROM public.dws_qbit_card_transaction_2024
UNION ALL SELECT '2025', COUNT(*) FROM public.dws_qbit_card_transaction_2025
UNION ALL SELECT '2026', COUNT(*) FROM public.dws_qbit_card_transaction_2026
UNION ALL SELECT '2027', COUNT(*) FROM public.dws_qbit_card_transaction_2027;

-- 3) 确认无误后提交；发现删错则执行 ROLLBACK;
COMMIT;

-- =============================================================
-- 重新灌入：清空前/后均可，但清空后必须保证 batch 覆盖全量日期范围
-- 重跑 Flink batch 作业即可，其会调用删除函数按年路由 + 重聚合源表。
-- 关键陷阱：batch 的“重聚合”只处理 createTime 落在传入日期区间的源行。
--   - 默认 batch 文件区间写死 '2026-01-01' ~ '2026-08-17'，只会重洗 2026。
--   - 要全量重洗，必须把区间拉到最早 createTime ~ 今天，例如：
--       SELECT public.fn_delete_dws_qbit_card_transaction_cdc(false, DATE '2024-01-01', DATE '2026-08-18');
--     否则 2024/2025 分表会保持空表。
--   - 若只洗 2026，用默认区间即可，无需改。
-- =============================================================

-- 若只需快速清空且无需回滚，可用 TRUNCATE（更快、锁更重、DDL 不可回滚）：
-- TRUNCATE TABLE public.dws_qbit_card_transaction_2024,
--                public.dws_qbit_card_transaction_2025,
--                public.dws_qbit_card_transaction_2026,
--                public.dws_qbit_card_transaction_2027;
