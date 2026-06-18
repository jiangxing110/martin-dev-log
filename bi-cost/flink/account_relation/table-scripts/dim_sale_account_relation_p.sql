CREATE TABLE "dim"."dim_sale_account_relation_p" (
  "id" varchar(64) NOT NULL,
  "relation_account_id" varchar(64) NOT NULL,
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

ALTER TABLE "dim"."dim_sale_account_relation_p"
  OWNER TO "qbit_admin";

COMMENT ON TABLE "dim"."dim_sale_account_relation_p" IS '销售关系时间线维表，不展开子户';
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

CREATE INDEX "idx_dim_sale_relation_account_time" ON "dim"."dim_sale_account_relation_p" USING btree (
  "relation_account_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "relation_start_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST,
  "relation_end_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dim_sale_relation_sale_am" ON "dim"."dim_sale_account_relation_p" USING btree (
  "sale_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "am_id" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE TABLE "dim"."dim_sale_account_relation_2021" PARTITION OF "dim"."dim_sale_account_relation_p"
FOR VALUES FROM ('2021-01-01 00:00:00') TO ('2022-01-01 00:00:00');

CREATE TABLE "dim"."dim_sale_account_relation_2022" PARTITION OF "dim"."dim_sale_account_relation_p"
FOR VALUES FROM ('2022-01-01 00:00:00') TO ('2023-01-01 00:00:00');

CREATE TABLE "dim"."dim_sale_account_relation_2023" PARTITION OF "dim"."dim_sale_account_relation_p"
FOR VALUES FROM ('2023-01-01 00:00:00') TO ('2024-01-01 00:00:00');

CREATE TABLE "dim"."dim_sale_account_relation_2024" PARTITION OF "dim"."dim_sale_account_relation_p"
FOR VALUES FROM ('2024-01-01 00:00:00') TO ('2025-01-01 00:00:00');

CREATE TABLE "dim"."dim_sale_account_relation_2025" PARTITION OF "dim"."dim_sale_account_relation_p"
FOR VALUES FROM ('2025-01-01 00:00:00') TO ('2026-01-01 00:00:00');

CREATE TABLE "dim"."dim_sale_account_relation_2026" PARTITION OF "dim"."dim_sale_account_relation_p"
FOR VALUES FROM ('2026-01-01 00:00:00') TO ('2027-01-01 00:00:00');

CREATE TABLE "dim"."dim_sale_account_relation_2027" PARTITION OF "dim"."dim_sale_account_relation_p"
FOR VALUES FROM ('2027-01-01 00:00:00') TO ('2028-01-01 00:00:00');
