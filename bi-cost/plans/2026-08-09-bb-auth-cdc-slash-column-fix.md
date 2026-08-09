# BB Auth CDC 斜杠字段修复计划

- [x] 根据异常定位 PostgreSQL 在 JDBC Source 打开阶段解析到 `/`。
- [x] 对照 BB Auth batch/monthly-cdc 确认安全字段别名写法。
- [x] 将 Auth Source DDL 和下游引用改为 snake_case。
- [x] 根据 heartbeat 截图定位失败节点为 `source_qbit_card`。
- [x] 将 `source_qbit_card` 改为按昨天 Auth 窗口命中的 `Card Proxy` 下推过滤。
- [x] 执行静态检查确认不再使用带斜杠字段名，且 `source_qbit_card` 不再全量扫描。
- [ ] 重新部署验证 JDBC Source 正常打开。
