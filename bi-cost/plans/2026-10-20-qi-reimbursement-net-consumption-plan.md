# QI Reimbursement 净消费口径修正执行计划

**目标：** 将 QI v2 CDC DWS 的 Reimbursement 基数与 BI 及 batch SQL 对齐。

**范围：** 修改 CDC DWS SQL 和目标表列注释；保留交易时间作为 `report_date`，不修改用户指定保留的两份查询文件。

**设计：** [QI Reimbursement 基数与净消费口径对齐](../design-docs/2026-10-20-qi-reimbursement-net-consumption-design.md)

## 步骤与进度

- [x] 在 CDC 月度明细投影中保留 `is_qbit_provision`。
- [x] 将 Reimbursement 基数改为 QBIT、非港、Closed/Pending 的 Consumption 净额，并按 1.35% 计费。
- [x] 更新目标表 Reimbursement 基数列注释。
- [x] 静态对比 CDC 与 batch 的计算条件，检查 diff 格式。
