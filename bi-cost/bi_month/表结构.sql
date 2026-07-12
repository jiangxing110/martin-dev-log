CREATE TABLE "public"."quantum_card_transaction_extend" (
  "id" int8 NOT NULL DEFAULT 0,
  "account_id" uuid,
  "card_id" uuid,
  "card_transaction_id" uuid,
  "source_id" varchar COLLATE "pg_catalog"."default",
  "transaction_id" uuid,
  "related_transaction_id" uuid,
  "related_card_transaction_id" uuid,
  "user_id" uuid,
  "transaction_display_id" varchar COLLATE "pg_catalog"."default",
  "account_display_id" varchar COLLATE "pg_catalog"."default",
  "account_verified_name" varchar COLLATE "pg_catalog"."default",
  "transaction_currency" varchar COLLATE "pg_catalog"."default",
  "transaction_amount" numeric,
  "auth_amount" numeric,
  "usd_amount" numeric NOT NULL DEFAULT 0,
  "mcc" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "city" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "country" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "state" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "merchant_name" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "mid" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "zip_code" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "type" varchar COLLATE "pg_catalog"."default",
  "level_two_label" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "payment_label" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "platform_label" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "third_party_fee" numeric NOT NULL DEFAULT 0,
  "mark_up_fee" numeric NOT NULL DEFAULT 0,
  "rate" numeric NOT NULL DEFAULT 0,
  "other_fee" jsonb,
  "card_type" varchar COLLATE "pg_catalog"."default",
  "bin" varchar COLLATE "pg_catalog"."default",
  "last_four" varchar COLLATE "pg_catalog"."default",
  "channel_provision" varchar COLLATE "pg_catalog"."default",
  "business_code_list" jsonb NOT NULL DEFAULT '[]'::jsonb,
  "remarks" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "create_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "update_time" timestamptz(6) DEFAULT CURRENT_TIMESTAMP,
  "delete_time" timestamptz(6),
  "version" int4 DEFAULT 1,
  "card_token" varchar COLLATE "pg_catalog"."default",
  "original_rate" numeric NOT NULL DEFAULT 0,
  "fail_code_type_id" int8,
  "detail" varchar COLLATE "pg_catalog"."default",
  "fee" numeric,
  "transaction_time" timestamptz(6),
  "original_transaction_time" timestamptz(6),
  "completion_time" timestamptz(6),
  "original_completion_time" timestamptz(6),
  "status" varchar COLLATE "pg_catalog"."default",
  "risk_type" varchar(255) COLLATE "pg_catalog"."default",
  "transaction_scope" int4,
  CONSTRAINT "quantum_card_transaction_extend_copy1_pkey" PRIMARY KEY ("id")
)
;

ALTER TABLE "public"."quantum_card_transaction_extend" 
  OWNER TO "qbit_admin";

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."account_id" IS '业务表id';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."card_id" IS '卡id';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."card_transaction_id" IS '原始交易id';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."source_id" IS '原始渠道交易id';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."transaction_id" IS '动钱表的id';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."related_transaction_id" IS '关联交易id';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."related_card_transaction_id" IS '关联qbit card transaction id';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."user_id" IS '关联卡的创建人';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."transaction_display_id" IS '交易表的displayId';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."account_display_id" IS '账户displayId';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."account_verified_name" IS '账户displayId';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."transaction_currency" IS '币种';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."transaction_amount" IS '交易金额';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."auth_amount" IS 'auth金额';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."usd_amount" IS '交易金额';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."mcc" IS 'mcc code';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."city" IS '城市';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."country" IS '国家';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."state" IS '省';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."merchant_name" IS '商户名';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."mid" IS '商户id';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."zip_code" IS '邮编';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."type" IS '交易类型';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."level_two_label" IS '二级标签';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."payment_label" IS '付款标签';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."platform_label" IS '消费平台标签';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."third_party_fee" IS '三方 手续费 usd';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."mark_up_fee" IS '三方 手续费 usd';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."rate" IS '汇率';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."other_fee" IS '其他附加费';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."card_type" IS '卡类型';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."bin" IS '卡bin';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."last_four" IS '后四位';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."channel_provision" IS '渠道';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."business_code_list" IS '业务码';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."remarks" IS '备注';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."create_time" IS '创建时间';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."update_time" IS '更新时间';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."delete_time" IS '删除时间';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."version" IS '版本';

