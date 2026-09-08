-- BB 月度 Cashback rate 修正脚本
-- Updated Time: 2026-09-08 12:30:00
-- 说明：直接修正 ods.ods_bi_month_tag 中现有的有效 BB_CASH_RATE 记录。

BEGIN;

WITH rate_rows(detail, amount) AS (
    VALUES
        ('2026-01', 0.02208669::numeric),
        ('2026-02', 0.02204001::numeric),
        ('2026-03', 0.02183684::numeric),
        ('2026-04', 0.02161762::numeric),
        ('2026-05', 0.02122117::numeric),
        ('2026-06', 0.02085309::numeric),
        ('2026-07', 0.02061664::numeric),
        ('2026-08', 0.02059184::numeric),
        ('DEFAULT_FALLBACK', 0.02059391::numeric)
)
UPDATE "ods"."ods_bi_month_tag" target
SET
    "amount" = rate_rows.amount,
    "update_time" = NOW()
FROM rate_rows
WHERE target."provider" = 'BB'
  AND target."tag" = 'BB_CASH_RATE'
  AND target."detail" = rate_rows.detail
  AND target."delete_time" IS NULL;

-- 执行后核对实际生效的费率。
SELECT
    "detail",
    "amount",
    "update_time"
FROM "ods"."ods_bi_month_tag"
WHERE "provider" = 'BB'
  AND "tag" = 'BB_CASH_RATE'
  AND "delete_time" IS NULL
ORDER BY
    CASE WHEN "detail" = 'DEFAULT_FALLBACK' THEN '9999-99' ELSE "detail" END;

COMMIT;
