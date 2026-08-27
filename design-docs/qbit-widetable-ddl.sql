--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-25 00:00:00
-- Description:    量子卡交易大宽表 DDL
--
-- 设计约束：
--   1. 一行对应一条 public.qbit_card_transaction 交易记录。
--   2. 不依赖 quantum_card_transaction_extend。
--   3. create_time 直接来源于 qbit_card_transaction.createTime，作为分区键。
--   4. 主键为 (id, create_time)，适配分区表唯一键要求。
--   5. settlement 一对多明细不展开到本表。
--   6. 新增字段采用 ADD COLUMN，不直接修改既有字段含义。
--********************************************************************--

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_transaction_p" (
  -- 主表事实字段
  "id"                       varchar(128) NOT NULL,
  "account_id"               uuid,
  "card_id"                  uuid,
  "provider"                 varchar(100),
  "business_type"            varchar(50),
  "status"                   varchar(30),
  "display_status"           varchar(30),
  "currency"                 varchar(30),
  "settle_amount"            numeric(20,4),
  "original_amount"          numeric(20,4),
  "transaction_currency"     varchar(30),
  "transaction_amount"       numeric(20,4),
  "fee"                      numeric(20,4),
  "detail"                   text,
  "source_id"                varchar(255),
  "transaction_time"         timestamptz,
  "complete_time"            timestamptz,
  "transaction_ref_id"       uuid,
  "related_qbit_tx_id"       uuid,
  "payment_label"            varchar(100),
  "platform_label"           varchar(100),
  "second_label"             varchar(100),
  "comments"                 varchar(500),
  "authorization_code"       varchar(100),
  "is_show"                  boolean,
  "released"                 boolean,
  "third_complete_time"      timestamptz,
  "special_source_data"      jsonb,

  -- special_source_data 反规范化字段
  "spc_authorization_time"        timestamptz,
  "spc_authorization_date"        date,
  "spc_thirdparty_settle_amount" numeric(20,4),
  "spc_markup_fee"                numeric(20,4),
  "spc_qbit_card_recharge_type"   varchar(100),
  "spc_transaction_id"            varchar(255),
  "spc_merchant_source_amount"    numeric(20,4),
  "spc_date"                      date,
  "spc_merchant_name"             varchar(255),
  "spc_mid"                       varchar(100),
  "spc_mcc"                       varchar(30),
  "spc_city"                      varchar(100),
  "spc_country"                   varchar(100),
  "spc_state"                     varchar(100),
  "spc_zip_code"                  varchar(30),
  "business_code_list"            jsonb,
  "spc_system_trace_audit_no"     varchar(100),
  "spc_fail_reason"               varchar(500),

  -- 卡维度字段，来源 public."qbitCard"
  "card_no_last_four"         varchar(10),
  "card_provider"             varchar(100),
  "card_type_dim"             varchar(30),
  "label"                     varchar(255),
  "group_id"                  uuid,
  "balance_id"                uuid,
  "first_six"                 varchar(10),
  "card_belong"               varchar(100),
  "physical_card_status"      varchar(30),
  "card_mode"                 varchar(30),
  "card_status"               varchar(30),
  "group_name"                varchar(255),
  "group_status"              varchar(30),

  -- 账户维度字段，country 来源 public."accountExtend"
  "acc_verified_name"         varchar(255),
  "parent_account_id"         uuid,
  "account_type"              varchar(30),
  "acc_country"               varchar(100),
  "referral_code_id"          varchar(100),
  "acc_type"                 varchar(50),
  "acc_display_id"            varchar(15),
  "tenant_id"                 int8,
  "root_account_id"           uuid,

  -- 销售关系字段，来源 dim.dim_sale_account_relation_p
  "sale_id"                   varchar(64),
  "am_id"                     varchar(64),
  "operation_manager_id"      varchar(64),

  -- 审计字段
  "create_time"               timestamptz NOT NULL,
  "update_time"               timestamptz,
  "delete_time"               timestamptz,
  "version"                   int4 DEFAULT 1,

  CONSTRAINT "dwm_quantum_card_transaction_pkey"
    PRIMARY KEY ("id", "create_time")
)
PARTITION BY RANGE ("create_time" "pg_catalog"."timestamptz_ops");

COMMENT ON TABLE "dwm"."dwm_quantum_card_transaction_p"
  IS '量子卡交易分析大宽表；一行对应一条 qbit_card_transaction，不依赖 quantum_card_transaction_extend';

COMMENT ON COLUMN "dwm"."dwm_quantum_card_transaction_p"."id"
  IS '交易主表主键，直接来源 qbit_card_transaction.id';
