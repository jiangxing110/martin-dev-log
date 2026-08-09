# QI CDC 执行参数调整方案

## 摘要

QI DWM CDC 出现 TaskManager 心跳超时。先将执行并行度和算子链参数与正常运行的 batch 对齐，减少单并行度和禁用算子链带来的执行压力。

## 变更

- `parallelism.default` 从 `1` 调整为 `4`。
- `pipeline.operator-chaining` 从 `false` 调整为 `true`。
- 不修改数据窗口、关联和分摊逻辑。

## 风险

该调整不能消除 CDC 全量读取关联表的根因；如果仍然超时，需要继续将大表关联下推到 PostgreSQL。
