-- 销售佣金物化视图无数据排查脚本
-- 方式：一段一段执行，不要整文件一次性全跑。
--
-- 当前先执行【第 1 段】。
-- 第 1 段只回答一个问题：
--   dws.dws_sales_revenue_monthly 在当前物化视图的近三个月窗口里，到底有没有可用收入数据？
--
-- 如果你要指定月份，把下面 settlement_month_filter 从 NULL 改成月初日期，例如：
--   '2026-06-01'::date AS settlement_month_filter

-- =========================
-- 第 1 段：源收入是否存在
-- =========================
WITH params AS (
  SELECT
    date_trunc('month', CURRENT_DATE - interval '3 months')::date AS min_settlement_month,
    NULL::date AS settlement_month_filter
),
source_rows AS (
  SELECT
    r.*
  FROM "dws"."dws_sales_revenue_monthly" r
  CROSS JOIN params p
  WHERE r.delete_time IS NULL
    AND r.settlement_month >= p.min_settlement_month
    AND (p.settlement_month_filter IS NULL OR r.settlement_month = p.settlement_month_filter)
)
SELECT
  'source_total' AS check_step,
  COUNT(*) AS row_count,
  COUNT(DISTINCT settlement_month) AS month_count,
  MIN(settlement_month) AS min_settlement_month,
  MAX(settlement_month) AS max_settlement_month,
  COUNT(DISTINCT root_account_id) AS root_account_count,
  SUM(COALESCE(real_income_value, income_value, 0))::numeric(20,4) AS income_amount
FROM source_rows;

-- 第 1 段结果怎么看：
-- 1. row_count = 0：
--    近三个月窗口没有收入源数据。先查 dws_sales_revenue_monthly 是否加载、settlement_month 是否在窗口内。
-- 2. row_count > 0：
--    源收入存在。下一步再执行“第 2 段：收入过滤后是否还有数据”。


-- =========================
-- 第 2 段：过滤掉成本/特殊指标后是否还有可计佣收入
-- =========================
WITH params AS (
  SELECT
    date_trunc('month', CURRENT_DATE - interval '3 months')::date AS min_settlement_month,
    NULL::date AS settlement_month_filter
),
source_rows AS (
  SELECT
    r.*
  FROM "dws"."dws_sales_revenue_monthly" r
  CROSS JOIN params p
  WHERE r.delete_time IS NULL
    AND r.settlement_month >= p.min_settlement_month
    AND (p.settlement_month_filter IS NULL OR r.settlement_month = p.settlement_month_filter)
),
revenue_rows AS (
  SELECT
    *
  FROM source_rows
  WHERE metric_code NOT IN (
    'assets_acceptance_fee_gt_zero',
    'assets_acceptance_fee_eq_zero',
    'physical_card_cost'
  )
)
SELECT
  'revenue_after_metric_filter' AS check_step,
  COUNT(*) AS row_count,
  COUNT(DISTINCT settlement_month) AS month_count,
  MIN(settlement_month) AS min_settlement_month,
  MAX(settlement_month) AS max_settlement_month,
  COUNT(DISTINCT root_account_id) AS root_account_count,
  COUNT(*) FILTER (WHERE sale_department IS NULL) AS sale_department_null_count,
  COUNT(*) FILTER (WHERE sale_department IS NOT NULL) AS sale_department_not_null_count,
  COUNT(DISTINCT sale_department) FILTER (WHERE sale_department IS NOT NULL) AS sale_department_count,
  SUM(COALESCE(real_income_value, income_value, 0))::numeric(20,4) AS income_amount
FROM revenue_rows;

-- 第 2 段结果怎么看：
-- 1. row_count = 0：
--    数据都被 metric_code 过滤掉了，需要看源表 metric_code 是否全是成本/特殊项。
-- 2. row_count > 0 且 sale_department_null_count = row_count：
--    收入还在，但部门全为空。最终会因为规则表按 department_id 匹配而没有数据。
-- 3. row_count > 0 且 sale_department_not_null_count > 0：
--    继续执行第 3 段，看部门 ID 是否能命中规则表。


