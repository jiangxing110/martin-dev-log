# 物化视图目录分包方案

## 摘要

将 `online/view` 更名为 `online/materialized-view`，用于存放需要定时刷新的
普通物化视图；新增同级 `online/incremental-materialized-view`，用于存放
随底表自动维护的增量物化视图。

本次仅调整仓库目录和补充说明，不修改 SQL 内容、数据库对象名或调度逻辑。

## 目录

```text
online/
├── materialized-view/
└── incremental-materialized-view/
```

