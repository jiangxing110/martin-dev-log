CREATE TABLE "public"."daily_statement_file" (
  "create_time" timestamptz(6) NOT NULL DEFAULT now(),
  "update_time" timestamptz(6) NOT NULL DEFAULT now(),
  "delete_time" timestamptz(6),
  "version" int4 NOT NULL DEFAULT 1,
  "remarks" varchar COLLATE "pg_catalog"."default",
  "id" int8 NOT NULL,
  "account_id" uuid NOT NULL,
  "statement_date" date NOT NULL,
  "statement_type" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'DAILY'::character varying,
  "currency" varchar COLLATE "pg_catalog"."default",
  "file_url" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "file_size" int8 NOT NULL DEFAULT 0,
  "status" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'completed'::character varying,
  "occurrence_time" timestamptz(6) NOT NULL DEFAULT now(),
  CONSTRAINT "PK_daily_statement_file_id" PRIMARY KEY ("id")
)
;

ALTER TABLE "public"."daily_statement_file" 
  OWNER TO "qbit_admin";

CREATE INDEX "IDX_daily_statement_file_account_date" ON "public"."daily_statement_file" USING btree (
  "account_id" "pg_catalog"."uuid_ops" ASC NULLS LAST,
  "statement_date" "pg_catalog"."date_ops" ASC NULLS LAST
);

CREATE UNIQUE INDEX "UK_daily_statement_file_unique" ON "public"."daily_statement_file" USING btree (
  "account_id" "pg_catalog"."uuid_ops" ASC NULLS LAST,
  "statement_date" "pg_catalog"."date_ops" ASC NULLS LAST,
  "statement_type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "currency" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

COMMENT ON COLUMN "public"."daily_statement_file"."remarks" IS '备注';

COMMENT ON COLUMN "public"."daily_statement_file"."account_id" IS '账户ID';

COMMENT ON COLUMN "public"."daily_statement_file"."statement_date" IS '账单日期';

COMMENT ON COLUMN "public"."daily_statement_file"."statement_type" IS '账单类型: DAILY/MONTHLY';

COMMENT ON COLUMN "public"."daily_statement_file"."currency" IS '币种';

COMMENT ON COLUMN "public"."daily_statement_file"."file_url" IS '账单文件URL';

COMMENT ON COLUMN "public"."daily_statement_file"."file_size" IS '文件大小(Byte)';

COMMENT ON COLUMN "public"."daily_statement_file"."status" IS '账单状态';

COMMENT ON COLUMN "public"."daily_statement_file"."occurrence_time" IS '业务发生时间';

CREATE TABLE "public"."balance_snapshot" (
  "id" int8 NOT NULL,
  "account_id" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "currency" varchar(10) COLLATE "pg_catalog"."default" NOT NULL,
  "wallet_type" varchar(32) COLLATE "pg_catalog"."default",
  "available" numeric(30,8) NOT NULL DEFAULT 0,
  "frozen" numeric(30,8) NOT NULL DEFAULT 0,
  "pending" numeric(30,8) NOT NULL DEFAULT 0,
  "snapshot_date" date NOT NULL,
  "create_time" timestamp(6) DEFAULT CURRENT_TIMESTAMP,
  "version" int4 NOT NULL DEFAULT 1,
  "update_time" timestamp(6) DEFAULT CURRENT_TIMESTAMP,
  "delete_time" timestamp(6),
  "remarks" varchar COLLATE "pg_catalog"."default",
  "balance_id" varchar(64) COLLATE "pg_catalog"."default",
  CONSTRAINT "balance_snapshot_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "balance_snapshot_account_id_currency_wallet_type_snapshot_d_key" UNIQUE ("account_id", "currency", "wallet_type", "snapshot_date")
)
;

ALTER TABLE "public"."balance_snapshot" 
  OWNER TO "qbit_admin";

COMMENT ON COLUMN "public"."balance_snapshot"."balance_id" IS '钱包余额ID（对应 balance.id，可为空，用于兼容历史聚合快照数据）';


