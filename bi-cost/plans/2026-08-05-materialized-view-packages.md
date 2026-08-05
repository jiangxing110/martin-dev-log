# Materialized View Packages Implementation Plan

**Goal:** 区分普通物化视图和增量物化视图的上线脚本目录。

- [x] 将 `online/view` 更名为 `online/materialized-view`。
- [x] 保持原 SQL 文件内容不变。
- [x] 新增 `online/incremental-materialized-view`。
- [x] 为两个目录补充维护说明。
- [x] 校验移动前后 SQL 文件内容和文件数量。
