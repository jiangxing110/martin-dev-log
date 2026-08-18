# dws_qbit_card_transaction v2 — 运行部署指南

> 配套 `flink_reference/` 下的 `table/` `cdc/` `batch/` 脚本。
> 本指南说明如何在阿里云实时计算 Flink 版（VVR SQL v2）上把这套「分表、不重建表、跨年安全」的 ETL 跑起来、部署上线、并安全切换。

## 0. 适用平台与组件

- **计算**：阿里云实时计算 Flink 版（VVR SQL v2 作业）。
- **结果表连接器**：`connector='adbpg'`（AnalyticDB for PostgreSQL，平台托管，无需额外依赖）。
- **源表 / 删除函数调用**：`connector='jdbc'`，需要 **PostgreSQL JDBC 驱动 jar** 作为「附加依赖文件」。
- **凭证**：通过平台「变量」里的 secret 类型变量 `${secret_values.ADB_PG_*}` 注入。
- **目标库**：现有 `dws_qbit_card_transaction_<YYYY>` / `_extend_<YYYY>` 分表（含线上数据，不重建）。

## 1. 准备阶段（目标库，一次性）

### 1.1 注册删除函数

删除函数被 Flink 作业里的 JDBC 临时表调用，**必须先于任何作业注册**。它只建函数、不碰任何表。

```bash
psql "$ADB_PG_DSN" -f table/register_fn_dws_qbit_card_transaction_cdc_delete_v2.sql
```

创建：
- `public.fn_delete_qbit_card_transaction_cdc(p_dry_run, p_start, p_end)`
- `public.fn_delete_qbit_card_transaction_extend_cdc(p_dry_run, p_start, p_end)`

`p_start IS NULL` → CDC 模式（扫描昨天变更窗口）；`p_start/p_end` 传入日期 → 补数/修复模式（按 `create_date` 区间跨分表清理）。

### 1.2 dry-run 核对影响行数（先别真删）

```sql
SELECT public.fn_delete_qbit_card_transaction_cdc(true);        -- 只 COUNT，返回计划删除行数
SELECT public.fn_delete_qbit_card_transaction_extend_cdc(true);
```

只想核对 2026 修复区间时：

```sql
SELECT public.fn_delete_qbit_card_transaction_cdc(true, DATE '2026-01-01', DATE '2026-08-17');
```

确认返回数字在预期内（不要误删大量历史）后再进入正式流程。

## 2. 在 Flink 平台建作业（每个 .sql 一个作业）

对以下每个文件各建一个 SQL 作业，全文粘贴：

| 作业 | 文件 | 类型 | 运行模式 |
|------|------|------|----------|
| 修复作业 | `batch/dws_qbit_card_transaction_v2-batch-sql.sql` | 批处理 | BATCH（按需手动触发） |
| 修复作业 | `batch/dws_qbit_card_transaction_extend_v2-batch-sql.sql` | 批处理 | BATCH（按需手动触发） |
| 增量作业 | `cdc/dws_qbit_card_transaction_v2-cdc-sql.sql` | 流/增量 | BATCH + 每日定时 |
| 增量作业 | `cdc/dws_qbit_card_transaction_extend_v2-cdc-sql.sql` | 流/增量 | BATCH + 每日定时 |

建作业步骤：

1. 新建 SQL 作业（VVR SQL v2），粘贴文件全文。
2. **附加依赖文件**：上传 `postgresql-42.7.4.jar`（JDBC source 与删除函数调用需要）。
3. **变量**：在工作空间「变量」中定义 5 个 **secret 类型**变量：
   - `ADB_PG_VPC_HOSTNAME`
   - `ADB_PG_VPC_PORT`
   - `ADB_PG_DATABASE`
   - `ADB_PG_USERNAME`
   - `ADB_PG_PASSWORD`
4. 文件头部的 `SET` 已配好，无需改动。

> CDC 作业也用 **BATCH 模式 + 每日定时**（如 02:00），不是长驻流。`CURRENT_DATE` 取运行当日，处理「昨天」窗口；先删后插 + 确定性主键保证重复调度幂等。

## 3. 修复现有脏数据（batch 作业）

针对「pending 反复重写 + 非幂等主键」导致的重复/膨胀数据做一次校正。

- 默认修复区间 `2026-01-01 ~ 2026-08-17`（脚本第 0 步删除函数调用、第 2 步 `v_scope_rows` 过滤的日期），按需修改，**可跨年**（删除函数会自动覆盖 2025 / 2026 两个分表）。
- **首次**：把删除函数调用里的 `false` 改成 `true` 跑一次，看控制台 `affected_rows` 是否合理；确认后改回 `false`。
- 用 **BATCH 模式**启动：整段删除 + 确定性哈希主键重算写入，旧的随机 id 重复行被清掉，重新生成确定性行。

