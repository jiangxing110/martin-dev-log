# Quantum v2 月度补偿 CDC 执行计划

## 1. 脚本生成

- [x] 从 batch 派生 `bb`、`qi`、`sl` 的 monthly-cdc insert 脚本。
- [x] 将 batch 时间占位符改为动态上月窗口。
- [x] 为 DWS 汇总和特殊费用新增 monthly-cdc delete 脚本。
- [x] 将 DWS monthly insert 写入模式改为 `insert`。

## 2. 执行顺序

- [x] DWM 明细脚本先执行，保持 upsert。
- [x] DWS 普通汇总、活跃卡、固定成本按 delete 再 insert 执行。
- [x] 在执行说明中标记每月 8 号调度 cron。

## 3. 验证

- [x] 检查 monthly-cdc 脚本无残留 `${start_*}` / `${end_*}`。
- [x] 检查 DWS monthly insert 无 upsert。
- [x] 检查 monthly delete 均为单 DELETE。
