# Account Analysis CDC Idle Timeout Fix Plan

**Goal:** 避免 account-analysis CDC 初始化期间因空闲事务超时导致 Source 和 checkpoint 失败。

- [x] 从异常栈定位最先失败的 Source 和 PostgreSQL 根因。
- [x] 对照仓库中大表 CDC 的可用配置。
- [x] 为 11 个 Source 禁止 publication 自动创建。
- [x] 为 11 个 Source开启增量快照并保留 slot。
- [x] 新增源 PostgreSQL 环境检查脚本。
- [x] 执行最终静态检查。
- [ ] 在源库执行环境检查并重新部署验证 checkpoint。
