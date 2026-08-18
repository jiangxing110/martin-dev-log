
--0.ods_sale_am_transaction_2026
CREATE TABLE ods_sale_am_transaction_2026 (
    transaction_id    UUID           PRIMARY KEY,
    sale_id           varchar(50)           ,
    am_id             varchar(50)        ,
    create_time       TIMESTAMPTZ    NOT NULL,
    update_time       TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    delete_time       TIMESTAMPTZ    NULL,
    remarks           TEXT           NULL,
    version           INTEGER        NOT NULL DEFAULT 1
) WITH (OIDS = FALSE);

COMMENT ON TABLE ods_sale_am_transaction_2026 IS '销售交易事实表(按年分表)';
COMMENT ON COLUMN ods_sale_am_transaction_2026.transaction_id IS '交易流水号';
COMMENT ON COLUMN ods_sale_am_transaction_2026.sale_id IS '所属销售人员ID';
COMMENT ON COLUMN ods_sale_am_transaction_2026.am_id IS '所属am人员ID';


--1.dws_qbit_card_wallet_transaction_2026
CREATE TABLE "public"."dws_qbit_card_wallet_transaction_2026" (
  "id" int8 NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "business_type" varchar(50) COLLATE "pg_catalog"."default",
  "status" varchar(50) COLLATE "pg_catalog"."default",
  "origin_amount" numeric(18,2),
  "transaction_count" int4,
  "fee" numeric(18,2),
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1,
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  CONSTRAINT "dws_qbit_card_wallet_transaction_2026_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "public"."dws_qbit_card_wallet_transaction_2026" OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_qbit_card_wallet_transaction_2026"."business_type" IS '交易类型';
COMMENT ON COLUMN "public"."dws_qbit_card_wallet_transaction_2026"."status" IS '状态';
COMMENT ON COLUMN "public"."dws_qbit_card_wallet_transaction_2026"."origin_amount" IS '原始金额';
COMMENT ON COLUMN "public"."dws_qbit_card_wallet_transaction_2026"."transaction_count" IS '交易笔数';
COMMENT ON COLUMN "public"."dws_qbit_card_wallet_transaction_2026"."fee" IS '手续费';
COMMENT ON COLUMN "public"."dws_qbit_card_wallet_transaction_2026"."create_date" IS '统计发生日期';

-- 2.CREATE_TABLE dws_qbit_card_transaction_2026
CREATE TABLE "public"."dws_qbit_card_transaction_2026" (
  "id" bigint NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "business_type" varchar(50) COLLATE "pg_catalog"."default",
  "status" varchar(50) COLLATE "pg_catalog"."default",
  "provider" varchar(50) COLLATE "pg_catalog"."default",
   "bin" varchar(50) COLLATE "pg_catalog"."default",
  "origin_amount" numeric(18, 2),
  "settle_amount" numeric(18, 2),
  "transaction_count" int4,
  "fee" numeric(18, 2),
  "create_date" timestamp(6) NOT NULL,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "version" int4 DEFAULT 1, -- 版本号
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6), -- 逻辑删除时间
  CONSTRAINT "dws_qbit_card_transaction_2026_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "public"."dws_qbit_card_transaction_2026" OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_2026"."business_type" IS '交易类型';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_2026"."status" IS '状态';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_2026"."provider" IS '交易渠道';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_2026"."bin" IS '卡bin';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_2026"."origin_amount" IS '原始金额';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_2026"."settle_amount" IS '结算金额';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_2026"."transaction_count" IS '交易笔数';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_2026"."fee" IS '手续费';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_2026"."create_date" IS '统计发生日期';


--3.创建 dws_qbit_card_transaction_extend_2026 表
CREATE TABLE "public"."dws_qbit_card_transaction_extend_2026" (
  "id" int8 NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "provider" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "bin" varchar(50) COLLATE "pg_catalog"."default",
  "business_type" varchar(50) COLLATE "pg_catalog"."default",
  "status" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "settle_amount" numeric(18,2),
  "transaction_currency" varchar(50) COLLATE "pg_catalog"."default",
  "country" varchar(50) COLLATE "pg_catalog"."default",
  "related_transaction"  bool NOT NULL DEFAULT false, 
  "transaction_count" int4,
  "fx_fee" numeric(18,2),
  "atm_fee" numeric(18,2),
  "apple_pay_fee" numeric(18,2),
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_qbit_card_transaction_extend_2026_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "public"."dws_qbit_card_transaction_extend_2026"  OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_extend_2026"."provider" IS '交易渠道';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_extend_2026"."bin" IS '卡bin';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_extend_2026"."business_type" IS '交易类型';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_extend_2026"."status" IS '交易状态';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_extend_2026"."settle_amount" IS '清算金额';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_extend_2026"."transaction_currency" IS '交易币种';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_extend_2026"."country" IS '交易国家';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_extend_2026"."related_transaction" IS '是否关联订单';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_extend_2026"."transaction_count" IS '交易笔数';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_extend_2026"."fx_fee" IS 'fx_fee';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_extend_2026"."atm_fee" IS 'atm_fee提现';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_extend_2026"."apple_pay_fee" IS 'apple_pay_fee';
COMMENT ON COLUMN "public"."dws_qbit_card_transaction_extend_2026"."create_date" IS '统计发生日期';

-- 4.CREATE_TABLE dws_qbit_card_group_transaction_2026
CREATE TABLE "public"."dws_qbit_card_group_transaction_2026" (
  "id" bigint NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "business_type" varchar(50) COLLATE "pg_catalog"."default",
  "status" varchar(50) COLLATE "pg_catalog"."default",
  "origin_amount" numeric(18, 2),
  "transaction_count" int4,
  "fee" numeric(18, 2),
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6), -- 逻辑删除时间
  CONSTRAINT "dws_qbit_card_group_transaction_2026_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "public"."dws_qbit_card_group_transaction_2026" OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_qbit_card_group_transaction_2026"."business_type" IS '交易类型';
COMMENT ON COLUMN "public"."dws_qbit_card_group_transaction_2026"."status" IS '交易状态';
COMMENT ON COLUMN "public"."dws_qbit_card_group_transaction_2026"."origin_amount" IS '原始交易金额';
COMMENT ON COLUMN "public"."dws_qbit_card_group_transaction_2026"."transaction_count" IS '交易笔数';
COMMENT ON COLUMN "public"."dws_qbit_card_group_transaction_2026"."fee" IS '交易手续费';
COMMENT ON COLUMN "public"."dws_qbit_card_group_transaction_2026"."create_date" IS '统计发生日期';

-- 5.CREATE_TABLE dws_transfer_2026
CREATE TABLE "public"."dws_transfer_2026" (
  "id" bigint NOT NULL, -- 雪花ID
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "business_type_detail" varchar(50) COLLATE "pg_catalog"."default",
  "settlement_currency" varchar(50) COLLATE "pg_catalog"."default",
  "status" varchar(50) COLLATE "pg_catalog"."default",
  "currency" varchar(30) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'USD'::character varying,
  "usd_amount" numeric(18, 2),
  "transaction_count" int4,
  "fee" numeric(18, 2),
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1, -- 版本号
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6), -- 逻辑删除时间
  CONSTRAINT "dws_transfer_2026_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "public"."dws_transfer_2026" OWNER TO "qbit_admin";

COMMENT ON COLUMN "public"."dws_transfer_2026"."business_type_detail" IS '交易类型';
COMMENT ON COLUMN "public"."dws_transfer_2026"."settlement_currency" IS '结算币种';
COMMENT ON COLUMN "public"."dws_transfer_2026"."status" IS '交易状态';
COMMENT ON COLUMN "public"."dws_transfer_2026"."currency" IS '交易币种';
COMMENT ON COLUMN "public"."dws_transfer_2026"."usd_amount" IS 'usd金额';
COMMENT ON COLUMN "public"."dws_transfer_2026"."transaction_count" IS '交易笔数统计';
COMMENT ON COLUMN "public"."dws_transfer_2026"."fee" IS '交易手续费';
COMMENT ON COLUMN "public"."dws_transfer_2026"."create_date" IS '统计发生日期';


-- 6.CREATE_TABLE dws_transfer_extend_2026
CREATE TABLE "public"."dws_transfer_extend_2026" (
  "id" int8 NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "status" varchar(50) COLLATE "pg_catalog"."default",
  "dbs_receive" numeric(18,2),
  "cl_receive" numeric(18,2),
  "ep_receive" numeric(18,2),
  "rd_receive" numeric(18,2),
  "settle_fx_fee" numeric(18,2),
  "conversion_fx_amount" numeric(18,2),
  "conversion_fx_fee" numeric(18,2),
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_transfer_extend_2026_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "public"."dws_transfer_extend_2026" OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_transfer_extend_2026"."status" IS '状态';
COMMENT ON COLUMN "public"."dws_transfer_extend_2026"."dbs_receive" IS '状态';
COMMENT ON COLUMN "public"."dws_transfer_extend_2026"."cl_receive" IS '状态';
COMMENT ON COLUMN "public"."dws_transfer_extend_2026"."ep_receive" IS '状态';
COMMENT ON COLUMN "public"."dws_transfer_extend_2026"."rd_receive" IS '状态';
COMMENT ON COLUMN "public"."dws_transfer_extend_2026"."settle_fx_fee" IS '人民币结汇fx手续费';
COMMENT ON COLUMN "public"."dws_transfer_extend_2026"."conversion_fx_amount" IS '海外付款或fx markup';
COMMENT ON COLUMN "public"."dws_transfer_extend_2026"."conversion_fx_fee" IS '海外付款或fx 金额';


-- 7.CREATE_TABLE dws_crypto_assets_transfers_2026
CREATE TABLE "public"."dws_crypto_assets_transfers_2026"(
  "id" int8 NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "status" varchar(50) COLLATE "pg_catalog"."default",
  "sender_type" varchar(50) COLLATE "pg_catalog"."default",
  "recipient_type" varchar(50) COLLATE "pg_catalog"."default",
  "transaction_count" int4,
  "origin_amount" numeric(18,2),
  "settlement_amount" numeric(18,2),
  "currency" varchar(30) COLLATE "pg_catalog"."default" NOT NULL,
  "action" varchar(20) COLLATE "pg_catalog"."default" NOT NULL,
  "fee" numeric(18,2),
  "fee2" numeric(18,2),
  "cross_chain_fee" numeric(18,2),
  "hidden" bool NOT NULL DEFAULT false, 
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_crypto_assets_transfers_2026_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "public"."dws_crypto_assets_transfers_2026" OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_crypto_assets_transfers_2026"."status" IS '交易状态';
COMMENT ON COLUMN "public"."dws_crypto_assets_transfers_2026"."sender_type" IS '交易发送方';
COMMENT ON COLUMN "public"."dws_crypto_assets_transfers_2026"."recipient_type" IS '交易接收方';
COMMENT ON COLUMN "public"."dws_crypto_assets_transfers_2026"."transaction_count" IS '交易笔数';
COMMENT ON COLUMN "public"."dws_crypto_assets_transfers_2026"."origin_amount" IS '原始交易金额';
COMMENT ON COLUMN "public"."dws_crypto_assets_transfers_2026"."settlement_amount" IS '结算金额';
COMMENT ON COLUMN "public"."dws_crypto_assets_transfers_2026"."currency" IS '交易币种';
COMMENT ON COLUMN "public"."dws_crypto_assets_transfers_2026"."action" IS '交易类型';
COMMENT ON COLUMN "public"."dws_crypto_assets_transfers_2026"."fee" IS 'fee1';
COMMENT ON COLUMN "public"."dws_crypto_assets_transfers_2026"."fee2" IS 'fee2';
COMMENT ON COLUMN "public"."dws_crypto_assets_transfers_2026"."cross_chain_fee" IS '跨链fee';
COMMENT ON COLUMN "public"."dws_crypto_assets_transfers_2026"."hidden" IS 'hidden';
COMMENT ON COLUMN "public"."dws_crypto_assets_transfers_2026"."create_date" IS '统计发生日期';



-- 8.CREATE_TABLE ods_qbit_card_2026
CREATE TABLE "public"."ods_fund_profits_2026" (
  "id" int8 NOT NULL,
  "fund_id" int8 NOT NULL,
  "create_time" timestamptz(6) NOT NULL,
  "update_time" timestamptz(6) NOT NULL,
  "delete_time" timestamptz(6),
  "version" int4 NOT NULL DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "account_id" uuid NOT NULL,
  "product_id" int8 NOT NULL,
  "date" timestamp(6) NOT NULL,
  "currency" varchar(32) COLLATE "pg_catalog"."default" NOT NULL,
  "profit" numeric NOT NULL,
  "service_fee" numeric NOT NULL,
  "status" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "apr" numeric NOT NULL,
  "share" numeric NOT NULL DEFAULT 0,
  "net_value" numeric NOT NULL DEFAULT 0,
  CONSTRAINT "ods_fund_profits_2026_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "public"."ods_fund_profits_2026" OWNER TO "qbit_admin";


-- 9.CREATE_TABLE ods_qbit_card_2026
CREATE TABLE "public"."ods_qbit_card_2026" (
  "id" int8 NOT NULL,
  "create_time" timestamptz(6) NOT NULL,
  "update_time" timestamptz(6) NOT NULL,
  "delete_time" timestamptz(6),
  "version" int4 NOT NULL DEFAULT 1,
  "remarks" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "card_id" uuid NOT NULL ,
  "account_id" uuid NOT NULL,
  "currency" varchar(30) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'USD'::character varying,
  "status" varchar(30) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'Active'::character varying,
  "provider" varchar(50) COLLATE "pg_catalog"."default",
  "type" varchar COLLATE "pg_catalog"."default",
  "token" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "user_delete_time" date,
  "delete_card_time" timestamptz(6),
  "first_six" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "card_belong" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'Common'::character varying,
  "physical_card_status" varchar(30) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'Na'::character varying,
  "card_mode" varchar(30) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'VirtualCard'::character varying,
  CONSTRAINT "ods_qbit_card_2026_pkey" PRIMARY KEY ("id")
);

-- 10.CREATE_TABLE dws_open_card_2026
CREATE TABLE "public"."dws_open_card_2026" (
  "id" int8 NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "provider" varchar(50) COLLATE "pg_catalog"."default",
  "bin" varchar(50) COLLATE "pg_catalog"."default",
  "status" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "fee" numeric NOT NULL,
  "count" int4 NOT NULL,
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_open_card_2026_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "public"."dws_open_card_2026"  OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_open_card_2026"."provider" IS '交易渠道';
COMMENT ON COLUMN "public"."dws_open_card_2026"."bin" IS '卡bin'; 
COMMENT ON COLUMN "public"."dws_open_card_2026"."status" IS '交易状态';
COMMENT ON COLUMN "public"."dws_open_card_2026"."fee" IS '交易手续费';
COMMENT ON COLUMN "public"."dws_open_card_2026"."count" IS '交易次数';
COMMENT ON COLUMN "public"."dws_open_card_2026"."create_date" IS '统计发生日期';


--11.创建 dws_physical_card_2026 表
CREATE TABLE "public"."dws_physical_card_2026" (
  "id" int8 NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "provider" varchar(50) COLLATE "pg_catalog"."default",
  "bin" varchar(50) COLLATE "pg_catalog"."default",
  "status" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "transaction_count" int4,
  "physical_card_fee" numeric(18,2),
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_physical_card_2026_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "public"."dws_physical_card_2026"  OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_physical_card_2026"."provider" IS '交易渠道';
COMMENT ON COLUMN "public"."dws_physical_card_2026"."bin" IS '卡bin'; 
COMMENT ON COLUMN "public"."dws_physical_card_2026"."status" IS '交易状态';
COMMENT ON COLUMN "public"."dws_physical_card_2026"."transaction_count" IS '交易次数';
COMMENT ON COLUMN "public"."dws_physical_card_2026"."physical_card_fee" IS '实体卡fee';
COMMENT ON COLUMN "public"."dws_physical_card_2026"."create_date" IS '统计发生日期';


--12.创建 dws_sale_card_wallet_transaction_2026 表
CREATE TABLE "public"."dws_sale_card_wallet_transaction_2026" (
  "id" int8 NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
 "sale_or_am_id" varchar(50),
  "business_type" varchar(50) COLLATE "pg_catalog"."default",
  "status" varchar(50) COLLATE "pg_catalog"."default",
  "origin_amount" numeric(18,2),
  "transaction_count" int4,
  "fee" numeric(18,2),
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_sale_card_wallet_transaction_2026_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "public"."dws_sale_card_wallet_transaction_2026" OWNER TO "qbit_admin";

ALTER TABLE "public"."dws_sale_card_wallet_transaction_2026" OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_sale_card_wallet_transaction_2026"."business_type" IS '交易类型';
COMMENT ON COLUMN "public"."dws_sale_card_wallet_transaction_2026"."status" IS '状态';
COMMENT ON COLUMN "public"."dws_sale_card_wallet_transaction_2026"."origin_amount" IS '原始金额';
COMMENT ON COLUMN "public"."dws_sale_card_wallet_transaction_2026"."transaction_count" IS '交易笔数';
COMMENT ON COLUMN "public"."dws_sale_card_wallet_transaction_2026"."fee" IS '手续费';
COMMENT ON COLUMN "public"."dws_sale_card_wallet_transaction_2026"."create_date" IS '统计发生日期';


-- 13.CREATE_TABLE dws_qbit_card_transaction_2026
CREATE TABLE "public"."dws_sale_card_transaction_2026" (
  "id" bigint NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
 "sale_or_am_id" varchar(50),
  "business_type" varchar(50) COLLATE "pg_catalog"."default",
  "status" varchar(50) COLLATE "pg_catalog"."default",
  "provider" varchar(50) COLLATE "pg_catalog"."default",
  "bin" varchar(50) COLLATE "pg_catalog"."default",
  "origin_amount" numeric(18, 2),
  "settle_amount" numeric(18, 2),
  "transaction_count" int4,
  "fee" numeric(18, 2),
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1, -- 版本号
  "remarks" varchar(255) COLLATE "pg_catalog"."default", 
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6), -- 逻辑删除时间
  CONSTRAINT "dws_sale_card_transaction_2026_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "public"."dws_sale_card_transaction_2026" OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_sale_card_transaction_2026"."business_type" IS '交易类型';
COMMENT ON COLUMN "public"."dws_sale_card_transaction_2026"."status" IS '状态';
COMMENT ON COLUMN "public"."dws_sale_card_transaction_2026"."provider" IS '交易渠道';
COMMENT ON COLUMN "public"."dws_sale_card_transaction_2026"."bin" IS '卡bin';
COMMENT ON COLUMN "public"."dws_sale_card_transaction_2026"."origin_amount" IS '原始金额';
COMMENT ON COLUMN "public"."dws_sale_card_transaction_2026"."settle_amount" IS '结算金额';
COMMENT ON COLUMN "public"."dws_sale_card_transaction_2026"."transaction_count" IS '交易笔数';
COMMENT ON COLUMN "public"."dws_sale_card_transaction_2026"."fee" IS '手续费';
COMMENT ON COLUMN "public"."dws_sale_card_transaction_2026"."create_date" IS '统计发生日期';


--14.创建 dws_qbit_card_consumption_extend_2026 表
CREATE TABLE "public"."dws_sale_card_transaction_extend_2026" (
  "id" int8 NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
 "sale_or_am_id" varchar(50),
  "business_type" varchar(50) COLLATE "pg_catalog"."default",
  "provider" varchar(50) COLLATE "pg_catalog"."default",
  "bin" varchar(50) COLLATE "pg_catalog"."default",
  "status" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "settle_amount" numeric(18,2),
  "transaction_currency" varchar(50) COLLATE "pg_catalog"."default",
  "country" varchar(50) COLLATE "pg_catalog"."default",
  "transaction_count" int4,
  "fx_fee" numeric(18,2),
  "atm_fee" numeric(18,2),
  "apple_pay_fee" numeric(18,2),
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_sale_card_transaction_extend_2026_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "public"."dws_sale_card_transaction_extend_2026"  OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_sale_card_transaction_extend_2026"."provider" IS '交易渠道';
COMMENT ON COLUMN "public"."dws_sale_card_transaction_extend_2026"."bin" IS '卡bin';
COMMENT ON COLUMN "public"."dws_sale_card_transaction_extend_2026"."status" IS '交易状态';
COMMENT ON COLUMN "public"."dws_sale_card_transaction_extend_2026"."settle_amount" IS '清算金额';
COMMENT ON COLUMN "public"."dws_sale_card_transaction_extend_2026"."transaction_currency" IS '交易币种';
COMMENT ON COLUMN "public"."dws_sale_card_transaction_extend_2026"."country" IS '交易国家';
COMMENT ON COLUMN "public"."dws_sale_card_transaction_extend_2026"."transaction_count" IS '交易笔数';
COMMENT ON COLUMN "public"."dws_sale_card_transaction_extend_2026"."fx_fee" IS 'fx_fee';
COMMENT ON COLUMN "public"."dws_sale_card_transaction_extend_2026"."atm_fee" IS 'atm_fee提现';
COMMENT ON COLUMN "public"."dws_sale_card_transaction_extend_2026"."apple_pay_fee" IS 'apple_pay_fee';
COMMENT ON COLUMN "public"."dws_sale_card_transaction_extend_2026"."create_date" IS '统计发生日期';


-- 15.CREATE_TABLE dws_sale_card_group_transaction_2026
CREATE TABLE "public"."dws_sale_card_group_transaction_2026" (
  "id" bigint NOT NULL, -- 雪花ID
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
 "sale_or_am_id" varchar(50),
  "business_type" varchar(50) COLLATE "pg_catalog"."default",
  "status" varchar(50) COLLATE "pg_catalog"."default",
  "origin_amount" numeric(18, 2),
  "transaction_count" int4,
  "fee" numeric(18, 2),
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1, -- 版本号
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6), -- 逻辑删除时间
  CONSTRAINT "dws_sale_card_group_transaction_2026_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "public"."dws_sale_card_group_transaction_2026" OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_sale_card_group_transaction_2026"."business_type" IS '交易类型';
COMMENT ON COLUMN "public"."dws_sale_card_group_transaction_2026"."status" IS '交易状态';
COMMENT ON COLUMN "public"."dws_sale_card_group_transaction_2026"."origin_amount" IS '原始交易金额';
COMMENT ON COLUMN "public"."dws_sale_card_group_transaction_2026"."transaction_count" IS '交易笔数';
COMMENT ON COLUMN "public"."dws_sale_card_group_transaction_2026"."fee" IS '交易手续费';
COMMENT ON COLUMN "public"."dws_sale_card_group_transaction_2026"."create_date" IS '统计发生日期';


-- 16.CREATE_TABLE dws_sale_transfer_2026
CREATE TABLE "public"."dws_sale_transfer_2026" (
  "id" int8 NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "sale_or_am_id" varchar(50) COLLATE "pg_catalog"."default",
  "business_type_detail" varchar(50) COLLATE "pg_catalog"."default",
  "settlement_currency" varchar(50) COLLATE "pg_catalog"."default",
  "status" varchar(50) COLLATE "pg_catalog"."default",
  "currency" varchar(30) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'USD'::character varying,
  "usd_amount" numeric(18,2),
  "transaction_count" int4,
  "fee" numeric(18,2),
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  "business_type_code" varchar(255) COLLATE "pg_catalog"."default",
  CONSTRAINT "dws_sale_transfer_2026_pkey" PRIMARY KEY ("id")
)
;

ALTER TABLE "public"."dws_sale_transfer_2026" OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_sale_transfer_2026"."business_type_detail" IS '交易类型';
COMMENT ON COLUMN "public"."dws_sale_transfer_2026"."settlement_currency" IS '结算币种';
COMMENT ON COLUMN "public"."dws_sale_transfer_2026"."status" IS '交易状态';
COMMENT ON COLUMN "public"."dws_sale_transfer_2026"."currency" IS '交易币种';
COMMENT ON COLUMN "public"."dws_sale_transfer_2026"."usd_amount" IS 'usd金额';
COMMENT ON COLUMN "public"."dws_sale_transfer_2026"."transaction_count" IS '交易笔数统计';
COMMENT ON COLUMN "public"."dws_sale_transfer_2026"."fee" IS '交易手续费';
COMMENT ON COLUMN "public"."dws_sale_transfer_2026"."create_date" IS '统计发生日期';
COMMENT ON COLUMN "public"."dws_sale_transfer_2026"."business_type_code" IS '交易类型code';

-- 17.CREATE_TABLE dws_transfer_extend_2026
CREATE TABLE "public"."dws_sale_transfer_extend_2026" (
  "id" int8 NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
 "sale_or_am_id" varchar(50),
  "status" varchar(50) COLLATE "pg_catalog"."default",
  "dbs_receive" numeric(18,2),
  "cl_receive" numeric(18,2),
  "ep_receive" numeric(18,2),
  "rd_receive" numeric(18,2),
  "settle_fx_fee" numeric(18,2),
  "conversion_fx_amount" numeric(18,2),
  "conversion_fx_fee" numeric(18,2),
  "inbound_profit" numeric(18,2),
  "conversion_fx_profit" numeric(18,2),
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_sale_transfer_extend_2026_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "public"."dws_sale_transfer_extend_2026" OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_sale_transfer_extend_2026"."status" IS '状态';
COMMENT ON COLUMN "public"."dws_sale_transfer_extend_2026"."dbs_receive" IS '状态';
COMMENT ON COLUMN "public"."dws_sale_transfer_extend_2026"."cl_receive" IS '状态';
COMMENT ON COLUMN "public"."dws_sale_transfer_extend_2026"."ep_receive" IS '状态';
COMMENT ON COLUMN "public"."dws_sale_transfer_extend_2026"."rd_receive" IS '状态';
COMMENT ON COLUMN "public"."dws_sale_transfer_extend_2026"."settle_fx_fee" IS '人民币结汇fx手续费';
COMMENT ON COLUMN "public"."dws_sale_transfer_extend_2026"."conversion_fx_amount" IS '海外付款或fx markup';
COMMENT ON COLUMN "public"."dws_sale_transfer_extend_2026"."conversion_fx_fee" IS '海外付款或fx 金额';


-- 18.CREATE_TABLE dws_crypto_assets_transfers_2026
CREATE TABLE "public"."dws_sale_crypto_assets_transfers_2026"(
  "id" int8 NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
 "sale_or_am_id" varchar(50),
  "status" varchar(50) COLLATE "pg_catalog"."default",
  "sender_type" varchar(50) COLLATE "pg_catalog"."default",
  "recipient_type" varchar(50) COLLATE "pg_catalog"."default",
  "transaction_count" int4,
  "origin_amount" numeric(18,2),
  "settlement_amount" numeric(18,2),
  "currency" varchar(30) COLLATE "pg_catalog"."default" NOT NULL,
  "action" varchar(20) COLLATE "pg_catalog"."default" NOT NULL,
  "fee" numeric(18,2),
  "fee2" numeric(18,2),
  "cross_chain_fee" numeric(18,2),
  "exchange_profit" numeric(18,2),
  "payment_profit" numeric(18,2),
  "hidden" bool NOT NULL DEFAULT false, 
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_sale_crypto_assets_transfers_2026_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "public"."dws_sale_crypto_assets_transfers_2026" OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_sale_crypto_assets_transfers_2026"."status" IS '交易状态';
COMMENT ON COLUMN "public"."dws_sale_crypto_assets_transfers_2026"."sender_type" IS '交易发送方';
COMMENT ON COLUMN "public"."dws_sale_crypto_assets_transfers_2026"."recipient_type" IS '交易接收方';
COMMENT ON COLUMN "public"."dws_sale_crypto_assets_transfers_2026"."transaction_count" IS '交易笔数';
COMMENT ON COLUMN "public"."dws_sale_crypto_assets_transfers_2026"."origin_amount" IS '原始交易金额';
COMMENT ON COLUMN "public"."dws_sale_crypto_assets_transfers_2026"."settlement_amount" IS '结算金额';
COMMENT ON COLUMN "public"."dws_sale_crypto_assets_transfers_2026"."currency" IS '交易币种';
COMMENT ON COLUMN "public"."dws_sale_crypto_assets_transfers_2026"."action" IS '交易类型';
COMMENT ON COLUMN "public"."dws_sale_crypto_assets_transfers_2026"."fee" IS 'fee1';
COMMENT ON COLUMN "public"."dws_sale_crypto_assets_transfers_2026"."fee2" IS 'fee2';
COMMENT ON COLUMN "public"."dws_sale_crypto_assets_transfers_2026"."cross_chain_fee" IS '跨链fee';
COMMENT ON COLUMN "public"."dws_sale_crypto_assets_transfers_2026"."exchange_profit" IS '交易手续费毛利';
COMMENT ON COLUMN "public"."dws_sale_crypto_assets_transfers_2026"."payment_profit" IS 'payment毛利';
COMMENT ON COLUMN "public"."dws_sale_crypto_assets_transfers_2026"."hidden" IS 'hidden';
COMMENT ON COLUMN "public"."dws_sale_crypto_assets_transfers_2026"."create_date" IS '统计发生日期';


-- 19.CREATE_TABLE ods_sale_fund_profits_2026
CREATE TABLE "public"."ods_sale_fund_profits_2026" (
  "id" int8 NOT NULL,
  "fund_id" int8 NOT NULL,
  "create_time" timestamptz(6) NOT NULL,
  "update_time" timestamptz(6) NOT NULL,
  "delete_time" timestamptz(6),
  "version" int4 NOT NULL DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "account_id" uuid NOT NULL,
 "sale_or_am_id" varchar(50),
  "product_id" int8 NOT NULL,
  "date" timestamp(6) NOT NULL,
  "currency" varchar(32) COLLATE "pg_catalog"."default" NOT NULL,
  "profit" numeric NOT NULL,
  "service_fee" numeric NOT NULL,
  "status" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "apr" numeric NOT NULL,
  "share" numeric NOT NULL DEFAULT 0,
  "net_value" numeric NOT NULL DEFAULT 0,
  CONSTRAINT "ods_sale_fund_profits_2026_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "public"."ods_sale_fund_profits_2026" OWNER TO "qbit_admin";


-- 20.CREATE_TABLE ods_sale_qbit_card_2026
CREATE TABLE "public"."ods_sale_qbit_card_2026" (
  "id" int8 NOT NULL,
  "create_time" timestamptz(6) NOT NULL,
  "update_time" timestamptz(6) NOT NULL,
  "delete_time" timestamptz(6),
  "version" int4 NOT NULL DEFAULT 1,
  "remarks" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
 "sale_or_am_id" varchar(50),
  "card_id" uuid NOT NULL ,
  "account_id" uuid NOT NULL,
  "currency" varchar(30) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'USD'::character varying,
  "status" varchar(30) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'Active'::character varying,
  "provider" varchar(50) COLLATE "pg_catalog"."default",
  "type" varchar COLLATE "pg_catalog"."default",
  "token" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "user_delete_time" date,
  "delete_card_time" timestamptz(6),
  "first_six" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "card_belong" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'Common'::character varying,
  "physical_card_status" varchar(30) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'Na'::character varying,
  "card_mode" varchar(30) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'VirtualCard'::character varying,
  CONSTRAINT "ods_sale_qbit_card_2026_pkey" PRIMARY KEY ("id")
);

-- 21.CREATE_TABLE dws_sale_open_card_2026
CREATE TABLE "public"."dws_sale_open_card_2026" (
  "id" int8 NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "provider" varchar(50) COLLATE "pg_catalog"."default",
  "bin" varchar(50) COLLATE "pg_catalog"."default",
  "status" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
 "sale_or_am_id" varchar(50),
  "fee" numeric NOT NULL,
  "count" int4 NOT NULL,
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_sale_open_card_2026_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "public"."dws_sale_open_card_2026"  OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_sale_open_card_2026"."provider" IS '交易渠道';
COMMENT ON COLUMN "public"."dws_sale_open_card_2026"."bin" IS '卡bin'; 
COMMENT ON COLUMN "public"."dws_sale_open_card_2026"."status" IS '交易状态';
COMMENT ON COLUMN "public"."dws_sale_open_card_2026"."fee" IS '交易手续费';
COMMENT ON COLUMN "public"."dws_sale_open_card_2026"."count" IS '交易次数';
COMMENT ON COLUMN "public"."dws_sale_open_card_2026"."create_date" IS '统计发生日期';


--22.创建 dws_sale_physical_card_2026 表
CREATE TABLE "public"."dws_sale_physical_card_2026" (
  "id" int8 NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
 "sale_or_am_id" varchar(50),
  "provider" varchar(50) COLLATE "pg_catalog"."default",
  "bin" varchar(50) COLLATE "pg_catalog"."default",
  "status" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "transaction_count" int4,
  "physical_card_fee" numeric(18,2),
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_sale_physical_card_2026_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "public"."dws_sale_physical_card_2026"  OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_sale_physical_card_2026"."provider" IS '交易渠道';
COMMENT ON COLUMN "public"."dws_sale_physical_card_2026"."bin" IS '卡bin'; 
COMMENT ON COLUMN "public"."dws_sale_physical_card_2026"."status" IS '交易状态';
COMMENT ON COLUMN "public"."dws_sale_physical_card_2026"."transaction_count" IS '交易次数';
COMMENT ON COLUMN "public"."dws_sale_physical_card_2026"."physical_card_fee" IS '实体卡fee';
COMMENT ON COLUMN "public"."dws_sale_physical_card_2026"."create_date" IS '统计发生日期';


--23 dws_qbit_card_cost_2026
CREATE TABLE "public"."dws_qbit_card_cost_2026" (
  "id" int8 NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "cost_type" varchar(50) COLLATE "pg_catalog"."default",
  "provider" varchar(50) COLLATE "pg_catalog"."default",
  "bin" varchar(50) COLLATE "pg_catalog"."default",
  "cost_amount" numeric(18,2),
  "cost_count" numeric(18,2),
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1,
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "fee" numeric(18,2),
  CONSTRAINT "dws_qbit_card_cost_2026_pkey" PRIMARY KEY ("id")
)
;

ALTER TABLE "public"."dws_qbit_card_cost_2026" OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_qbit_card_cost_2026"."cost_type" IS '成本类型';
COMMENT ON COLUMN "public"."dws_qbit_card_cost_2026"."provider" IS '交易渠道';
COMMENT ON COLUMN "public"."dws_qbit_card_cost_2026"."bin" IS '卡bin';
COMMENT ON COLUMN "public"."dws_qbit_card_cost_2026"."cost_amount" IS '成本统计金额';
COMMENT ON COLUMN "public"."dws_qbit_card_cost_2026"."cost_count" IS '成本统计笔数';
COMMENT ON COLUMN "public"."dws_qbit_card_cost_2026"."create_date" IS '统计发生日期';
COMMENT ON COLUMN "public"."dws_qbit_card_cost_2026"."fee" IS '有效收入';


--24 dws_sale_card_cost_2026
CREATE TABLE "public"."dws_sale_card_cost_2026" (
  "id" int8 NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "sale_or_am_id" varchar(50) COLLATE "pg_catalog"."default",
  "cost_type" varchar(50) COLLATE "pg_catalog"."default",
  "provider" varchar(50) COLLATE "pg_catalog"."default",
  "bin" varchar(50) COLLATE "pg_catalog"."default",
  "cost_amount" numeric(18,2),
  "cost_count" numeric(18,2),
  "create_date" timestamp(6) NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  "fee" numeric(18,2),
  CONSTRAINT "dws_sale_card_cost_2026_pkey" PRIMARY KEY ("id")
)
;

ALTER TABLE "public"."dws_sale_card_cost_2026" OWNER TO "qbit_admin";
COMMENT ON COLUMN "public"."dws_sale_card_cost_2026"."cost_type" IS '成本类型';
COMMENT ON COLUMN "public"."dws_sale_card_cost_2026"."provider" IS '交易渠道';
COMMENT ON COLUMN "public"."dws_sale_card_cost_2026"."bin" IS '卡bin';
COMMENT ON COLUMN "public"."dws_sale_card_cost_2026"."cost_amount" IS '成本统计金额';
COMMENT ON COLUMN "public"."dws_sale_card_cost_2026"."cost_count" IS '成本统计笔数';
COMMENT ON COLUMN "public"."dws_sale_card_cost_2026"."create_date" IS '统计发生日期';
COMMENT ON COLUMN "public"."dws_sale_card_cost_2026"."fee" IS '有效收入';