--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-07-17
-- Description:    修复 QI v2 DWM 表 id 类型与 Flink ADBPG sink 写入类型不一致的问题
-- Notes:
--   1. Flink JDBC/ADBPG sink 将 id 作为 STRING/varchar 参数写入。
--   2. 原表 id 为 uuid 时会报：column "id" is of type uuid but expression is of type character varying。
--   3. v2 表的 id 来源是 qbit_card_transaction.id，业务上仍是 UUID 字符串，使用 varchar(36) 更适配 Flink 写入。
--********************************************************************--

ALTER TABLE "dwm"."dwm_qi_card_transaction_detail_v2_p"
    ALTER COLUMN "id" TYPE varchar(36)
    USING "id"::text;
