CREATE TABLE "public"."qbit_card_settlement_bb_clean_2026" (
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
  CONSTRAINT "qbit_card_settlement_bb_clean_2026_pkey" PRIMARY KEY ("id", "createTime")
)
PARTITION BY RANGE (
  "createTime" "pg_catalog"."timestamptz_ops"
)
;

ALTER TABLE "public"."qbit_card_settlement_bb_clean_2026"
  OWNER TO "qbit_admin";

-- 字段备注
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."id" IS '主键ID';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."remarks" IS '备注';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."createTime" IS '记录创建时间-分区键';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."updateTime" IS '记录更新时间';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."deleteTime" IS '逻辑删除时间';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."version" IS '版本号';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."cardHashId" IS '卡片HashID';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."transactionId" IS '交易ID';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."referenceNumber" IS '通道参考号';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."recordType" IS '结算记录类型';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."effectiveDate" IS '生效日期';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."batchDate" IS '批次日期';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."transactionType" IS '结算交易类型 (如 authorization.clearing)';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."transactionCode" IS '交易码';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."billingAmount" IS '计费金额 (结算侧)';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."billingCurrencyCode" IS '计费币种';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."transactionAmount" IS '交易金额';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."transactionCurrencyCode" IS '交易币种';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."authorizationCode" IS '授权码';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."description" IS '描述';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."cardAcceptorId" IS '商户ID (Acceptor)';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."interchangeReference" IS 'Interchange参考号';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."visaTransactionId" IS 'VISA交易ID';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."tokenRequestorId" IS 'Token请求方ID';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."tokenNumber" IS 'Token卡号';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."billingAmountRaw" IS '计费金额原始值';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."transactionAmountRaw" IS '交易金额原始值';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."rawData" IS '结算原始JSON数据';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."settlementDay" IS '结算日期';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."hash" IS '数据指纹';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."provider" IS '通道 provider';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."settleCompleted" IS '是否已完成结算';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."qbitCardTransactionId" IS '关联的Qbit交易ID';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."compareTime" IS '对账时间';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."id_" IS '旧ID字段';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."statusMessage" IS '状态信息/消息';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."country" IS '国家';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."mid" IS '商户ID';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."merchantCountry" IS '商户所在国家';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."channel" IS '渠道';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."wallet" IS '钱包类型';
COMMENT ON COLUMN "public"."qbit_card_settlement_bb_clean_2026"."mcc" IS 'MCC商户类别码';
COMMENT ON TABLE "public"."qbit_card_settlement_bb_clean_2026" IS 'BB通道结算数据清洗表-按月分区';

-- 已存在的月分区
ALTER TABLE "public"."qbit_card_settlement_bb_clean_2026" ATTACH PARTITION "public"."qbit_card_settlement_bb_clean_2026_m03" FOR VALUES FROM ('2026-03-01 00:00:00+08') TO ('2026-04-01 00:00:00+08');
ALTER TABLE "public"."qbit_card_settlement_bb_clean_2026" ATTACH PARTITION "public"."qbit_card_settlement_bb_clean_2026_m04" FOR VALUES FROM ('2026-04-01 00:00:00+08') TO ('2026-05-01 00:00:00+08');