-- =========================
-- 第 3 段：部门为空时，销售 / AM 字段是否还在
-- =========================
-- 第 2 段已经看到 sale_department 全为空，所以最终规则 join 必然没有数据。
-- 第 3 段只确认还有没有 sale_id / am_id，可以决定后面是修源表写 department_id，
-- 还是在物化视图里临时通过销售维表补 department_id。
WITH params AS (
  SELECT
    date_trunc('month', CURRENT_DATE - interval '3 months')::date AS min_settlement_month,
    NULL::date AS settlement_month_filter
),
revenue_rows AS (
  SELECT
    r.*
  FROM "dws"."dws_sales_revenue_monthly" r
  CROSS JOIN params p
  WHERE r.delete_time IS NULL
    AND r.settlement_month >= p.min_settlement_month
    AND (p.settlement_month_filter IS NULL OR r.settlement_month = p.settlement_month_filter)
    AND r.metric_code NOT IN (
      'assets_acceptance_fee_gt_zero',
      'assets_acceptance_fee_eq_zero',
      'physical_card_cost'
    )
)
SELECT
  'sales_field_probe' AS check_step,
  settlement_month,
  product,
  COUNT(*) AS row_count,
  COUNT(*) FILTER (WHERE sale_id IS NULL) AS sale_id_null_count,
  COUNT(*) FILTER (WHERE sale_id IS NOT NULL) AS sale_id_not_null_count,
  COUNT(DISTINCT sale_id) FILTER (WHERE sale_id IS NOT NULL) AS sale_id_count,
  COUNT(*) FILTER (WHERE am_id IS NULL) AS am_id_null_count,
  COUNT(*) FILTER (WHERE am_id IS NOT NULL) AS am_id_not_null_count,
  COUNT(DISTINCT am_id) FILTER (WHERE am_id IS NOT NULL) AS am_id_count,
  SUM(COALESCE(real_income_value, income_value, 0))::numeric(20,4) AS income_amount
FROM revenue_rows
GROUP BY settlement_month, product
ORDER BY settlement_month DESC, product;

-- 第 3 段结果怎么看：
-- 1. sale_id_not_null_count > 0：
--    源收入有销售 ID，但没有部门 ID。可以通过销售维表 / 用户部门关系补 department_id。
-- 2. sale_id_not_null_count = 0 且 am_id_not_null_count > 0：
--    只有 AM ID，需要确认 AM 是否也走同一套部门规则。
-- 3. sale_id_not_null_count = 0 且 am_id_not_null_count = 0：
--    源收入连销售 / AM 都没有，必须先修 dws_sales_revenue_monthly 的销售归因。


-- =========================
-- 第 4 段：列出需要补部门的销售 ID
-- =========================
-- 第 3 段显示 sale_id 大部分有值，但 sale_department 全为空。
-- 第 4 段只列出这些 sale_id 的金额和行数，方便确认销售 ID 对应哪个部门。
WITH params AS (
  SELECT
    date_trunc('month', CURRENT_DATE - interval '3 months')::date AS min_settlement_month,
    NULL::date AS settlement_month_filter
),
revenue_rows AS (
  SELECT
    r.*
  FROM "dws"."dws_sales_revenue_monthly" r
  CROSS JOIN params p
  WHERE r.delete_time IS NULL
    AND r.settlement_month >= p.min_settlement_month
    AND (p.settlement_month_filter IS NULL OR r.settlement_month = p.settlement_month_filter)
    AND r.metric_code NOT IN (
      'assets_acceptance_fee_gt_zero',
      'assets_acceptance_fee_eq_zero',
      'physical_card_cost'
    )
)
SELECT
  'sale_id_need_department' AS check_step,
  sale_id,
  COUNT(*) AS row_count,
  COUNT(DISTINCT settlement_month) AS month_count,
  COUNT(DISTINCT root_account_id) AS root_account_count,
  COUNT(DISTINCT product) AS product_count,
  STRING_AGG(DISTINCT product, ',' ORDER BY product) AS products,
  SUM(COALESCE(real_income_value, income_value, 0))::numeric(20,4) AS income_amount
FROM revenue_rows
WHERE sale_id IS NOT NULL
GROUP BY sale_id
ORDER BY income_amount DESC NULLS LAST, row_count DESC;

-- 第 4 段结果怎么看：
-- 1. sale_id 数量很少：
--    可以先人工确认这些 sale_id 对应部门，然后决定补数方案。
-- 2. sale_id 数量很多：
--    需要找系统销售/用户维表，不能靠手工维护。
-- 3. 下一步建议：
--    先拿这个结果里的前几个 sale_id，查系统用户/员工/部门表，确认 sale_id -> department_id 来源。


