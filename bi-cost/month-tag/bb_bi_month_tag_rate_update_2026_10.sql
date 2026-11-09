-- BB 2026-10 月度 Cashback rate 单独修正
-- Created Time: 2026-11-09 00:00:00
-- Updated Time: 2026-11-09 00:00:00
-- 说明：合并月度 seed 已执行，本脚本只更新已存在的 BB 2026-10 BB_CASH_RATE，不改 QI 或其他月份。
-- rate = 2.2698% * 1.0377 = 2.35537146% = 0.0235537146

-- 执行前确认目标行存在且当前有效；预期返回 1 行。
SELECT
    id,
    provider,
    product_line,
    account_type,
    tag,
    detail,
    amount,
    delete_time
FROM ods.ods_bi_month_tag
WHERE id = 202611060901
  AND provider = 'BB'
  AND product_line = 'BB'
  AND account_type = 'fullCustomer'
  AND tag = 'BB_CASH_RATE'
  AND detail = '2026-10'
  AND delete_time IS NULL;

BEGIN;

UPDATE ods.ods_bi_month_tag
SET
    amount = 0.022698::numeric * 1.0377::numeric,
    update_time = NOW(),
    remarks = 'BB 2026-10 monthly cashback rate; 2.2698% * 1.0377 = 2.35537146%'
WHERE id = 202611060901
  AND provider = 'BB'
  AND product_line = 'BB'
  AND account_type = 'fullCustomer'
  AND tag = 'BB_CASH_RATE'
  AND detail = '2026-10'
  AND delete_time IS NULL
RETURNING id, provider, tag, detail, amount, update_time;

COMMIT;

-- 执行后应返回 1 行，amount 应为 0.0235537146。
SELECT
    id,
    provider,
    product_line,
    account_type,
    tag,
    detail,
    amount,
    update_time
FROM ods.ods_bi_month_tag
WHERE id = 202611060901
  AND provider = 'BB'
  AND product_line = 'BB'
  AND account_type = 'fullCustomer'
  AND tag = 'BB_CASH_RATE'
  AND detail = '2026-10'
  AND delete_time IS NULL;
