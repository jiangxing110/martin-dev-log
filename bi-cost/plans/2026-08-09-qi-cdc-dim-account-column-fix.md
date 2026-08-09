# QI CDC dim_account Column Fix Plan

**Goal:** 修复 QI DWM CDC 因读取不存在的 `dim_account.delete_time` 而启动失败。

- [x] 根据异常定位失败的 JDBC Source。
- [x] 对照 QI batch 确认 `dim.dim_account` 字段口径。
- [x] 删除 Source DDL 和 JDBC 查询中的 `delete_time`。
- [x] 执行静态检查并确认业务 SQL 无其他变化。
- [ ] 重新部署验证 Source 可以正常打开。