-- =========================
-- 第 5 段：通过 system_user_department 补部门是否可行
-- =========================
-- 依赖表：
--   public.system_user_department.user_id = dws_sales_revenue_monthly.sale_id::uuid
--   public.system_user_department.department_id = system_department.id
--
-- 这一段验证两个问题：
--   1. sale_id 能不能补出 department_id。
--   2. 补出的 department_id 是否存在于 dim.dim_sales_commission_rule。
WITH params AS (
  SELECT
    date_trunc('month', CURRENT_DATE - interval '3 months')::date AS min_settlement_month,
    NULL::date AS settlement_month_filter
),
revenue_rows AS (
  SELECT
    r.*
  FROM "dws"."dws_sales_revenue_monthly" r
  CROSS JOIN params p
  WHERE r.delete_time IS NULL
    AND r.settlement_month >= p.min_settlement_month
    AND (p.settlement_month_filter IS NULL OR r.settlement_month = p.settlement_month_filter)
    AND r.metric_code NOT IN (
      'assets_acceptance_fee_gt_zero',
      'assets_acceptance_fee_eq_zero',
      'physical_card_cost'
    )
),
sale_department AS (
  SELECT
    user_id::text AS sale_id,
    department_id::text AS department_id,
    COUNT(*) AS department_relation_count
  FROM "public"."system_user_department"
  WHERE delete_time IS NULL
  GROUP BY user_id::text, department_id::text
),
rule_departments AS (
  SELECT DISTINCT department_id
  FROM "dim"."dim_sales_commission_rule"
  WHERE enabled = true
    AND delete_time IS NULL
)
SELECT
  'sale_department_join_probe' AS check_step,
  r.settlement_month,
  r.product,
  COUNT(*) AS row_count,
  COUNT(*) FILTER (WHERE r.sale_id IS NULL) AS sale_id_null_count,
  COUNT(*) FILTER (WHERE r.sale_id IS NOT NULL) AS sale_id_not_null_count,
  COUNT(*) FILTER (WHERE sd.department_id IS NULL) AS department_join_null_count,
  COUNT(*) FILTER (WHERE sd.department_id IS NOT NULL) AS department_join_not_null_count,
  COUNT(DISTINCT sd.department_id) FILTER (WHERE sd.department_id IS NOT NULL) AS joined_department_count,
  COUNT(*) FILTER (WHERE rd.department_id IS NOT NULL) AS rule_department_match_count,
  COUNT(*) FILTER (WHERE sd.department_id IS NOT NULL AND rd.department_id IS NULL) AS department_not_in_rule_count,
  SUM(COALESCE(r.real_income_value, r.income_value, 0))::numeric(20,4) AS income_amount
FROM revenue_rows r
LEFT JOIN sale_department sd
  ON sd.sale_id = r.sale_id
LEFT JOIN rule_departments rd
  ON rd.department_id = sd.department_id
GROUP BY r.settlement_month, r.product
ORDER BY r.settlement_month DESC, r.product;

-- 第 5 段结果怎么看：
-- 1. department_join_not_null_count 很高：
--    可以在物化视图里用 system_user_department 补 department_id。
-- 2. rule_department_match_count = department_join_not_null_count：
--    补出的部门都能命中规则表部门，下一段就验证完整规则匹配。
-- 3. department_not_in_rule_count > 0：
--    有销售部门不在规则表里，需要补 dim_sales_commission_rule 的部门规则。


-- =========================
-- 第 6 段：system_user_department 是否一人多部门
-- =========================
-- 第 5 段 row_count 比第 3 段变大，说明直接 join system_user_department 会放大收入。
-- 第 6 段专门看：
--   1. 哪些 sale_id 绑定了多个 department_id。
--   2. 补出来的 department_id 哪些不在返佣规则表。
--   3. 后续物化视图不能直接 join 多部门表，必须先选定一个部门口径。
WITH params AS (
  SELECT
    date_trunc('month', CURRENT_DATE - interval '3 months')::date AS min_settlement_month,
    NULL::date AS settlement_month_filter
),
revenue_rows AS (
  SELECT
    r.*
  FROM "dws"."dws_sales_revenue_monthly" r
  CROSS JOIN params p
  WHERE r.delete_time IS NULL
    AND r.settlement_month >= p.min_settlement_month
    AND (p.settlement_month_filter IS NULL OR r.settlement_month = p.settlement_month_filter)
    AND r.metric_code NOT IN (
      'assets_acceptance_fee_gt_zero',
      'assets_acceptance_fee_eq_zero',
      'physical_card_cost'
    )
),
sale_department AS (
  SELECT
    user_id::text AS sale_id,
    department_id::text AS department_id
  FROM "public"."system_user_department"
  WHERE delete_time IS NULL
),
sale_department_count AS (
  SELECT
    sale_id,
    COUNT(*) AS department_relation_count,
    COUNT(DISTINCT department_id) AS department_count,
    STRING_AGG(DISTINCT department_id, ',' ORDER BY department_id) AS department_ids
  FROM sale_department
  GROUP BY sale_id
),
rule_departments AS (
  SELECT DISTINCT department_id
  FROM "dim"."dim_sales_commission_rule"
  WHERE enabled = true
    AND delete_time IS NULL
)
SELECT
  'multi_department_summary' AS check_step,
  COUNT(DISTINCT r.sale_id) FILTER (WHERE r.sale_id IS NOT NULL) AS sale_id_count,
  COUNT(DISTINCT r.sale_id) FILTER (WHERE r.sale_id IS NOT NULL AND sdc.department_count IS NULL) AS no_department_sale_count,
  COUNT(DISTINCT r.sale_id) FILTER (WHERE sdc.department_count = 1) AS one_department_sale_count,
  COUNT(DISTINCT r.sale_id) FILTER (WHERE sdc.department_count > 1) AS multi_department_sale_count,
  COUNT(*) AS revenue_row_count,
  SUM(COALESCE(r.real_income_value, r.income_value, 0))::numeric(20,4) AS income_amount
