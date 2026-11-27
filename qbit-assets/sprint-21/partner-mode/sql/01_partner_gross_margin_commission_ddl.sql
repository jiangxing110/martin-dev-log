-- ============================================================================
-- 合伙人毛利返佣结果表 DDL（须在应用代码上线前执行）
-- 适用表：public.partner_gross_margin_commission_p
-- ============================================================================

-- 1. 补建 2027 ~ 2029 年度分区
CREATE TABLE IF NOT EXISTS public.partner_gross_margin_commission_2027 PARTITION OF public.partner_gross_margin_commission_p FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE TABLE IF NOT EXISTS public.partner_gross_margin_commission_2028 PARTITION OF public.partner_gross_margin_commission_p FOR VALUES FROM ('2028-01-01') TO ('2029-01-01');
CREATE TABLE IF NOT EXISTS public.partner_gross_margin_commission_2029 PARTITION OF public.partner_gross_margin_commission_p FOR VALUES FROM ('2029-01-01') TO ('2030-01-01');

-- 2. 新增业务唯一索引（分区表父表不支持 CONCURRENTLY，请选非跑批时段执行；自动级联至所有子分区）
CREATE UNIQUE INDEX IF NOT EXISTS uk_partner_gross_margin_commission_biz ON public.partner_gross_margin_commission_p (settlement_month, partner_id, account_id, product_line_type, snapshot_date);
