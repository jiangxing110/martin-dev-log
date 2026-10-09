# BB 2026 年 10 月初始化脚本方案

## 摘要

以 BB 2026 年 9 月初始化脚本为模板，新增 2026 年 10 月 active card count、card finance 和 channel fixed fee 三类 Flink SQL。业务时间窗口使用 `[2026-10-01, 2026-11-01)`，保留已有字段、计算、删除与写入逻辑。

## 范围

- `flink/quantum-v2/bb/month-init/active-card-count/`
- `flink/quantum-v2/bb/month-init/card-finance/`
- `flink/quantum-v2/bb/month-init/channel-fixed-fee/`

## 处理方案

- 分别复制 9 月脚本生成 10 月脚本。
- 将业务数据窗口、月份范围及脚本文件名更新为 2026 年 10 月；结束边界更新为 2026-11-01。
- 保留 SQL 业务逻辑不变，文件头更新时间更新为 2026-10-09 00:00:00。

## 验证

- 三个脚本文件名与月份边界一致。
- 10 月脚本不存在残留的 9 月业务日期。
- `git diff --check` 通过。
