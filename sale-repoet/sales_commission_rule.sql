-- 销售佣金返佣规则表
-- 说明：
-- 1. department_code 使用 system_department.id。
-- 2. product/provider/item 为空表示通配。
-- 3. start_time/end_time 使用左闭右开区间：[start_time, end_time)。
-- 4. 8号快照写入 sales_commission_snapshot_detail 时，需要保存命中的 rule_code、commission_rate。

CREATE TABLE "dws"."sales_commission_rule" (
  "id" int8 NOT NULL,
  "rule_code" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "rule_name" varchar(255) COLLATE "pg_catalog"."default" NOT NULL,
  "department_code" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "product" varchar(64) COLLATE "pg_catalog"."default",
  "provider" varchar(64) COLLATE "pg_catalog"."default",
  "item" varchar(64) COLLATE "pg_catalog"."default",
  "commission_base_type" varchar(32) COLLATE "pg_catalog"."default" NOT NULL,
  "active_days_min" int4,
  "active_days_max" int4,
  "commission_rate" numeric(10,6) NOT NULL,
  "invite_type" varchar(32) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'all',
  "start_time" timestamp(6) NOT NULL,
  "end_time" timestamp(6),
  "priority" int4 NOT NULL DEFAULT 100,
  "enabled" bool NOT NULL DEFAULT true,
  "remarks" varchar(1000) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "sales_commission_rule_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "uk_sales_commission_rule_code" UNIQUE ("rule_code")
);

ALTER TABLE "dws"."sales_commission_rule"
  OWNER TO "flink_cdc_user";

COMMENT ON TABLE "dws"."sales_commission_rule" IS '销售佣金返佣规则表，用于按部门、产品、渠道、收费项、活跃天数和直邀类型维护佣金率';
COMMENT ON COLUMN "dws"."sales_commission_rule"."id" IS '主键ID';
COMMENT ON COLUMN "dws"."sales_commission_rule"."rule_code" IS '规则编码，需写入佣金快照明细用于历史追溯';
COMMENT ON COLUMN "dws"."sales_commission_rule"."rule_name" IS '规则名称';
COMMENT ON COLUMN "dws"."sales_commission_rule"."department_code" IS '部门ID，来源system_department.id';
COMMENT ON COLUMN "dws"."sales_commission_rule"."product" IS '产品线编码，空表示全部产品；示例：qbit_card、group_account、crypto、treasury、open_api';
COMMENT ON COLUMN "dws"."sales_commission_rule"."provider" IS '服务商/渠道编码，空表示全部provider';
COMMENT ON COLUMN "dws"."sales_commission_rule"."item" IS '收费项编码，空表示全部收费项；OpenAPI一次性费用、月费可用该字段区分';
COMMENT ON COLUMN "dws"."sales_commission_rule"."commission_base_type" IS '计佣基数类型：gp=按毛利计佣，actual_fee=按实际收费计佣';
COMMENT ON COLUMN "dws"."sales_commission_rule"."active_days_min" IS '活跃天数下限，包含；空表示不限制';
COMMENT ON COLUMN "dws"."sales_commission_rule"."active_days_max" IS '活跃天数上限，包含；空表示不限制';
COMMENT ON COLUMN "dws"."sales_commission_rule"."commission_rate" IS '佣金率，例如0.120000表示12%';
COMMENT ON COLUMN "dws"."sales_commission_rule"."invite_type" IS '直邀类型：all=不区分，direct=直邀，non_direct=非直邀';
COMMENT ON COLUMN "dws"."sales_commission_rule"."start_time" IS '规则生效开始时间，包含';
COMMENT ON COLUMN "dws"."sales_commission_rule"."end_time" IS '规则生效结束时间，不包含；空表示长期有效';
COMMENT ON COLUMN "dws"."sales_commission_rule"."priority" IS '规则优先级，数字越小优先级越高';
COMMENT ON COLUMN "dws"."sales_commission_rule"."enabled" IS '是否启用';
COMMENT ON COLUMN "dws"."sales_commission_rule"."remarks" IS '备注';
COMMENT ON COLUMN "dws"."sales_commission_rule"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dws"."sales_commission_rule"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "dws"."sales_commission_rule"."delete_time" IS '逻辑删除时间';

CREATE INDEX "idx_sales_commission_rule_match"
ON "dws"."sales_commission_rule" (
  "department_code",
  "product",
  "provider",
  "item",
  "invite_type",
  "enabled",
  "priority"
);

CREATE INDEX "idx_sales_commission_rule_time"
ON "dws"."sales_commission_rule" (
  "start_time",
  "end_time"
);

