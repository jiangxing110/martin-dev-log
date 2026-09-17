-- PD-2242 / PD-1999：账户品牌名/DBA明细表
CREATE TABLE IF NOT EXISTS account_brand_name (
    id BIGINT NOT NULL,
    remarks VARCHAR(500),
    account_id VARCHAR(64) NOT NULL,
    brand_name VARCHAR(128) NOT NULL,
    normalized_name VARCHAR(128) NOT NULL,
    source_type VARCHAR(32) NOT NULL,
    source_id VARCHAR(64),
    created_by VARCHAR(64),
    updated_by VARCHAR(64),
    create_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    update_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    delete_time TIMESTAMP NULL,
    version INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT pk_account_brand_name PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_account_brand_name_account_id
    ON account_brand_name (account_id)
    WHERE delete_time IS NULL;

CREATE INDEX IF NOT EXISTS idx_account_brand_name_search
    ON account_brand_name (account_id, normalized_name)
    WHERE delete_time IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uk_account_brand_name
    ON account_brand_name (account_id, normalized_name)
    WHERE delete_time IS NULL;
