# BB 2026 年 11 月初始化脚本 Implementation Plan

**Goal:** 为 BB 生成 2026 年 11 月的三类 Flink 月初始化脚本。

**Architecture:** 分别以 10 月 active card count、card finance、channel fixed fee 脚本为模板，仅顺延固化月份边界和文件头更新时间，不改 SQL 业务逻辑。

**Tech Stack:** Flink SQL、PostgreSQL JDBC、Markdown。

**Spec:** `design-docs/2026-11-05-bb-month-init-november-design.md`

## Constraints

- 业务窗口为 `[2026-11-01, 2026-12-01)`。
- 保留原字段定义、计算、删除与写入逻辑。
- 保留创建时间，`Updated Time` 设为 `2026-11-05 14:47:02`。
- 不执行上线、提交或推送。

## Execution

- [x] 生成三类 2026-11 SQL 文件，日期全部顺延至 11 月窗口。
- [x] 检查新文件名、日期边界、更新时间及 SQL 逻辑与 10 月版本一致（日期变化除外）。
- [x] 运行 `git diff --check`。