## 4. 部署每日增量（cdc 作业）

- 扫描「昨天 `updateTime` / `deleteTime` 变更」的源行 → 定位受影响 `create_date`（含往年创建的 pending）→ 调删除函数清对应分表 → 重算写回。
- **运行方式**：BATCH 模式 + 每日定时调度（如 02:00）。
- **首次部署**：将脚本中 `fn_delete_qbit_card_transaction_cdc(false)` 改 `true` dry-run 一次确认；改回 `false` 后正式调度。
- 因为「先删后插 + 确定性主键」，重复调度天然幂等。

## 5. 灰度切换

1. 停旧 PG 三步任务（`insert_task_job.sql` / `delete_task_job.sql` / `update_insert_job.sql`）。
2. 观察 cdc 作业连续跑几天无异常后，v2 正式接管每日增量。

## 6. 注意事项 / 已知坑

- **失败重跑的数据空洞**：删除函数先 DELETE、INSERT 后执行。若作业在「删完但没插完」时挂掉、且当天窗口已过，下次调度不会补那天的数。
  - **缓解**：把 cdc 脚本 `restart-strategy.fixed-delay.attempts` 从 `1` 调到 `3`，瞬时 JDBC 错误会在同一 `CURRENT_DATE` 窗口内自愈（重删=空操作，重整插入）。
  - 硬性失败则手动用 batch 跑一次对应日期区间补数。
- **CDC 源是全表扫描** `qbit_card_transaction`（LEFT JOIN `qbitCard`）。大表建议给 `updateTime` / `deleteTime` 加索引，或在源子查询加 `scan.query` 收窄；删除函数已按年份路由，切换源不影响跨年逻辑。
- **删除函数被多次调用**：每个分表 INSERT 的 `CROSS JOIN` 都会触发一次（幂等，多删几次无碍）。想严格只删一次，可把删除函数调用挪出 Flink，作为独立调度步骤先执行。
- **extend 的 `settle_fee` 列**：旧 INSERT 引用过但该 DDL 副本可能未列出，以线上真实表结构为准，执行前对齐（删列或 `ALTER TABLE ... ADD COLUMN`）。
- **回滚简单**：v1 不改表结构、不删表。出问题就停 cdc、重启旧 PG 三步任务；删除函数只动指定日期/区间，不影响其他日期。
- **幂等机制回顾**：删除函数（昨天变更 → 受影响唯一业务键 `(create_date, account_id, provider, bin, business_type, status)` → 对应分表按 key 精准 DELETE）→ Flink 重算 `id = ABS(HASH_CODE(CONCAT(create_date, 业务键)))` → `UPSERT writeMode='upsert'`（同 key 覆盖 / 新 key 新增）。确定性主键 + 按 key 删/写，任意重跑只留一份，写放大与失败空窗面从“整天”降到“单 key”。

## 7. 文件清单映射

```
flink_reference/
├── README.md            # 设计说明（为何改、v1/v2 路线图）
├── DEPLOY.md            # 本文件：运行部署指南
├── table/
│   ├── register_fn_dws_qbit_card_transaction_cdc_delete_v2.sql  # 删除函数（步骤 1.1）
│   ├── dws_qbit_card_transaction_ddl.sql                       # 结构参考（IF NOT EXISTS）
│   └── dws_qbit_card_transaction_extend_ddl.sql               # extend 结构参考
├── cdc/                 # 流作业，每表一个（步骤 2 / 4）
│   ├── dws_qbit_card_transaction_v2-cdc-sql.sql
│   └── dws_qbit_card_transaction_extend_v2-cdc-sql.sql
└── batch/               # 批作业（修复/补数），每表一个（步骤 3）
    ├── dws_qbit_card_transaction_v2-batch-sql.sql
    └── dws_qbit_card_transaction_extend_v2-batch-sql.sql
```

## 8. 上线检查清单（建议顺序）

- [ ] 目标库执行 `register_fn_*.sql`，函数创建成功
- [ ] `fn_delete_*(true)` dry-run 返回行数合理
- [ ] Flink 各作业已建，附加依赖 jar 已上传，5 个 secret 变量已定义
- [ ] batch 作业 `true` 预演 → 改 `false` → BATCH 启动，修复完成
- [ ] cdc 作业 `true` 预演 → 改 `false` → BATCH + 每日定时上线
- [ ] cdc `restart-strategy.fixed-delay.attempts` 已调到 3（防数据空洞）
- [ ] 停旧 PG 三步任务，观察数日无异常
