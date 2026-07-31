# BB DWM Transaction V2 2025 分区补充方案

## 摘要

BB 交易 DWM 表 `dwm.dwm_bb_card_transaction_detail_v2_p` 按 `transaction_time` 做月分区。批处理回刷虽然按 `start_time/end_time` 覆盖 `transaction_time`、`original_completion_time` 和 refund `postDate` 多种业务口径，但最终写入物理分区时仍以 `transaction_time` 路由。

本次失败行的 `transaction_time` 是 `2025-11-14 09:54:15.494`，而当前 DDL 只创建了 2026 年分区，因此 ADBPG 报 `no partition of relation found for row`。本次按历史回刷范围补 2025-08 至 2025-12 共 5 个月分区。

## 方案

- 不改 batch 回刷筛选口径。
- 为 `dwm.dwm_bb_card_transaction_detail_v2_p` 补充 2025 年 8-12 月分区。
- 新增独立迁移脚本，生产环境可直接执行补分区。
- 同步更新建表脚本，避免新环境初始化后再次缺 2025 分区。

## 影响

- 修复 2025 年 8-12 月 `transaction_time` 明细无法写入的问题。
- 不改变 DWM 主键、指标口径和 batch 入参含义。
- 如果未来出现 2025 年以前的 `transaction_time`，仍需继续补对应历史分区或评估 default partition。
