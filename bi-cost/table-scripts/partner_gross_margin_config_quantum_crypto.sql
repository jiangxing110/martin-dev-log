--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-09-02
-- Description:    量子账户/加密资产合伙人毛利返佣默认费率配置
-- Notes:
--   1. 本脚本沿用 public.partner_gross_margin_config 及其 detail 表。
--   2. 默认阶梯：0-20,000 为10%，20,000以上为20%。
--   3. 修改 v_partner_id/v_account_id/v_effective_time 后可复用。
--   4. 使用确定性 hash ID，重复执行不会产生重复配置。
--********************************************************************--

CREATE TEMPORARY TABLE tmp_partner_gross_margin_config_seed (
  partner_id varchar(64),
  account_id varchar(64),
  product_line_type varchar(32),
  effective_time TIMESTAMP(6),
  expiration_time TIMESTAMP(6)
);

INSERT INTO tmp_partner_gross_margin_config_seed VALUES
  ('fc3827ec-58e9-4f42-a661-a3aa658c3e61', 'fc3827ec-58e9-4f42-a661-a3aa658c3e61', 'QUANTUM_ACCOUNT', TIMESTAMP '2026-09-02 08:00:00', TIMESTAMP '2027-09-01 15:59:59'),
  ('fc3827ec-58e9-4f42-a661-a3aa658c3e61', 'fc3827ec-58e9-4f42-a661-a3aa658c3e61', 'CRYPTO_ASSETS', TIMESTAMP '2026-09-02 08:00:00', TIMESTAMP '2027-09-01 15:59:59');

INSERT INTO public.partner_gross_margin_config
  (id, create_time, update_time, delete_time, version, remarks, partner_id, account_id, product_line_type, effective_time, expiration_time)
SELECT
  abs(hashtext(concat_ws(':', partner_id, account_id, product_line_type, effective_time::text)))::bigint,
  now(), now(), NULL, 1, 'default gross margin commission config',
  partner_id, account_id, product_line_type, effective_time, expiration_time
FROM tmp_partner_gross_margin_config_seed
ON CONFLICT (id) DO UPDATE SET
  update_time = now(),
  delete_time = NULL,
  version = public.partner_gross_margin_config.version + 1,
  expiration_time = EXCLUDED.expiration_time;

INSERT INTO public.partner_gross_margin_config_detail
  (id, create_time, update_time, delete_time, version, remarks, config_id, ladder_max_amount, ladder_min_amount, rate_value, effective_time, expiration_time)
SELECT
  abs(hashtext(concat_ws(':', c.id::text, tier.ladder_min_amount::text, COALESCE(tier.ladder_max_amount::text, 'INF'))))::bigint,
  now(), now(), NULL, 1, 'default progressive tier', c.id,
  tier.ladder_max_amount, tier.ladder_min_amount, tier.rate_value,
  c.effective_time, c.expiration_time
FROM public.partner_gross_margin_config c
JOIN tmp_partner_gross_margin_config_seed s
  ON s.partner_id = c.partner_id
 AND s.account_id = c.account_id
 AND s.product_line_type = c.product_line_type
 AND s.effective_time = c.effective_time
CROSS JOIN (VALUES
  (CAST(0 AS numeric(20,12)), CAST(20000 AS numeric(20,12)), CAST(0.10 AS numeric(20,12))),
  (CAST(20000 AS numeric(20,12)), CAST(NULL AS numeric(20,12)), CAST(0.20 AS numeric(20,12)))
) AS tier(ladder_min_amount, ladder_max_amount, rate_value)
ON CONFLICT (id) DO UPDATE SET
  update_time = now(),
  delete_time = NULL,
  version = public.partner_gross_margin_config_detail.version + 1,
  rate_value = EXCLUDED.rate_value,
  expiration_time = EXCLUDED.expiration_time;

DROP TABLE tmp_partner_gross_margin_config_seed;
