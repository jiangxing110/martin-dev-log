# QI DWS CDC 心跳超时修复方案

## 摘要

QI DWS CDC 在运行时出现 TaskManager heartbeat timeout。该脚本与正常运行的 batch/monthly 相比，执行参数较弱，并且 DWM Source 会先读取整张 `dwm.dwm_qi_card_transaction_detail_v2_p`，再在 Flink 内计算受影响月份，容易造成大范围扫描和 TM 资源压力。

## 方案

- 将执行参数对齐 QI DWS batch/monthly：并行度 4、开启 operator chaining、补充网络内存参数和 `heartbeat.timeout = 600000`。
- 将 DWM 明细 Source 改为在 PostgreSQL 侧计算 `fact_changed_months`、`config_changed_months`、`changed_months`。
- 额外增加 `source_qi_changed_months`，避免 delete-only 变更因为 DWM Source 只返回未删除明细而丢失受影响月份。
- DWM Source 只读取受影响月份内未删除明细，保留后续 DWS 聚合和 rate 逻辑不变。
- 增加 `scan.auto-commit = false` 并将 fetch size 调整为 2000，和 batch/monthly 的 JDBC 读取方式一致。

## 验证

- CDC 不再直接全量读取 `dwm.dwm_qi_card_transaction_detail_v2_p`。
- 受影响月份口径与删除函数一致。
- 删除变更月份由独立 changed months Source 提供，不依赖未删除明细反推。
- 业务聚合公式、rate 取值、sink 字段顺序不变。
