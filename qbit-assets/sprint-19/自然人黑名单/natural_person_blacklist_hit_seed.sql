-- 自然人黑名单命中记录测试数据，共 30 条独立事件，拆成 3 组 INSERT（每组 10 条）。
-- 数据来自黑名单分页接口返回的 8 条名单；脱敏快照匹配接口展示值。
-- RELEASED 名单的命中时间均早于对应 released_time，用于模拟历史命中。
-- 请先确认这些名单记录已存在。本脚本会创建命中表（若不存在）并插入命中事件，不修改名单/身份表。
-- create_time 由脚本指定；update_time/version/delete_time 使用表默认值。
-- 本脚本是一次性测试数据，成功执行后不要重复执行（事件 ID 和 request_id 固定）。

CREATE TABLE IF NOT EXISTS public.natural_person_blacklist_hit (
    id bigint PRIMARY KEY NOT NULL,
    remarks varchar(255),
    create_time timestamptz NOT NULL DEFAULT now(),
    update_time timestamptz NOT NULL DEFAULT now(),
    delete_time timestamptz,
    version integer NOT NULL DEFAULT 0,
    source_system varchar(64) NOT NULL,
    request_id varchar(128),
    scene varchar(64) NOT NULL,
    source_type varchar(64),
    account_id varchar(64),
    cardholder_id varchar(64),
    matched_details jsonb NOT NULL DEFAULT '[]'::jsonb,
    CONSTRAINT uk_natural_person_blacklist_hit_request UNIQUE (source_system, request_id)
);

COMMENT ON TABLE public.natural_person_blacklist_hit IS '自然人黑名单命中事件，永久保留';
COMMENT ON COLUMN public.natural_person_blacklist_hit.id IS '命中事件 ID';
COMMENT ON COLUMN public.natural_person_blacklist_hit.remarks IS '命中事件备注';
COMMENT ON COLUMN public.natural_person_blacklist_hit.create_time IS '创建时间';
COMMENT ON COLUMN public.natural_person_blacklist_hit.update_time IS '更新时间';
COMMENT ON COLUMN public.natural_person_blacklist_hit.delete_time IS '软删除时间';
COMMENT ON COLUMN public.natural_person_blacklist_hit.version IS '乐观锁版本号';
COMMENT ON COLUMN public.natural_person_blacklist_hit.source_system IS '命中请求来源系统';
COMMENT ON COLUMN public.natural_person_blacklist_hit.request_id IS '来源系统请求 ID；预校验阶段可能为空';
COMMENT ON COLUMN public.natural_person_blacklist_hit.scene IS '命中业务场景';
COMMENT ON COLUMN public.natural_person_blacklist_hit.source_type IS 'KYC 来源类型';
COMMENT ON COLUMN public.natural_person_blacklist_hit.account_id IS '账户 ID';
COMMENT ON COLUMN public.natural_person_blacklist_hit.cardholder_id IS '持卡人 ID';
COMMENT ON COLUMN public.natural_person_blacklist_hit.matched_details IS '命中名单和维度的脱敏快照';

CREATE INDEX IF NOT EXISTS idx_natural_person_blacklist_hit_create_time
    ON public.natural_person_blacklist_hit (create_time DESC);
CREATE INDEX IF NOT EXISTS idx_natural_person_blacklist_hit_account
    ON public.natural_person_blacklist_hit (account_id, create_time DESC)
    WHERE account_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_natural_person_blacklist_hit_details
    ON public.natural_person_blacklist_hit USING gin (matched_details);

