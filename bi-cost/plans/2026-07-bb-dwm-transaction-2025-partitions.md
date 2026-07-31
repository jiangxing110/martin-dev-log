# BB DWM Transaction V2 2025 分区补充执行计划

**Goal:** 修复 BB 交易 DWM batch 写入历史 `transaction_time` 时缺少 2025 年 8-12 月分区的问题。

## Steps

- [x] 读取 Flink connector 报错，确认失败点在 ADBPG sink 写入。
- [x] 确认目标表 `dwm_bb_card_transaction_detail_v2_p` 以 `transaction_time` 分区。
- [x] 确认失败行 `transaction_time = 2025-11-14 09:54:15.494`，当前 DDL 只有 2026 年分区。
- [x] 新增 2025 年 8-12 月分区迁移脚本。
- [x] 同步更新目标表建表脚本。
- [x] 做文本级验证，确认 2025-11 分区已覆盖失败行月份。
