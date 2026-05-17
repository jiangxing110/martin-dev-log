CREATE TABLE "public"."qbit_card_transaction_clean_2026" (
  "id" uuid NOT NULL,
  "remarks" varchar COLLATE "pg_catalog"."default",
  "createTime" timestamptz(6) NOT NULL DEFAULT now(),
  "updateTime" timestamptz(6) NOT NULL DEFAULT now(),
  "deleteTime" timestamptz(6),
  "version" int4 NOT NULL,
  "accountId" uuid NOT NULL,
  "cardId" uuid,
  "currency" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "status" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "displayStatus" varchar(30) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'Pending'::character varying,
  "provider" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "settleAmount" float8 NOT NULL DEFAULT '0'::double precision,
  "originalAmount" float8 NOT NULL DEFAULT '0'::double precision,
  "fee" float8 NOT NULL DEFAULT '0'::double precision,
  "detail" varchar COLLATE "pg_catalog"."default",
  "businessType" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "sourceId" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "transactionTime" timestamptz(6) DEFAULT now(),
  "merchantShow" bool DEFAULT true,
  "specialSourceData" json,
  "transactionId" uuid,
  "systemTraceAuditNumber" varchar COLLATE "pg_catalog"."default",
  "authorizationCode" varchar COLLATE "pg_catalog"."default",
  "statusLog" varchar COLLATE "pg_catalog"."default",
  "comments" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "transactionCurrency" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'USD'::character varying,
  "transactionAmount" float8 NOT NULL DEFAULT '0'::double precision,
  "relatedQbitTxId" uuid,
  "paymentLabel" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "platformLabel" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "secondLabel" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "completeTime" timestamp(6),
  "released" bool NOT NULL DEFAULT false,
  "thirdCompleteTime" timestamp(6),
  "id_" int8,
  "isShow" bool DEFAULT true,
  CONSTRAINT "qbit_card_transaction_clean_2026_pkey" PRIMARY KEY ("id", "createTime")
)
PARTITION BY RANGE (
  "createTime" "pg_catalog"."timestamptz_ops"
)
;

ALTER TABLE "public"."qbit_card_transaction_clean_2026"
  OWNER TO "qbit_admin";

-- 字段备注
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."id" IS '主键ID';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."remarks" IS '备注';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."createTime" IS '记录创建时间-分区键';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."updateTime" IS '记录更新时间';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."deleteTime" IS '逻辑删除时间';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."version" IS '版本号';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."accountId" IS '账户ID';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."cardId" IS '卡片ID';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."currency" IS '币种';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."status" IS '交易状态';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."displayStatus" IS '展示状态';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."provider" IS '通道 provider';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."settleAmount" IS '结算金额';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."originalAmount" IS '原始金额';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."fee" IS '手续费';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."detail" IS '交易详情';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."businessType" IS '业务类型 (Consumption/Credit等)';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."sourceId" IS '源交易ID (关联结算)';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."transactionTime" IS '交易发起时间';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."merchantShow" IS '是否对商户展示';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."specialSourceData" IS '特殊源数据JSON (含错误码/国家等)';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."transactionId" IS '交易UUID';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."systemTraceAuditNumber" IS '系统跟踪审计号';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."authorizationCode" IS '授权码';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."statusLog" IS '状态变更日志';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."comments" IS '备注说明';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."transactionCurrency" IS '交易币种';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."transactionAmount" IS '交易金额';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."relatedQbitTxId" IS '关联的Qbit交易ID';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."paymentLabel" IS '支付标签';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."platformLabel" IS '平台标签';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."secondLabel" IS '二级标签';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."completeTime" IS '完成时间';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."released" IS '是否已释放';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."thirdCompleteTime" IS '三方完成时间';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."id_" IS '旧ID字段';
COMMENT ON COLUMN "public"."qbit_card_transaction_clean_2026"."isShow" IS '是否展示';
COMMENT ON TABLE "public"."qbit_card_transaction_clean_2026" IS 'Qbit卡交易数据清洗表-按月分区';

-- 已存在的月分区
ALTER TABLE "public"."qbit_card_transaction_clean_2026" ATTACH PARTITION "public"."qbit_card_transaction_clean_2026_m03" FOR VALUES FROM ('2026-03-01 00:00:00+08') TO ('2026-04-01 00:00:00+08');
ALTER TABLE "public"."qbit_card_transaction_clean_2026" ATTACH PARTITION "public"."qbit_card_transaction_clean_2026_m04" FOR VALUES FROM ('2026-04-01 00:00:00+08') TO ('2026-05-01 00:00:00+08');