INSERT INTO public.natural_person_blacklist_hit (id, create_time, source_system, request_id, scene, source_type, account_id, cardholder_id, matched_details)
VALUES
    (2115363300000000001,'2026-10-28 16:41:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-001','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_001','h_test_blacklist_001','[{"blacklistId":2115362955267727361,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362955267727361,"identityType":"NATIONALITY_ID","maskedValue":"*****267A"}]'::jsonb),
    (2115363300000000002,'2026-10-28 16:42:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-002','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_002','h_test_blacklist_002','[{"blacklistId":2115362911873458177,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362911873458177,"identityType":"NATIONALITY_ID","maskedValue":"*********267A"}]'::jsonb),
    (2115363300000000003,'2026-10-28 16:43:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-003','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_003','h_test_blacklist_003','[{"blacklistId":2115362881385062402,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362881385062402,"identityType":"NATIONALITY_ID","maskedValue":"*********267A"}]'::jsonb),
    (2115363300000000004,'2026-10-28 16:42:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-004','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_004','h_test_blacklist_004','[{"blacklistId":2115362844487770113,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362844487770113,"identityType":"NATIONALITY_ID","maskedValue":"*****567A"}]'::jsonb),
    (2115363300000000005,'2026-10-28 16:41:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-005','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_005','h_test_blacklist_005','[{"blacklistId":2115362809456943105,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362809456943105,"identityType":"NATIONALITY_ID","maskedValue":"*******567A"}]'::jsonb),
    (2115363300000000006,'2026-10-28 16:41:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-006','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_006','h_test_blacklist_006','[{"blacklistId":2115362751483273217,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362751483273217,"identityType":"NATIONALITY_ID","maskedValue":"*****567A"}]'::jsonb),
    (2115363300000000007,'2026-10-28 16:42:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-007','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_007','h_test_blacklist_007','[{"blacklistId":2115362704834224130,"identityType":"EMAIL","maskedValue":"a***e@example.com"}]'::jsonb),
    (2115363300000000008,'2026-10-28 16:43:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-008','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_008','h_test_blacklist_008','[{"blacklistId":2115361705314803714,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115361705314803714,"identityType":"NATIONALITY_ID","maskedValue":"*****567A"}]'::jsonb),
    (2115363300000000009,'2026-10-28 16:43:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-009','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_009','h_test_blacklist_009','[{"blacklistId":2115362955267727361,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362955267727361,"identityType":"NATIONALITY_ID","maskedValue":"*****267A"}]'::jsonb),
    (2115363300000000010,'2026-10-28 16:44:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-010','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_010','h_test_blacklist_010','[{"blacklistId":2115362911873458177,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362911873458177,"identityType":"NATIONALITY_ID","maskedValue":"*********267A"}]'::jsonb);

INSERT INTO public.natural_person_blacklist_hit (id, create_time, source_system, request_id, scene, source_type, account_id, cardholder_id, matched_details)
VALUES
    (2115363300000000011,'2026-10-28 16:45:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-011','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_011','h_test_blacklist_011','[{"blacklistId":2115362881385062402,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362881385062402,"identityType":"NATIONALITY_ID","maskedValue":"*********267A"}]'::jsonb),
    (2115363300000000012,'2026-10-28 16:44:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-012','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_012','h_test_blacklist_012','[{"blacklistId":2115362844487770113,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362844487770113,"identityType":"NATIONALITY_ID","maskedValue":"*****567A"}]'::jsonb),
    (2115363300000000013,'2026-10-28 16:43:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-013','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_013','h_test_blacklist_013','[{"blacklistId":2115362809456943105,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362809456943105,"identityType":"NATIONALITY_ID","maskedValue":"*******567A"}]'::jsonb),
    (2115363300000000014,'2026-10-28 16:43:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-014','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_014','h_test_blacklist_014','[{"blacklistId":2115362751483273217,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362751483273217,"identityType":"NATIONALITY_ID","maskedValue":"*****567A"}]'::jsonb),
    (2115363300000000015,'2026-10-28 16:44:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-015','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_015','h_test_blacklist_015','[{"blacklistId":2115362704834224130,"identityType":"EMAIL","maskedValue":"a***e@example.com"}]'::jsonb),
    (2115363300000000016,'2026-10-28 16:45:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-016','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_016','h_test_blacklist_016','[{"blacklistId":2115361705314803714,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115361705314803714,"identityType":"NATIONALITY_ID","maskedValue":"*****567A"}]'::jsonb),
    (2115363300000000017,'2026-10-28 16:45:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-017','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_017','h_test_blacklist_017','[{"blacklistId":2115362955267727361,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362955267727361,"identityType":"NATIONALITY_ID","maskedValue":"*****267A"}]'::jsonb),
    (2115363300000000018,'2026-10-28 16:46:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-018','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_018','h_test_blacklist_018','[{"blacklistId":2115362911873458177,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362911873458177,"identityType":"NATIONALITY_ID","maskedValue":"*********267A"}]'::jsonb),
    (2115363300000000019,'2026-10-28 16:47:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-019','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_019','h_test_blacklist_019','[{"blacklistId":2115362881385062402,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362881385062402,"identityType":"NATIONALITY_ID","maskedValue":"*********267A"}]'::jsonb),
    (2115363300000000020,'2026-10-28 16:46:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-020','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_020','h_test_blacklist_020','[{"blacklistId":2115362844487770113,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362844487770113,"identityType":"NATIONALITY_ID","maskedValue":"*****567A"}]'::jsonb);

