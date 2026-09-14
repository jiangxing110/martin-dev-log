-- 销售佣金返佣规则维表
-- 规则重建版本：2026-09-14
-- 口径：按当前部门 ID 精确匹配；国内新增销售小组只配置非加密产品。
-- 说明：product/provider/item 为空表示通配；start_time/end_time 使用左闭右开区间。

BEGIN;

CREATE TABLE IF NOT EXISTS "dim"."dim_sales_commission_rule" (
  "id" int8 NOT NULL,
  "rule_code" varchar(64) NOT NULL,
  "rule_name" varchar(255) NOT NULL,
  "department_id" varchar(64) NOT NULL,
  "product" varchar(64),
  "provider" varchar(64),
  "item" varchar(64),
  "commission_base_type" varchar(32) NOT NULL,
  "active_days_min" int4,
  "active_days_max" int4,
  "commission_rate" numeric(10,6) NOT NULL,
  "invite_type" varchar(32) NOT NULL DEFAULT 'all',
  "start_time" timestamp(6) NOT NULL,
  "end_time" timestamp(6) NOT NULL DEFAULT timestamp '2099-01-01 00:00:00',
  "priority" int4 NOT NULL DEFAULT 100,
  "enabled" bool NOT NULL DEFAULT true,
  "remarks" varchar(1000),
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dim_sales_commission_rule_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "dim"."dim_sales_commission_rule" OWNER TO "flink_cdc_user";

COMMENT ON TABLE "dim"."dim_sales_commission_rule" IS '销售佣金返佣规则维表，按当前部门、产品、渠道、收费项、活跃天数和直邀类型维护佣金率';
COMMENT ON COLUMN "dim"."dim_sales_commission_rule"."product" IS '产品线编码，空表示全部产品';
COMMENT ON COLUMN "dim"."dim_sales_commission_rule"."commission_base_type" IS '计佣基数类型：gp=按毛利计佣，actual_fee=按实际收费计佣';
COMMENT ON COLUMN "dim"."dim_sales_commission_rule"."invite_type" IS '直邀类型：all=不区分，direct=直邀，non_direct=非直邀';

CREATE INDEX IF NOT EXISTS "idx_dim_sales_commission_rule_code"
ON "dim"."dim_sales_commission_rule" ("rule_code");

CREATE INDEX IF NOT EXISTS "idx_dim_sales_commission_rule_match"
ON "dim"."dim_sales_commission_rule" ("department_id", "product", "provider", "item", "invite_type", "enabled", "priority");

CREATE INDEX IF NOT EXISTS "idx_dim_sales_commission_rule_time"
ON "dim"."dim_sales_commission_rule" ("start_time", "end_time");

-- 规则重建：清空整张规则表，避免旧部门、旧产品或旧规则残留。
TRUNCATE TABLE "dim"."dim_sales_commission_rule";

-- 当前组织中允许计算 crypto 的部门：13～20 行的实际业务部门。
-- 海外业务为组织节点，不直接承接销售人员，因此不生成部门规则。
WITH crypto_departments(department_id) AS (
  VALUES
    ('2077248232127864834'), -- 国际销售团队
    ('2028709205416460290'), -- 大客户销售部
    ('1762301052057112578'), -- 其他
    ('1740320675756810242'), -- 海外业务销售部 - 1
    ('1851130772357509121'), -- 海外业务销售部 - 2，下面单独配置
    ('1740320716902932481'), -- 大客户管理部
    ('1760576792068489218'), -- 创新业务部
    ('2097615280722743297')  -- 销售三组
),
ordinary_departments(department_id, department_name) AS (
  VALUES
    ('1740319905791647746', '销售一部'),
    ('1740319923059597313', '销售二部'),
    ('2066369412858433538', '销售三部'),
    ('2077248232127864834', '国际销售团队'),
    ('1740320716902932481', '大客户管理部'),
    ('1740320675756810242', '海外业务销售部 - 1'),
    ('1762301052057112578', '其他'),
    ('1760576792068489218', '创新业务部'),
    ('2097614575010123778', '销售一组'),
    ('2097614680696270850', '销售二组'),
    ('2097614776689037313', '销售三组'),
    ('2097614875836264450', '销售四组'),
    ('2097615094967676929', '销售一组'),
    ('2097615188473221122', '销售二组'),
    ('2097615280722743297', '销售三组'),
    ('2028709205416460290', '大客户销售部')
),
products(product, product_name, rate_0_180, rate_181_365, rate_366_1095) AS (
  VALUES
    ('qbit_card', '量子卡', 0.120000::numeric, 0.060000::numeric, 0.036000::numeric),
    ('group_account', '全球账户', 0.120000::numeric, 0.060000::numeric, 0.036000::numeric),
    ('treasury', '理财', 0.200000::numeric, 0.060000::numeric, 0.036000::numeric),
    ('crypto', '加密稳定币', 0.120000::numeric, 0.060000::numeric, 0.036000::numeric)
),
active_ranges(active_days_min, active_days_max, range_code, range_name, rate_column) AS (
  VALUES
    (0, 180, '0_180', '0-180天', 'rate_0_180'),
    (181, 365, '181_365', '181-365天', 'rate_181_365'),
    (366, 1095, '366_1095', '366-1095天', 'rate_366_1095')
),
generated_rules AS (
  SELECT
    100000 + row_number() OVER (ORDER BY d.department_id, p.product, ar.active_days_min) AS id,
    concat('gp_', d.department_id, '_', p.product, '_', ar.range_code) AS rule_code,
    concat(d.department_name, '-', p.product_name, '-GP-', ar.range_name) AS rule_name,
    d.department_id,
    p.product,
    NULL::varchar AS provider,
    NULL::varchar AS item,
    'gp' AS commission_base_type,
    ar.active_days_min,
    ar.active_days_max,
    CASE ar.rate_column
      WHEN 'rate_0_180' THEN p.rate_0_180
      WHEN 'rate_181_365' THEN p.rate_181_365
      ELSE p.rate_366_1095
    END AS commission_rate,
    'all' AS invite_type,
    timestamp '2026-01-01 00:00:00' AS start_time,
    timestamp '2099-01-01 00:00:00' AS end_time,
    100 AS priority,
    true AS enabled,
    CASE WHEN p.product = 'crypto' THEN '加密业务普通GP阶梯规则' ELSE '普通产品GP阶梯规则' END AS remarks
  FROM ordinary_departments d
  CROSS JOIN products p
  LEFT JOIN crypto_departments cd ON cd.department_id = d.department_id
  CROSS JOIN active_ranges ar
  WHERE p.product <> 'crypto' OR cd.department_id IS NOT NULL
),
inserted AS (
  INSERT INTO "dim"."dim_sales_commission_rule" (
    "id", "rule_code", "rule_name", "department_id", "product", "provider", "item",
    "commission_base_type", "active_days_min", "active_days_max", "commission_rate",
    "invite_type", "start_time", "end_time", "priority", "enabled", "remarks"
  )
  SELECT
    id, rule_code, rule_name, department_id, product, provider, item,
    commission_base_type, active_days_min, active_days_max, commission_rate,
    invite_type, start_time, end_time, priority, enabled, remarks
  FROM generated_rules
  ON CONFLICT ("id") DO UPDATE SET
    "rule_code" = EXCLUDED."rule_code",
    "rule_name" = EXCLUDED."rule_name",
    "department_id" = EXCLUDED."department_id",
    "product" = EXCLUDED."product",
    "provider" = EXCLUDED."provider",
    "item" = EXCLUDED."item",
    "commission_base_type" = EXCLUDED."commission_base_type",
    "active_days_min" = EXCLUDED."active_days_min",
    "active_days_max" = EXCLUDED."active_days_max",
    "commission_rate" = EXCLUDED."commission_rate",
    "invite_type" = EXCLUDED."invite_type",
    "start_time" = EXCLUDED."start_time",
    "end_time" = EXCLUDED."end_time",
    "priority" = EXCLUDED."priority",
    "enabled" = EXCLUDED."enabled",
    "remarks" = EXCLUDED."remarks",
    "update_time" = now(),
    "delete_time" = NULL
  RETURNING 1
)
SELECT COUNT(*) AS ordinary_rule_count FROM inserted;

-- 普通 crypto 部门：活跃超过 1095 天仍保留收入记录，但佣金率为 0。
WITH crypto_zero_departments(department_id, department_name) AS (
  VALUES
    ('2077248232127864834', '国际销售团队'),
    ('2028709205416460290', '大客户销售部'),
    ('1762301052057112578', '其他'),
    ('1740320675756810242', '海外业务销售部 - 1'),
    ('1740320716902932481', '大客户管理部'),
    ('1760576792068489218', '创新业务部'),
    ('2097615280722743297', '销售三组')
)
INSERT INTO "dim"."dim_sales_commission_rule" (
  "id", "rule_code", "rule_name", "department_id", "product", "provider", "item",
  "commission_base_type", "active_days_min", "active_days_max", "commission_rate",
  "invite_type", "start_time", "end_time", "priority", "enabled", "remarks"
)
SELECT
  100069 + ROW_NUMBER() OVER (ORDER BY department_id),
  concat('gp_', department_id, '_crypto_over_1095'),
  concat(department_name, '-加密稳定币-GP-1096天以上-0%'),
  department_id, 'crypto', NULL, NULL, 'gp', 1096, 999999, 0.000000,
  'all', timestamp '2026-01-01', timestamp '2099-01-01', 100, true,
  '加密业务活跃超过1095天，佣金率为0'
FROM crypto_zero_departments;

-- 海外业务销售部 - 2：直邀/非直邀特殊规则，product=NULL 表示所有产品。
INSERT INTO "dim"."dim_sales_commission_rule" (
  "id", "rule_code", "rule_name", "department_id", "product", "provider", "item",
  "commission_base_type", "active_days_min", "active_days_max", "commission_rate",
  "invite_type", "start_time", "end_time", "priority", "enabled", "remarks"
)
VALUES
  (400001, 'overseas_sales_2_direct_gp_20pct', '海外业务销售部-2-直邀-GP-20%', '1851130772357509121', NULL, NULL, NULL, 'gp', NULL, NULL, 0.200000, 'direct', timestamp '2026-01-01', timestamp '2099-01-01', 10, true, '海外业务销售部-2直邀客户按GP 20%计佣'),
  (400002, 'overseas_sales_2_non_direct_gp_10pct', '海外业务销售部-2-非直邀-GP-10%', '1851130772357509121', NULL, NULL, NULL, 'gp', NULL, NULL, 0.100000, 'non_direct', timestamp '2026-01-01', timestamp '2099-01-01', 10, true, '海外业务销售部-2非直邀客户按GP 10%计佣')
ON CONFLICT ("id") DO UPDATE SET
  "rule_code" = EXCLUDED."rule_code",
  "rule_name" = EXCLUDED."rule_name",
  "department_id" = EXCLUDED."department_id",
  "product" = EXCLUDED."product",
  "provider" = EXCLUDED."provider",
  "item" = EXCLUDED."item",
  "commission_base_type" = EXCLUDED."commission_base_type",
  "active_days_min" = EXCLUDED."active_days_min",
  "active_days_max" = EXCLUDED."active_days_max",
  "commission_rate" = EXCLUDED."commission_rate",
  "invite_type" = EXCLUDED."invite_type",
  "start_time" = EXCLUDED."start_time",
  "end_time" = EXCLUDED."end_time",
  "priority" = EXCLUDED."priority",
  "enabled" = EXCLUDED."enabled",
  "remarks" = EXCLUDED."remarks",
  "update_time" = now(),
  "delete_time" = NULL;

-- OpenAPI一次性费用：按实际收费15%。适用于当前可承接销售业务的部门。
WITH departments(department_id, department_name) AS (
  SELECT * FROM (VALUES
    ('1740319905791647746', '销售一部'), ('1740319923059597313', '销售二部'),
    ('2066369412858433538', '销售三部'), ('2077248232127864834', '国际销售团队'),
    ('1740320716902932481', '大客户管理部'), ('1740320675756810242', '海外业务销售部 - 1'),
    ('1762301052057112578', '其他'), ('1760576792068489218', '创新业务部'),
    ('2097614575010123778', '销售一组'), ('2097614680696270850', '销售二组'),
    ('2097614776689037313', '销售三组'), ('2097614875836264450', '销售四组'),
    ('2097615094967676929', '销售一组'), ('2097615188473221122', '销售二组'),
    ('2097615280722743297', '销售三组'), ('2028709205416460290', '大客户销售部')
  ) AS x(department_id, department_name)
),
generated_rules AS (
  SELECT
    200000 + row_number() OVER (ORDER BY d.department_id) AS id,
    concat('open_api_api_one_time_fee_', d.department_id, '_15pct') AS rule_code,
    concat(d.department_name, '-OpenAPI一次性费用-15%') AS rule_name,
    d.department_id, 'open_api' AS product, NULL::varchar AS provider, 'api_one_time_fee' AS item,
    'actual_fee' AS commission_base_type, NULL::int4 AS active_days_min, NULL::int4 AS active_days_max,
    0.150000::numeric AS commission_rate, 'all' AS invite_type,
    timestamp '2026-01-01' AS start_time, timestamp '2099-01-01' AS end_time,
    100 AS priority, true AS enabled, 'OpenAPI一次性费用按实际收费15%计佣' AS remarks
  FROM departments d
)
INSERT INTO "dim"."dim_sales_commission_rule" (
  "id", "rule_code", "rule_name", "department_id", "product", "provider", "item",
  "commission_base_type", "active_days_min", "active_days_max", "commission_rate",
  "invite_type", "start_time", "end_time", "priority", "enabled", "remarks"
)
SELECT * FROM generated_rules
ON CONFLICT ("id") DO UPDATE SET
  "rule_code" = EXCLUDED."rule_code", "rule_name" = EXCLUDED."rule_name", "department_id" = EXCLUDED."department_id",
  "product" = EXCLUDED."product", "provider" = EXCLUDED."provider", "item" = EXCLUDED."item",
  "commission_base_type" = EXCLUDED."commission_base_type", "active_days_min" = EXCLUDED."active_days_min", "active_days_max" = EXCLUDED."active_days_max",
  "commission_rate" = EXCLUDED."commission_rate", "invite_type" = EXCLUDED."invite_type", "start_time" = EXCLUDED."start_time", "end_time" = EXCLUDED."end_time",
  "priority" = EXCLUDED."priority", "enabled" = EXCLUDED."enabled", "remarks" = EXCLUDED."remarks", "update_time" = now(), "delete_time" = NULL;

-- OpenAPI月费：0-365天10%，366-1095天0%，按实际收费计佣。
WITH departments(department_id, department_name) AS (
  SELECT * FROM (VALUES
    ('1740319905791647746', '销售一部'), ('1740319923059597313', '销售二部'), ('2066369412858433538', '销售三部'),
    ('2077248232127864834', '国际销售团队'), ('1740320716902932481', '大客户管理部'), ('1740320675756810242', '海外业务销售部 - 1'),
    ('1762301052057112578', '其他'), ('1760576792068489218', '创新业务部'), ('2097614575010123778', '销售一组'),
    ('2097614680696270850', '销售二组'), ('2097614776689037313', '销售三组'), ('2097614875836264450', '销售四组'),
    ('2097615094967676929', '销售一组'), ('2097615188473221122', '销售二组'), ('2097615280722743297', '销售三组'),
    ('2028709205416460290', '大客户销售部')
  ) AS x(department_id, department_name)
),
ranges(active_days_min, active_days_max, range_code, rate) AS (
  VALUES (0, 365, '0_365', 0.100000::numeric), (366, 1095, '366_1095', 0.000000::numeric)
),
generated_rules AS (
  SELECT
    300000 + row_number() OVER (ORDER BY d.department_id, r.active_days_min) AS id,
    concat('open_api_monthly_', d.department_id, '_', r.range_code) AS rule_code,
    concat(d.department_name, '-OpenAPI月费-', r.range_code) AS rule_name,
    d.department_id, 'open_api' AS product, NULL::varchar AS provider, 'api_monthly_fee' AS item,
    'actual_fee' AS commission_base_type, r.active_days_min, r.active_days_max, r.rate AS commission_rate, 'all' AS invite_type,
    timestamp '2026-01-01' AS start_time, timestamp '2099-01-01' AS end_time, 100 AS priority, true AS enabled,
    'OpenAPI月费按实际收费和活跃天数计佣' AS remarks
  FROM departments d CROSS JOIN ranges r
)
INSERT INTO "dim"."dim_sales_commission_rule" (
  "id", "rule_code", "rule_name", "department_id", "product", "provider", "item",
  "commission_base_type", "active_days_min", "active_days_max", "commission_rate",
  "invite_type", "start_time", "end_time", "priority", "enabled", "remarks"
)
SELECT * FROM generated_rules
ON CONFLICT ("id") DO UPDATE SET
  "rule_code" = EXCLUDED."rule_code", "rule_name" = EXCLUDED."rule_name", "department_id" = EXCLUDED."department_id",
  "product" = EXCLUDED."product", "provider" = EXCLUDED."provider", "item" = EXCLUDED."item",
  "commission_base_type" = EXCLUDED."commission_base_type", "active_days_min" = EXCLUDED."active_days_min", "active_days_max" = EXCLUDED."active_days_max",
  "commission_rate" = EXCLUDED."commission_rate", "invite_type" = EXCLUDED."invite_type", "start_time" = EXCLUDED."start_time", "end_time" = EXCLUDED."end_time",
  "priority" = EXCLUDED."priority", "enabled" = EXCLUDED."enabled", "remarks" = EXCLUDED."remarks", "update_time" = now(), "delete_time" = NULL;

COMMIT;
