# 毛利物化视图 V2 方案

## 摘要

使用 V2 脚本重建 `dws.mv_gross_profit_daily`，完整沿用现有毛利物化视图的收入、
分类映射和毛利计算逻辑，仅将渠道成本来源从
`dws.dws_total_channel_cost_daily_v2_p` 切换为
`dws.mv_channel_cost_daily`。

现有刷新任务继续使用 `dws.mv_gross_profit_daily`，无需新增 V2 调度。
V2 仅表示脚本版本，不进入数据库对象名称。
