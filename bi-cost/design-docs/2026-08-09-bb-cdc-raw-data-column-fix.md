# BB CDC raw_data 字段修复方案

## 摘要

BB DWM CDC 的 settlement Source 直接读取 `ods.ods_qbit_card_settlement.raw_data`。线上报错显示 JDBC 打开 Source 时找不到 `raw_data` 字段，说明当前部署环境的该 Source 依赖字段与实际表结构不一致。

## 方案

- 参考 BB batch 的 online 原表读取方式，将 settlement Source 改为读取 `public."qbitCardSettlement"`。
- 在 JDBC 子查询里显式映射驼峰字段：`CAST("rawData" AS text) AS raw_data`。
- 保持下游 `v_matched_settle`、`v_bb_base` 和成本计算字段不变。
- 保留 `provider = 'BlueBancCard'`、未删除和 `rawData` NUL 字符过滤。

## 验证

- CDC 文件不再从 `ods.ods_qbit_card_settlement` 读取 settlement。
- Source DDL 中的 `raw_data` 由 online 原表 `rawData` 显式投影得到。
- 下游引用仍统一使用 `s.raw_data`，业务逻辑不扩大改动范围。
