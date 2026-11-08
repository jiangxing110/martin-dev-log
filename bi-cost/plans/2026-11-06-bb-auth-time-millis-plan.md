# BB Auth 时间字段毫秒解析修复 Implementation Plan

**Goal:** 修复 BB Auth 批处理脚本解析带毫秒 `Trans Date / Time` 值时报 AM 字段错误的问题。

**Architecture:** 在 Auth source 和 Qbit card 子查询中各用 `auth_parsed` CTE 解析一次时间。分支覆盖 ISO 日期、带 AM/PM 的月/日时间、以及 24 小时月/日时间，并在需要时清理小数秒、归一零点小时。Qbit card 侧先生成时间窗内去重的 Card Proxy 集合，再与卡表 join，避免相关 `EXISTS` 重复检查。

**Tech Stack:** Flink SQL、PostgreSQL JDBC、Markdown。

**Spec:** `design-docs/2026-11-06-bb-auth-time-millis-design.md`

## Constraints

- 仅修改 `flink/quantum-v2/bb/batch/dwm_online_bb_card_auth_detail_v2-batch-sql.sql`。
- 兼容 `YYYY-MM-DDTHH:MI:SS[.fraction]`、`MM/DD/YYYY HH:MI:SS[.fraction] AM/PM` 和 `MM/DD/YYYY HH24:MI:SS[.fraction]`。
- 将带 AM/PM 的 `0:...` 与 `00:...` 小时按午夜归一为 `12:... AM`。
- 不改变业务时间窗口、字段、关联和目标表写入逻辑。
- 保留 `Created Time`，更新 `Updated Time`，格式为 `YYYY-MM-DD HH:mm:ss`。
- 不执行提交或推送。

## Review Focus

- ISO 值（含可选 T 分隔符）进入 24 小时 ISO 解析分支。
- AM/PM 值先清理小数秒并处理 0 小时，再进入 12 小时解析分支。
- 其余值进入月/日 24 小时解析分支。
- 投影、时间窗口过滤和卡片筛选使用同一解析逻辑。
- Qbit card 筛选对有效 Card Proxy 去重后 join，保持每张卡最多匹配一次。

## Execution

- [x] 评审并确认本方案。
- [x] 更新目标 SQL 的 Auth source 和卡片筛选查询，使用 `auth_parsed` CTE 覆盖三种时间格式。
- [x] 更新文件头 `Updated Time`，保留 `Created Time`。
- [x] 静态确认两个 CTE 的格式分支一致、时间过滤使用 `parsed_trans_time`，并对目标 SQL 运行 `git diff --check`。
- [x] 静态确认 Qbit card 使用去重代理集合 join，不再使用相关 `EXISTS`。
- [ ] 有目标库访问条件时，用实际样本确认带毫秒和不带毫秒值都能解析。
