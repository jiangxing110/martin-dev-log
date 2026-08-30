# Online ODS Batch and CDC Scripts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 6 张 Online ODS 表生成 batch 与 ods-day-cdc 两套 SQL 脚本。

**Architecture:** `online/cdc/ods-day-cdc` 脚本复用现有字段和 sink 映射，但与 batch 脚本一样使用 JDBC 批读，并固定过滤前一天 `create_time/update_time` 变化的数据；目录名称表示日级变更/回刷用途，不代表流式 postgres-cdc。batch 脚本使用 `start_time/end_time` 区间过滤。两套脚本均写入 ADBPG upsert 目标。

**Tech Stack:** Flink SQL、PostgreSQL JDBC、PostgreSQL CDC、ADBPG sink。

**Spec:** `design-docs/2026-08-30-online-ods-batch-cdc-design.md`

## Global Constraints

- 不修改用户已有未提交文件。
- 6 张表各生成 1 份 batch 和 1 份 CDC，共 12 份 SQL。
- 保留现有字段顺序、字段类型、目标表、主键、dt 和 submit_time 规则。
- batch 和 ods-day-cdc 均使用 JDBC 批读 + ADBPG upsert。
- 不在新脚本中创建或依赖 postgres-cdc slot、publication。
- batch 使用 `${start_time}` 和 `${end_time}`，按 `[start_time, end_time)` 过滤新增或修改记录。
- ods-day-cdc 使用 `[CURRENT_DATE - INTERVAL '1 day', CURRENT_DATE)` 过滤新增或修改记录。

---

### Task 1: 创建 CDC 目录脚本

**Files:**
- Create: `online/cdc/ods-day-cdc/ods_online_global_sub_account-cdc-sql.sql`
- Create: `online/cdc/ods-day-cdc/ods_online_crypto_assets_addresses-cdc-sql.sql`
- Create: `online/cdc/ods-day-cdc/ods_online_crypto_assets_transactions-cdc-sql.sql`
- Create: `online/cdc/ods-day-cdc/ods_online_idv_channel_request_record-cdc-sql.sql`
- Create: `online/cdc/ods-day-cdc/ods_online_payment_transaction_record-cdc-sql.sql`
- Create: `online/cdc/ods-day-cdc/ods_online_qbit_physical_card-cdc-sql.sql`

- [x] 从现有 `online/cdc/ods` 对应脚本生成新文件。
- [x] 保持 source/sink 定义和 INSERT 映射完全一致。
- [x] 检查 6 份文件均使用 JDBC 批处理。

### Task 2: 创建 Batch 目录脚本

**Files:**
- Create: `online/batch/ods/ods_online_global_sub_account-batch-sql.sql`
- Create: `online/batch/ods/ods_online_crypto_assets_addresses-batch-sql.sql`
- Create: `online/batch/ods/ods_online_crypto_assets_transactions-batch-sql.sql`
- Create: `online/batch/ods/ods_online_idv_channel_request_record-batch-sql.sql`
- Create: `online/batch/ods/ods_online_payment_transaction_record-batch-sql.sql`
- Create: `online/batch/ods/ods_online_qbit_physical_card-batch-sql.sql`

- [x] 复制 CDC 的 source/sink 字段结构和 INSERT 映射。
- [x] 将 source connector 改为 JDBC，并使用 PG Test 连接参数。
- [x] 保留目标 ADBPG upsert 配置。
- [x] 将作业说明改为 JDBC 批处理和全量初始化语义。

### Task 3: 静态验证与交付

**Files:**
- Verify: 12 个新增 SQL 文件及本计划涉及的目录。

- [x] 统计目录文件数量为 batch 6、CDC 6。
- [x] 检查每个脚本包含一个 source、一个 sink 和一个 INSERT。
- [x] 检查 batch/CDC 成对脚本的目标表、主键及字段数量一致。
- [x] 查看 Git diff，确认现有用户修改未被覆盖。