COMMENT ON COLUMN "public"."quantum_card_transaction_extend"."card_token" IS '渠道的card id';



CREATE TABLE "public"."qbitCard" (
  "id" uuid NOT NULL,
  "remarks" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "createTime" timestamptz(6) NOT NULL DEFAULT now(),
  "updateTime" timestamptz(6) NOT NULL DEFAULT now(),
  "deleteTime" timestamptz(6),
  "version" int4 NOT NULL,
  "accountId" uuid NOT NULL,
  "userName" varchar COLLATE "pg_catalog"."default",
  "firstName" varchar COLLATE "pg_catalog"."default",
  "lastName" varchar COLLATE "pg_catalog"."default",
  "currency" varchar(30) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'USD'::character varying,
  "status" varchar(30) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'Active'::character varying,
  "qbitCardNo" varchar COLLATE "pg_catalog"."default",
  "qbitCardNoLastFour" varchar COLLATE "pg_catalog"."default",
  "provider" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "type" varchar COLLATE "pg_catalog"."default",
  "expiryDate" timestamp(6),
  "cvv" varchar COLLATE "pg_catalog"."default",
  "useType" varchar COLLATE "pg_catalog"."default",
  "token" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "label" varchar COLLATE "pg_catalog"."default" DEFAULT '默认'::character varying,
  "cardAddress" json,
  "userDeleteTime" date,
  "isMasterCard" bool NOT NULL DEFAULT false,
  "cardholderInfo" json,
  "groupId" uuid,
  "userId" uuid,
  "balanceId" uuid,
  "apiBalance" float8 DEFAULT '0'::double precision,
  "statusLog" varchar COLLATE "pg_catalog"."default",
  "lifeTimeAmountLimit" float8,
  "frozenType" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'Self'::character varying,
  "previousStatus" varchar(30) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'Active'::character varying,
  "qbitCardUsageType" varchar(30) COLLATE "pg_catalog"."default",
  "deleteCardTime" timestamptz(6),
  "transactionLimitsType" varchar COLLATE "pg_catalog"."default" DEFAULT 'NA'::character varying,
  "createCardBatchNo" uuid,
  "frozenCardTime" timestamptz(6),
  "email" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "qbitCardCustomerId" uuid,
  "firstSix" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "cardBelong" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'Common'::character varying,
  "physicalCardStatus" varchar(30) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'Na'::character varying,
  "cardMode" varchar(30) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'VirtualCard'::character varying,
  "id_" int8,
  "uniqueKey" varchar COLLATE "pg_catalog"."default",
  "noUploadReimburse" bool DEFAULT false,
  "sourceType" varchar COLLATE "pg_catalog"."default",
  "cardholderId" varchar COLLATE "pg_catalog"."default",
  CONSTRAINT "PK_fa15b3933b94ba2ef610aa85c31" PRIMARY KEY ("id")
)
;

ALTER TABLE "public"."qbitCard" 
  OWNER TO "qbit_admin";

CREATE INDEX "IDX_cardId" ON "public"."qbitCard" USING btree (
  "id" "pg_catalog"."uuid_ops" ASC NULLS LAST
);

CREATE INDEX "idx_qc_account_cardno" ON "public"."qbitCard" USING btree (
  "accountId" "pg_catalog"."uuid_ops" ASC NULLS LAST,
  "qbitCardNoLastFour" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "deleteTime" "pg_catalog"."timestamptz_ops" ASC NULLS LAST
);

