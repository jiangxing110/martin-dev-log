# BB DWM card transaction detail v2 性能优化 — 开发方案

## 背景
`bi-cost/flink/quantum-v2/bb/batch/dwm_online_bb_card_transaction_detail_v2-batch-sql.sql` 在批量回刷场景中执行缓慢，当前作业图里最明显的瓶颈集中在交易-结算匹配和销售关系回溯两段 join 链路。

## 目标
- 降低 SQL 执行时的 join 放大和回表次数
- 避免 `OR` 条件导致的低效 join 计划
- 保持现有业务口径不变

## 方案设计

### 核心逻辑
1. 将交易与结算的匹配从单条 `OR` join 拆成两条等值 join，再 `UNION` 合并，减少 join 规划歧义。
2. 将 direct/root 两段销售关系回溯改成候选关系集的统一排序选择，避免 `v_bb_base` 被重复扫描两次。
3. 保留现有输出字段和落表结构，不改结果 schema。

### 变更清单
- 修改 `bi-cost/flink/quantum-v2/bb/batch/dwm_online_bb_card_transaction_detail_v2-batch-sql.sql`

### 风险点
- `UNION`/`ROW_NUMBER` 可能引入轻微去重开销，但通常远低于 `OR` join 和重复大表扫描的代价。
- 需要确认交易到结算的多对多语义与现有结果一致，避免误删重复明细。
- 仅靠 SQL 脚本内的 `SET` 可能无法覆盖 VVP 集群默认 TaskManager 内存，`Insufficient number of network buffers` 仍可能需要平台侧提升 `taskmanager.memory.process.size` 和 network memory。

## 验收标准
- 作业计划里不再出现基于 `OR` 的大表 join 热点
- 运行时长明显下降，且结果记录数与历史基线一致

## 备注
- 该优化仅针对执行性能，不调整业务筛选口径。
- 若运行时仍报 `required 2048, but only 983 available`，需要同步调整集群侧 TaskManager 进程内存，而不是继续只改 SQL。
