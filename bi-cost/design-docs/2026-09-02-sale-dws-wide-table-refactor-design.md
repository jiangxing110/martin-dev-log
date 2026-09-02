# 销售 DWS 13/14/18 宽表化方案

## 摘要

将 13、14、18 的 CDC 与 Batch 从“PostgreSQL 先做全量关系匹配和聚合”改为“按时间窗口读取交易明细，在 Flink 中匹配销售关系并聚合”，降低全年回刷时 PostgreSQL 临时文件和排序中间结果超限的风险。

## 范围

- `task_2026/flink_reference/batch/13_*、14_*、18_*`
- `task_2026/flink_reference/cdc/13_*、14_*、18_*`

保留现有删除函数、销售 DWS 字段、年度分表 sink、确定性主键和 upsert 行为。

## 处理方案

1. 交易 source 只读取当前批次或 CDC 最近一天窗口内的有效明细。
2. 关系 source 仅读取窗口内交易账户及其 root 账户对应的有效关系。
3. Flink 分别执行直接账户关系和 root 账户关系匹配；每笔交易用 `ROW_NUMBER()` 优先直接关系、再取最新生效关系。
4. 将非空 `sale_id` 与 `am_id` 展开为统计维度；两者相同只保留一条。
5. 在 Flink 按原有业务维度聚合后写入原有年度 sink。

## 运行约束

- Batch 使用 `start_date`、`end_date`，建议按 10 天或更小窗口执行，`end_date` 按半开区间处理。
- CDC 使用最近一天变更记录确定受影响账户和日期，再读取这些 scope 的当前有效交易。
- 不执行 commit、push 或线上表删除。

## 验证

- 六个 SQL 不再包含旧的 `source_dws_*` PostgreSQL 聚合 source。
- Batch 含 `start_date/end_date` 时间窗口，CDC 含 create/update/delete 最近一天窗口。
- 六个 SQL 均包含独立关系 source、直接/root 匹配和 `ROW_NUMBER()`。
- `git diff --check` 通过，并进行 SQL 结构静态检查。
