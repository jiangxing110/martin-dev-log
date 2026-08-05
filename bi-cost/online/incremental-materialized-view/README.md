# 增量物化视图

本目录存放通过 `CREATE INCREMENTAL MATERIALIZED VIEW` 创建的增量物化视图。

增量物化视图随底表变化自动维护，不需要配置
`REFRESH MATERIALIZED VIEW` 调度。ADBPG 可能为复杂查询自动创建
`nest`、`imv` 等内部对象；这些对象由数据库维护，不应单独修改或删除。

同事现有的毛利及有效收入增量物化视图不因本目录创建而移动或修改。

