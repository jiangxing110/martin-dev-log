-- BB 月度渠道实际成本差额固定成本 Upsert
-- Updated Time: 2026-08-24 15:20:00
-- 说明：存在有效月份配置时 UPDATE，不存在时 INSERT；不删除任何历史记录。
--       amount = 渠道实际成本 - 系统计算成本。

BEGIN;

CREATE TEMP TABLE tmp_bb_channel_cost_adjustment (
    id              BIGINT,
    tag             TEXT,
    statistics_time TIMESTAMPTZ,
    amount          NUMERIC(20, 4),
    detail          TEXT,
    remarks         TEXT
) ON COMMIT DROP;

INSERT INTO tmp_bb_channel_cost_adjustment
    (id, tag, statistics_time, amount, detail, remarks)
VALUES
    (202608240901, 'CHANNEL_COST', '2026-01-01 00:00:00+08'::TIMESTAMPTZ,  7649.6463,  '2026-01', 'BB 2026-01 actual cost adjustment'),
    (202608240902, 'CHANNEL_COST', '2026-02-01 00:00:00+08'::TIMESTAMPTZ, 11887.3651,  '2026-02', 'BB 2026-02 actual cost adjustment'),
    (202608240903, 'CHANNEL_COST', '2026-03-01 00:00:00+08'::TIMESTAMPTZ,  4203.3993,  '2026-03', 'BB 2026-03 actual cost adjustment'),
    (202608240904, 'CHANNEL_COST', '2026-04-01 00:00:00+08'::TIMESTAMPTZ,  1217.1687,  '2026-04', 'BB 2026-04 actual cost adjustment'),
    (202608240905, 'CHANNEL_COST', '2026-05-01 00:00:00+08'::TIMESTAMPTZ,  -535.0827,  '2026-05', 'BB 2026-05 actual cost adjustment'),
    (202608240906, 'CHANNEL_COST', '2026-06-01 00:00:00+08'::TIMESTAMPTZ,   179.5862,  '2026-06', 'BB 2026-06 actual cost adjustment'),
    (202608240907, 'CHANNEL_COST', '2026-07-01 00:00:00+08'::TIMESTAMPTZ,  -126.4002,  '2026-07', 'BB 2026-07 actual cost adjustment');

-- 已存在有效月份配置：更新金额。
UPDATE "ods"."ods_bi_month_tag" target
SET
    "amount" = s.amount,
    "statistics_time" = s.statistics_time,
    "update_time" = NOW(),
    "remarks" = s.remarks
FROM tmp_bb_channel_cost_adjustment s
WHERE target."provider" = 'BB'
  AND target."product_line" = 'BB'
  AND target."account_type" = 'fullCustomer'
  AND target."tag" = s.tag
  AND target."detail" = s.detail
  AND target."delete_time" IS NULL;

-- 不存在有效月份配置：插入新记录。
INSERT INTO "ods"."ods_bi_month_tag"
    ("id", "create_time", "update_time", "delete_time", "version", "tag", "statistics_time", "amount", "remarks", "detail", "account_type", "provider", "product_line")
SELECT
    s.id,
    NOW(),
    NOW(),
    NULL::TIMESTAMPTZ,
    1,
    s.tag,
    s.statistics_time,
    s.amount,
    s.remarks,
    s.detail,
    'fullCustomer',
    'BB',
    'BB'
FROM tmp_bb_channel_cost_adjustment s
WHERE NOT EXISTS (
    SELECT 1
    FROM "ods"."ods_bi_month_tag" existing
    WHERE existing."provider" = 'BB'
      AND existing."product_line" = 'BB'
      AND existing."account_type" = 'fullCustomer'
      AND existing."tag" = s.tag
      AND existing."detail" = s.detail
      AND existing."delete_time" IS NULL
)
AND NOT EXISTS (
    SELECT 1
    FROM "ods"."ods_bi_month_tag" existing_id
    WHERE existing_id."id" = s.id
);

COMMIT;

SELECT
    "detail",
    "amount",
    "statistics_time",
    "update_time",
    "remarks"
FROM "ods"."ods_bi_month_tag"
WHERE "provider" = 'BB'
  AND "product_line" = 'BB'
  AND "account_type" = 'fullCustomer'
  AND "tag" = 'CHANNEL_COST'
  AND "detail" BETWEEN '2026-01' AND '2026-07'
  AND "delete_time" IS NULL
ORDER BY "detail";
