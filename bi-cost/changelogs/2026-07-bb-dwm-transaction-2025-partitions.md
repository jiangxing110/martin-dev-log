# BB DWM Transaction V2 补充 2025 年 5 个月分区

## 变更时间

2026-07-30 22:00:21

## 变更内容

- 新增 `dwm.dwm_bb_card_transaction_detail_v2_p` 的 2025 年 8-12 月 transaction_time 分区。
- 新增生产迁移脚本：`flink/quantum-v2/bb/ddl-migrations/20260730_add_bb_dwm_tx_v2_2025_partitions.sql`。
- 同步更新建表脚本，避免新环境初始化缺少历史分区。

## 修复问题

- 修复 batch 写入 `transaction_time = 2025-11-14 09:54:15.494` 时 ADBPG 报 `no partition of relation found for row`。
