# STAGING 销售关系与量子卡交易宽表全量同步实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development to implement this plan task-by-task.

**目标：** 新增两份全部读写 STAGING PostgreSQL 的每日全量 Flink SQL 脚本。

**架构：** 先全量 upsert 销售关系维表，再全量读取交易及相关维度并 upsert 量子卡交易宽表。两份脚本复用现有字段映射和表结构，只改变连接配置、输出目录和交易源的时间过滤策略。

**技术栈：** Flink SQL、JDBC、PostgreSQL/ADBPG sink。

**方案：** `design-docs/2026-09-18-staging-qbit-full-sync-design.md`

## 全局约束

- JDBC host、port、username、password 必须使用 `STAGING_PG_ASSETS_*` 四个 secret 变量。
- JDBC database 必须使用 `${secret_values.STAGING_PG_ASSETS_DATABASE}`。
- 两份脚本均为全量读取 + upsert，不执行隐式目标表清空。
- STAGING 宽表目标已确认超长的 255/30 长度字段必须先扩为 `text`，不截断源数据；迁移脚本可重复执行。
- 调度顺序为销售关系脚本先执行，交易宽表脚本后执行。
- 默认只保留工作区修改，不执行 git commit 或 git push。

---

### 任务 1：新增 STAGING 销售关系全量脚本

**文件：**

- Create: `flink/quantum-v2/qbit-card-transaction-widetable/staging/dim_online_sale_account_relation-staging-full.sql`

- [x] 复用现有销售关系字段映射。
- [x] 将 source 和 sink 的连接切换为 STAGING 变量。
- [x] 保持目标表为 `dim.dim_sale_account_relation_p`。

### 任务 2：新增 STAGING 量子卡交易宽表全量脚本

**文件：**

- Create: `flink/quantum-v2/qbit-card-transaction-widetable/staging/dwm_online_qbit_card_transaction_widetable-staging-full.sql`

- [x] 复用现有交易、卡、卡组、账户、账户扩展、账户关系和销售关系字段映射。
- [x] 将全部 source、lookup 和 sink 连接切换为 STAGING 变量。
- [x] 删除交易及关联子查询中的 `start_time/end_time` 过滤。
- [x] 保持目标表为 `dwm.dwm_quantum_card_transaction_p`。

### 任务 3：静态验证与变更记录

**文件：**

- Create: `changelogs/2026-09-18-staging-qbit-full-sync.md`
- Create: `flink/quantum-v2/qbit-card-transaction-widetable/staging/dwm_qbit_card_transaction_widetable_p-staging-widen.sql`

- [x] 检查新增脚本中的连接变量、数据库名、源表和目标表。
- [x] 检查 staging 交易脚本不含时间窗口参数。
- [x] 运行 `git diff --check`。
- [x] 记录未执行真实数据库同步，交付调度依赖顺序。
- [x] 新增 STAGING 宽表超长字段迁移 SQL。
