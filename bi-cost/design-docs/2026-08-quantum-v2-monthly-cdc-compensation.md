# Quantum v2 月度补偿 CDC 方案

## 摘要

Quantum v2 的实时 CDC 覆盖日常增量变更，但部分月度成本类数据需要在每月固定时间按完整上月窗口重算。
本方案新增独立的 `flink/quantum-v2/{bb,qi,sl}/monthly-cdc/` 脚本包，不改原 batch 和实时 CDC 文件：DWM 明细继续 upsert，DWS 汇总先删除上月旧数据再重新 insert。

## 目标

1. 每月 8 号可按上月完整窗口重跑 `bb`、`qi`、`sl` 的 Quantum v2 成本链路。
2. DWS 聚合表执行顺序为先 delete 后 insert，避免 ADBPG beam 分区表在 `ON CONFLICT DO UPDATE` 中更新分区列。
3. 月度 insert 逻辑直接继承 batch 口径，仅将 `start_time/end_time` 或 `start_date/end_date` 改为动态上月窗口。
4. DWM 明细层保留 upsert，不额外前置 delete。
5. 月度补偿脚本统一放在 `{bb,qi,sl}/monthly-cdc/`，和实时 `cdc/` 包隔离。

## 非目标

1. 不调整 batch 原文件。
2. 不把多个 DML 合并到一个 Flink SQL 文件里。
3. 本次不覆盖 `bz`，保持范围在当前已讨论的 `bb`、`qi`、`sl`。

## 方案

### 1. 月度窗口

所有 monthly-cdc 脚本使用同一时间窗口：

- `start`: 上月 1 号 00:00:00
- `end`: 本月 1 号 00:00:00

JDBC 子查询中使用 PostgreSQL `date_trunc('month', CURRENT_DATE - INTERVAL '1 month')` / `date_trunc('month', CURRENT_DATE)`。
Flink SQL 本体中使用 `DATE_FORMAT(CURRENT_DATE, 'yyyy-MM-01')` 组合表达式。

### 2. DWM 明细

DWM 明细脚本从 batch 派生，保留 `writeMode = 'upsert'`。
这些表是明细粒度，主键可覆盖同一条明细，不需要先删整月。
BB transaction DWM 的 settlement `createTime` 读取窗口按 BB 原始成本对账口径处理：从费用月前 1 个月开始，到费用月后下月 9 号 00:00 前结束，避免把 9 号之后的下月 settlement 计入当月成本。

### 3. DWS 汇总

DWS 汇总和特殊费用脚本拆为两步执行：

1. `*-monthly-cdc-delete-sql.sql` 删除上月对应口径旧数据。
2. `*-monthly-cdc-sql.sql` 使用 `writeMode = 'insert'` 重新灌入上月结果。

特殊费用通过 `special_fee_type` 区分：

- 普通汇总：`special_fee_type IS NULL` 或排除固定成本/活跃卡费用。
- 固定成本：`special_fee_type = 'CHANNEL_FIXED_FEE'`。
- BB 活跃卡费用：`special_fee_type = 'ACTIVE_CARD_ACCOUNT_FEE'`。

## 调度建议

在 VVR 或外部编排系统中配置 cron：`0 0 8 * *`。
各 SQL 文件仍建议拆成独立作业，按顺序串行执行，避免多 DML 单作业限制。

## 验收标准

1. monthly-cdc 文件不再依赖手工传入 `start_time/end_time` 或 `start_date/end_date`。
2. 每月 8 号执行时自然覆盖上月整月。
3. DWS insert 脚本不再生成 `ON CONFLICT DO UPDATE`。
4. DWS delete 脚本只清理上月对应 `special_fee_type` 范围，不误删其它费用类型。
