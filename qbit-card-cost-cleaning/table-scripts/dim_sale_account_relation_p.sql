CREATE TABLE "dim"."dim_sale_account_relation_p" (
  "id" int8 NOT NULL,
  "report_date" date NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "root_account_id" varchar(36) COLLATE "pg_catalog"."default",
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "operation_manager_id" varchar(64) COLLATE "pg_catalog"."default",
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dim_sale_account_relation_pkey" PRIMARY KEY ("id", "report_date")
);

ALTER TABLE "dim"."dim_sale_account_relation_p"
  OWNER TO "qbit_admin";

COMMENT ON TABLE "dim"."dim_sale_account_relation_p" IS '客户销售关系日快照表';
COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."report_date" IS '快照日期-分区键';
COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."account_id" IS '账户ID';
COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."root_account_id" IS '根账户ID, 用于API子户回退';
COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."sale_id" IS '销售ID';
COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."am_id" IS 'AM ID';
COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."operation_manager_id" IS '运营经理ID';

CREATE INDEX "idx_dim_sale_account_relation_acc" ON "dim"."dim_sale_account_relation_p" USING btree (
  "report_date" ASC NULLS LAST,
  "account_id" COLLATE "pg_catalog"."default" ASC NULLS LAST
);

COMMENT ON COLUMN "dim"."dim_sale_account_relation_p"."remarks" IS '建议从 salesAccountRelation 最早生效时间 2021-04-21 开始初始化';
