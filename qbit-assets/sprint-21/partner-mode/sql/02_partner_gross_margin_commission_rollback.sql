-- ============================================================================
-- 合伙人毛利返佣结果表 DDL 回滚脚本
-- 注意：必须先回滚第 1 批 / 第 2 批应用代码（ON CONFLICT 依赖该业务唯一索引），
--       再执行以下索引删除语句。2027 分区为纯新增结构，无需回滚。
-- ============================================================================

DROP INDEX IF EXISTS public.uk_partner_gross_margin_commission_biz;


https://github.com/yetone/magpie


按下面 3 步执行即可（目标库：业务主库 db1 的 public schema，务必先执行 SQL，再发布本次代码）：

第 1 步：建索引前先查重

先单独执行查重 SQL，确认返回 0 行：

sql
SELECT settlement_month, partner_id, account_id, product_line_type, snapshot_date, COUNT(*) AS cnt
FROM public.partner_gross_margin_commission_p
GROUP BY settlement_month, partner_id, account_id, product_line_type, snapshot_date
HAVING COUNT(*) > 1;

若测试库有历史重复数据，先让 DBA 或手动清理掉重复行再执行第 2 步。

第 2 步：建 2027 分区 + 业务唯一索引
测试环境：直接在数据库工具（DataGrip / Navicat / psql）执行以下核心 DDL（测试库通常没有 qbit-prod 等生产角色，不需要跑脚本里的 OWNER/GRANT 行）：
sql
CREATE TABLE IF NOT EXISTS public.partner_gross_margin_commission_2027
    PARTITION OF public.partner_gross_margin_commission_p
        FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');
CREATE UNIQUE INDEX IF NOT EXISTS uk_partner_gross_margin_commission_biz
    ON public.partner_gross_margin_commission_p
        (settlement_month, partner_id, account_id, product_line_type, snapshot_date);
生产环境：把完整的 01_partner_gross_margin_commission_ddl.sql 提工单给 DBA，在非跑批时段执行（分区表父表建索引不支持 CONCURRENTLY，会短暂锁表；里面已含 2027 分区与生产角色授权）。
第 3 步：确认生效

执行完后跑一句校验，确认 2026、2027 分区和唯一索引都已自动级联创建成功：

sql
SELECT tablename, indexname
FROM pg_indexes
WHERE tablename LIKE 'partner_gross_margin_commission%'
ORDER BY tablename, indexname;

看到 partner_gross_margin_commission_2026 和 partner_gross_margin_commission_2027 下都有唯一索引后，就可以发布代码跑批测试了。