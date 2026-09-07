# quantum_card_transaction_extend_p 表迁移方案

## 摘要

由于运行环境已将交易扩展表切换为按 `create_time` 分区的 `public.quantum_card_transaction_extend_p`，仓库脚本仍引用旧表 `public.quantum_card_transaction_extend`，导致 Flink JDBC source 启动时失败。本次统一更新仓库内受影响的物理表引用及相关说明。

## 范围

- BB 成本核对脚本、BB Flink Batch/CDC/检查脚本。
- QI Flink Batch/CDC 脚本中对交易扩展表的关联。
- BB/QI DWM 表结构脚本中描述交易主源的注释。
- 不修改明确声明不依赖该表的 Qbit 交易宽表脚本。

## 处理方案

1. 将实际 SQL 中的 `public.quantum_card_transaction_extend` 替换为 `public.quantum_card_transaction_extend_p`。
2. 保留 Flink 临时表名称、查询字段、过滤条件、时间窗口和关联逻辑不变。
3. 将 BB/QI DWM 表结构脚本中的交易主源说明同步更新为新表名。
4. 不修改 Qbit 交易宽表“不依赖交易扩展表”的说明。

## 验证

- 全量搜索确认不再存在旧物理表引用。
- 新表名引用覆盖所有原实际 SQL 引用。
- `git diff --check` 通过。
- 检查工作区已有无关改动未被覆盖。
