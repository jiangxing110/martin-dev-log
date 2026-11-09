# 2026-10 销售佣金返佣重算执行计划

## 目标

在 BB 10 月返佣和 DWS 数据更新后，重建销售佣金 10 月预估结果和快照。

## 步骤

- [x] 确认 BB 返佣并入销售佣金有效收入、毛利及佣金结果，确定快照表范围。
- [x] 编写 10 月快照删除 SQL，限定 `settlement_month = DATE '2026-10-01'`。
- [x] 明确重刷物化视图和 Flink 快照批处理参数。
- [ ] 在 ADBPG 执行删除事务并提交。
- [ ] 刷新物化视图并重跑 10 月快照批处理。
- [ ] 核对重写后的汇总及明细。

## 执行参数

- `snapshot_date`: `2026-11-08`
- `settlement_month`: `2026-10`
- 物化视图刷新：`SELECT dws.sp_refresh_mv_sales_commission_recent_estimate();`

## 当前状态

脚本已准备；数据库删除、物化视图刷新和 Flink 重跑尚未执行。
