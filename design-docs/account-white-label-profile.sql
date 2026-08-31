-- 白标客户配置只读投影表
-- 主数据由 white-label-server 维护，qbit-assets 仅接收同步并供 Admin 展示
-- 作者：martinJiang
-- 日期：2026-08-31

CREATE TABLE account_white_label_profile
(
    id              bigint                  NOT NULL PRIMARY KEY,
    account_id      varchar(64)             NOT NULL,
    admin_domain    varchar(255),
    app_domain      varchar(255),
    brand_name      varchar(255),
    login_email     varchar(320),
    brand_logo      text,
    favicon         text,
    source          varchar(64)             NOT NULL DEFAULT 'WHITE_LABEL',
    source_version  bigint,
    last_sync_time  timestamp,
    sync_status     varchar(32)             NOT NULL DEFAULT 'SUCCESS',
    last_sync_error text,
    remarks         varchar(500),
    create_time     timestamp               NOT NULL DEFAULT now(),
    update_time     timestamp               NOT NULL DEFAULT now(),
    delete_time     timestamp,
    version         integer                 NOT NULL DEFAULT 0
);

COMMENT ON TABLE account_white_label_profile IS '白标客户配置只读投影表';
COMMENT ON COLUMN account_white_label_profile.id IS '主键ID';
COMMENT ON COLUMN account_white_label_profile.account_id IS 'qbit-assets账户ID';
COMMENT ON COLUMN account_white_label_profile.admin_domain IS 'Admin域名';
COMMENT ON COLUMN account_white_label_profile.app_domain IS 'C端域名';
COMMENT ON COLUMN account_white_label_profile.brand_name IS '品牌名称';
COMMENT ON COLUMN account_white_label_profile.login_email IS '登录邮箱';
COMMENT ON COLUMN account_white_label_profile.brand_logo IS '品牌Logo地址';
COMMENT ON COLUMN account_white_label_profile.favicon IS 'Favicon地址';
COMMENT ON COLUMN account_white_label_profile.source IS '配置来源';
COMMENT ON COLUMN account_white_label_profile.source_version IS '白标配置版本';
COMMENT ON COLUMN account_white_label_profile.last_sync_time IS '最近一次成功同步时间';
COMMENT ON COLUMN account_white_label_profile.sync_status IS '同步状态：SUCCESS/FAILED';
COMMENT ON COLUMN account_white_label_profile.last_sync_error IS '最近一次同步错误';
COMMENT ON COLUMN account_white_label_profile.remarks IS '备注';
COMMENT ON COLUMN account_white_label_profile.create_time IS '创建时间';
COMMENT ON COLUMN account_white_label_profile.update_time IS '更新时间';
COMMENT ON COLUMN account_white_label_profile.delete_time IS '软删除时间';
COMMENT ON COLUMN account_white_label_profile.version IS '乐观锁版本';

CREATE UNIQUE INDEX uk_account_white_label_profile_account_source
    ON account_white_label_profile (account_id, source)
    WHERE delete_time IS NULL;

CREATE INDEX idx_account_white_label_profile_sync_status
    ON account_white_label_profile (sync_status)
    WHERE delete_time IS NULL;


[Interlace] Offboarding Completion Notice

Dear <%verifiedName%>,

The offboarding process for your account has been completed. Account status are as follows:

- <%Partial offboarding%>: Your <%service%> has been closed. Other services remain available.
- <%Full offboarding%>: Your account has been closed. Login and all related services are no longer available.
All remaining funds have been settled as part of the offboarding process.

Thank you for your prompt attention.

[Interlace template]

因PC渠道所有接口都无法使用，导致卡无法使用，也无法删卡，但是系统又会正常收取相关活跃卡费。
跟leader商量后决定，从2026.10.01开始，不再收取PC卡的活跃卡费。