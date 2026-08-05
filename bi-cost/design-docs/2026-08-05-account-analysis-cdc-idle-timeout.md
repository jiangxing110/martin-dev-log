# Account Analysis CDC 空闲事务超时修复

## 摘要

`source_crypto_assets_transfers` 在 PostgreSQL publication 初始化/流读取启动时
被 `idle_in_transaction_session_timeout` 断开，Source 先失败，随后 checkpoint
因无法快照失败 Source 而失败。Checkpoint 不是根因。

## 修改

- 11 个 Source 禁止 Debezium 自动创建或修改预建 publication。
- 11 个 Source 保留 replication slot，停止作业时不自动删除。
- 11 个 Source 开启增量快照，抓取批次统一为 4096。
- 新增源 PostgreSQL 只读环境检查脚本。
- 不修改业务 JOIN、激活阈值、字段映射或 ADBPG Sink。

## 部署前提

`flink_cdc_publication` 必须已经包含脚本使用的 11 张源表。如果源库配置的
`idle_in_transaction_session_timeout` 仍不足以支撑 CDC 初始化，需要 DBA
针对 CDC 用户提高该参数，修改后重新建立连接。

