# BB Auth 时间字段毫秒解析修复方案

## 摘要

修复 BB Auth 批处理导入对多种 `Trans Date / Time` 格式解析失败的问题。以解析 CTE 分支支持 ISO 日期、带 AM/PM 的月/日格式和 24 小时制月/日格式，并将小数秒及 12 小时制的零点小时归一化。

## 背景与根因

`flink/quantum-v2/bb/batch/dwm_online_bb_card_auth_detail_v2-batch-sql.sql` 的 JDBC 子查询此前固定使用 `MM/DD/YYYY HH12:MI:SS AM`。日志先暴露了毫秒被当成 AM/PM 字段，后续又暴露 `HH12` 不接受小时值 `0`。用户提供的格式样本还要求同时支持 ISO 日期和不带 AM/PM 的 24 小时格式。该字段在 Auth source 查询和 Qbit card 的 `EXISTS` 子查询中均会解析。

## 处理方案

- 在 JDBC 查询中用 `auth_parsed` CTE 计算一次 `parsed_trans_time`。
- ISO 日期（以 `YYYY-M-D` 开头）替换 `T` 分隔符并按 `YYYY-MM-DD HH24:MI:SS` 解析。
- 带 AM/PM 的月/日日期先移除小数秒、将零点小时变为 `12`，再按 `MM/DD/YYYY HH12:MI:SS AM` 解析。
- 其余月/日日期移除小数秒后按 `MM/DD/YYYY HH24:MI:SS` 解析。
- Auth source 投影、时间窗口过滤及卡片筛选都使用 `parsed_trans_time`，保持逻辑一致。
- Qbit card 查询先从 Auth 解析 CTE 中选出时间窗内去重的 Card Proxy，再与卡表 join；避免对卡表每一行执行相关时间解析 `EXISTS`。
- 不改变字段输出、时间窗口、关联条件和目标表写入逻辑。
- 原解析掩码仅精确到秒，因此移除小数秒不会降低 `auth_time` 既有精度。
- `00:... AM` 转成等价的 `12:... AM`，保持午夜时刻含义。

## 范围

- 仅修改 `flink/quantum-v2/bb/batch/dwm_online_bb_card_auth_detail_v2-batch-sql.sql`。
- 不修改 CDC 脚本或成本核算 SQL；它们不在本次批处理任务范围内。

## 验证

- 检查 Auth source 和卡片筛选查询都包含相同的三格式解析分支，且过滤使用解析后的时间字段。
- 确认 Qbit card 查询按去重后的有效 Card Proxy 集合 join，且时间窗边界不变。
- 检查差异仅涉及时间解析表达式及文件头 `Updated Time`。
- 在具备目标库访问条件时，用实际月表样本分别确认两种时间格式均可解析。

## 评审事项

- 确认 ISO、带 AM/PM 和 24 小时格式各自进入预期的解析分支。
- 确认有/无毫秒与 `0`/`00` 小时值能在对应格式分支中归一化。
- 确认变更仅应用到批处理导入脚本。