CREATE INDEX "qbitCard_accountId_userName_idx" ON "public"."qbitCard" USING btree (
  "accountId" "pg_catalog"."uuid_ops" ASC NULLS LAST,
  "userName" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

COMMENT ON COLUMN "public"."qbitCard"."remarks" IS '备注';

COMMENT ON COLUMN "public"."qbitCard"."accountId" IS '卡的拥有者id';

COMMENT ON COLUMN "public"."qbitCard"."userName" IS '卡的用户名称';

COMMENT ON COLUMN "public"."qbitCard"."firstName" IS '用户的名';

COMMENT ON COLUMN "public"."qbitCard"."lastName" IS '用户的姓';

COMMENT ON COLUMN "public"."qbitCard"."currency" IS '币种';

COMMENT ON COLUMN "public"."qbitCard"."status" IS '状态';

COMMENT ON COLUMN "public"."qbitCard"."qbitCardNo" IS '量子卡号';

COMMENT ON COLUMN "public"."qbitCard"."qbitCardNoLastFour" IS '量子卡号后四位';

COMMENT ON COLUMN "public"."qbitCard"."provider" IS '不同提供者的卡 pennyCard,paycertifyCard,wexCard';

COMMENT ON COLUMN "public"."qbitCard"."type" IS '类型：VISA, Master, Amex';

COMMENT ON COLUMN "public"."qbitCard"."expiryDate" IS '过期日期';

COMMENT ON COLUMN "public"."qbitCard"."cvv" IS 'cvv';

COMMENT ON COLUMN "public"."qbitCard"."useType" IS '使用类别';

COMMENT ON COLUMN "public"."qbitCard"."token" IS '卡在三方的唯一id';

COMMENT ON COLUMN "public"."qbitCard"."label" IS '标签，便于用户自己区分和筛选';

COMMENT ON COLUMN "public"."qbitCard"."cardAddress" IS '卡自身的验证地址';

COMMENT ON COLUMN "public"."qbitCard"."userDeleteTime" IS '用户的删除时间';

COMMENT ON COLUMN "public"."qbitCard"."isMasterCard" IS 'nium那边需要一个字段，标识是否为主卡';

COMMENT ON COLUMN "public"."qbitCard"."cardholderInfo" IS '持卡人信息';

COMMENT ON COLUMN "public"."qbitCard"."groupId" IS '卡分组Id';

COMMENT ON COLUMN "public"."qbitCard"."userId" IS '创建人Id';

COMMENT ON COLUMN "public"."qbitCard"."lifeTimeAmountLimit" IS '卡的消费限额';

COMMENT ON COLUMN "public"."qbitCard"."frozenType" IS '冻结类型 默认自己冻结';

COMMENT ON COLUMN "public"."qbitCard"."previousStatus" IS '冻结之前状态';

COMMENT ON COLUMN "public"."qbitCard"."qbitCardUsageType" IS '不同功能的卡：储值卡PrepaidCard, 额度卡BudgetCard';

COMMENT ON COLUMN "public"."qbitCard"."transactionLimitsType" IS '卡的消费限额类型';

COMMENT ON COLUMN "public"."qbitCard"."createCardBatchNo" IS '开卡批次号';

COMMENT ON COLUMN "public"."qbitCard"."email" IS '接收验证码邮箱';

COMMENT ON COLUMN "public"."qbitCard"."qbitCardCustomerId" IS '开户id';

COMMENT ON COLUMN "public"."qbitCard"."firstSix" IS '前6位';

COMMENT ON COLUMN "public"."qbitCard"."cardBelong" IS '卡归属';

COMMENT ON COLUMN "public"."qbitCard"."physicalCardStatus" IS '状态';

COMMENT ON COLUMN "public"."qbitCard"."cardMode" IS '虚拟卡/实体卡';

COMMENT ON COLUMN "public"."qbitCard"."uniqueKey" IS '幂等校验的key';


CREATE TABLE "public"."qbitCardSettlement" (
  "id" uuid NOT NULL,
  "remarks" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "createTime" timestamptz(6) NOT NULL DEFAULT now(),
  "updateTime" timestamptz(6) NOT NULL DEFAULT now(),
  "deleteTime" timestamptz(6),
  "version" int4 NOT NULL,
  "cardHashId" varchar COLLATE "pg_catalog"."default",
  "transactionId" varchar COLLATE "pg_catalog"."default",
  "referenceNumber" varchar COLLATE "pg_catalog"."default",
  "recordType" varchar COLLATE "pg_catalog"."default",
  "effectiveDate" varchar COLLATE "pg_catalog"."default",
  "batchDate" varchar COLLATE "pg_catalog"."default",
  "transactionType" varchar COLLATE "pg_catalog"."default",
  "transactionCode" varchar COLLATE "pg_catalog"."default",
  "billingAmount" float8 NOT NULL DEFAULT '0'::double precision,
  "billingCurrencyCode" varchar COLLATE "pg_catalog"."default",
  "transactionAmount" float8 NOT NULL DEFAULT '0'::double precision,
  "transactionCurrencyCode" varchar COLLATE "pg_catalog"."default",
  "authorizationCode" varchar COLLATE "pg_catalog"."default",
  "description" varchar COLLATE "pg_catalog"."default",
  "cardAcceptorId" varchar COLLATE "pg_catalog"."default",
  "interchangeReference" varchar COLLATE "pg_catalog"."default",
  "visaTransactionId" varchar COLLATE "pg_catalog"."default",
  "tokenRequestorId" varchar COLLATE "pg_catalog"."default",
  "tokenNumber" varchar COLLATE "pg_catalog"."default",
  "billingAmountRaw" varchar COLLATE "pg_catalog"."default",
  "transactionAmountRaw" varchar COLLATE "pg_catalog"."default",
  "rawData" json,
  "settlementDay" varchar COLLATE "pg_catalog"."default",
  "hash" varchar COLLATE "pg_catalog"."default",
  "provider" varchar COLLATE "pg_catalog"."default",
  "settleCompleted" bool NOT NULL DEFAULT false,
  "qbitCardTransactionId" varchar COLLATE "pg_catalog"."default",
  "compareTime" timestamptz(6),
  "id_" int8,
  "statusMessage" varchar(255) COLLATE "pg_catalog"."default",
  "country" varchar(255) COLLATE "pg_catalog"."default",
  "mid" varchar(40) COLLATE "pg_catalog"."default",
  "merchantCountry" varchar(255) COLLATE "pg_catalog"."default",
  "channel" varchar(255) COLLATE "pg_catalog"."default",
  "wallet" varchar(40) COLLATE "pg_catalog"."default",
  "mcc" varchar COLLATE "pg_catalog"."default",
  CONSTRAINT "PK_738db04fa796c69cfc7997a2d90" PRIMARY KEY ("id")
)
;

ALTER TABLE "public"."qbitCardSettlement" 
  OWNER TO "qbit_admin";

COMMENT ON COLUMN "public"."qbitCardSettlement"."remarks" IS '备注';

COMMENT ON COLUMN "public"."qbitCardSettlement"."transactionId" IS '三方交易ID';

COMMENT ON COLUMN "public"."qbitCardSettlement"."rawData" IS '详情';

COMMENT ON COLUMN "public"."qbitCardSettlement"."settlementDay" IS '清算日期';

COMMENT ON COLUMN "public"."qbitCardSettlement"."hash" IS 'rawData(三方数据) string后的hash值';

COMMENT ON COLUMN "public"."qbitCardSettlement"."provider" IS '卡的提供者';

COMMENT ON COLUMN "public"."qbitCardSettlement"."settleCompleted" IS '是否已经清算完成';

COMMENT ON COLUMN "public"."qbitCardSettlement"."qbitCardTransactionId" IS '我方交易ID';

COMMENT ON COLUMN "public"."qbitCardSettlement"."compareTime" IS '对账日期';

COMMENT ON COLUMN "public"."qbitCardSettlement"."id_" IS '数字id';


CREATE TABLE "dim"."dim_account" (
  "id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "verified_name" varchar COLLATE "pg_catalog"."default",
  "verified_name_en" varchar COLLATE "pg_catalog"."default",
  "display_id" varchar(255) COLLATE "pg_catalog"."default",
  "account_type" varchar(30) COLLATE "pg_catalog"."default" NOT NULL,
  "type" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "status" varchar(30) COLLATE "pg_catalog"."default" NOT NULL,
  "country" varchar COLLATE "pg_catalog"."default",
  "kyc_status" varchar(30) COLLATE "pg_catalog"."default",
  "kyb_status" varchar(30) COLLATE "pg_catalog"."default",
  "parent_account_id" varchar(36) COLLATE "pg_catalog"."default",
  "tenant_id" int8,
  "is_valid" bool DEFAULT true,
  "create_time" timestamptz(6),
  "update_time" timestamptz(6),
  "system_type" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  CONSTRAINT "dim_account_pkey" PRIMARY KEY ("id")
)
;

ALTER TABLE "dim"."dim_account" 
  OWNER TO "flink_cdc_user";

COMMENT ON TABLE "dim"."dim_account" IS '公共主数据：企业/商户/API账户';



CREATE TABLE "public"."api_account_relation" (
  "id" int8 NOT NULL,
  "create_time" timestamptz(6) NOT NULL DEFAULT now(),
  "update_time" timestamptz(6) NOT NULL DEFAULT now(),
  "delete_time" timestamptz(6),
  "version" int4 NOT NULL DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "account_id" uuid NOT NULL,
  "parent_account_id" uuid NOT NULL,
  "root_id" uuid NOT NULL,
  "relation_type" varchar(20) COLLATE "pg_catalog"."default" DEFAULT 'api'::character varying,
  CONSTRAINT "api_account_relation_pkey" PRIMARY KEY ("id")
)
;

ALTER TABLE "public"."api_account_relation" 
  OWNER TO "qbit_admin";

CREATE INDEX "idx_api_account_relation_account_id" ON "public"."api_account_relation" USING btree (
  "account_id" "pg_catalog"."uuid_ops" ASC NULLS LAST
);

CREATE INDEX "idx_api_account_relation_account_root" ON "public"."api_account_relation" USING btree (
  "account_id" "pg_catalog"."uuid_ops" ASC NULLS LAST,
  "root_id" "pg_catalog"."uuid_ops" ASC NULLS LAST
);

CREATE INDEX "idx_api_account_relation_root_id" ON "public"."api_account_relation" USING btree (
  "root_id" "pg_catalog"."uuid_ops" ASC NULLS LAST
);


CREATE TABLE "dim"."dim_sale_account_relation_p" (
  "id" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "relation_account_id" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "operation_manager_id" varchar(64) COLLATE "pg_catalog"."default",
  "relation_start_time" timestamp(6) NOT NULL,
  "relation_end_time" timestamp(6),
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dim_sale_account_relation_pkey" PRIMARY KEY ("id", "relation_start_time")
)
PARTITION BY RANGE (
  "relation_start_time" "pg_catalog"."timestamp_ops"
)
;

ALTER TABLE "dim"."dim_sale_account_relation_p" 
  OWNER TO "flink_cdc_user";

CREATE INDEX "idx_dim_sale_relation_account_time" ON "dim"."dim_sale_account_relation_p" USING btree (
  "relation_account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "relation_start_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST,
  "relation_end_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dim_sale_relation_sale_am" ON "dim"."dim_sale_account_relation_p" USING btree (
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

ALTER TABLE "dim"."dim_sale_account_relation_p" ATTACH PARTITION "dim"."dim_sale_account_relation_2021" FOR VALUES FROM (
'2021-01-01 00:00:00'
) TO (
'2022-01-01 00:00:00'
)
;

ALTER TABLE "dim"."dim_sale_account_relation_p" ATTACH PARTITION "dim"."dim_sale_account_relation_2022" FOR VALUES FROM (
'2022-01-01 00:00:00'
) TO (
'2023-01-01 00:00:00'
)
;

ALTER TABLE "dim"."dim_sale_account_relation_p" ATTACH PARTITION "dim"."dim_sale_account_relation_2023" FOR VALUES FROM (
'2023-01-01 00:00:00'
) TO (
'2024-01-01 00:00:00'
)
;

ALTER TABLE "dim"."dim_sale_account_relation_p" ATTACH PARTITION "dim"."dim_sale_account_relation_2024" FOR VALUES FROM (
'2024-01-01 00:00:00'
) TO (
'2025-01-01 00:00:00'
)
;

ALTER TABLE "dim"."dim_sale_account_relation_p" ATTACH PARTITION "dim"."dim_sale_account_relation_2025" FOR VALUES FROM (
'2025-01-01 00:00:00'
) TO (
'2026-01-01 00:00:00'
)
;

ALTER TABLE "dim"."dim_sale_account_relation_p" ATTACH PARTITION "dim"."dim_sale_account_relation_2026" FOR VALUES FROM (
'2026-01-01 00:00:00'
) TO (
'2027-01-01 00:00:00'
)
;

ALTER TABLE "dim"."dim_sale_account_relation_p" ATTACH PARTITION "dim"."dim_sale_account_relation_2027" FOR VALUES FROM (
'2027-01-01 00:00:00'
) TO (
'2028-01-01 00:00:00'
)
;

COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."id" IS '原 salesAccountRelation.id';

COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."relation_account_id" IS '销售关系账户ID，对应 salesAccountRelation.accountId';

COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."sale_id" IS '销售ID，对应 salesAccountRelation.salesId';

COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."am_id" IS 'AM ID，对应 salesAccountRelation.amId';

COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."operation_manager_id" IS '运营管理人ID，对应 salesAccountRelation.operationManagerId';

COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."relation_start_time" IS '销售关系生效时间，对应 salesAccountRelation.createTime';

COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."relation_end_time" IS '销售关系结束时间，对应 salesAccountRelation.deleteTime';

COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."version" IS '乐观锁版本';

COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."remarks" IS '备注';

COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."create_time" IS '记录创建时间';

COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."update_time" IS '记录更新时间';

COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."delete_time" IS '逻辑删除时间';

COMMENT ON TABLE "dim"."dim_sale_account_relation_p" IS '销售关系时间线维表，不展开子户';



CREATE TABLE "ods"."ods_bi_month_tag" (
  "id" int8 NOT NULL,
  "create_time" timestamptz(6) NOT NULL,
  "update_time" timestamptz(6) NOT NULL,
  "delete_time" timestamptz(6),
  "version" int4 NOT NULL DEFAULT 1,
  "tag" varchar(255) COLLATE "pg_catalog"."default",
  "statistics_time" timestamptz(6),
  "amount" numeric DEFAULT 0,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "detail" varchar(255) COLLATE "pg_catalog"."default",
  "account_type" varchar(255) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'fullCustomer'::character varying,
  "provider" varchar(255) COLLATE "pg_catalog"."default",
  "product_line" varchar(255) COLLATE "pg_catalog"."default",
  CONSTRAINT "ods_bi_month_tag_pkey" PRIMARY KEY ("id")
)
;

ALTER TABLE "ods"."ods_bi_month_tag" 
  OWNER TO "qbit_admin";

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."id" IS '主键';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."create_time" IS '创建时间';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."update_time" IS '数据更新时间';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."delete_time" IS '删除时间';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."version" IS '乐观锁';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."tag" IS '记录标签';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."statistics_time" IS '统计月份';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."amount" IS '金额';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."detail" IS '统计月份';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."account_type" IS '账号类型';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."provider" IS '渠道';

COMMENT ON COLUMN "ods"."ods_bi_month_tag"."product_line" IS '产品线';

COMMENT ON TABLE "ods"."ods_bi_month_tag" IS 'PG业务表bi_month_tag同步ODS层表';