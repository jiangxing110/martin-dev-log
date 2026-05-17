CREATE TABLE "public"."dws_bb_card_finance_daily_p" (
  "id" int8 NOT NULL,
  "report_date" date NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "m_dom_auth_count" int4 DEFAULT 0,
  "m_int_auth_count" int4 DEFAULT 0,
  "v_dom_auth_count" int4 DEFAULT 0,
  "v_int_auth_count" int4 DEFAULT 0,
  "m_int_decline_count" int4 DEFAULT 0,
  "v_int_decline_count" int4 DEFAULT 0,
  "dom_decline_count" int4 DEFAULT 0,
  "m_int_reversal_count" int4 DEFAULT 0,
  "v_int_reversal_count" int4 DEFAULT 0,
  "dom_reversal_count" int4 DEFAULT 0,
  "m_int_refund_count" int4 DEFAULT 0,
  "v_int_refund_count" int4 DEFAULT 0,
  "dom_refund_count" int4 DEFAULT 0,
  "av_m_dom_count" int4 DEFAULT 0,
  "av_m_int_count" int4 DEFAULT 0,
  "av_v_dom_count" int4 DEFAULT 0,
  "av_v_int_count" int4 DEFAULT 0,
  "m_dom_clearing_vol" numeric(20,4) DEFAULT 0,
  "m_int_clearing_vol" numeric(20,4) DEFAULT 0,
  "v_dom_clearing_vol" numeric(20,4) DEFAULT 0,
  "v_int_clearing_vol" numeric(20,4) DEFAULT 0,
  "bb_rebate_base_amt" numeric(20,4) DEFAULT 0,
  "bb_channel_cashback_comm" numeric(20,4) DEFAULT 0,
  "active_card_count" int4 DEFAULT 0,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dws_bb_daily_pkey" PRIMARY KEY ("id", "report_date")
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
)
;

ALTER TABLE "public"."dws_bb_card_finance_daily_p"
  OWNER TO "qbit_admin";

-- 字段备注
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."id" IS '主键: 业务指纹, 2+YYYYMMDD+abs(hashtext(account_id))';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."report_date" IS '统计日期: 以交易落地北京时间为准';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."m_dom_auth_count" IS 'Master本地授权成功笔数 (计费因子: 0.11)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."m_int_auth_count" IS 'Master国际授权成功笔数 (计费因子: 0.48)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."v_dom_auth_count" IS 'VISA本地授权成功笔数 (计费因子: 0.073)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."v_int_auth_count" IS 'VISA国际授权成功笔数 (计费因子: 0.48)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."m_int_decline_count" IS 'Master国际拒绝笔数 (计费因子: 0.36 或 0.48)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."v_int_decline_count" IS 'VISA国际拒绝笔数 (计费因子: 0.36)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."dom_decline_count" IS '所有卡组织本地拒绝总笔数 (计费因子: 0.089/0.11)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."m_int_reversal_count" IS 'Master国际冲正笔数 (计费因子: 0.72)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."v_int_reversal_count" IS 'VISA国际冲正笔数 (计费因子: 0.71)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."dom_reversal_count" IS '所有卡组织本地冲正总笔数 (计费因子: 0.18)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."m_int_refund_count" IS 'Master国际退款成功笔数 (计费因子: 0.48)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."v_int_refund_count" IS 'VISA国际退款成功笔数 (计费因子: 0.48)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."dom_refund_count" IS '所有卡组织本地退款总笔数 (计费因子: 0.11)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."av_m_dom_count" IS '绑卡验证-Master本地成功笔数 (计费因子: 0.11)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."av_m_int_count" IS '绑卡验证-Master国际成功笔数 (计费因子: 0.48)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."av_v_dom_count" IS '绑卡验证-VISA本地成功笔数 (计费因子: 0.073)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."av_v_int_count" IS '绑卡验证-VISA国际成功笔数 (计费因子: 0.48)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."m_dom_clearing_vol" IS 'Master本地清算总额 (Volume Fee计费基数, 费率: 0.21%)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."m_int_clearing_vol" IS 'Master国际清算总额 (Volume Fee计费基数, 费率: 1.11%)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."v_dom_clearing_vol" IS 'VISA本地清算总额 (Volume Fee计费基数, 费率: 0.16%)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."v_int_clearing_vol" IS 'VISA国际清算总额 (Volume Fee计费基数, 费率: 1.16%)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."bb_rebate_base_amt" IS 'BB渠道客户返现总基数 (Consumption+Credit有效清算总额)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."bb_channel_cashback_comm" IS 'BB渠道返现抽成基数 (计算逻辑同返现基数, 费率由渠道侧动态给出)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."active_card_count" IS '当日去重后的活跃卡片数 (计费因子: 0.1/张)';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."version" IS '乐观锁版本号';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."remarks" IS '统计备注';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."create_time" IS '系统记录创建时间';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."update_time" IS '系统最后更新时间';
COMMENT ON COLUMN "public"."dws_bb_card_finance_daily_p"."delete_time" IS '逻辑删除时间戳';
COMMENT ON TABLE "public"."dws_bb_card_finance_daily_p" IS 'BB渠道财务日报汇总表-包含所有计费基数因子';

-- 2026 年分区
ALTER TABLE "public"."dws_bb_card_finance_daily_p" ATTACH PARTITION "public"."dws_bb_cost_daily_2026" FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