FROM revenue_rows r
LEFT JOIN sale_department_count sdc
  ON sdc.sale_id = r.sale_id;

-- 第 6.1 段：部门维度汇总，确认哪些部门不在规则表。
WITH params AS (
  SELECT
    date_trunc('month', CURRENT_DATE - interval '3 months')::date AS min_settlement_month,
    NULL::date AS settlement_month_filter
),
revenue_rows AS (
  SELECT
    r.*
  FROM "dws"."dws_sales_revenue_monthly" r
  CROSS JOIN params p
  WHERE r.delete_time IS NULL
    AND r.settlement_month >= p.min_settlement_month
    AND (p.settlement_month_filter IS NULL OR r.settlement_month = p.settlement_month_filter)
    AND r.metric_code NOT IN (
      'assets_acceptance_fee_gt_zero',
      'assets_acceptance_fee_eq_zero',
      'physical_card_cost'
    )
),
sale_department AS (
  SELECT
    user_id::text AS sale_id,
    department_id::text AS department_id
  FROM "public"."system_user_department"
  WHERE delete_time IS NULL
),
rule_departments AS (
  SELECT DISTINCT department_id
  FROM "dim"."dim_sales_commission_rule"
  WHERE enabled = true
    AND delete_time IS NULL
)
SELECT
  'department_rule_status' AS check_step,
  sd.department_id,
  CASE WHEN rd.department_id IS NULL THEN 'not_in_rule_table' ELSE 'in_rule_table' END AS rule_status,
  COUNT(DISTINCT r.sale_id) AS sale_id_count,
  COUNT(*) AS joined_row_count,
  SUM(COALESCE(r.real_income_value, r.income_value, 0))::numeric(20,4) AS income_amount
FROM revenue_rows r
JOIN sale_department sd
  ON sd.sale_id = r.sale_id
LEFT JOIN rule_departments rd
  ON rd.department_id = sd.department_id
GROUP BY sd.department_id, rd.department_id
ORDER BY rule_status DESC, income_amount DESC NULLS LAST;

-- 第 6.2 段：列出多部门销售。这个结果决定后面部门口径怎么取。
WITH params AS (
  SELECT
    date_trunc('month', CURRENT_DATE - interval '3 months')::date AS min_settlement_month,
    NULL::date AS settlement_month_filter
),
revenue_rows AS (
  SELECT
    r.*
  FROM "dws"."dws_sales_revenue_monthly" r
  CROSS JOIN params p
  WHERE r.delete_time IS NULL
    AND r.settlement_month >= p.min_settlement_month
    AND (p.settlement_month_filter IS NULL OR r.settlement_month = p.settlement_month_filter)
    AND r.metric_code NOT IN (
      'assets_acceptance_fee_gt_zero',
      'assets_acceptance_fee_eq_zero',
      'physical_card_cost'
    )
),
sale_department_count AS (
  SELECT
    user_id::text AS sale_id,
    COUNT(DISTINCT department_id::text) AS department_count,
    STRING_AGG(DISTINCT department_id::text, ',' ORDER BY department_id::text) AS department_ids
  FROM "public"."system_user_department"
  WHERE delete_time IS NULL
  GROUP BY user_id::text
)
SELECT
  'multi_department_sale_detail' AS check_step,
  r.sale_id,
  sdc.department_count,
  sdc.department_ids,
  COUNT(*) AS revenue_row_count,
  COUNT(DISTINCT r.product) AS product_count,
  STRING_AGG(DISTINCT r.product, ',' ORDER BY r.product) AS products,
  SUM(COALESCE(r.real_income_value, r.income_value, 0))::numeric(20,4) AS income_amount
FROM revenue_rows r
JOIN sale_department_count sdc
  ON sdc.sale_id = r.sale_id
WHERE sdc.department_count > 1
GROUP BY r.sale_id, sdc.department_count, sdc.department_ids
ORDER BY income_amount DESC NULLS LAST, revenue_row_count DESC;

-- 第 6 段结果怎么看：
-- 1. multi_department_sale_count = 0：
--    可以安全用 system_user_department 补 department_id。
-- 2. multi_department_sale_count > 0：
--    不能直接 join，否则收入会重复。需要确定“用户多部门时取哪个部门”的业务规则。
-- 3. department_rule_status 里 not_in_rule_table：
--    这些部门没有返佣规则，补了部门也不会出佣金。
