# QI CDC JDBC 关联下推方案

## 摘要

QI DWM CDC 连续出现 TaskManager 心跳超时。主交易虽然只扫描昨天发生变化的数据，但 Flink 仍全量读取 `quantum_card_transaction_extend`、`api_account_relation` 和 `dim_sale_account_relation_p` 并执行 Join 和窗口排序，导致 TM CPU、内存和 GC 压力过高。

## 目标

- 保留 `qbit_card_transaction` 昨天 `updateTime/createTime/deleteTime` 变更窗口。
- 参考 batch，将卡 BIN、交易扩展和销售关系计算下推到 PostgreSQL。
- 保持 DWM 输出字段、销售关系优先级和下游分摊逻辑不变。

## 设计

1. 主交易 Source 在 PostgreSQL 内关联 `card_bin` 和 `quantum_card_transaction_extend`，扩展表仅匹配当前变更交易且限制 `channel_provision = 'QBIT'`。
2. 新增单一 `source_qi_sale_relation`，通过 CTE 复用昨天变更交易集合，在 PostgreSQL 内分别匹配直接账户和根账户销售关系。
3. 直接账户关系优先，未命中时回退根账户关系，与现有 Flink 视图语义一致。
4. 删除 Flink 侧四个全量 Source、两个 `ROW_NUMBER()` 视图及相关 Join。
5. `dim_account` 保持独立 Source，与 batch 一致。

## 验证

- SQL 中不存在无条件全量读取 `quantum_card_transaction_extend` 的 Source。
- SQL 中不存在独立全量读取销售关系的 Source。
- 主交易和销售关系 CTE 使用相同的昨天变更窗口。
- DWM View 和 Sink 字段顺序不变。