INSERT INTO public.natural_person_blacklist_hit (id, create_time, source_system, request_id, scene, source_type, account_id, cardholder_id, matched_details)
VALUES
    (2115363300000000021,'2026-10-28 16:45:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-021','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_021','h_test_blacklist_021','[{"blacklistId":2115362809456943105,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362809456943105,"identityType":"NATIONALITY_ID","maskedValue":"*******567A"}]'::jsonb),
    (2115363300000000022,'2026-10-28 16:45:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-022','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_022','h_test_blacklist_022','[{"blacklistId":2115362751483273217,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362751483273217,"identityType":"NATIONALITY_ID","maskedValue":"*****567A"}]'::jsonb),
    (2115363300000000023,'2026-10-28 16:46:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-023','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_023','h_test_blacklist_023','[{"blacklistId":2115362704834224130,"identityType":"EMAIL","maskedValue":"a***e@example.com"}]'::jsonb),
    (2115363300000000024,'2026-10-28 16:47:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-024','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_024','h_test_blacklist_024','[{"blacklistId":2115361705314803714,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115361705314803714,"identityType":"NATIONALITY_ID","maskedValue":"*****567A"}]'::jsonb),
    (2115363300000000025,'2026-10-28 16:47:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-025','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_025','h_test_blacklist_025','[{"blacklistId":2115362955267727361,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362955267727361,"identityType":"NATIONALITY_ID","maskedValue":"*****267A"}]'::jsonb),
    (2115363300000000026,'2026-10-28 16:48:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-026','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_026','h_test_blacklist_026','[{"blacklistId":2115362911873458177,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362911873458177,"identityType":"NATIONALITY_ID","maskedValue":"*********267A"}]'::jsonb),
    (2115363300000000027,'2026-10-28 16:49:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-027','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_027','h_test_blacklist_027','[{"blacklistId":2115362881385062402,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362881385062402,"identityType":"NATIONALITY_ID","maskedValue":"*********267A"}]'::jsonb),
    (2115363300000000028,'2026-10-28 16:48:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-028','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_028','h_test_blacklist_028','[{"blacklistId":2115362844487770113,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362844487770113,"identityType":"NATIONALITY_ID","maskedValue":"*****567A"}]'::jsonb),
    (2115363300000000029,'2026-10-28 16:47:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-029','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_029','h_test_blacklist_029','[{"blacklistId":2115362809456943105,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362809456943105,"identityType":"NATIONALITY_ID","maskedValue":"*******567A"}]'::jsonb),
    (2115363300000000030,'2026-10-28 16:47:00+08','QBIT_ASSETS_SQL_SEED','seed-natural-person-blacklist-hit-030','KYC_SUMSUB_PRECHECK','SUMSUB','acc_test_blacklist_030','h_test_blacklist_030','[{"blacklistId":2115362751483273217,"identityType":"EMAIL","maskedValue":"a***e@example.com"},{"blacklistId":2115362751483273217,"identityType":"NATIONALITY_ID","maskedValue":"*****567A"}]'::jsonb);

