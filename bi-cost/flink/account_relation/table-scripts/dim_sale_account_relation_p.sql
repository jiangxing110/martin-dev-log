CREATE TABLE "public"."dim_sale_account_relation_p" (
  "id" uuid NOT NULL,
  "relation_account_id" uuid NOT NULL,
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
);

ALTER TABLE "public"."dim_sale_account_relation_p"
  OWNER TO "qbit_admin";

COMMENT ON TABLE "public"."dim_sale_account_relation_p" IS '销售关系时间线维表，不展开子户';
COMMENT ON COLUMN "public"."dim_sale_account_relation_p"."id" IS '原 salesAccountRelation.id';
COMMENT ON COLUMN "public"."dim_sale_account_relation_p"."relation_account_id" IS '销售关系账户ID，对应 salesAccountRelation.accountId';
COMMENT ON COLUMN "public"."dim_sale_account_relation_p"."sale_id" IS '销售ID，对应 salesAccountRelation.salesId';
COMMENT ON COLUMN "public"."dim_sale_account_relation_p"."am_id" IS 'AM ID，对应 salesAccountRelation.amId';
COMMENT ON COLUMN "public"."dim_sale_account_relation_p"."operation_manager_id" IS '运营管理人ID，对应 salesAccountRelation.operationManagerId';
COMMENT ON COLUMN "public"."dim_sale_account_relation_p"."relation_start_time" IS '销售关系生效时间，对应 salesAccountRelation.createTime';
COMMENT ON COLUMN "public"."dim_sale_account_relation_p"."relation_end_time" IS '销售关系结束时间，对应 salesAccountRelation.deleteTime';
COMMENT ON COLUMN "public"."dim_sale_account_relation_p"."version" IS '乐观锁版本';
COMMENT ON COLUMN "public"."dim_sale_account_relation_p"."remarks" IS '备注';
COMMENT ON COLUMN "public"."dim_sale_account_relation_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "public"."dim_sale_account_relation_p"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "public"."dim_sale_account_relation_p"."delete_time" IS '逻辑删除时间';

CREATE INDEX "idx_dim_sale_relation_account_time" ON "public"."dim_sale_account_relation_p" USING btree (
  "relation_account_id" "pg_catalog"."uuid_ops" ASC NULLS LAST,
  "relation_start_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST,
  "relation_end_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dim_sale_relation_sale_am" ON "public"."dim_sale_account_relation_p" USING btree (
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

ALTER TABLE "public"."dim_sale_account_relation_p" ATTACH PARTITION "public"."dim_sale_account_relation_2026_01" FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2026-02-01 00:00:00');
ALTER TABLE "public"."dim_sale_account_relation_p" ATTACH PARTITION "public"."dim_sale_account_relation_2026_02" FOR VALUES FROM ('2026-02-01 00:00:00') TO ('2026-03-01 00:00:00');
ALTER TABLE "public"."dim_sale_account_relation_p" ATTACH PARTITION "public"."dim_sale_account_relation_2026_03" FOR VALUES FROM ('2026-03-01 00:00:00') TO ('2026-04-01 00:00:00');
ALTER TABLE "public"."dim_sale_account_relation_p" ATTACH PARTITION "public"."dim_sale_account_relation_2026_04" FOR VALUES FROM ('2026-04-01 00:00:00') TO ('2026-05-01 00:00:00');
ALTER TABLE "public"."dim_sale_account_relation_p" ATTACH PARTITION "public"."dim_sale_account_relation_2026_05" FOR VALUES FROM ('2026-05-01 00:00:00') TO ('2026-06-01 00:00:00');
ALTER TABLE "public"."dim_sale_account_relation_p" ATTACH PARTITION "public"."dim_sale_account_relation_2026_06" FOR VALUES FROM ('2026-06-01 00:00:00') TO ('2026-07-01 00:00:00');
ALTER TABLE "public"."dim_sale_account_relation_p" ATTACH PARTITION "public"."dim_sale_account_relation_2026_07" FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-08-01 00:00:00');
ALTER TABLE "public"."dim_sale_account_relation_p" ATTACH PARTITION "public"."dim_sale_account_relation_2026_08" FOR VALUES FROM ('2026-08-01 00:00:00') TO ('2026-09-01 00:00:00');
ALTER TABLE "public"."dim_sale_account_relation_p" ATTACH PARTITION "public"."dim_sale_account_relation_2026_09" FOR VALUES FROM ('2026-09-01 00:00:00') TO ('2026-10-01 00:00:00');
ALTER TABLE "public"."dim_sale_account_relation_p" ATTACH PARTITION "public"."dim_sale_account_relation_2026_10" FOR VALUES FROM ('2026-10-01 00:00:00') TO ('2026-11-01 00:00:00');
ALTER TABLE "public"."dim_sale_account_relation_p" ATTACH PARTITION "public"."dim_sale_account_relation_2026_11" FOR VALUES FROM ('2026-11-01 00:00:00') TO ('2026-12-01 00:00:00');
ALTER TABLE "public"."dim_sale_account_relation_p" ATTACH PARTITION "public"."dim_sale_account_relation_2026_12" FOR VALUES FROM ('2026-12-01 00:00:00') TO ('2027-01-01 00:00:00');
