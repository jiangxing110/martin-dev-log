# QI CDC JDBC Pushdown Implementation Plan

> **For agentic workers:** Execute this plan task-by-task and verify every SQL boundary before deployment.

**Goal:** 消除 QI CDC 在 Flink 中读取大表并执行大范围 Join 导致的 TaskManager 心跳超时。

**Architecture:** 保留昨天变更窗口，将交易扩展和销售关系关联下推至 PostgreSQL JDBC 子查询。Flink 只处理已裁剪的交易、账户维度和每笔交易唯一的销售关系结果。

**Tech Stack:** Flink SQL, PostgreSQL JDBC, ADB-PG sink

## Global Constraints

- 不改变昨天 `updateTime/createTime/deleteTime` 窗口。
- 不改变直接销售关系优先于根账户销售关系的规则。
- 不改变 DWM Sink 字段和顺序。
- 不提交 Git 变更。

---

### Task 1: 主交易关联下推

**Files:**
- Modify: `flink/quantum-v2/qi/cdc/dwm_online_qi_card_transaction_detail_v2-cdc-sql.sql`

- [x] 在静态检查中确认当前存在全量扩展表 Source。
- [x] 将 `card_bin` 和 QBIT 扩展字段合并到主交易 JDBC 查询。
- [x] 删除独立的卡 BIN 和扩展表 Source。
- [x] 校验主交易昨天变更窗口保持不变。

### Task 2: 销售关系关联下推

**Files:**
- Modify: `flink/quantum-v2/qi/cdc/dwm_online_qi_card_transaction_detail_v2-cdc-sql.sql`

- [x] 在静态检查中确认当前存在全量关系 Source 和 Flink 窗口排序。
- [x] 新增 `source_qi_sale_relation` PostgreSQL CTE 查询。
- [x] 删除独立账户关系、销售关系 Source 和排名视图。
- [x] 将 DWM View 改为关联唯一销售关系 Source。

### Task 3: 静态验证

**Files:**
- Verify: `flink/quantum-v2/qi/cdc/dwm_online_qi_card_transaction_detail_v2-cdc-sql.sql`

- [x] 检查无遗留 Source 或视图引用。
- [x] 检查变更窗口在两个 JDBC 查询中一致。
- [x] 检查 DWM Sink 字段顺序未改变。
- [x] 执行 `git diff --check` 并审阅最终 diff。
- [ ] 重新部署并观察 TaskManager 心跳和 GC。
