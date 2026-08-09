# BB Transaction CDC Source 超时修复方案

## 摘要

BB transaction CDC 在 VVR 中无明确异常但作业失败，血缘图显示失败/取消集中在 `source_quantum_card_transaction_extend`、`source_qbit_card`、`source_qbit_card_settlement`。当前脚本会全量读取交易、卡和 BlueBanc settlement，数据量过大时容易导致 Source 任务超时或被取消。

## 方案

- `source_quantum_card_transaction_extend` 改为只读取昨天交易自身变更，或昨天新增/变化的 BlueBanc settlement 能匹配到的交易。
- `source_qbit_card` 改为按 changed tx 的 `card_id` 下推过滤。
- `source_qbit_card_settlement` 改为按 changed tx 的 `source_id/card_transaction_id` 下推过滤。
- 将 `EXISTS + OR` 相关子查询改为 `UNION + 等值 JOIN`，避免 JDBC Source 长时间停留在 RUNNING 且 0 records。
- 补充 `heartbeat.timeout = 600000`、`scan.auto-commit = false`，降低 JDBC 长读任务被心跳超时影响的概率。
- 执行参数对齐可正常运行的 batch：`parallelism.default = 1`、`pipeline.default-parallelism = 1`、`table.exec.resource.default-parallelism = 1`，避免 CDC 将每个 JDBC Source 拆成 4 个 task 后并发打库。
- 保持下游 `v_bb_tx`、`v_matched_settle`、`v_bb_base` 和 sink 字段逻辑不变。

## 验证

- 三个主 Source 不再裸扫大表。
- CDC 运行图并行度与 batch 一致，避免 Source task 数量膨胀。
- 默认 CDC 窗口仍为 `[CURRENT_DATE - 1 day, CURRENT_DATE)`。
- 卡组织、BlueBanc provider、Master/VISA、Consumption/Credit、排除 AUTO CLASS 过滤逻辑保留。
