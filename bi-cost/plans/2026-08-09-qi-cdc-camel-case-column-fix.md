# QI CDC JDBC 驼峰字段修复计划

- [x] 根据异常定位 JDBC 外层查询的大小写问题。
- [x] 对照 QI batch 确认小写下划线字段模式。
- [x] 修改 Source DDL、JDBC 别名及下游字段引用。
- [x] 执行静态检查并核对业务 SQL diff。
- [ ] 重新部署验证 JDBC Source 正常打开。