-- 初始规则数据：除海外业务销售部 - 2 外，按产品和活跃天数阶梯计佣。
WITH normal_departments(department_code, department_name) AS (
  VALUES
    ('1740319905791647746', '销售一部'),
    ('1740319923059597313', '销售二部'),
    ('2066369412858433538', '销售三部'),
    ('2077248232127864834', '销售四部'),
    ('1740320716902932481', '大客户管理部'),
    ('1740320675756810242', '海外业务销售部 - 1'),
    ('1762301052057112578', '其他'),
    ('1760576792068489218', '创新业务部')
),
gp_products(product, product_name, rate_0_180, rate_181_365, rate_366_1095) AS (
  VALUES
    ('qbit_card', '量子卡', 0.120000::numeric, 0.060000::numeric, 0.036000::numeric),
    ('group_account', '全球账户付款', 0.120000::numeric, 0.060000::numeric, 0.036000::numeric),
    ('crypto', '加密稳定币', 0.120000::numeric, 0.060000::numeric, 0.036000::numeric),
    ('treasury', '理财', 0.200000::numeric, 0.060000::numeric, 0.036000::numeric),
    ('acquiring', '收单', 0.120000::numeric, 0.060000::numeric, 0.036000::numeric),
    ('scan_to_pay', '扫码支付', 0.120000::numeric, 0.060000::numeric, 0.036000::numeric)
),
active_ranges(active_days_min, active_days_max, range_code, range_name, rate_column) AS (
  VALUES
    (0, 180, '0_180', '0-180天', 'rate_0_180'),
    (181, 365, '181_365', '181-365天', 'rate_181_365'),
    (366, 1095, '366_1095', '366-1095天', 'rate_366_1095')
),
generated_rules AS (
  SELECT
    100000 + row_number() OVER (ORDER BY d.department_code, p.product, r.active_days_min) AS id,
    concat('gp_', d.department_code, '_', p.product, '_', r.range_code) AS rule_code,
    concat(d.department_name, '-', p.product_name, '-GP-', r.range_name) AS rule_name,
    d.department_code,
    p.product,
    NULL::varchar AS provider,
    NULL::varchar AS item,
    'gp' AS commission_base_type,
    r.active_days_min,
    r.active_days_max,
    CASE r.rate_column
      WHEN 'rate_0_180' THEN p.rate_0_180
      WHEN 'rate_181_365' THEN p.rate_181_365
      ELSE p.rate_366_1095
    END AS commission_rate,
    'all' AS invite_type,
    timestamp '2026-06-01 00:00:00' AS start_time,
    NULL::timestamp AS end_time,
    100 AS priority,
    true AS enabled,
    '常规产品按GP和活跃天数阶梯计佣' AS remarks
  FROM normal_departments d
  CROSS JOIN gp_products p
  CROSS JOIN active_ranges r
)
INSERT INTO "dws"."sales_commission_rule" (
  "id", "rule_code", "rule_name", "department_code", "product", "provider", "item",
  "commission_base_type", "active_days_min", "active_days_max", "commission_rate",
  "invite_type", "start_time", "end_time", "priority", "enabled", "remarks"
)
SELECT
  id, rule_code, rule_name, department_code, product, provider, item,
  commission_base_type, active_days_min, active_days_max, commission_rate,
  invite_type, start_time, end_time, priority, enabled, remarks
FROM generated_rules
ON CONFLICT ("rule_code") DO NOTHING;

-- OpenAPI一次性费用：按实际收费15%。
WITH normal_departments(department_code, department_name) AS (
  VALUES
    ('1740319905791647746', '销售一部'),
    ('1740319923059597313', '销售二部'),
    ('2066369412858433538', '销售三部'),
    ('2077248232127864834', '销售四部'),
    ('1740320716902932481', '大客户管理部'),
    ('1740320675756810242', '海外业务销售部 - 1'),
    ('1762301052057112578', '其他'),
    ('1760576792068489218', '创新业务部')
),
openapi_items(item, item_name) AS (
  VALUES
    ('api_one_time_fee', 'API一次性合规及接入费/卡面设计费/白标系统部署费')
),
generated_rules AS (
  SELECT
    200000 + row_number() OVER (ORDER BY d.department_code, i.item) AS id,
    concat('open_api_', d.department_code, '_', i.item, '_15pct') AS rule_code,
    concat(d.department_name, '-', i.item_name, '-15%') AS rule_name,
    d.department_code,
    'open_api' AS product,
    NULL::varchar AS provider,
    i.item,
    'actual_fee' AS commission_base_type,
    NULL::int4 AS active_days_min,
    NULL::int4 AS active_days_max,
    0.150000::numeric AS commission_rate,
    'all' AS invite_type,
    timestamp '2026-06-01 00:00:00' AS start_time,
    NULL::timestamp AS end_time,
    100 AS priority,
    true AS enabled,
    'OpenAPI一次性费用按实际收费15%计佣' AS remarks
  FROM normal_departments d
  CROSS JOIN openapi_items i
)
INSERT INTO "dws"."sales_commission_rule" (
  "id", "rule_code", "rule_name", "department_code", "product", "provider", "item",
  "commission_base_type", "active_days_min", "active_days_max", "commission_rate",
  "invite_type", "start_time", "end_time", "priority", "enabled", "remarks"
)
SELECT
  id, rule_code, rule_name, department_code, product, provider, item,
  commission_base_type, active_days_min, active_days_max, commission_rate,
  invite_type, start_time, end_time, priority, enabled, remarks
