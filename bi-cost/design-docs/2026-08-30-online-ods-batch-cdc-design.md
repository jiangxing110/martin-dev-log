# Online ODS Batch and CDC Scripts Design

## 摘要

为 6 张 Online ODS 表补齐独立的批处理脚本，并将现有 CDC 脚本归档到 `ods-day-cdc` 目录，保持现有字段映射和目标表语义不变。

## 背景

当前 6 张表已有 `flink/ods/` 下的 CDC 源脚本以及 `online/cdc/ods/` 下的 CDC 副本，但缺少 `online/batch/ods/` 下可用于初始化、补数和区间重跑的 JDBC 批处理版本，也缺少按目录约定放置的 `online/cdc/ods-day-cdc/` 版本。

## 方案

为以下表各创建一份 batch 和一份 CDC：

- `globalSubAccount` → `ods_global_sub_account`
- `crypto_assets_addresses` → `ods_crypto_assets_addresses`
- `crypto_assets_transactions` → `ods_crypto_assets_transactions`
- `idv_channel_request_record` → `ods_idv_channel_request_record`
- `payment_transaction_record` → `ods_payment_transaction_record`
- `qbitPhysicalCard` → `ods_qbit_physical_card`

`ods-day-cdc` 版本从现有 `online/cdc/ods/` 脚本复制字段映射，但按用户要求统一使用 JDBC 批处理，不使用 postgres-cdc 流式连接；目录名称仅表示日级变更/回刷用途。

Batch 版本参考 BB 交易 batch 脚本的 JDBC source + ADBPG sink 模式：源端使用 PG JDBC 批读，显式列出字段并将 Flink `STRING` 字段在 PG 侧转换为 `text`，通过 `start_time/end_time` 过滤 `create_time` 或 `update_time`，目标端使用 ADBPG upsert；沿用每张表现有的源字段、目标字段、类型转换、`dt = create_time::DATE` 和 `submit_time = create_time` 规则。`ods-day-cdc` 版本固定读取前一天新增或修改的数据。

## 影响范围

- 新增 6 个 `online/batch/ods/*-batch-sql.sql`。
- 新增 6 个 `online/cdc/ods-day-cdc/*-cdc-sql.sql`。
- 不修改已有 `flink/ods/` 和 `online/cdc/ods/` 文件。
- 不改变 ODS 表结构、主键或已有脚本；新脚本不创建 CDC slot。

## 验证

- 检查新目录和文件数量均为 6。
- 检查每份脚本恰有一个 source、一个 sink 和一个 INSERT。
- 检查 batch 和 ods-day-cdc 两套脚本均使用 JDBC。
- 对比 batch 与 CDC 的字段声明、SELECT 字段数量及目标表名称。
- 检查 Git diff，确保没有覆盖用户现有未提交修改。
