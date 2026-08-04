# Quantum v2 月度补偿 CDC 变更日志

## 2026-08-04

- 新增独立包 `flink/quantum-v2/{bb,qi,sl}/monthly-cdc/`，放置 `bb`、`qi`、`sl` 的月度补偿 CDC 脚本，用于每月 8 号重跑上月 Quantum v2 成本。
- DWM 明细 monthly-cdc 保留 batch 逻辑和 upsert 写入。
- DWS monthly-cdc 拆分为 delete 和 insert，insert 使用 `writeMode = 'insert'`，规避 ADBPG beam 分区表 `ON CONFLICT DO UPDATE` 限制。
- monthly delete 固定清理上月完整窗口，并按 `special_fee_type` 限定普通汇总、渠道固定成本和 BB 活跃卡费用。
