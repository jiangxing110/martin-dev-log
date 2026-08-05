# Quantum PostgreSQL Delete Schedule Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `online/delete` 中生成 BB、QI、SL 的 PostgreSQL/ADBPG 原生日常和月度删除调度脚本。

**Architecture:** 每个渠道使用一个日常存储过程和一个月度存储过程，共 6 个脚本。脚本通过 `pg_cron` 注册调用存储过程，并根据 `cron.timezone` 安全选择北京时间或 UTC 表达式。

**Tech Stack:** PostgreSQL SQL、PL/pgSQL、pg_cron、AnalyticDB PostgreSQL

## Global Constraints

- 日常 CDC 删除每天北京时间 02:00 执行。
- monthly-cdc 删除每月 8 日北京时间 02:00 执行。
- DELETE 范围和 `special_fee_type` 条件必须与对应 Flink 脚本一致。
- 不修改现有 Flink SQL。

---

### Task 1: BB 删除调度

**Files:**
- Create: `online/delete/schedule_quantum_bb_cdc_delete_2am.sql`
- Create: `online/delete/schedule_quantum_bb_monthly_delete_2am.sql`

- [ ] 创建 BB 日常存储过程，顺序执行普通汇总、固定成本和 Active Card 删除。
- [ ] 创建 BB 月度存储过程，删除上个月对应的三类数据。
- [ ] 注册幂等 pg_cron 任务并输出注册结果。

### Task 2: QI 删除调度

**Files:**
- Create: `online/delete/schedule_quantum_qi_cdc_delete_2am.sql`
- Create: `online/delete/schedule_quantum_qi_monthly_delete_2am.sql`

- [ ] 创建 QI 日常存储过程，保留事实表和配置表变化月份逻辑。
- [ ] 创建 QI 月度存储过程，删除上月普通汇总和固定成本。
- [ ] 注册幂等 pg_cron 任务并输出注册结果。

### Task 3: SL 删除调度

**Files:**
- Create: `online/delete/schedule_quantum_sl_cdc_delete_2am.sql`
- Create: `online/delete/schedule_quantum_sl_monthly_delete_2am.sql`

- [ ] 创建 SL 日常存储过程，保留结算月份和固定成本配置变化逻辑。
- [ ] 创建 SL 月度存储过程，删除上月普通汇总和固定成本。
- [ ] 注册幂等 pg_cron 任务并输出注册结果。

### Task 4: 静态验证

**Files:**
- Test: `online/delete/*.sql`

- [ ] 验证 6 个脚本均包含扩展检查、时区判断、幂等注册和结果查询。
- [ ] 对照 14 个 Flink DELETE 核对目标表、月份范围及专项费用条件。
- [ ] 运行 `git diff --check`，确认不存在空白和补丁格式问题。