COMMENT ON COLUMN "dwm"."dwm_quantum_card_transaction_p"."transaction_time"
  IS '交易发生时间，成本、交易量和销售关系分析的业务时间';
COMMENT ON COLUMN "dwm"."dwm_quantum_card_transaction_p"."complete_time"
  IS '我方交易完成时间';
COMMENT ON COLUMN "dwm"."dwm_quantum_card_transaction_p"."third_complete_time"
  IS '三方交易完成时间';
COMMENT ON COLUMN "dwm"."dwm_quantum_card_transaction_p"."transaction_ref_id"
  IS '动钱表关联 ID，用于回滚追踪';
COMMENT ON COLUMN "dwm"."dwm_quantum_card_transaction_p"."related_qbit_tx_id"
  IS '退款来源交易 ID';
COMMENT ON COLUMN "dwm"."dwm_quantum_card_transaction_p"."special_source_data"
  IS '三方源数据 JSON；低频或未稳定字段保留在此';
COMMENT ON COLUMN "dwm"."dwm_quantum_card_transaction_p"."business_code_list"
  IS '业务码列表，直接来源 qbit_card_transaction.specialSourceData.code，兼容数组包含查询';
COMMENT ON COLUMN "dwm"."dwm_quantum_card_transaction_p"."balance_id"
  IS '卡余额关联 ID，用于余额、资金和交易核对';
COMMENT ON COLUMN "dwm"."dwm_quantum_card_transaction_p"."card_status"
  IS '卡当前状态，来源 qbitCard.status';
COMMENT ON COLUMN "dwm"."dwm_quantum_card_transaction_p"."group_name"
  IS '卡组名称，来源 qbitCardGroup.groupName';
COMMENT ON COLUMN "dwm"."dwm_quantum_card_transaction_p"."group_status"
  IS '卡组状态，来源 qbitCardGroup.status';
COMMENT ON COLUMN "dwm"."dwm_quantum_card_transaction_p"."acc_country"
  IS '账户注册国家，来源 accountExtend.country；实际字段名以线上 DDL 为准';
COMMENT ON COLUMN "dwm"."dwm_quantum_card_transaction_p"."operation_manager_id"
  IS '运营管理人 ID，来源 dim_sale_account_relation_p.operation_manager_id';
COMMENT ON COLUMN "dwm"."dwm_quantum_card_transaction_p"."create_time"
  IS '分区键，直接来源 qbit_card_transaction.createTime，不是宽表重建时间';
COMMENT ON COLUMN "dwm"."dwm_quantum_card_transaction_p"."update_time"
  IS '来源 qbit_card_transaction.updateTime，用于增量变更识别';
COMMENT ON COLUMN "dwm"."dwm_quantum_card_transaction_p"."delete_time"
  IS '来源 qbit_card_transaction.deleteTime，软删除标记';

-- 常用查询索引
CREATE INDEX IF NOT EXISTS "idx_dwm_qct_time_account"
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree (
    "transaction_time", "account_id"
  );

CREATE INDEX IF NOT EXISTS "idx_dwm_qct_account_time"
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree (
    "account_id", "transaction_time"
  );

CREATE INDEX IF NOT EXISTS "idx_dwm_qct_sale_time"
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree (
    "sale_id", "am_id", "transaction_time"
  );

CREATE INDEX IF NOT EXISTS "idx_dwm_qct_operation_manager_time"
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree (
    "operation_manager_id", "transaction_time"
  );

CREATE INDEX IF NOT EXISTS "idx_dwm_qct_card_time"
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree (
    "card_id", "transaction_time"
  );

CREATE INDEX IF NOT EXISTS "idx_dwm_qct_group_time"
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree (
    "group_id", "transaction_time"
  );

CREATE INDEX IF NOT EXISTS "idx_dwm_qct_provider_business_status"
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree (
    "provider", "business_type", "status", "transaction_time"
  );

CREATE INDEX IF NOT EXISTS "idx_dwm_qct_card_status_time"
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree (
    "card_status", "transaction_time"
  );

CREATE INDEX IF NOT EXISTS "idx_dwm_qct_source_id"
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree ("source_id");

CREATE INDEX IF NOT EXISTS "idx_dwm_qct_update_time"
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree ("update_time");

CREATE INDEX IF NOT EXISTS "idx_dwm_qct_business_code_list_gin"
  ON "dwm"."dwm_quantum_card_transaction_p" USING gin ("business_code_list");

