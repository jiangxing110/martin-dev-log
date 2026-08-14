# 普通物化视图

本目录存放需要通过 `REFRESH MATERIALIZED VIEW` 更新的普通物化视图。

- `mv_*.sql`：创建普通物化视图和索引。
- `schedule_refresh_*.sql`：注册物化视图刷新任务。

普通物化视图不会随底表变化自动维护，部署时需要同时确认刷新调度。