FROM generated_rules
ON CONFLICT ("rule_code") DO NOTHING;

-- OpenAPI月费：0-365天10%，366-1095天0%，按实际收费计佣。
WITH normal_departments(department_code, department_name) AS (
  VALUES
    ('1740319905791647746', '销售一部'),
    ('1740319923059597313', '销售二部'),
    ('2066369412858433538', '销售三部'),
    ('2077248232127864834', '销售四部'),
    ('1740320716902932481', '大客户管理部'),
    ('1740320675756810242', '海外业务销售部 - 1'),
    ('1762301052057112578', '其他'),
    ('1760576792068489218', '创新业务部')
),
active_ranges(active_days_min, active_days_max, range_code, rate) AS (
  VALUES
    (0, 365, '0_365', 0.100000::numeric),
    (366, 1095, '366_1095', 0.000000::numeric)
),
generated_rules AS (
  SELECT
    300000 + row_number() OVER (ORDER BY d.department_code, r.active_days_min) AS id,
    concat('open_api_', d.department_code, '_monthly_', r.range_code) AS rule_code,
    concat(d.department_name, '-OpenAPI月费-', r.range_code) AS rule_name,
    d.department_code,
    'open_api' AS product,
    NULL::varchar AS provider,
    'api_monthly_fee' AS item,
    'actual_fee' AS commission_base_type,
    r.active_days_min,
    r.active_days_max,
    r.rate AS commission_rate,
    'all' AS invite_type,
    timestamp '2026-06-01 00:00:00' AS start_time,
    NULL::timestamp AS end_time,
    100 AS priority,
    true AS enabled,
    'OpenAPI月费按实际收费和活跃天数计佣' AS remarks
  FROM normal_departments d
  CROSS JOIN active_ranges r
)
INSERT INTO "dws"."sales_commission_rule" (
  "id", "rule_code", "rule_name", "department_code", "product", "provider", "item",
  "commission_base_type", "active_days_min", "active_days_max", "commission_rate",
  "invite_type", "start_time", "end_time", "priority", "enabled", "remarks"
)
SELECT
  id, rule_code, rule_name, department_code, product, provider, item,
  commission_base_type, active_days_min, active_days_max, commission_rate,
  invite_type, start_time, end_time, priority, enabled, remarks
FROM generated_rules
ON CONFLICT ("rule_code") DO NOTHING;

-- 海外业务销售部 - 2：直邀客户20%，非直邀客户10%，按GP计佣，优先级高于普通规则。
INSERT INTO "dws"."sales_commission_rule" (
  "id", "rule_code", "rule_name", "department_code", "product", "provider", "item",
  "commission_base_type", "active_days_min", "active_days_max", "commission_rate",
  "invite_type", "start_time", "end_time", "priority", "enabled", "remarks"
)
VALUES
  (
    400001,
    'overseas_sales_2_direct_gp_20pct',
    '海外业务销售部-2-直邀客户-GP-20%',
    '1851130772357509121',
    NULL,
    NULL,
    NULL,
    'gp',
    NULL,
    NULL,
    0.200000,
    'direct',
    timestamp '2026-06-01 00:00:00',
    NULL,
    10,
    true,
    '海外业务销售部-2直邀客户按GP 20%计佣'
  ),
  (
    400002,
    'overseas_sales_2_non_direct_gp_10pct',
    '海外业务销售部-2-非直邀客户-GP-10%',
    '1851130772357509121',
    NULL,
    NULL,
    NULL,
    'gp',
    NULL,
    NULL,
    0.100000,
    'non_direct',
    timestamp '2026-06-01 00:00:00',
    NULL,
    10,
    true,
    '海外业务销售部-2非直邀客户按GP 10%计佣'
  )
ON CONFLICT ("rule_code") DO NOTHING;
