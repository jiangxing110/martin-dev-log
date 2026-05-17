CREATE TABLE "public"."dws_account_metric_2026" (
  "id" int8 NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "metric_code" int4 NOT NULL,
  "metric_value" numeric(38,10) NOT NULL DEFAULT 0,
  "create_date" timestamp(6) NOT NULL,
  "extra" jsonb,
  "version" int4 DEFAULT 1,
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  CONSTRAINT "dws_account_metric_di_pkey" PRIMARY KEY ("id")
)
;

ALTER TABLE "public"."dws_account_metric_2026" 
  OWNER TO "qbit_admin";

COMMENT ON COLUMN "public"."dws_account_metric_2026"."id" IS '主键ID，全局唯一，由应用或调度层生成，不依赖业务唯一约束';

COMMENT ON COLUMN "public"."dws_account_metric_2026"."account_id" IS '账户ID，统一账户体系下的唯一标识（量子账户 / 全球账户 / 加密账户等）';

COMMENT ON COLUMN "public"."dws_account_metric_2026"."metric_code" IS '指标编码（整型），由 Java 项目内 MetricEnum 定义，代表具体统计指标';

COMMENT ON COLUMN "public"."dws_account_metric_2026"."metric_value" IS '指标数值，高精度数值类型，金额类指标统一按标准币种口径存储';

COMMENT ON COLUMN "public"."dws_account_metric_2026"."create_date" IS '指标归属日期（统计日期），用于日维度聚合，与数据写入时间无关';

COMMENT ON COLUMN "public"."dws_account_metric_2026"."extra" IS '扩展字段（JSON），用于存储非标准化维度或临时业务属性，避免频繁表结构调整';

COMMENT ON COLUMN "public"."dws_account_metric_2026"."version" IS '数据版本号或批次号，用于支持补数、回刷及多批次统计';

COMMENT ON COLUMN "public"."dws_account_metric_2026"."create_time" IS '数据创建时间，记录该行数据首次写入数据库的时间';

COMMENT ON COLUMN "public"."dws_account_metric_2026"."update_time" IS '数据更新时间，记录该行数据最近一次被更新的时间';

COMMENT ON COLUMN "public"."dws_account_metric_2026"."delete_time" IS '逻辑删除时间，非空表示该条指标数据已被废弃';

COMMENT ON COLUMN "public"."dws_account_metric_2026"."remarks" IS '备注说明，用于记录指标口径说明、异常标注或人工修正信息';

COMMENT ON TABLE "public"."dws_account_metric_2026" IS '账户级指标事实表（DWS层竖表模型），统一承载量子账户、量子卡、全球账户、加密资产等资金类指标，支持多时间口径、多业务维度的日级统计与分析';