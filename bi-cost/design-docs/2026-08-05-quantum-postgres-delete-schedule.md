# 量子卡 PostgreSQL 删除调度方案

## 摘要

将 `flink/quantum-v2` 中 BB、QI、SL 的 DWS DELETE 逻辑迁移为
PostgreSQL/ADBPG 原生存储过程，并通过 `pg_cron` 调度。日常 CDC
删除每天北京时间 02:00 执行；monthly-cdc 删除每月 8 日北京时间
02:00 执行。

## 设计

- BB、QI、SL 分别提供日常和月度脚本，共 6 个注册脚本。
- 每个脚本创建一个渠道级存储过程；同一渠道内的普通汇总、固定成本
  和 Active Card 删除按顺序执行，避免同表并发删除。
- 日常任务沿用原 CDC 的前一天 `[CURRENT_DATE - 1 DAY, CURRENT_DATE)`
  变化月份识别逻辑。
- 月度任务只删除上个月 `[上月月初, 本月月初)` 数据。
- `special_fee_type` 条件完全沿用对应 Flink DELETE：
  普通汇总不删除专项费用，固定成本只删除 `CHANNEL_FIXED_FEE`，
  BB Active Card 只删除 `ACTIVE_CARD_ACCOUNT_FEE`。
- 注册脚本根据 `cron.timezone` 选择北京时间或 UTC cron 表达式；
  其他时区直接报错，避免任务在错误时间执行。

## 执行顺序

1. 在目标 ADBPG 数据库执行 6 个注册脚本。
2. 查询 `cron.job` 确认任务、时区、表达式和执行用户。
3. pg_cron 删除成功后，再由现有工作流触发对应 Flink INSERT 作业。

## 风险控制

- 脚本不会创建 `pg_cron` 扩展；扩展不存在时明确报错。
- 重复执行注册脚本会先删除同名任务，再创建新任务。
- 日常与月度使用不同存储过程和 cron 名称，互不覆盖。
- 数据删除是不可逆操作，首次上线前应手动执行存储过程并核对影响行数。
