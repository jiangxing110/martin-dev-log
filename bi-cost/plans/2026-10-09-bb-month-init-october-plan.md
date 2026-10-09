# BB 2026 年 10 月初始化脚本 Implementation Plan

**Goal:** 基于 9 月 BB 月初始化脚本生成完整月份范围的 2026 年 10 月脚本。

**Architecture:** 仅复制脚本并顺延月份边界，不改变 SQL 业务逻辑。

**Tech Stack:** Flink SQL、PostgreSQL JDBC、Markdown、Git。

**Spec:** `design-docs/2026-10-09-bb-month-init-october-design.md`

## Constraints

- 10 月范围为 `[2026-10-01, 2026-11-01)`。
- 保留字段定义、计算逻辑、删除函数和 sink 配置。
- 不执行上线、提交或推送。

## Task 1：生成月度脚本

- [x] 生成 active card count 脚本。
- [x] 生成 card finance 脚本。
- [x] 生成 channel fixed fee 脚本。
- [x] 更新文件名、日期边界和更新时间。

## Task 2：静态检查

- [x] 确认文件名和业务日期边界均指向 2026 年 10 月。
- [x] 检查无 9 月日期残留。
- [x] 运行 `git diff --check`。
