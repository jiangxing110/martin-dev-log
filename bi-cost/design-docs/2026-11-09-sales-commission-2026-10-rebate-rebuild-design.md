# 2026-10 销售佣金返佣重算方案

## 摘要

BB 10 月返佣已计入销售佣金预估视图中的有效收入、毛利及佣金计算结果，快照表没有独立的返佣记录。因此按正确 BB DWS 数据刷新预估物化视图后，需要按 `settlement_month = 2026-10-01` 替换销售佣金快照明细和汇总数据。

## 范围

- 目标月份：2026-10。
- 来源：`dws.mv_sales_commission_recent_estimate`。
- 目标：`dws.dws_sales_commission_snapshot_detail_p`、`dws.dws_sales_commission_snapshot_p`。
- 快照日期沿用当月固化日期 `2026-11-08`。
- 不单独删除或插入“返佣行”；重建该结算月的整份佣金快照，避免收入、毛利和佣金彼此不一致。

## 执行顺序

1. 更新 BB 10 月返现标签并重刷 BB DWS。
2. 调用 `dws.sp_refresh_mv_sales_commission_recent_estimate()` 刷新销售佣金预估物化视图。
3. 执行 `online/delete_sales_commission_snapshot_2026_10.sql`，确认删除数量和残留数量后提交事务。
4. 在 Flink 运行 `sales-commission/batch/dws_online_sales_commission_snapshot-batch-sql.sql`，参数设为 `snapshot_date=2026-11-08`、`settlement_month=2026-10`。
5. 检查快照表 10 月行数、佣金金额和关键客户结果。

## 风险与边界

- 删除针对两张快照表全部 10 月结算月份记录；不是只删除 BB 行，因为返佣已汇总进其他金额字段。
- 删除提交后，若 Flink 批处理失败，10 月快照暂时为空，需要修复后重新执行批处理。
- 本地只准备脚本，不连接数据库执行，也不运行 Flink 作业。