-- 月分区：覆盖 2020-01 至 2029-12。
CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2020_01"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2020-01-01 00:00:00+08') TO ('2020-02-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2020_02"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2020-02-01 00:00:00+08') TO ('2020-03-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2020_03"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2020-03-01 00:00:00+08') TO ('2020-04-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2020_04"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2020-04-01 00:00:00+08') TO ('2020-05-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2020_05"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2020-05-01 00:00:00+08') TO ('2020-06-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2020_06"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2020-06-01 00:00:00+08') TO ('2020-07-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2020_07"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2020-07-01 00:00:00+08') TO ('2020-08-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2020_08"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2020-08-01 00:00:00+08') TO ('2020-09-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2020_09"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2020-09-01 00:00:00+08') TO ('2020-10-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2020_10"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2020-10-01 00:00:00+08') TO ('2020-11-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2020_11"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2020-11-01 00:00:00+08') TO ('2020-12-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2020_12"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2020-12-01 00:00:00+08') TO ('2021-01-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2021_01"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2021-01-01 00:00:00+08') TO ('2021-02-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2021_02"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2021-02-01 00:00:00+08') TO ('2021-03-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2021_03"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2021-03-01 00:00:00+08') TO ('2021-04-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2021_04"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2021-04-01 00:00:00+08') TO ('2021-05-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2021_05"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2021-05-01 00:00:00+08') TO ('2021-06-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2021_06"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2021-06-01 00:00:00+08') TO ('2021-07-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2021_07"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2021-07-01 00:00:00+08') TO ('2021-08-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2021_08"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2021-08-01 00:00:00+08') TO ('2021-09-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2021_09"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2021-09-01 00:00:00+08') TO ('2021-10-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2021_10"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2021-10-01 00:00:00+08') TO ('2021-11-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2021_11"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2021-11-01 00:00:00+08') TO ('2021-12-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2021_12"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2021-12-01 00:00:00+08') TO ('2022-01-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2022_01"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2022-01-01 00:00:00+08') TO ('2022-02-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2022_02"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2022-02-01 00:00:00+08') TO ('2022-03-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2022_03"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2022-03-01 00:00:00+08') TO ('2022-04-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2022_04"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2022-04-01 00:00:00+08') TO ('2022-05-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2022_05"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2022-05-01 00:00:00+08') TO ('2022-06-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2022_06"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2022-06-01 00:00:00+08') TO ('2022-07-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2022_07"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2022-07-01 00:00:00+08') TO ('2022-08-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2022_08"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2022-08-01 00:00:00+08') TO ('2022-09-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2022_09"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2022-09-01 00:00:00+08') TO ('2022-10-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2022_10"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2022-10-01 00:00:00+08') TO ('2022-11-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2022_11"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2022-11-01 00:00:00+08') TO ('2022-12-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2022_12"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2022-12-01 00:00:00+08') TO ('2023-01-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2023_01"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2023-01-01 00:00:00+08') TO ('2023-02-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2023_02"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2023-02-01 00:00:00+08') TO ('2023-03-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2023_03"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2023-03-01 00:00:00+08') TO ('2023-04-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2023_04"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2023-04-01 00:00:00+08') TO ('2023-05-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2023_05"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2023-05-01 00:00:00+08') TO ('2023-06-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2023_06"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2023-06-01 00:00:00+08') TO ('2023-07-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2023_07"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2023-07-01 00:00:00+08') TO ('2023-08-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2023_08"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2023-08-01 00:00:00+08') TO ('2023-09-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2023_09"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2023-09-01 00:00:00+08') TO ('2023-10-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2023_10"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2023-10-01 00:00:00+08') TO ('2023-11-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2023_11"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2023-11-01 00:00:00+08') TO ('2023-12-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2023_12"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2023-12-01 00:00:00+08') TO ('2024-01-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2024_01"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2024-01-01 00:00:00+08') TO ('2024-02-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2024_02"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2024-02-01 00:00:00+08') TO ('2024-03-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2024_03"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2024-03-01 00:00:00+08') TO ('2024-04-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2024_04"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2024-04-01 00:00:00+08') TO ('2024-05-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2024_05"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2024-05-01 00:00:00+08') TO ('2024-06-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2024_06"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2024-06-01 00:00:00+08') TO ('2024-07-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2024_07"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2024-07-01 00:00:00+08') TO ('2024-08-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2024_08"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2024-08-01 00:00:00+08') TO ('2024-09-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2024_09"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2024-09-01 00:00:00+08') TO ('2024-10-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2024_10"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2024-10-01 00:00:00+08') TO ('2024-11-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2024_11"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2024-11-01 00:00:00+08') TO ('2024-12-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2024_12"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2024-12-01 00:00:00+08') TO ('2025-01-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2025_01"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2025-01-01 00:00:00+08') TO ('2025-02-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2025_02"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2025-02-01 00:00:00+08') TO ('2025-03-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2025_03"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2025-03-01 00:00:00+08') TO ('2025-04-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2025_04"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2025-04-01 00:00:00+08') TO ('2025-05-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2025_05"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2025-05-01 00:00:00+08') TO ('2025-06-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2025_06"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2025-06-01 00:00:00+08') TO ('2025-07-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2025_07"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2025-07-01 00:00:00+08') TO ('2025-08-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2025_08"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2025-08-01 00:00:00+08') TO ('2025-09-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2025_09"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2025-09-01 00:00:00+08') TO ('2025-10-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2025_10"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2025-10-01 00:00:00+08') TO ('2025-11-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2025_11"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2025-11-01 00:00:00+08') TO ('2025-12-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2025_12"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2025-12-01 00:00:00+08') TO ('2026-01-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2026_01"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2026-01-01 00:00:00+08') TO ('2026-02-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2026_02"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2026-02-01 00:00:00+08') TO ('2026-03-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2026_03"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2026-03-01 00:00:00+08') TO ('2026-04-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2026_04"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2026-04-01 00:00:00+08') TO ('2026-05-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2026_05"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2026-05-01 00:00:00+08') TO ('2026-06-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2026_06"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2026-06-01 00:00:00+08') TO ('2026-07-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2026_07"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2026-07-01 00:00:00+08') TO ('2026-08-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2026_08"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2026-08-01 00:00:00+08') TO ('2026-09-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2026_09"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2026-09-01 00:00:00+08') TO ('2026-10-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2026_10"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2026-10-01 00:00:00+08') TO ('2026-11-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2026_11"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2026-11-01 00:00:00+08') TO ('2026-12-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2026_12"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2026-12-01 00:00:00+08') TO ('2027-01-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2027_01"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2027-01-01 00:00:00+08') TO ('2027-02-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2027_02"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2027-02-01 00:00:00+08') TO ('2027-03-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2027_03"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2027-03-01 00:00:00+08') TO ('2027-04-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2027_04"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2027-04-01 00:00:00+08') TO ('2027-05-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2027_05"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2027-05-01 00:00:00+08') TO ('2027-06-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2027_06"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2027-06-01 00:00:00+08') TO ('2027-07-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2027_07"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2027-07-01 00:00:00+08') TO ('2027-08-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2027_08"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2027-08-01 00:00:00+08') TO ('2027-09-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2027_09"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2027-09-01 00:00:00+08') TO ('2027-10-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2027_10"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2027-10-01 00:00:00+08') TO ('2027-11-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2027_11"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2027-11-01 00:00:00+08') TO ('2027-12-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2027_12"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2027-12-01 00:00:00+08') TO ('2028-01-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2028_01"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2028-01-01 00:00:00+08') TO ('2028-02-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2028_02"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2028-02-01 00:00:00+08') TO ('2028-03-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2028_03"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2028-03-01 00:00:00+08') TO ('2028-04-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2028_04"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2028-04-01 00:00:00+08') TO ('2028-05-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2028_05"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2028-05-01 00:00:00+08') TO ('2028-06-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2028_06"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2028-06-01 00:00:00+08') TO ('2028-07-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2028_07"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2028-07-01 00:00:00+08') TO ('2028-08-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2028_08"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2028-08-01 00:00:00+08') TO ('2028-09-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2028_09"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2028-09-01 00:00:00+08') TO ('2028-10-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2028_10"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2028-10-01 00:00:00+08') TO ('2028-11-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2028_11"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2028-11-01 00:00:00+08') TO ('2028-12-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2028_12"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2028-12-01 00:00:00+08') TO ('2029-01-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2029_01"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2029-01-01 00:00:00+08') TO ('2029-02-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2029_02"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2029-02-01 00:00:00+08') TO ('2029-03-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2029_03"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2029-03-01 00:00:00+08') TO ('2029-04-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2029_04"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2029-04-01 00:00:00+08') TO ('2029-05-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2029_05"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2029-05-01 00:00:00+08') TO ('2029-06-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2029_06"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2029-06-01 00:00:00+08') TO ('2029-07-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2029_07"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2029-07-01 00:00:00+08') TO ('2029-08-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2029_08"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2029-08-01 00:00:00+08') TO ('2029-09-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2029_09"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2029-09-01 00:00:00+08') TO ('2029-10-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2029_10"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2029-10-01 00:00:00+08') TO ('2029-11-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2029_11"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2029-11-01 00:00:00+08') TO ('2029-12-01 00:00:00+08');

CREATE TABLE IF NOT EXISTS "dwm"."dwm_quantum_card_txn_2029_12"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2029-12-01 00:00:00+08') TO ('2030-01-01 00:00:00+08');
