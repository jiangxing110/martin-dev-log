# 渠道成本与毛利增量物化视图方案

- Created Time: 2026-08-13 00:00:00
- Updated Time: 2026-08-13 00:00:00
- Status: 已评审并实现

## 摘要

将总渠道成本日汇总和毛利日汇总从普通物化视图脚本扩展出 ADBPG 增量物化视图版本。新增脚本放在 `online/incremental-view/`，保留 `online/materialized-view/` 下现有普通物化视图和 pg_cron 刷新脚本，便于回滚和对比。

## 目标

1. 新增 `dws.mv_channel_cost_daily` 的增量物化视图创建脚本。
2. 新增 `dws.mv_gross_profit_daily` 当前主版本的增量物化视图创建脚本。
3. 新增 `dws.mv_gross_profit_daily` AASA 口径版本的增量物化视图创建脚本。
4. 增量版本不再描述 `REFRESH MATERIALIZED VIEW` 或 pg_cron 调度。

## SQL 设计

1. 语法使用 `CREATE INCREMENTAL MATERIALIZED VIEW ... AS`。
2. 对象名、字段、分布键、owner 与原普通物化视图保持一致；`id` 索引改为普通索引。
3. `mv_channel_cost_daily` 继续汇总 BB/BZ/QI/SL 和金融渠道成本，按 `report_date/account_id/sale_id/am_id` 聚合四个成本桶。
4. `mv_gross_profit_daily` 继续从有效收入和 `dws.mv_channel_cost_daily` 汇总成本，保留 treasury 收入口径。
5. `mv_gross_profit_daily_aasa` 继续从有效收入和 `dws.dws_total_channel_cost_daily_v2_p` 汇总成本，保留原 AASA 版本 category 范围。
6. ADBPG 增量物化视图不支持 CTE，增量脚本使用派生表承载 union 和 BB 月汇总逻辑。
7. ADBPG 增量物化视图不支持包含聚合函数的复杂表达式，聚合层只保留 `SUM(column)`、`MIN(column)`、`MAX(column)` 形式；清洗、分桶和零值过滤前移或后移到非聚合层。
8. ADBPG 增量物化视图不支持唯一索引或主键，`id` 只创建普通索引。

## 上线边界

- 不删除或修改普通物化视图脚本。
- 不删除或修改现有 pg_cron 刷新脚本。
- `mv_gross_profit_daily.sql` 和 `mv_gross_profit_daily_aasa.sql` 都创建 `dws.mv_gross_profit_daily`，上线时只能选择一个版本执行。
- 若目标 ADBPG 对复杂增量物化视图存在其他语法或能力限制，以数据库执行结果为准，再按报错拆分查询。

## 验收标准

- 新增三份 SQL 均位于 `online/incremental-view/`。
- 新增 SQL 使用 `CREATE INCREMENTAL MATERIALIZED VIEW`。
- 新增 SQL 不包含 CTE。
- 聚合层不包含 `SUM(CASE ...)`、聚合后强转或 `HAVING SUM(...)`。
- 新增 SQL 不包含唯一索引或主键。
- 新增 SQL 不包含刷新调度说明。
- 原 `online/materialized-view/` 文件保持不变。
