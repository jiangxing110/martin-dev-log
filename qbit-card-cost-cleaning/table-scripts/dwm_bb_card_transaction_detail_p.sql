CREATE TABLE "public"."dwm_bb_card_transaction_detail_p" (
  "id" uuid NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "card_id" uuid NOT NULL,
  "transaction_time" timestamptz(6) NOT NULL,
  "third_complete_time" timestamp(6),
  "business_type" varchar(50) COLLATE "pg_catalog"."default",
  "status" varchar(20) COLLATE "pg_catalog"."default",
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "card_org" varchar(20) COLLATE "pg_catalog"."default",
  "is_dom" bool DEFAULT false,
  "resp_code" varchar(20) COLLATE "pg_catalog"."default",
  "request_code" varchar(50) COLLATE "pg_catalog"."default",
  "reason_code" varchar(50) COLLATE "pg_catalog"."default",
  "is_valid_settle" bool DEFAULT false,
  "is_clearing" bool DEFAULT false,
  "is_reversal" bool DEFAULT false,
  "is_refund" bool DEFAULT false,
  "billing_amount" numeric(20,4) DEFAULT 0,
  "version" int4 DEFAULT 1,
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  "settle_country" varchar(10) COLLATE "pg_catalog"."default",
  "tx_country" varchar(10) COLLATE "pg_catalog"."default",
  CONSTRAINT "dwm_bb_card_tx_pkey" PRIMARY KEY ("id", "transaction_time")
)
PARTITION BY RANGE (
  "transaction_time" "pg_catalog"."timestamptz_ops"
)
;

ALTER TABLE "public"."dwm_bb_card_transaction_detail_p"
  OWNER TO "qbit_admin";

-- 字段备注
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."id" IS '主键ID-对应ODS层交易ID';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."account_id" IS '账户ID';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."card_id" IS '卡片UUID';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."transaction_time" IS '交易发起时间-分区键';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."third_complete_time" IS '三方完成时间-Volume Fee统计基准时间';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."business_type" IS '业务类型:Consumption/Credit/Fee_Consumption';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."status" IS '交易状态';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."remarks" IS '业务备注-用于识别AV绑卡手续费等';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."card_org" IS '卡组织:Master/VISA';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."is_dom" IS '是否本地交易:TRUE本地,FALSE国际';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."resp_code" IS '响应码:APPROVE/DECLINE';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."request_code" IS '请求类型:ST-AUTH_REV/ST-PARTIAL_REV等';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."reason_code" IS '二级原因码';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."is_valid_settle" IS '是否有效结算:排除ST-XXX_ADV等预扣费类型';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."is_clearing" IS '是否清算:对应authorization.clearing';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."is_reversal" IS '是否冲正:对应authorization.reversal';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."is_refund" IS '是否退款:对应refund.clearing';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."billing_amount" IS '计费金额-清算金额';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."version" IS '乐观锁版本';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."delete_time" IS '逻辑删除时间';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."settle_country" IS '从结算原始JSON中提取的国家';
COMMENT ON COLUMN "public"."dwm_bb_card_transaction_detail_p"."tx_country" IS '从交易原始JSON中提取的国家';
COMMENT ON TABLE "public"."dwm_bb_card_transaction_detail_p" IS 'BB渠道明细因子层-月度分区表';

-- 2026 全年月度分区
ALTER TABLE "public"."dwm_bb_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_bb_card_tx_2026_01" FOR VALUES FROM ('2026-01-01 00:00:00+08') TO ('2026-02-01 00:00:00+08');
ALTER TABLE "public"."dwm_bb_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_bb_card_tx_2026_02" FOR VALUES FROM ('2026-02-01 00:00:00+08') TO ('2026-03-01 00:00:00+08');
ALTER TABLE "public"."dwm_bb_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_bb_card_tx_2026_03" FOR VALUES FROM ('2026-03-01 00:00:00+08') TO ('2026-04-01 00:00:00+08');
ALTER TABLE "public"."dwm_bb_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_bb_card_tx_2026_04" FOR VALUES FROM ('2026-04-01 00:00:00+08') TO ('2026-05-01 00:00:00+08');
ALTER TABLE "public"."dwm_bb_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_bb_card_tx_2026_05" FOR VALUES FROM ('2026-05-01 00:00:00+08') TO ('2026-06-01 00:00:00+08');
ALTER TABLE "public"."dwm_bb_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_bb_card_tx_2026_06" FOR VALUES FROM ('2026-06-01 00:00:00+08') TO ('2026-07-01 00:00:00+08');
ALTER TABLE "public"."dwm_bb_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_bb_card_tx_2026_07" FOR VALUES FROM ('2026-07-01 00:00:00+08') TO ('2026-08-01 00:00:00+08');
ALTER TABLE "public"."dwm_bb_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_bb_card_tx_2026_08" FOR VALUES FROM ('2026-08-01 00:00:00+08') TO ('2026-09-01 00:00:00+08');
ALTER TABLE "public"."dwm_bb_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_bb_card_tx_2026_09" FOR VALUES FROM ('2026-09-01 00:00:00+08') TO ('2026-10-01 00:00:00+08');
ALTER TABLE "public"."dwm_bb_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_bb_card_tx_2026_10" FOR VALUES FROM ('2026-10-01 00:00:00+08') TO ('2026-11-01 00:00:00+08');
ALTER TABLE "public"."dwm_bb_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_bb_card_tx_2026_11" FOR VALUES FROM ('2026-11-01 00:00:00+08') TO ('2026-12-01 00:00:00+08');
ALTER TABLE "public"."dwm_bb_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_bb_card_tx_2026_12" FOR VALUES FROM ('2026-12-01 00:00:00+08') TO ('2027-01-01 00:00:00+08');
