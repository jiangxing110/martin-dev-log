# BB 2026 年 8/9 月初始化脚本方案

## 摘要

修正 BB 月初始化脚本的月份边界，并生成 2026 年 9 月版本。8 月脚本统一使用完整月份窗口，9 月脚本基于修正后的 8 月模板顺延生成。

## 范围

- `flink/quantum-v2/bb/month-init/active-card-count/`
- `flink/quantum-v2/bb/month-init/card-finance/`
- `flink/quantum-v2/bb/month-init/channel-fixed-fee/`

## 处理方案

- 8 月：将业务数据窗口统一为 `[2026-08-01, 2026-09-01)`。
- 9 月：新增脚本并统一使用 `[2026-09-01, 2026-10-01)`。
- 保留现有字段、聚合、删除函数、sink 和计算逻辑不变。

## 验证

- 6 个脚本的文件名与月份边界一致。
- 8 月脚本不再出现 `2026-08-23`。
- 9 月脚本不再出现 8 月日期。
- `git diff --check` 通过。
