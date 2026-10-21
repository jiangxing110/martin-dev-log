# QI Reimbursement 基数与净消费口径对齐

## 摘要

修正 QI v2 CDC DWS 的 `cost_reimbursement_base_amt`，使其与 BI 和现有 batch SQL 一致，按 QBIT 非港 Closed/Pending 净消费计费。

## 处理方案

- 在 CDC 月度交易行中保留 `is_qbit_provision`，只将 QBIT 数据纳入 Reimbursement 基数。
- Reimbursement 基数包括 `Consumption`、`Credit`、`Reversal`：Consumption 正向，Credit/Reversal 反向，按金额乘 1.35%。
- 保留非港及 Closed/Pending 条件，基数以 4 位小数写入。
- 更新目标表列注释，记录新的计费口径。
- 保持 `report_date` 使用 `transaction_time`，不改变现有业务日期定义； BI 的 `create_time` 日期筛选差异另行核对。
- 不修改 batch SQL、临时查询 SQL、费率或其他成本项。

## 验证

- 对照 batch SQL，确认 CDC 的 QBIT、非港、状态、交易类型和正负号条件一致。
- 确认 Reimbursement 字段只有这一处表达式，且不再是 Consumption-only。
- 使用 `git diff --check` 检查补丁格式。
