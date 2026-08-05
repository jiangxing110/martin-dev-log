# Gross Profit V2 Channel Cost MV Plan

**Goal:** 新增读取 `dws.mv_channel_cost_daily` 的毛利普通物化视图 V2。

- [x] 复制现有毛利物化视图逻辑。
- [x] 保持数据库对象和索引使用原名称，V2 仅作为脚本版本。
- [x] 将四个渠道成本桶来源切换为 `dws.mv_channel_cost_daily`。
- [x] 纳入 `treasury` 有效收入，无对应渠道成本时按 0 计算。
- [x] 保持原毛利脚本不变。
- [x] 执行静态格式和差异检查。
