CREATE TABLE IF NOT EXISTS public.natural_person_blacklist (
    id bigint PRIMARY KEY NOT NULL,
    remarks varchar(255),
    create_time timestamptz NOT NULL DEFAULT now(),
    update_time timestamptz NOT NULL DEFAULT now(),
    delete_time timestamptz,
    version integer NOT NULL DEFAULT 0,
    status varchar(20) NOT NULL,
    source varchar(20) NOT NULL,
    source_business_type varchar(64),
    source_business_id varchar(128),
    import_batch_no varchar(64),
    created_user_id varchar(64),
    released_user_id varchar(64),
    released_time timestamptz
);

COMMENT ON TABLE public.natural_person_blacklist IS '自然人黑名单生命周期记录';
COMMENT ON COLUMN public.natural_person_blacklist.id IS '名单生命周期 ID';
COMMENT ON COLUMN public.natural_person_blacklist.remarks IS '加黑原因备注';
COMMENT ON COLUMN public.natural_person_blacklist.create_time IS '创建时间';
COMMENT ON COLUMN public.natural_person_blacklist.update_time IS '更新时间';
COMMENT ON COLUMN public.natural_person_blacklist.delete_time IS '软删除时间';
COMMENT ON COLUMN public.natural_person_blacklist.version IS '乐观锁版本号';
COMMENT ON COLUMN public.natural_person_blacklist.status IS '名单状态：ACTIVE 生效，RELEASED 已解除';
COMMENT ON COLUMN public.natural_person_blacklist.source IS '名单来源：MANUAL 人工，IMPORT 导入，DISPOSITION 处置联动';
COMMENT ON COLUMN public.natural_person_blacklist.source_business_type IS '来源业务类型';
COMMENT ON COLUMN public.natural_person_blacklist.source_business_id IS '来源业务 ID';
COMMENT ON COLUMN public.natural_person_blacklist.import_batch_no IS '导入批次号';
COMMENT ON COLUMN public.natural_person_blacklist.created_user_id IS '加黑操作人 user ID';
COMMENT ON COLUMN public.natural_person_blacklist.released_user_id IS '解除操作人 user ID';
COMMENT ON COLUMN public.natural_person_blacklist.released_time IS '名单解除时间';

CREATE INDEX IF NOT EXISTS idx_natural_person_blacklist_status_source_time
    ON public.natural_person_blacklist (status, source, create_time DESC)
    WHERE delete_time IS NULL;
CREATE INDEX IF NOT EXISTS idx_natural_person_blacklist_import_batch
    ON public.natural_person_blacklist (import_batch_no)
    WHERE import_batch_no IS NOT NULL AND delete_time IS NULL;

CREATE TABLE IF NOT EXISTS public.natural_person_blacklist_identity (
    id bigint PRIMARY KEY NOT NULL,
    remarks varchar(255),
    create_time timestamptz NOT NULL DEFAULT now(),
    update_time timestamptz NOT NULL DEFAULT now(),
    delete_time timestamptz,
    version integer NOT NULL DEFAULT 0,
    blacklist_id bigint NOT NULL,
    identity_type varchar(32) NOT NULL,
    country_code varchar(2),
    id_type varchar(64),
    identity_value text NOT NULL,
    normalized_value text NOT NULL,
    masked_value varchar(512) NOT NULL,
    active boolean NOT NULL DEFAULT true,
    CONSTRAINT ck_natural_person_blacklist_identity_dimension CHECK (
        (identity_type = 'EMAIL' AND country_code IS NULL AND id_type IS NULL)
        OR (identity_type = 'NATIONALITY_ID' AND country_code IS NOT NULL AND id_type IS NOT NULL)
    )
);

COMMENT ON TABLE public.natural_person_blacklist_identity IS '自然人黑名单身份匹配维度';
COMMENT ON COLUMN public.natural_person_blacklist_identity.id IS '身份维度记录 ID';
COMMENT ON COLUMN public.natural_person_blacklist_identity.remarks IS '身份维度备注';
COMMENT ON COLUMN public.natural_person_blacklist_identity.create_time IS '创建时间';
COMMENT ON COLUMN public.natural_person_blacklist_identity.update_time IS '更新时间';
COMMENT ON COLUMN public.natural_person_blacklist_identity.delete_time IS '软删除时间';
COMMENT ON COLUMN public.natural_person_blacklist_identity.version IS '乐观锁版本号';
COMMENT ON COLUMN public.natural_person_blacklist_identity.blacklist_id IS '所属黑名单 ID';
COMMENT ON COLUMN public.natural_person_blacklist_identity.identity_type IS '身份维度类型：EMAIL 或 NATIONALITY_ID';
COMMENT ON COLUMN public.natural_person_blacklist_identity.country_code IS '国籍 ISO 3166-1 alpha-2 代码';
COMMENT ON COLUMN public.natural_person_blacklist_identity.id_type IS '系统规范证件类型代码';
COMMENT ON COLUMN public.natural_person_blacklist_identity.identity_value IS '身份原文，数据库明文保存';
COMMENT ON COLUMN public.natural_person_blacklist_identity.normalized_value IS '规范化身份值，用于精确匹配';
COMMENT ON COLUMN public.natural_person_blacklist_identity.masked_value IS '脱敏展示值';
COMMENT ON COLUMN public.natural_person_blacklist_identity.active IS '是否参与活动名单匹配';

CREATE UNIQUE INDEX IF NOT EXISTS uk_natural_person_blacklist_email_active
    ON public.natural_person_blacklist_identity (normalized_value)
    WHERE identity_type = 'EMAIL' AND active = true AND delete_time IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uk_natural_person_blacklist_document_active
    ON public.natural_person_blacklist_identity (country_code, id_type, normalized_value)
    WHERE identity_type = 'NATIONALITY_ID' AND active = true AND delete_time IS NULL;
CREATE INDEX IF NOT EXISTS idx_natural_person_blacklist_identity_parent
    ON public.natural_person_blacklist_identity (blacklist_id)
    WHERE delete_time IS NULL;
CREATE INDEX IF NOT EXISTS idx_natural_person_blacklist_identity_match
    ON public.natural_person_blacklist_identity (identity_type, normalized_value)
    WHERE active = true AND delete_time IS NULL;

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

-- 清除旧版本命中表中已废弃的状态码、商户 ID 和业务发生时间列；命中时间统一使用 create_time。
ALTER TABLE IF EXISTS public.natural_person_blacklist_hit
    DROP COLUMN IF EXISTS result_code,
    DROP COLUMN IF EXISTS merchant_id,
    DROP COLUMN IF EXISTS occurred_at;

-- 创建持卡人记录前也可能写入命中事件，因此来源请求 ID 允许为空。
ALTER TABLE IF EXISTS public.natural_person_blacklist_hit
    ALTER COLUMN request_id DROP NOT NULL;
