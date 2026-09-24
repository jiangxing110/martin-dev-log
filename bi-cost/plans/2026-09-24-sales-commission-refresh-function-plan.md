# 销售佣金刷新函数修复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement the plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 Flink CDC 刷新任务读取 `void` 函数结果导致的失败。

**Architecture:** 数据库刷新函数返回文本状态，Flink JDBC source 继续读取单行单列结果并交给 blackhole sink；物化视图刷新逻辑和 advisory lock 逻辑保持不变。

**Tech Stack:** PostgreSQL/ADBPG PL/pgSQL、Flink SQL JDBC connector。

**Spec:** `design-docs/2026-09-24-sales-commission-refresh-function-design.md`

## Global Constraints

- 不改变物化视图 SQL 和刷新业务逻辑。
- 刷新异常必须继续抛出。
- 不执行 git commit 或 git push。

## Tasks

### Task 1: 修复函数返回类型

- [x] 删除旧的 `void` 函数定义。
- [x] 创建返回 `text` 的同名函数。
- [x] 保留并发锁和异常释放逻辑。

### Task 2: 验证

- [x] 检查函数包含 `RETURNS text` 和成功状态返回值。
- [x] 运行 `git diff --check`。
- [ ] 在 ADB 执行函数脚本并手动调用一次。
- [ ] 重启 Flink CDC 任务确认不再失败。
