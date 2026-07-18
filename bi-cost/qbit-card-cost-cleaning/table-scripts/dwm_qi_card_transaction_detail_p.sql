CREATE TABLE "public"."dwm_qi_card_transaction_detail_p" (
  "id" uuid NOT NULL,
  "transaction_id" varchar(100) COLLATE "pg_catalog"."default" NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "status" varchar(20) COLLATE "pg_catalog"."default",
  "transaction_time" timestamptz(6) NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  "billing_amount" numeric(20,4) DEFAULT 0,
  "is_qbit_provision" bool DEFAULT false,
  "is_hk_region" bool DEFAULT false,
  "is_consumption" bool DEFAULT false,
  "is_reversal_or_credit" bool DEFAULT false,
  "has_special_code" bool DEFAULT false,
  "is_vip_account" bool DEFAULT false,
  "business_type" varchar(50) COLLATE "pg_catalog"."default",
  "card_id" varchar(255) COLLATE "pg_catalog"."default",
  CONSTRAINT "dwm_qi_card_tx_pkey" PRIMARY KEY ("id", "transaction_time")
)
PARTITION BY RANGE (
  "transaction_time" "pg_catalog"."timestamptz_ops"
)
;

ALTER TABLE "public"."dwm_qi_card_transaction_detail_p"
  OWNER TO "qbit_admin";

-- 字段备注
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."id" IS '主键ID';
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."transaction_id" IS '原始交易ID';
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."account_id" IS '账户ID';
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."status" IS '交易状态';
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."transaction_time" IS '交易时间';
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."version" IS '版本号';
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."remarks" IS '备注';
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."create_time" IS '创建时间';
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."update_time" IS '更新时间';
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."delete_time" IS '删除时间';
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."billing_amount" IS '清算/计费金额 (USD)';
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."is_qbit_provision" IS '是否为Qbit预置卡';
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."is_hk_region" IS '是否为香港地区交易 (判定非港费用)';
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."is_consumption" IS '是否为消费类型 (+)';
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."is_reversal_or_credit" IS '是否为冲正退款 (-)';
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."has_special_code" IS '是否含有特殊错误码 (判定VRM排除项)';
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."is_vip_account" IS '是否为ACS VIP账户';
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."business_type" IS '业务类型';
COMMENT ON COLUMN "public"."dwm_qi_card_transaction_detail_p"."card_id" IS '卡片ID (用于统计活跃卡)';

-- 索引
CREATE INDEX "idx_dwm_qi_tx_time_acc" ON "public"."dwm_qi_card_transaction_detail_p" USING btree (
  "transaction_time" "pg_catalog"."timestamptz_ops" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dwm_qi_update_time" ON "public"."dwm_qi_card_transaction_detail_p" USING btree (
  "update_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST
);

-- 2026 全年月度分区
ALTER TABLE "public"."dwm_qi_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_qi_card_tx_2026_01" FOR VALUES FROM ('2026-01-01 00:00:00+08') TO ('2026-02-01 00:00:00+08');
ALTER TABLE "public"."dwm_qi_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_qi_card_tx_2026_02" FOR VALUES FROM ('2026-02-01 00:00:00+08') TO ('2026-03-01 00:00:00+08');
ALTER TABLE "public"."dwm_qi_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_qi_card_tx_2026_03" FOR VALUES FROM ('2026-03-01 00:00:00+08') TO ('2026-04-01 00:00:00+08');
ALTER TABLE "public"."dwm_qi_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_qi_card_tx_2026_04" FOR VALUES FROM ('2026-04-01 00:00:00+08') TO ('2026-05-01 00:00:00+08');
ALTER TABLE "public"."dwm_qi_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_qi_card_tx_2026_05" FOR VALUES FROM ('2026-05-01 00:00:00+08') TO ('2026-06-01 00:00:00+08');
ALTER TABLE "public"."dwm_qi_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_qi_card_tx_2026_06" FOR VALUES FROM ('2026-06-01 00:00:00+08') TO ('2026-07-01 00:00:00+08');
ALTER TABLE "public"."dwm_qi_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_qi_card_tx_2026_07" FOR VALUES FROM ('2026-07-01 00:00:00+08') TO ('2026-08-01 00:00:00+08');
ALTER TABLE "public"."dwm_qi_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_qi_card_tx_2026_08" FOR VALUES FROM ('2026-08-01 00:00:00+08') TO ('2026-09-01 00:00:00+08');
ALTER TABLE "public"."dwm_qi_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_qi_card_tx_2026_09" FOR VALUES FROM ('2026-09-01 00:00:00+08') TO ('2026-10-01 00:00:00+08');
ALTER TABLE "public"."dwm_qi_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_qi_card_tx_2026_10" FOR VALUES FROM ('2026-10-01 00:00:00+08') TO ('2026-11-01 00:00:00+08');
ALTER TABLE "public"."dwm_qi_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_qi_card_tx_2026_11" FOR VALUES FROM ('2026-11-01 00:00:00+08') TO ('2026-12-01 00:00:00+08');
ALTER TABLE "public"."dwm_qi_card_transaction_detail_p" ATTACH PARTITION "public"."dwm_qi_card_tx_2026_12" FOR VALUES FROM ('2026-12-01 00:00:00+08') TO ('2027-01-01 00:00:00+08');
