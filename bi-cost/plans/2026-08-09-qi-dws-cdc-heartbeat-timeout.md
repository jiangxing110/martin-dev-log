# QI DWS CDC 心跳超时修复计划

- [x] 根据异常确认是 TaskManager heartbeat timeout。
- [x] 对照 batch/monthly 找出执行参数差异。
- [x] 定位 CDC DWM Source 全表读取导致读放大。
- [x] 将 DWM Source 改为 PostgreSQL 侧按 affected months 下推过滤。
- [x] 增加独立 changed months Source，覆盖 delete-only 变更月份。
- [x] 执行静态检查确认不再全表拉取 DWM。
- [ ] 重新部署验证作业不再 heartbeat timeout。
