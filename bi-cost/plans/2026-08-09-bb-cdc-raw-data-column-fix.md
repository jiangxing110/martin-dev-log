# BB CDC raw_data 字段修复计划

- [x] 根据异常定位 `raw_data` 字段来源。
- [x] 对照 BB batch 和 ODS 同步脚本确认 online 原表字段为 `rawData`。
- [x] 修改 BB CDC settlement Source，显式投影 `rawData AS raw_data`。
- [x] 执行静态检查确认 Source 不再依赖 ODS `raw_data`。
- [ ] 重新部署验证 JDBC Source 正常打开。
